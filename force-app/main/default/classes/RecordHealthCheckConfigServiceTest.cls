/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckConfigServiceTest {
  @testSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @isTest
  static void getDefinitionResponseLoadsSettingsAndAppliesCheckLimit() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    RecordHealthCheckDefinitionResponse response = service.getDefinitionResponse(
      'Account_Data_Quality',
      accountRecord.Id
    );
    Test.stopTest();

    System.assertEquals('Account Data Quality', response.displayTitle);
    System.assertEquals('Automatic', response.triggerMode);
    System.assertEquals(
      'OnDemand',
      response.comparisonDisplay,
      'The Check Set ships with the OnDemand comparison default.'
    );
    System.assertNotEquals(null, response.checks);
    System.assert(response.checks.size() > 0, 'Expected at least one check.');
    System.assert(
      response.checks.size() <= 25,
      'Definitions must respect the framework check cap.'
    );
    System.assertEquals(
      response.totalAvailableCheckCount > response.checks.size(),
      response.checksOmittedByLimit
    );
  }

  @isTest
  static void validateRejectsUnrecognizedComparisonDisplay() {
    // A fully-valid Set except for an unrecognized ComparisonDisplay reaches the
    // strict validation branch. Blank is treated as the OnDemand default for
    // upgraded metadata, but non-blank unknown values still fail.
    Record_Health_Check_Set__mdt checkSet = new Record_Health_Check_Set__mdt(
      IsActive__c = true,
      ObjectApiName__c = 'Account',
      PassedChecksDisplay__c = 'SHOW_EACH_CHECK',
      SkippedChecksDisplay__c = 'SHOW_COUNT_ONLY',
      CardRunMode__c = 'RUN_ON_LOAD',
      CardRevealMode__c = 'ALL_AT_ONCE',
      FoundExpectedDisplay__c = 'Bogus'
    );
    // Account key prefix — no DML needed to get an Account-typed Id.
    Id accountId = '001000000000001AAA';

    try {
      new RecordHealthCheckConfigService()
        .validateCheckSetForDefinition(checkSet, 'Test_Set', accountId);
      System.assert(
        false,
        'Expected a ConfigException for a bad ComparisonDisplay.'
      );
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      System.assertEquals(
        RecordHealthCheckConfigService.RC_INVALID_CONFIG,
        ex.reasonCode
      );
      System.assert(
        ex.getMessage().contains('Found/Expected Display'),
        'Message should name the offending field: ' + ex.getMessage()
      );
    }
  }

  @isTest
  static void getDefinitionResponseRejectsObjectMismatch() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    try {
      service.getDefinitionResponse(
        'Account_Data_Quality',
        UserInfo.getUserId()
      );
      System.assert(false, 'Expected an object mismatch exception.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      System.assertEquals(
        RecordHealthCheckConfigService.RC_OBJECT_MISMATCH,
        ex.reasonCode
      );
    }
  }

  @isTest
  static void getDefinitionResponseRejectsMissingRecordContext() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    try {
      service.getDefinitionResponse('Account_Data_Quality', null);
      System.assert(false, 'Expected a missing record context exception.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      System.assertEquals(
        RecordHealthCheckConfigService.RC_NO_RECORD_CONTEXT,
        ex.reasonCode
      );
    }
  }

  @isTest
  static void validateRuleForEvaluationReturnsUnableForInvalidQueryRule() {
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Invalid_Query_Test',
      MasterLabel = 'Invalid Query Test',
      CheckTitle__c = 'Invalid Query Test',
      EvaluationType__c = 'QUERY',
      FailureSeverity__c = 'WARNING',
      ComparisonOperator__c = 'EQUALS',
      QueryResultHandling__c = 'ONE_RESULT',
      ExpectedValueSource__c = 'FIXED_VALUE',
      ExpectedFixedValue__c = 'Hot',
      FailureMessage__c = 'Invalid query failed.',
      EvaluationOrder__c = 10
    );

    RecordHealthCheckResult result = new RecordHealthCheckConfigService()
      .validateRuleForEvaluation(rule);

    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals('INVALID_SOQL_TEMPLATE', result.reasonCode);
    System.assertEquals('Invalid_Query_Test', result.checkDeveloperName);
  }
}
