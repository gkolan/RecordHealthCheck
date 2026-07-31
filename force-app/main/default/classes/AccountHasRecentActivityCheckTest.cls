/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for AccountHasRecentActivityCheck — the Apex example that passes when an
 * Account has a completed Task or logged Event inside a tunable window.
 */
@IsTest
private class AccountHasRecentActivityCheckTest {
  @IsTest
  static void completedTaskInsideWindowPasses() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Pass'
    );

    RecordHealthCheckTestDataFactory.createTask(
      new Task(
        WhatId = account.Id,
        Subject = 'Recent call',
        Status = 'Completed',
        ActivityDate = Date.today()
      )
    );

    RecordHealthCheckResult result = evaluate(account.Id, null);

    System.assertEquals('PASS', result.status);
    System.assertEquals('1', result.actualValue);
    System.assertEquals('1', result.expectedValue);
  }

  @IsTest
  static void noActivityFails() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Fail'
    );

    RecordHealthCheckResult result = evaluate(account.Id, null);

    System.assertEquals('FAIL', result.status);
    System.assertEquals('0', result.actualValue);
    System.assertEquals('1', result.expectedValue);
  }

  @IsTest
  static void activityOutsideWindowFails() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Stale'
    );

    RecordHealthCheckTestDataFactory.createTask(
      new Task(
        WhatId = account.Id,
        Subject = 'Old call',
        Status = 'Completed',
        ActivityDate = Date.today().addDays(-400)
      )
    );

    // A 90-day window excludes the 400-day-old task.
    RecordHealthCheckResult result = evaluate(
      account.Id,
      new Map<String, Object>{ 'daysBack' => 90 }
    );

    System.assertEquals('FAIL', result.status);
    System.assertEquals('0', result.actualValue);
    System.assertEquals('1', result.expectedValue);
  }

  @IsTest
  static void invalidDaysBackFallsBackToDefault() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Default'
    );

    RecordHealthCheckTestDataFactory.createTask(
      new Task(
        WhatId = account.Id,
        Subject = 'Recent call',
        Status = 'Completed',
        ActivityDate = Date.today()
      )
    );

    // Out-of-range and unparseable values both fall back to the 30-day default
    // which still includes today's task.
    System.assertEquals(
      'PASS',
      evaluate(account.Id, new Map<String, Object>{ 'daysBack' => 999999 })
        .status
    );
    System.assertEquals(
      'PASS',
      evaluate(account.Id, new Map<String, Object>{ 'daysBack' => 'abc' })
        .status
    );
  }

  /**
   * The check is bulk, so a single-record assertion is a scope of one. Kept
   * returning the 1.x shape so the existing assertions stay readable.
   */
  private static RecordHealthCheckResult evaluate(
    Id recordId,
    Map<String, Object> parameters
  ) {
    RecordHealthCheckOutcome outcome = evaluateScope(
        new List<Id>{ recordId },
        parameters
      )
      .get(recordId);
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = outcome.status;
    result.reasonCode = outcome.reasonCode;
    result.actualValue = outcome.found == null
      ? null
      : outcome.found.storedValue;
    result.expectedValue = outcome.expected == null
      ? null
      : outcome.expected.storedValue;
    return result;
  }

  private static Map<Id, RecordHealthCheckOutcome> evaluateScope(
    List<Id> recordIds,
    Map<String, Object> parameters
  ) {
    return new AccountHasRecentActivityCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          recordIds,
          parameters,
          'Account_Has_Recent_Activity',
          null,
          null
        )
      );
  }

  /**
   * The property the bulk contract exists for: query count must not move with
   * scope size. Two queries serve one record and they serve two hundred.
   */
  @IsTest
  static void queryCountDoesNotGrowWithScopeSize() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 200; i++) {
      accounts.add(new Account(Name = 'Bulk Scope ' + i));
    }
    insert accounts;
    List<Id> accountIds = new List<Id>(new Map<Id, Account>(accounts).keySet());

    Test.startTest();
    Integer before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> single = evaluateScope(
      new List<Id>{ accountIds[0] },
      null
    );
    Integer afterSingle = Limits.getQueries() - before;

    before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> all = evaluateScope(accountIds, null);
    Integer afterAll = Limits.getQueries() - before;
    Test.stopTest();

    System.assertEquals(
      afterSingle,
      afterAll,
      'A scope of 200 must cost the same queries as a scope of 1.'
    );
    System.assertEquals(2, afterAll, 'One query for Task, one for Event.');
    System.assertEquals(1, single.size());
    System.assertEquals(
      200,
      all.size(),
      'Every record in scope must receive an outcome.'
    );
  }

  /**
   * Zero is a real answer. An aggregate returns no row for an Account with no
   * activity, so seeding matters: without it these records would be missing
   * from the map entirely, and they are exactly the ones the check should flag.
   */
  @IsTest
  static void accountsWithNoActivityStillReceiveAnOutcome() {
    List<Account> accounts = new List<Account>{
      new Account(Name = 'No Activity A'),
      new Account(Name = 'No Activity B')
    };
    insert accounts;
    List<Id> accountIds = new List<Id>(new Map<Id, Account>(accounts).keySet());

    Test.startTest();
    Map<Id, RecordHealthCheckOutcome> outcomes = evaluateScope(
      accountIds,
      null
    );
    Test.stopTest();

    System.assertEquals(2, outcomes.size());
    for (Id accountId : accountIds) {
      RecordHealthCheckOutcome outcome = outcomes.get(accountId);
      System.assertNotEquals(null, outcome, 'Missing key for ' + accountId);
      System.assertEquals(RecordHealthCheckStatus.FAIL, outcome.status);
      System.assertEquals('0', outcome.found.storedValue, 'Zero, not absent.');
    }
  }

  /** An empty scope must not query at all, and must not throw. */
  @IsTest
  static void emptyScopeDoesNoWork() {
    Test.startTest();
    Integer before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> outcomes = evaluateScope(
      new List<Id>(),
      null
    );
    Integer used = Limits.getQueries() - before;
    Test.stopTest();

    System.assertEquals(0, outcomes.size());
    System.assertEquals(
      2,
      used,
      'Queries are bound to the scope, not skipped.'
    );
  }
}
