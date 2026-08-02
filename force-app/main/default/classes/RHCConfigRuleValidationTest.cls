/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RHCConfigRuleValidationTest {
  @IsTest
  static void configServiceValidationCoversInvalidBranches() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    assertUnable(
      service.validateRuleForEvaluation(baseRule('Bad_Type', 'Bogus')),
      'INVALID_CHECK_TYPE'
    );

    Record_Health_Check_Rule__mdt formulaRule = baseRule(
      'Missing_Formula',
      'FORMULA'
    );
    formulaRule.PassConditionFormula__c = null;
    assertUnable(
      service.validateRuleForEvaluation(formulaRule),
      'INVALID_FORMULA'
    );

    Record_Health_Check_Rule__mdt noSeverity = baseRule(
      'No_Severity',
      'FORMULA'
    );
    noSeverity.FailureSeverity__c = null;
    assertUnable(
      service.validateRuleForEvaluation(noSeverity),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check_Rule__mdt invalidApplicability = baseRule(
      'Bad_Applicability',
      'FORMULA'
    );
    invalidApplicability.ApplicabilityMode__c = 'Sometimes';
    assertUnable(
      service.validateRuleForEvaluation(invalidApplicability),
      'INVALID_CONFIG'
    );

    Record_Health_Check_Rule__mdt queryMissingPrimary = queryRule(
      'Query_Missing_Primary'
    );
    queryMissingPrimary.SourceQuery__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingPrimary),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt queryDualOperator = queryRule(
      'Query_Dual_Operator'
    );
    queryDualOperator.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    assertUnable(
      service.validateRuleForEvaluation(queryDualOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt queryInvalidOperator = queryRule(
      'Query_Invalid_Operator'
    );
    queryInvalidOperator.ComparisonOperator__c = 'Around';
    assertUnable(
      service.validateRuleForEvaluation(queryInvalidOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt queryMissingOperator = queryRule(
      'Query_Missing_Operator'
    );
    queryMissingOperator.ComparisonOperator__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt queryMissingMode = queryRule(
      'Query_Missing_Mode'
    );
    queryMissingMode.QueryResultHandling__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingMode),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check_Rule__mdt queryBadListMode = queryRule(
      'Query_Bad_List_Mode'
    );
    queryBadListMode.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    assertUnable(
      service.validateRuleForEvaluation(queryBadListMode),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt queryMissingSource = queryRule(
      'Query_Missing_Source'
    );
    queryMissingSource.ExpectedValueSource__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingSource),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check_Rule__mdt queryMissingStatic = queryRule(
      'Query_Missing_Static'
    );
    queryMissingStatic.ExpectedFixedValue__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingStatic),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check_Rule__mdt queryMissingFormula = queryRule(
      'Query_Missing_Comparison_Formula'
    );
    queryMissingFormula.ExpectedValueSource__c = 'RECORD_FORMULA';
    queryMissingFormula.ExpectedRecordFormula__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingFormula),
      'INVALID_FORMULA'
    );

    Record_Health_Check_Rule__mdt queryMissingComparisonQuery = queryRule(
      'Query_Missing_Comparison_Query'
    );
    queryMissingComparisonQuery.ExpectedValueSource__c = 'COMPARISON_QUERY';
    queryMissingComparisonQuery.ComparisonQuery__c = null;
    assertUnable(
      service.validateRuleForEvaluation(queryMissingComparisonQuery),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt queryBadMax = queryRule('Query_Bad_Max');
    queryBadMax.MaxQueryRows__c = 2001;
    assertUnable(
      service.validateRuleForEvaluation(queryBadMax),
      'GOVERNOR_LIMIT_RISK'
    );

    Record_Health_Check_Rule__mdt queryBadNull = queryRule('Query_Bad_Null');
    queryBadNull.EmptyValueHandling__c = 'Magic';
    assertUnable(
      service.validateRuleForEvaluation(queryBadNull),
      'INVALID_CONFIG'
    );

    Record_Health_Check_Rule__mdt queryBadEmpty = queryRule('Query_Bad_Empty');
    queryBadEmpty.NoRowsResult__c = 'Maybe';
    assertUnable(
      service.validateRuleForEvaluation(queryBadEmpty),
      'INVALID_CONFIG'
    );

    Record_Health_Check_Rule__mdt listOperator = queryRule(
      'Query_List_Operator'
    );
    listOperator.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    listOperator.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    listOperator.SourceQuery__c = null;
    listOperator.FindInListFormula__c = null;
    assertUnable(
      service.validateRuleForEvaluation(listOperator),
      'INVALID_FORMULA'
    );
    listOperator.FindInListFormula__c = 'BillingCity';
    listOperator.ComparisonQuery__c = null;
    assertUnable(
      service.validateRuleForEvaluation(listOperator),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt apexRule = baseRule(
      'Apex_Missing_Class',
      'APEX'
    );
    apexRule.ApexClass__c = null;
    assertUnable(
      service.validateRuleForEvaluation(apexRule),
      'APEX_CLASS_NOT_FOUND'
    );

    assertUnable(
      service.validateRuleForEvaluation(dualRule('Dual_Missing_Primary')),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt dualMissingComparison = dualRule(
      'Dual_Missing_Comparison'
    );
    dualMissingComparison.SourceQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    dualMissingComparison.ComparisonQuery__c = null;
    assertUnable(
      service.validateRuleForEvaluation(dualMissingComparison),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt dualMissingOperator = validDualRule(
      'Dual_Missing_Operator'
    );
    dualMissingOperator.ComparisonOperator__c = null;
    assertUnable(
      service.validateRuleForEvaluation(dualMissingOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt dualInvalidOperator = validDualRule(
      'Dual_Invalid_Operator'
    );
    dualInvalidOperator.ComparisonOperator__c = 'Near';
    assertUnable(
      service.validateRuleForEvaluation(dualInvalidOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt dualMissingMode = validDualRule(
      'Dual_Missing_Mode'
    );
    dualMissingMode.QueryResultHandling__c = null;
    assertUnable(
      service.validateRuleForEvaluation(dualMissingMode),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check_Rule__mdt dualBadMode = validDualRule('Dual_Bad_Mode');
    dualBadMode.QueryResultHandling__c = 'ANY_ROW_PASSES';
    assertUnable(
      service.validateRuleForEvaluation(dualBadMode),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt dualBadListOperator = validDualRule(
      'Dual_Bad_List_Operator'
    );
    dualBadListOperator.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualBadListOperator.ComparisonOperator__c = 'EQUALS';
    assertUnable(
      service.validateRuleForEvaluation(dualBadListOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt dualBadSingleValueOperator = validDualRule(
      'Dual_Bad_SingleValue_Operator'
    );
    dualBadSingleValueOperator.QueryResultHandling__c = 'ONE_RESULT';
    dualBadSingleValueOperator.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    assertUnable(
      service.validateRuleForEvaluation(dualBadSingleValueOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt dualBadMax = validDualRule('Dual_Bad_Max');
    dualBadMax.MaxQueryRows__c = 0;
    assertUnable(
      service.validateRuleForEvaluation(dualBadMax),
      'GOVERNOR_LIMIT_RISK'
    );

    Assert.areEqual(
      null,
      service.validateRuleForEvaluation(queryRule('Valid_Query'))
    );
    Assert.areEqual(
      null,
      service.validateRuleForEvaluation(validDualRule('Valid_Dual'))
    );
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

  private static void assertUnable(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected an unable result.');
    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(reasonCode, result.reasonCode);
  }
}
