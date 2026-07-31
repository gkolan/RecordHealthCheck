/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for AccountOpenOpportunityHealthCheck — the Apex example that fails when
 * any open Opportunity is simultaneously stale, missing Next Step, and not
 * closing this quarter.
 */
@IsTest
private class AccountOpenOpportunityHealthCheckTest {
  @IsTest
  static void noOpenOpportunitiesPasses() {
    Account account = new Account(Name = 'RHC Opp Health None');
    insert account;

    RecordHealthCheckResult result = evaluate(account.Id, null);

    System.assertEquals('PASS', result.status);
    System.assertEquals('0', result.actualValue);
    System.assertEquals('0', result.expectedValue);
  }

  @IsTest
  static void healthyOpenOpportunityPasses() {
    Account account = new Account(Name = 'RHC Opp Health Healthy');
    insert account;

    Date inQuarter = AccountOpenOpportunityHealthCheck.getQuarterStart(
      Date.today()
    );
    insert new Opportunity(
      AccountId = account.Id,
      Name = 'Healthy deal',
      StageName = 'Prospecting',
      NextStep = 'Schedule demo',
      CloseDate = inQuarter
    );

    RecordHealthCheckResult result = evaluate(account.Id, null);

    System.assertEquals(
      'PASS',
      result.status,
      'A deal with a Next Step closing this quarter is healthy.'
    );
    System.assertEquals('0', result.actualValue);
    System.assertEquals('0', result.expectedValue);
  }

  @IsTest
  static void unhealthyOpenOpportunityFails() {
    Account account = new Account(Name = 'RHC Opp Health Unhealthy');
    insert account;

    // No Next Step, closing far in the future, and (by default) no activity
    // stale, so the deal is unhealthy.
    insert new Opportunity(
      AccountId = account.Id,
      Name = 'Neglected deal',
      StageName = 'Prospecting',
      CloseDate = Date.today().addYears(2)
    );

    RecordHealthCheckResult result = evaluate(account.Id, null);

    System.assertEquals('FAIL', result.status);
    System.assertEquals('1', result.actualValue);
    System.assertEquals('0', result.expectedValue);
  }

  @IsTest
  static void staleDaysParametersFallBackSafely() {
    Account account = new Account(Name = 'RHC Opp Health Parameters');
    insert account;

    for (
      Map<String, Object> parameters : new List<Map<String, Object>>{
        new Map<String, Object>(),
        new Map<String, Object>{ 'staleDays' => null },
        new Map<String, Object>{ 'staleDays' => 0 },
        new Map<String, Object>{ 'staleDays' => 3651 },
        new Map<String, Object>{ 'staleDays' => 'not-a-number' },
        new Map<String, Object>{ 'staleDays' => 1 }
      }
    ) {
      System.assertEquals(
        'PASS',
        evaluate(account.Id, parameters).status,
        'Parameter parsing should never prevent evaluation.'
      );
    }
  }

  @IsTest
  static void isUnhealthyEvaluatesEachCriterion() {
    Date staleCutoff = Date.today().addDays(-30);
    Date quarterStart = AccountOpenOpportunityHealthCheck.getQuarterStart(
      Date.today()
    );
    Date quarterEnd = quarterStart.addMonths(3).addDays(-1);

    // LastActivityDate is a read-only system field and cannot be assigned in
    // Apex; a freshly constructed Opportunity already has it null, which counts
    // as stale.
    Opportunity unhealthy = new Opportunity(
      NextStep = null,
      CloseDate = quarterStart.addMonths(6)
    );
    System.assertEquals(
      true,
      AccountOpenOpportunityHealthCheck.isUnhealthy(
        unhealthy,
        staleCutoff,
        quarterStart,
        quarterEnd
      )
    );

    // A Next Step alone is enough to make it healthy (AND logic).
    Opportunity hasNextStep = new Opportunity(
      NextStep = 'Follow up',
      CloseDate = quarterStart.addMonths(6)
    );
    System.assertEquals(
      false,
      AccountOpenOpportunityHealthCheck.isUnhealthy(
        hasNextStep,
        staleCutoff,
        quarterStart,
        quarterEnd
      )
    );

    Opportunity explicitlyStale = (Opportunity) JSON.deserialize(
      '{"attributes":{"type":"Opportunity"},"LastActivityDate":"' +
        String.valueOf(staleCutoff.addDays(-1)) +
        '","CloseDate":"' +
        String.valueOf(quarterEnd.addDays(1)) +
        '"}',
      Opportunity.class
    );
    System.assertEquals(
      true,
      AccountOpenOpportunityHealthCheck.isUnhealthy(
        explicitlyStale,
        staleCutoff,
        quarterStart,
        quarterEnd
      ),
      'An activity date before the stale cutoff should count as stale.'
    );
  }

  @IsTest
  static void getQuarterStartReturnsFirstDayOfQuarter() {
    System.assertEquals(
      Date.newInstance(2026, 1, 1),
      AccountOpenOpportunityHealthCheck.getQuarterStart(
        Date.newInstance(2026, 2, 14)
      )
    );
    System.assertEquals(
      Date.newInstance(2026, 10, 1),
      AccountOpenOpportunityHealthCheck.getQuarterStart(
        Date.newInstance(2026, 12, 31)
      )
    );
  }

  /**
   * The check is bulk, so a single-record assertion is a scope of one. Mapped
   * back onto the 1.x shape so the existing assertions stay readable.
   */
  private static RecordHealthCheckResult evaluate(
    Id recordId,
    Map<String, Object> parameters
  ) {
    RecordHealthCheckOutcome outcome = new AccountOpenOpportunityHealthCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          new List<Id>{ recordId },
          parameters,
          'Open_Opportunities_Are_Healthy',
          null,
          null
        )
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
}
