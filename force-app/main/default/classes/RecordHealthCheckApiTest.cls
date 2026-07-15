/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckApiTest {
  @testSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @isTest
  static void runOneLinerReturnsAResult() {
    Account acct = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult result = RecordHealthCheck.runRule(
      'Account_DQ_BillingCity',
      acct.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'API should always return a result.');
    System.assertEquals(
      'Account_DQ_BillingCity',
      result.ruleDeveloperName,
      'Result should be for the requested check.'
    );
    System.assertNotEquals(
      null,
      result.status,
      'Result should carry a status.'
    );
  }

  @isTest
  static void runWithExplicitRunIdIsAccepted() {
    Account acct = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult correlated = RecordHealthCheck.runRule(
      'Account_DQ_BillingCity',
      acct.Id,
      'ticket-12345'
    );
    Test.stopTest();

    System.assertEquals('Account_DQ_BillingCity', correlated.ruleDeveloperName);
  }

  @isTest
  static void runSurfacesUnknownRuleAsReason() {
    Account acct = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult result = RecordHealthCheck.runRule(
      'No_Such_Check',
      acct.Id
    );
    Test.stopTest();

    System.assertEquals(
      'UNABLE_TO_EVALUATE',
      result.status,
      'Unknown config should be a clean UNABLE_TO_EVALUATE, not an exception.'
    );
    System.assertEquals('RULE_NOT_FOUND', result.reasonCode);
  }

  @isTest
  static void runSetReturnsVersionedCountsAndResults() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckSetResult response = RecordHealthCheck.runSet(
      'Account_Data_Quality',
      accountRecord.Id,
      'set-test-run'
    );
    Test.stopTest();

    System.assertEquals('1.0', response.contractVersion);
    System.assertEquals('set-test-run', response.runId);
    System.assert(
      response.results.size() > 0,
      'The Set must return its Rules.'
    );
    System.assertEquals(
      response.results.size(),
      response.passedCount +
        response.failedCount +
        response.skippedCount +
        response.unableCount +
        response.systemErrorCount,
      'Every result must appear in exactly one outcome count.'
    );
  }

  @isTest
  static void bulkRuleRunPreservesInputOrderAndVersion() {
    Account first = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Account second = RecordHealthCheckTestDataFactory.createAccount(
      'Second façade account'
    );

    Test.startTest();
    List<RecordHealthCheckResult> responses = RecordHealthCheck.runRule(
      'Account_DQ_BillingCity',
      new List<Id>{ first.Id, second.Id }
    );
    Test.stopTest();

    System.assertEquals(2, responses.size());
    System.assertEquals('1.0', responses[0].contractVersion);
    System.assertEquals('1.0', responses[1].contractVersion);
  }

  @isTest
  static void bulkRequestFailsBeforeRunningWhenEvaluationBudgetIsExceeded() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    List<Id> recordIds = new List<Id>();
    for (
      Integer index = 0;
      index <= RecordHealthCheck.MAX_EVALUATIONS_PER_CALL;
      index++
    ) {
      recordIds.add(accountRecord.Id);
    }

    Test.startTest();
    try {
      RecordHealthCheck.runRule('Account_DQ_BillingCity', recordIds);
      System.assert(
        false,
        'An over-budget request must fail before evaluation.'
      );
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(
        expected.getMessage().contains('too many checks'),
        'The caller receives stable, actionable budget guidance.'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void runRuleFlowActionReturnsOneAlignedResponsePerRequest() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunRuleFlowAction.Request request = new RecordHealthCheckRunRuleFlowAction.Request();
    request.ruleDeveloperName = 'Account_DQ_BillingCity';
    request.recordId = accountRecord.Id;

    Test.startTest();
    List<RecordHealthCheckRunRuleFlowAction.Response> responses = RecordHealthCheckRunRuleFlowAction.runRule(
      new List<RecordHealthCheckRunRuleFlowAction.Request>{ request }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals('1.0', responses[0].contractVersion);
    System.assertNotEquals(null, responses[0].status);
    System.assertNotEquals(null, responses[0].resultJson);
  }

  @isTest
  static void runSetFlowActionReturnsSetCounts() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
    setRequest.checkSetDeveloperName = 'Account_Data_Quality';
    setRequest.recordId = accountRecord.Id;

    Test.startTest();
    List<RecordHealthCheckRunSetFlowAction.Response> responses = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertNotEquals(null, responses[0].passedCount);
  }
}
