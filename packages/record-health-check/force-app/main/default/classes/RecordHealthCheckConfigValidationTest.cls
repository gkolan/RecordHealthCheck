/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckConfigValidationTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @IsTest
  static void configServiceCoversRemainingValidationBranches() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Record_Health_Check_Set__mdt invalidObject = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Invalid_Object',
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Missing__c'
      }
    );
    assertConfigException(
      service,
      invalidObject,
      accountRecord.Id,
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check_Rule__mdt rule = baseRule('Missing_Basics', 'FORMULA');
    rule.CheckTitle__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    rule = baseRule('Missing_Failure', 'FORMULA');
    rule.FailureMessage__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    rule = baseRule('App_Formula_Missing', 'FORMULA');
    rule.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    rule.ApplicabilityFormula__c = null;
    assertUnable(service.validateRuleForEvaluation(rule), 'INVALID_FORMULA');

    rule = baseRule('App_Soql_Missing', 'FORMULA');
    rule.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );
    rule.ApplicabilityCountQuery__c = 'SELECT Id FROM Account';
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );
    rule.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Contact';
    assertUnable(service.validateRuleForEvaluation(rule), 'INVALID_OPERATOR');
    rule.ApplicabilityCountOperator__c = 'Around';
    assertUnable(service.validateRuleForEvaluation(rule), 'INVALID_OPERATOR');
    rule.ApplicabilityCountOperator__c = 'GREATER_THAN';
    assertUnable(
      service.validateRuleForEvaluation(rule),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    rule = queryRule('Query_Missing_Primary_Field');
    rule.SourceQueryField__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );
    rule = queryRule('Query_Invalid_Mode');
    rule.QueryResultHandling__c = 'Nope';
    assertUnable(
      service.validateRuleForEvaluation(rule),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    rule = queryRule('Query_Invalid_Source');
    rule.ExpectedValueSource__c = 'Magic';
    assertUnable(
      service.validateRuleForEvaluation(rule),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    rule = queryRule('Query_Result_Missing_Field');
    rule.ExpectedValueSource__c = 'COMPARISON_QUERY';
    rule.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    rule.ComparisonQueryField__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );
    rule = queryRule('Query_List_Missing_Field');
    rule.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    rule.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    rule.SourceQuery__c = null;
    rule.FindInListFormula__c = 'BillingCity';
    rule.ComparisonQuery__c = 'SELECT MailingCity FROM Contact';
    rule.ComparisonQueryField__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );

    rule = apexRule('Apex_Invalid_Class', 'String', '{}');
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'APEX_CLASS_NOT_FOUND'
    );
    rule = apexRule('Apex_Invalid_Json', 'AccountHasRecentActivityCheck', '[]');
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_APEX_PARAMETERS'
    );

    rule = validDualRule('Dual_Missing_Primary_Field');
    rule.SourceQuery__c = 'SELECT BillingCity FROM Account';
    rule.SourceQueryField__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );
    rule = validDualRule('Dual_Missing_Comparison_Field');
    rule.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    rule.ComparisonQueryField__c = null;
    assertUnable(
      service.validateRuleForEvaluation(rule),
      'INVALID_SOQL_TEMPLATE'
    );
  }
  @IsTest
  static void checkSetValidationRejectsEveryInvalidSetting() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    Account record = RecordHealthCheckTestDataFactory.getHealthyAccount();
    List<Record_Health_Check_Set__mdt> invalidSets = new List<Record_Health_Check_Set__mdt>{
      validSet('Inactive', false),
      validSet('Blank_Object', true),
      validSet('Passed_Display', true),
      validSet('Skipped_Display', true),
      validSet('Run_Mode', true),
      validSet('Reveal_Mode', true)
    };
    invalidSets[1].ObjectApiName__c = null;
    invalidSets[2].PassedChecksDisplay__c = 'INVALID';
    invalidSets[3].SkippedChecksDisplay__c = 'INVALID';
    invalidSets[4].CardRunMode__c = 'INVALID';
    invalidSets[5].CardRevealMode__c = 'INVALID';

    Test.startTest();
    for (Record_Health_Check_Set__mdt checkSet : invalidSets) {
      assertConfigException(
        service,
        checkSet,
        record.Id,
        checkSet.DeveloperName == 'Inactive'
          ? RecordHealthCheckConfigService.RC_CONFIG_INACTIVE
          : RecordHealthCheckConfigService.RC_INVALID_CONFIG
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void lookupAndEmptyRuleHelpersCoverMissingConfigurations() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    String blankParent = service.findCheckSetDeveloperName(' ');
    String missingParent = service.findCheckSetDeveloperName('No_Such_Rule');
    RecordHealthCheckSetAvailability blankAvailability = service.getCheckSetAvailabilityForObject(
      ' '
    );
    try {
      RecordHealthCheckDefinitionLoader.validateActiveRulesForDefinition(
        new List<Record_Health_Check_Rule__mdt>(),
        'No_Rules'
      );
      Assert.fail('A Check Set without active Rules must be rejected.');
    } catch (RecordHealthCheckConfigService.ConfigException error) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_NO_ACTIVE_CHECKS,
        error.reasonCode,
        'The empty Rule list should use NO_ACTIVE_CHECKS.'
      );
    }
    Test.stopTest();

    Assert.isNull(
      blankParent,
      'A blank Rule identity should not resolve a Check Set.'
    );
    Assert.isNull(
      missingParent,
      'An unknown Rule identity should not resolve a Check Set.'
    );
    Assert.isFalse(
      blankAvailability.hasActive,
      'A blank object should report no active Check Sets.'
    );
  }

  private static Record_Health_Check_Set__mdt validSet(
    String developerName,
    Boolean active
  ) {
    return RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'IsActive__c' => active,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE'
      }
    );
  }

  private static void assertConfigException(
    RecordHealthCheckConfigService service,
    Record_Health_Check_Set__mdt checkSet,
    Id recordId,
    String reasonCode
  ) {
    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        checkSet.DeveloperName,
        recordId
      );
      Assert.isTrue(false, 'Expected a config exception.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      Assert.areEqual(reasonCode, ex.reasonCode);
    }
  }

  private static Record_Health_Check_Rule__mdt baseRule(
    String developerName,
    String checkType
  ) {
    return RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'MasterLabel' => developerName,
        'CheckTitle__c' => developerName,
        'EvaluationType__c' => checkType,
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => checkType == 'FORMULA' ? 'TRUE' : null,
        'FailureMessage__c' => 'Apex failure for {!record.Name}',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate test rule.',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD'
      }
    );
  }

  private static Record_Health_Check_Rule__mdt queryRule(String developerName) {
    Record_Health_Check_Rule__mdt rule = baseRule(developerName, 'QUERY');
    rule.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    rule.SourceQueryField__c = 'BillingCity';
    rule.QueryResultHandling__c = 'ONE_RESULT';
    rule.ComparisonOperator__c = 'EQUALS';
    rule.ExpectedValueSource__c = 'FIXED_VALUE';
    rule.ExpectedFixedValue__c = 'Chicago';
    return rule;
  }

  private static Record_Health_Check_Rule__mdt dualRule(String developerName) {
    return baseRule(developerName, 'COMPARE_TWO_QUERIES');
  }

  private static Record_Health_Check_Rule__mdt validDualRule(
    String developerName
  ) {
    Record_Health_Check_Rule__mdt rule = dualRule(developerName);
    rule.SourceQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    rule.SourceQueryField__c = 'totalCount';
    rule.ComparisonQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    rule.ComparisonQueryField__c = 'totalCount';
    rule.QueryResultHandling__c = 'ONE_RESULT';
    rule.ComparisonOperator__c = 'EQUALS';
    return rule;
  }

  private static Record_Health_Check_Rule__mdt apexRule(
    String developerName,
    String className,
    String parameters
  ) {
    Record_Health_Check_Rule__mdt rule = baseRule(developerName, 'APEX');
    rule.ApexClass__c = className;
    rule.ApexParametersJson__c = parameters;
    return rule;
  }

  private static void assertUnable(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected an unable result.');
    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(reasonCode, result.reasonCode);
  }
}
