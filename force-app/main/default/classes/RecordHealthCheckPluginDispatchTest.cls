/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Adversarial tests for the extension boundary.
 *
 * A custom Rule is third-party code running inside the framework's transaction.
 * These tests assume it is hostile rather than merely careless, because the
 * guarantee the product sells is that a health check never changes anything,
 * and a guarantee that only holds for well-behaved code is not a guarantee.
 *
 * The cases below are the ways a check could break that promise and have the
 * damage stick.
 */
@IsTest
private class RecordHealthCheckPluginDispatchTest {
  // ─── Test doubles ──────────────────────────────────────────────────────────

  /** Behaves. The control case. */
  private class WellBehavedRule implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  /** Mutates a record, which is the one thing the framework promises never happens. */
  private class MutatingRule implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update new Account(Id = scope.recordIds[0], Rating = 'Hot');
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  /**
   * The dangerous one. Mutates, then throws, so an engine that converts
   * exceptions into results before checking for side effects would commit the
   * mutation and report a tidy ERROR row alongside it.
   */
  private class MutateThenThrowRule implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update new Account(Id = scope.recordIds[0], Rating = 'Hot');
      throw new IllegalArgumentException('Nothing to see here.');
    }
  }

  /** Throws, but changes nothing. Attributable to the rule, so it may become results. */
  private class ThrowingRule implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      throw new IllegalArgumentException('Boom.');
    }
  }

  /** Answers about a record it was never asked about. */
  private class ExtraKeyRule implements RecordHealthCheckRule {
    public Id foreignId;
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      out.put(foreignId, RecordHealthCheckOutcome.fail('SMUGGLED'));
      return out;
    }
  }

  /** Silently drops a record, which without validation would simply vanish from the report. */
  private class SkippingRule implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      List<Id> ids = scope.recordIds;
      for (Integer i = 1; i < ids.size(); i++) {
        out.put(ids[i], RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  /** Returns nothing at all. */
  private class NullRule implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return null;
    }
  }

  /** Tries to keep the scope and mutate it later. */
  private class ScopeHoardingRule implements RecordHealthCheckRule {
    public RecordHealthCheckScope captured;
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      captured = scope;
      scope.recordIds.clear();
      scope.parameters.put('injected', 'yes');
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private static List<Account> makeAccounts(Integer count) {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      accounts.add(new Account(Name = 'Dispatch ' + i));
    }
    insert accounts;
    return accounts;
  }

  private static RecordHealthCheckScope scopeFor(List<Account> accounts) {
    return new RecordHealthCheckScope(
      'Account',
      new List<Id>(new Map<Id, Account>(accounts).keySet()),
      null,
      'Test_Rule',
      'Test_Set',
      'run-test'
    );
  }

  // ─── Side effects ──────────────────────────────────────────────────────────

  @IsTest
  static void mutatingRuleIsStoppedAndTheChangeIsRolledBack() {
    List<Account> accounts = makeAccounts(1);
    Id accountId = accounts[0].Id;

    Test.startTest();
    Boolean threw = false;
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(
        new MutatingRule(),
        scopeFor(accounts)
      );
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      threw = true;
      reasonCode = ex.reasonCode;
      System.assertEquals('DML', ex.effect);
      System.assertEquals(true, ex.reversible);
    }
    Test.stopTest();

    System.assertEquals(true, threw, 'A check that performs DML must fail.');
    System.assertEquals(
      RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
      reasonCode
    );
    // The dispatcher throws rather than returning, which is what lets the
    // caller abandon the transaction. Verified here by the rollback the test
    // framework performs around the assertion above.
    System.assertEquals(
      null,
      [SELECT Rating FROM Account WHERE Id = :accountId].Rating,
      'The mutation must not survive.'
    );
  }

  /**
   * The precedence case, and the reason the fence lives in a `finally`.
   *
   * If the exception were handled first, it would be converted into ordinary
   * ERROR results, those results would be returned normally, and the DML the
   * check performed on its way out would commit with them.
   */
  @IsTest
  static void mutateThenThrowReportsTheSideEffectNotTheException() {
    List<Account> accounts = makeAccounts(1);

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(
        new MutateThenThrowRule(),
        scopeFor(accounts)
      );
      System.assert(false, 'Expected the run to fail.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      reasonCode = ex.reasonCode;
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      System.assert(
        false,
        'The exception must not outrank the side effect it hid behind.'
      );
    }
    Test.stopTest();

    System.assertEquals(
      RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
      reasonCode,
      'A side effect outranks an exception thrown after it.'
    );
  }

  @IsTest
  static void throwingWithoutSideEffectsBecomesAnAttributableFailure() {
    List<Account> accounts = makeAccounts(1);

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(
        new ThrowingRule(),
        scopeFor(accounts)
      );
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reasonCode = ex.reasonCode;
    }
    Test.stopTest();

    System.assertEquals(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      reasonCode,
      'No prohibited effect, so the throw is safe to report as a result.'
    );
  }

  @IsTest
  static void wellBehavedRuleIsNotFlaggedAsASideEffect() {
    List<Account> accounts = makeAccounts(25);

    Test.startTest();
    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      new WellBehavedRule(),
      scopeFor(accounts)
    );
    Test.stopTest();

    System.assertEquals(
      25,
      outcomes.size(),
      'The fence must not fire on a check that behaves.'
    );
  }

  // ─── Completeness ──────────────────────────────────────────────────────────

  /**
   * Fail-closed on purpose. A check confused about which records it was handed
   * is not one whose other answers should be believed, so one stray key
   * invalidates the whole scope rather than being quietly dropped.
   */
  @IsTest
  static void answeringAboutAnUnrequestedRecordFailsTheWholeScope() {
    List<Account> inScope = makeAccounts(3);
    List<Account> outOfScope = makeAccounts(1);

    ExtraKeyRule rule = new ExtraKeyRule();
    rule.foreignId = outOfScope[0].Id;

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(rule, scopeFor(inScope));
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reasonCode = ex.reasonCode;
    }
    Test.stopTest();

    System.assertEquals(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY,
      reasonCode
    );
  }

  /** A dropped record becomes a visible ERROR rather than silently disappearing. */
  @IsTest
  static void aDroppedRecordBecomesAnErrorForThatRecordOnly() {
    List<Account> accounts = makeAccounts(4);
    RecordHealthCheckScope scope = scopeFor(accounts);
    Id dropped = scope.recordIds[0];

    Test.startTest();
    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      new SkippingRule(),
      scope
    );
    Test.stopTest();

    System.assertEquals(4, outcomes.size(), 'Every requested Id is answered.');
    System.assertEquals(
      RecordHealthCheckStatus.ERROR,
      outcomes.get(dropped).status
    );
    System.assertEquals(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
      outcomes.get(dropped).reasonCode
    );
    for (Integer i = 1; i < scope.recordIds.size(); i++) {
      System.assertEquals(
        RecordHealthCheckStatus.PASS,
        outcomes.get(scope.recordIds[i]).status,
        'One bad record must not cost the others their verdicts.'
      );
    }
  }

  @IsTest
  static void returningNothingIsAContractViolation() {
    List<Account> accounts = makeAccounts(2);

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(new NullRule(), scopeFor(accounts));
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reasonCode = ex.reasonCode;
    }
    Test.stopTest();

    System.assertEquals(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
      reasonCode
    );
  }

  // ─── Scope integrity ───────────────────────────────────────────────────────

  /** A check cannot reach engine state through the scope it was handed. */
  @IsTest
  static void mutatingTheScopeDoesNotAffectTheEngine() {
    List<Account> accounts = makeAccounts(3);
    RecordHealthCheckScope scope = scopeFor(accounts);
    ScopeHoardingRule rule = new ScopeHoardingRule();

    Test.startTest();
    // The rule clears the list and injects a parameter, but both act on copies,
    // so its own loop still sees all three records and it returns a complete
    // result. That it succeeds is the point: the tampering had no effect at all.
    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      rule,
      scope
    );
    Test.stopTest();

    System.assertEquals(
      3,
      outcomes.size(),
      'All three records still answered.'
    );
    System.assertEquals(3, scope.recordIds.size(), 'The scope is unchanged.');
    System.assertEquals(
      false,
      scope.parameters.containsKey('injected'),
      'Parameters cannot be injected into engine state.'
    );
  }

  /** A Rule is authored against one object, so a mixed scope is rejected before dispatch. */
  @IsTest
  static void mixedObjectTypesAreRejectedAtScopeConstruction() {
    Account account = new Account(Name = 'Mixed');
    insert account;
    Contact contact = new Contact(LastName = 'Mixed');
    insert contact;

    Test.startTest();
    Boolean threw = false;
    try {
      new RecordHealthCheckScope(
        'Account',
        new List<Id>{ account.Id, contact.Id },
        null,
        'Test_Rule',
        null,
        null
      );
    } catch (RecordHealthCheckScope.RecordHealthCheckScopeException ex) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw, 'A scope must not mix object types.');
  }

  /** Duplicates collapse, first occurrence wins, and order is preserved. */
  @IsTest
  static void duplicateIdsAreDeduplicatedPreservingOrder() {
    List<Account> accounts = makeAccounts(3);
    List<Id> ids = new List<Id>(new Map<Id, Account>(accounts).keySet());

    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ ids[2], ids[0], ids[2], ids[1], ids[0] },
      null,
      'Test_Rule',
      null,
      null
    );

    System.assertEquals(3, scope.size());
    System.assertEquals(ids[2], scope.recordIds[0]);
    System.assertEquals(ids[0], scope.recordIds[1]);
    System.assertEquals(ids[1], scope.recordIds[2]);
  }

  @IsTest
  static void nullIdsAreIgnoredRatherThanProducingAPhantomResult() {
    List<Account> accounts = makeAccounts(1);
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ accounts[0].Id, null, null },
      null,
      'Test_Rule',
      null,
      null
    );
    System.assertEquals(1, scope.size());
  }
}
