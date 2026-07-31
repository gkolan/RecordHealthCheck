/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * A hands-on tour of the 2.0 extension contract, meant to be run from anonymous
 * Apex against a scratch org so the guarantees can be watched rather than read.
 *
 *   RecordHealthCheckContractDemo.runAll();
 *
 * Every scenario creates its own Accounts and rolls them back at the end, so it
 * is safe to run repeatedly. Output goes to the debug log.
 *
 * This class is a demonstration harness, not part of the framework. Nothing in
 * the runtime path depends on it.
 */
public with sharing class RecordHealthCheckContractDemo {
  private static List<String> transcript = new List<String>();

  // ─── Demonstration checks ──────────────────────────────────────────────────

  /** Conforming: one query for the whole scope, loop does arithmetic only. */
  public class ContactCountCheck implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      List<Id> recordIds = scope.recordIds;
      Map<Id, Integer> counts = new Map<Id, Integer>();
      for (Id recordId : recordIds) {
        counts.put(recordId, 0); // zero is a real answer, not an absent one
      }
      for (AggregateResult row : [
        SELECT AccountId accountId, COUNT(Id) total
        FROM Contact
        WHERE AccountId IN :recordIds
        WITH USER_MODE
        GROUP BY AccountId
      ]) {
        counts.put((Id) row.get('accountId'), (Integer) row.get('total'));
      }

      RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(1);
      Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : recordIds) {
        Integer total = counts.get(recordId);
        results.put(
          recordId,
          (total >= 1
              ? RecordHealthCheckOutcome.pass('HAS_CONTACTS')
              : RecordHealthCheckOutcome.fail('NO_CONTACTS'))
            .withFound(RecordHealthCheckValue.ofCount(total))
            .withComparison('GREATER_THAN_OR_EQUAL', expected)
        );
      }
      return results;
    }
  }

  /** Non-conforming: satisfies the signature, queries inside the loop anyway. */
  public class QueryInLoopCheck implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        Integer total = [
          SELECT COUNT()
          FROM Contact
          WHERE AccountId = :recordId
          WITH USER_MODE
        ];
        results.put(recordId, RecordHealthCheckOutcome.pass('COUNTED'));
      }
      return results;
    }
  }

  /** Hostile: changes a record it was only asked to inspect. */
  public class MutatingCheck implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update new Account(Id = scope.recordIds[0], Rating = 'Hot');
      Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        results.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return results;
    }
  }

  /** Hostile and subtle: changes a record, then throws to cover its tracks. */
  public class MutateThenThrowCheck implements RecordHealthCheckRule {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update new Account(Id = scope.recordIds[0], Rating = 'Hot');
      throw new IllegalArgumentException('Something went wrong, honest.');
    }
  }

  /** Answers about a record it was never handed. */
  public class SmugglingCheck implements RecordHealthCheckRule {
    public Id foreignId;
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        results.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      results.put(foreignId, RecordHealthCheckOutcome.fail('LEAKED'));
      return results;
    }
  }

  // ─── Entry point ───────────────────────────────────────────────────────────

  public static void runAll() {
    transcript.clear();
    Savepoint sp = Database.setSavepoint();
    try {
      scopeSizeDoesNotChangeQueryCost();
      nonConformingCheckIsVisibleInTheNumbers();
      mutationIsBlockedAndRolledBack();
      mutateThenThrowStillReportsTheMutation();
      smuggledRecordFailsTheWholeScope();
      droppedRecordBecomesAnError();
      typedValuesHaveOneStoredForm();
    } finally {
      Database.rollback(sp);
    }
    System.debug(LoggingLevel.ERROR, '\n' + String.join(transcript, '\n'));
  }

  // ─── Scenarios ─────────────────────────────────────────────────────────────

  private static void scopeSizeDoesNotChangeQueryCost() {
    header('1. Scope size does not change query cost');
    List<Id> ids = makeAccounts(50, true);

    Integer before = Limits.getQueries();
    dispatch(new ContactCountCheck(), new List<Id>{ ids[0] });
    Integer one = Limits.getQueries() - before;

    before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> many = dispatch(
      new ContactCountCheck(),
      ids
    );
    Integer fifty = Limits.getQueries() - before;

    line('   scope of  1 -> ' + one + ' quer' + (one == 1 ? 'y' : 'ies'));
    line('   scope of 50 -> ' + fifty + ' quer' + (fifty == 1 ? 'y' : 'ies'));
    line('   outcomes returned: ' + many.size());
    verdict(
      one == fifty,
      'the record count has left the equation',
      'query cost still tracks scope size'
    );
  }

  private static void nonConformingCheckIsVisibleInTheNumbers() {
    header(
      '2. A non-conforming check satisfies the signature but not the intent'
    );
    List<Id> ids = makeAccounts(10, false);

    Integer before = Limits.getQueries();
    dispatch(new QueryInLoopCheck(), new List<Id>{ ids[0] });
    Integer one = Limits.getQueries() - before;

    before = Limits.getQueries();
    dispatch(new QueryInLoopCheck(), ids);
    Integer ten = Limits.getQueries() - before;

    line('   scope of  1 -> ' + one + ' quer' + (one == 1 ? 'y' : 'ies'));
    line('   scope of 10 -> ' + ten + ' queries');
    line('   The contract cannot catch this. Measurement can, and does.');
    verdict(
      ten > one,
      'growth is visible, which is what the harness asserts against',
      'expected query growth to show'
    );
  }

  private static void mutationIsBlockedAndRolledBack() {
    header(
      '3. A check that changes a record is stopped, and the change undone'
    );
    List<Id> ids = makeAccounts(1, false);

    String reason;
    Boolean reversible;
    try {
      dispatch(new MutatingCheck(), ids);
      reason = 'NOTHING THROWN';
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      reason = ex.reasonCode + ' (' + ex.effect + ')';
      reversible = ex.reversible;
    }

    Account after = [SELECT Rating FROM Account WHERE Id = :ids[0]];
    line('   outcome: ' + reason);
    line('   reversible: ' + reversible);
    line('   Rating after the run: ' + after.Rating);
    verdict(
      after.Rating == null,
      'the mutation did not survive',
      'THE MUTATION SURVIVED'
    );
  }

  private static void mutateThenThrowStillReportsTheMutation() {
    header('4. Mutating and then throwing does not hide the mutation');
    line('   Without the fence in a finally, the exception would become tidy');
    line('   ERROR rows and the DML would commit alongside them.');
    List<Id> ids = makeAccounts(1, false);

    String reason;
    try {
      dispatch(new MutateThenThrowCheck(), ids);
      reason = 'NOTHING THROWN';
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      reason = ex.reasonCode;
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reason = ex.reasonCode + ' <- the exception won, which is wrong';
    }

    Account after = [SELECT Rating FROM Account WHERE Id = :ids[0]];
    line('   outcome: ' + reason);
    line('   Rating after the run: ' + after.Rating);
    verdict(
      reason == RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED &&
        after.Rating == null,
      'the side effect outranked the exception it hid behind',
      'the exception masked the mutation'
    );
  }

  private static void smuggledRecordFailsTheWholeScope() {
    header('5. Answering about an unrequested record fails the whole scope');
    List<Id> inScope = makeAccounts(3, false);
    List<Id> outside = makeAccounts(1, false);

    SmugglingCheck check = new SmugglingCheck();
    check.foreignId = outside[0];

    String reason;
    try {
      dispatch(check, inScope);
      reason = 'NOTHING THROWN';
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reason = ex.reasonCode;
    }
    line('   outcome: ' + reason);
    line('   Fail-closed on purpose: a check confused about which records it');
    line('   was handed is not one whose other answers should be believed.');
    verdict(
      reason == RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY,
      'one stray key invalidated all three results',
      'the stray key was tolerated'
    );
  }

  private static void droppedRecordBecomesAnError() {
    header('6. A dropped record becomes a visible ERROR, not a silent absence');
    List<Id> ids = makeAccounts(3, true);

    // A check that simply forgets the first record.
    Map<Id, RecordHealthCheckOutcome> partial = new Map<Id, RecordHealthCheckOutcome>();
    for (Integer i = 1; i < ids.size(); i++) {
      partial.put(ids[i], RecordHealthCheckOutcome.pass('OK'));
    }

    Map<Id, RecordHealthCheckOutcome> completed = dispatch(
      new ForgetfulCheck(partial),
      ids
    );
    line('   records requested: ' + ids.size());
    line('   records answered by the check: ' + partial.size());
    line('   records in the engine result: ' + completed.size());
    line(
      '   status of the dropped record: ' +
        completed.get(ids[0]).status +
        ' / ' +
        completed.get(ids[0]).reasonCode
    );
    verdict(
      completed.size() == 3 &&
        completed.get(ids[0]).status == RecordHealthCheckStatus.ERROR,
      'the gap was filled rather than left to vanish from the report',
      'the dropped record disappeared'
    );
  }

  private static void typedValuesHaveOneStoredForm() {
    header('7. Every value has exactly one stored format');
    line('   COUNT     ' + RecordHealthCheckValue.ofCount(6).storedValue);
    line(
      '   NUMBER    ' + RecordHealthCheckValue.ofNumber(1234.50).storedValue
    );
    line('   BOOLEAN   ' + RecordHealthCheckValue.ofBoolean(true).storedValue);
    line(
      '   DATE      ' +
      RecordHealthCheckValue.ofDate(Date.newInstance(2026, 7, 31)).storedValue
    );
    line(
      '   DATETIME  ' +
      RecordHealthCheckValue.ofDateTime(
          Datetime.newInstanceGmt(2026, 7, 31, 9, 30, 0)
        )
        .storedValue
    );
    line(
      '   LIST      ' +
      String.join(
        RecordHealthCheckValue.ofList(new List<String>{ 'a', 'b' })
          .storedValues,
        ', '
      )
    );
    line('   No consumer has to guess how a value was encoded.');
    verdict(true, 'one format per type', '');
  }

  /** Returns a fixed, deliberately incomplete answer. */
  private class ForgetfulCheck implements RecordHealthCheckRule {
    private Map<Id, RecordHealthCheckOutcome> canned;
    private ForgetfulCheck(Map<Id, RecordHealthCheckOutcome> canned) {
      this.canned = canned;
    }
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return canned;
    }
  }

  // ─── Plumbing ──────────────────────────────────────────────────────────────

  private static Map<Id, RecordHealthCheckOutcome> dispatch(
    RecordHealthCheckRule check,
    List<Id> recordIds
  ) {
    return RecordHealthCheckPluginDispatch.run(
      check,
      new RecordHealthCheckScope(
        'Account',
        recordIds,
        new Map<String, Object>(),
        'Demo_Rule',
        'Demo_Set',
        'demo-run'
      )
    );
  }

  private static List<Id> makeAccounts(Integer count, Boolean withContacts) {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      accounts.add(new Account(Name = 'RHC Demo ' + i));
    }
    insert accounts;

    if (withContacts) {
      List<Contact> contacts = new List<Contact>();
      // Deliberately leave the first Account childless so the seeded-zero path
      // is exercised rather than assumed.
      for (Integer i = 1; i < accounts.size(); i++) {
        contacts.add(
          new Contact(LastName = 'Demo ' + i, AccountId = accounts[i].Id)
        );
      }
      if (!contacts.isEmpty()) {
        insert contacts;
      }
    }
    return new List<Id>(new Map<Id, Account>(accounts).keySet());
  }

  private static void header(String text) {
    transcript.add('\n' + text);
    transcript.add('   ' + '-'.repeat(Math.min(text.length(), 66)));
  }

  private static void line(String text) {
    transcript.add(text);
  }

  private static void verdict(Boolean held, String good, String bad) {
    transcript.add(held ? '   OK   ' + good : '   FAIL ' + bad);
  }
}
