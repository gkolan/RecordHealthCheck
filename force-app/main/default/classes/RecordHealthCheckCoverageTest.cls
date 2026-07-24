/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckCoverageTest {
  private class ThrowingRule implements RecordHealthCheckRule {
    public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
      throw new IllegalArgumentException('Test plugin failure.');
    }
  }

  private class NullRule implements RecordHealthCheckRule {
    public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
      return null;
    }
  }

  @testSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void dtoAndContextFieldsRoundTrip() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    RecordHealthCheckDefinition definition = new RecordHealthCheckDefinition();
    definition.developerName = 'Definition_Key';
    definition.label = 'Definition Label';
    definition.description = 'Definition Description';
    definition.priority = 1;
    definition.dependsOnRuleDeveloperName = 'Prereq';

    RecordHealthCheckDefinitionResponse response = new RecordHealthCheckDefinitionResponse();
    response.displayTitle = 'Title';
    response.displayDescription = 'Description';
    response.triggerMode = 'Manual';
    response.revealMode = 'AllAtOnce';
    response.successDisplayMode = 'Show';
    response.skippedDisplayMode = 'Hide';
    response.stopOnFirstError = true;
    response.totalAvailableCheckCount = 1;
    response.checksOmittedByLimit = false;
    response.showDiagnostics = true;
    response.checks = new List<RecordHealthCheckDefinition>{ definition };

    RecordHealthCheckContext context = new RecordHealthCheckContext();
    context.recordId = accountRecord.Id;
    context.objectApiName = 'Account';
    context.record = accountRecord;
    context.parameters = new Map<String, Object>{ 'mode' => 'PASS' };
    context.ruleDeveloperName = 'Definition_Key';

    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.ruleDeveloperName = definition.developerName;
    result.label = definition.label;
    result.status = 'PASS';
    result.severity = 'Info';
    result.message = 'Message';
    result.detailMessage = 'Detail';
    result.adminDetailMessage = 'Admin';
    result.reasonCode = 'REASON';
    result.priority = 1;
    result.durationMs = 10;
    result.evaluatorType = 'Test';

    System.assertEquals('Definition_Key', response.checks[0].developerName);
    System.assertEquals(accountRecord.Id, context.recordId);
    System.assertEquals('PASS', result.status);
  }

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

    System.assertEquals(
      null,
      service.validateRuleForEvaluation(queryRule('Valid_Query'))
    );
    System.assertEquals(
      null,
      service.validateRuleForEvaluation(validDualRule('Valid_Dual'))
    );
  }

  @IsTest
  static void metadataValidatorCoversInvalidInMemoryMetadata() {
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    Id setAId = Id.valueOf('m00000000000001');
    Id setBId = Id.valueOf('m00000000000002');

    List<Record_Health_Check_Set__mdt> checkSets = new List<Record_Health_Check_Set__mdt>{
      new Record_Health_Check_Set__mdt(
        DeveloperName = String.valueOf(setAId),
        MasterLabel = 'Set A',
        ObjectApiName__c = '',
        CardTitle__c = '',
        PassedChecksDisplay__c = 'Maybe',
        SkippedChecksDisplay__c = 'Sometimes'
      ),
      new Record_Health_Check_Set__mdt(
        DeveloperName = String.valueOf(setBId),
        MasterLabel = 'Set B',
        ObjectApiName__c = 'Account',
        CardTitle__c = 'Set B'
      )
    };

    Record_Health_Check_Rule__mdt missingBasics = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Missing_Basics',
      MasterLabel = 'Missing Basics',
      Record_Health_Check_Set__c = setAId
    );

    Record_Health_Check_Rule__mdt invalidType = baseRule(
      'Invalid_Type_For_Validator',
      'Unknown'
    );
    invalidType.Record_Health_Check_Set__c = setAId;

    Record_Health_Check_Rule__mdt invalidApplicability = baseRule(
      'Invalid_Applicability_For_Validator',
      'FORMULA'
    );
    invalidApplicability.Record_Health_Check_Set__c = setAId;
    invalidApplicability.ApplicabilityMode__c = 'WhenLucky';

    Record_Health_Check_Rule__mdt missingFormula = baseRule(
      'Missing_Formula_For_Validator',
      'FORMULA'
    );
    missingFormula.Record_Health_Check_Set__c = setAId;
    missingFormula.PassConditionFormula__c = null;

    Record_Health_Check_Rule__mdt invalidQuery = queryRule(
      'Invalid_Query_For_Validator'
    );
    invalidQuery.Record_Health_Check_Set__c = setAId;
    invalidQuery.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    invalidQuery.SourceQuery__c = null;
    invalidQuery.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    invalidQuery.ExpectedValueSource__c = null;
    invalidQuery.ExpectedFixedValue__c = null;
    invalidQuery.ExpectedRecordFormula__c = null;
    invalidQuery.ComparisonQuery__c = null;
    invalidQuery.MaxQueryRows__c = 2001;
    invalidQuery.EmptyValueHandling__c = 'InvalidNullBehavior';
    invalidQuery.NoRowsResult__c = 'InvalidEmptyBehavior';

    Record_Health_Check_Rule__mdt queryMissingOperator = queryRule(
      'Validator_Query_Missing_Operator'
    );
    queryMissingOperator.Record_Health_Check_Set__c = setAId;
    queryMissingOperator.ComparisonOperator__c = null;

    Record_Health_Check_Rule__mdt queryUnknownOperator = queryRule(
      'Validator_Query_Unknown_Operator'
    );
    queryUnknownOperator.Record_Health_Check_Set__c = setAId;
    queryUnknownOperator.ComparisonOperator__c = 'Around';

    Record_Health_Check_Rule__mdt queryMissingMode = queryRule(
      'Validator_Query_Missing_Mode'
    );
    queryMissingMode.Record_Health_Check_Set__c = setAId;
    queryMissingMode.QueryResultHandling__c = null;

    Record_Health_Check_Rule__mdt queryMissingStatic = queryRule(
      'Validator_Query_Missing_Static'
    );
    queryMissingStatic.Record_Health_Check_Set__c = setAId;
    queryMissingStatic.ExpectedFixedValue__c = null;

    Record_Health_Check_Rule__mdt queryMissingFormula = queryRule(
      'Validator_Query_Missing_Formula'
    );
    queryMissingFormula.Record_Health_Check_Set__c = setAId;
    queryMissingFormula.ExpectedValueSource__c = 'RECORD_FORMULA';
    queryMissingFormula.ExpectedRecordFormula__c = null;

    Record_Health_Check_Rule__mdt queryMissingComparisonQuery = queryRule(
      'Validator_Query_Missing_Comparison_Query'
    );
    queryMissingComparisonQuery.Record_Health_Check_Set__c = setAId;
    queryMissingComparisonQuery.ExpectedValueSource__c = 'COMPARISON_QUERY';
    queryMissingComparisonQuery.ComparisonQuery__c = null;

    Record_Health_Check_Rule__mdt invalidListQuery = queryRule(
      'Invalid_List_Query_For_Validator'
    );
    invalidListQuery.Record_Health_Check_Set__c = setAId;
    invalidListQuery.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    invalidListQuery.FindInListFormula__c = null;
    invalidListQuery.ComparisonQuery__c = null;

    Record_Health_Check_Rule__mdt invalidApex = baseRule(
      'Invalid_Apex_For_Validator',
      'APEX'
    );
    invalidApex.Record_Health_Check_Set__c = setAId;
    invalidApex.ApexClass__c = null;

    Record_Health_Check_Rule__mdt invalidDual = validDualRule(
      'Invalid_Dual_For_Validator'
    );
    invalidDual.Record_Health_Check_Set__c = setAId;
    invalidDual.SourceQuery__c = null;
    invalidDual.ComparisonQuery__c = null;
    invalidDual.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    invalidDual.QueryResultHandling__c = 'ONE_RESULT';

    Record_Health_Check_Rule__mdt dualMissingOperator = validDualRule(
      'Validator_Dual_Missing_Operator'
    );
    dualMissingOperator.Record_Health_Check_Set__c = setAId;
    dualMissingOperator.ComparisonOperator__c = null;

    Record_Health_Check_Rule__mdt dualUnknownOperator = validDualRule(
      'Validator_Dual_Unknown_Operator'
    );
    dualUnknownOperator.Record_Health_Check_Set__c = setAId;
    dualUnknownOperator.ComparisonOperator__c = 'Around';

    Record_Health_Check_Rule__mdt dualMissingMode = validDualRule(
      'Validator_Dual_Missing_Mode'
    );
    dualMissingMode.Record_Health_Check_Set__c = setAId;
    dualMissingMode.QueryResultHandling__c = null;

    Record_Health_Check_Rule__mdt dualUnknownMode = validDualRule(
      'Validator_Dual_Unknown_Mode'
    );
    dualUnknownMode.Record_Health_Check_Set__c = setAId;
    dualUnknownMode.QueryResultHandling__c = 'ANY_ROW_PASSES';

    Record_Health_Check_Rule__mdt dualBadListMode = validDualRule(
      'Validator_Dual_Bad_List_Mode'
    );
    dualBadListMode.Record_Health_Check_Set__c = setAId;
    dualBadListMode.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualBadListMode.ComparisonOperator__c = 'EQUALS';

    Record_Health_Check_Rule__mdt missingDependency = baseRule(
      'Missing_Dependency_For_Validator',
      'FORMULA'
    );
    missingDependency.Record_Health_Check_Set__c = setAId;
    missingDependency.PrerequisiteRule__c = 'No_Such_Rule';

    Record_Health_Check_Rule__mdt sameSetDependency = baseRule(
      'Same_Set_Dependency_For_Validator',
      'FORMULA'
    );
    sameSetDependency.Record_Health_Check_Set__c = setAId;
    sameSetDependency.EvaluationOrder__c = 5;
    sameSetDependency.PrerequisiteRule__c = 'Invalid_Type_For_Validator';

    Record_Health_Check_Rule__mdt cycleA = baseRule(
      'Cycle_A_For_Validator',
      'FORMULA'
    );
    cycleA.Record_Health_Check_Set__c = setAId;
    cycleA.EvaluationOrder__c = null;
    cycleA.PrerequisiteRule__c = 'Cycle_B_For_Validator';

    Record_Health_Check_Rule__mdt cycleB = baseRule(
      'Cycle_B_For_Validator',
      'FORMULA'
    );
    cycleB.Record_Health_Check_Set__c = setAId;
    cycleB.EvaluationOrder__c = null;
    cycleB.PrerequisiteRule__c = 'Cycle_A_For_Validator';

    Record_Health_Check_Rule__mdt crossSetTarget = baseRule(
      'Cross_Set_Target_For_Validator',
      'FORMULA'
    );
    crossSetTarget.Record_Health_Check_Set__c = setBId;
    crossSetTarget.EvaluationOrder__c = 1;

    Record_Health_Check_Rule__mdt crossSetSource = baseRule(
      'Cross_Set_Source_For_Validator',
      'FORMULA'
    );
    crossSetSource.Record_Health_Check_Set__c = setAId;
    crossSetSource.EvaluationOrder__c = 2;
    crossSetSource.PrerequisiteRule__c = 'Cross_Set_Target_For_Validator';

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = validator.validateRecords(
      checkSets,
      new List<Record_Health_Check_Rule__mdt>{
        missingBasics,
        invalidType,
        invalidApplicability,
        missingFormula,
        invalidQuery,
        queryMissingOperator,
        queryUnknownOperator,
        queryMissingMode,
        queryMissingStatic,
        queryMissingFormula,
        queryMissingComparisonQuery,
        invalidListQuery,
        invalidApex,
        invalidDual,
        dualMissingOperator,
        dualUnknownOperator,
        dualMissingMode,
        dualUnknownMode,
        dualBadListMode,
        missingDependency,
        sameSetDependency,
        cycleA,
        cycleB,
        crossSetTarget,
        crossSetSource
      }
    );

    System.assert(issues.size() > 20, 'Expected broad validation coverage.');
    Set<String> reasonCodes = new Set<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      reasonCodes.add(issue.reasonCode);
    }
    System.assert(reasonCodes.contains('MISSING_REQUIRED_FIELD'));
    System.assert(reasonCodes.contains('INVALID_CHECK_TYPE'));
    System.assert(reasonCodes.contains('INVALID_CONFIG'));
    System.assert(reasonCodes.contains('INVALID_OPERATOR'));
    System.assert(reasonCodes.contains('INVALID_DEPENDENCY'));
  }

  @IsTest
  static void soqlEvaluatorCoversOperatorAndQueryBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();

    String bound = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name} AND AnnualRevenue >= {!record.AnnualRevenue}',
      accountRecord
    );
    System.assert(
      bound.contains(String.escapeSingleQuotes(accountRecord.Name))
    );
    System.assert(bound.contains(String.valueOf(accountRecord.AnnualRevenue)));

    assertStatus(
      evaluator.evaluate(
        queryRule('Q_Equals_Pass'),
        accountRecord.Id,
        accountRecord
      ),
      'PASS'
    );

    Record_Health_Check_Rule__mdt notEquals = queryRule('Q_NotEquals_Fail');
    notEquals.ComparisonOperator__c = 'NOT_EQUALS';
    notEquals.ExpectedFixedValue__c = accountRecord.BillingCity;
    RecordHealthCheckResult notEqualsResult = evaluator.evaluate(
      notEquals,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(notEqualsResult, 'FAIL');
    // A non-passing single-query result carries the actual value and the
    // operator-described expectation so the UI can show both.
    System.assertEquals(
      accountRecord.BillingCity,
      notEqualsResult.actualValue,
      'actualValue should reflect the queried record value'
    );
    System.assertEquals(
      'to not equal ' + accountRecord.BillingCity,
      notEqualsResult.expectedValue,
      'expectedValue should describe the operator and operand'
    );

    Record_Health_Check_Rule__mdt contains = queryRule('Q_Contains_Pass');
    contains.ComparisonOperator__c = 'CONTAINS';
    contains.ExpectedFixedValue__c = 'hic';
    assertStatus(
      evaluator.evaluate(contains, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt doesNotContain = queryRule(
      'Q_Does_Not_Contain_Fail'
    );
    doesNotContain.ComparisonOperator__c = 'DOES_NOT_CONTAIN';
    doesNotContain.ExpectedFixedValue__c = 'hic';
    assertStatus(
      evaluator.evaluate(doesNotContain, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt greaterThan = queryRule('Q_Greater_Than');
    greaterThan.SourceQuery__c = 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}';
    greaterThan.SourceQueryField__c = 'AnnualRevenue';
    greaterThan.ComparisonOperator__c = 'GREATER_THAN';
    greaterThan.ExpectedFixedValue__c = '10';
    assertStatus(
      evaluator.evaluate(greaterThan, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt aggregateCount = queryRule(
      'Q_Aggregate_Count'
    );
    aggregateCount.SourceQuery__c = 'SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}';
    aggregateCount.SourceQueryField__c = null;
    aggregateCount.ComparisonOperator__c = 'GREATER_THAN';
    aggregateCount.ExpectedFixedValue__c = '0';
    assertStatus(
      evaluator.evaluate(aggregateCount, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt numericParseError = queryRule(
      'Q_Numeric_Parse_Error'
    );
    numericParseError.SourceQuery__c = 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}';
    numericParseError.SourceQueryField__c = 'AnnualRevenue';
    numericParseError.ComparisonOperator__c = 'EQUALS';
    numericParseError.ExpectedFixedValue__c = 'not-a-number';
    assertReason(
      evaluator.evaluate(numericParseError, accountRecord.Id, accountRecord),
      'INCOMPATIBLE_COMPARISON_TYPES'
    );

    Record_Health_Check_Rule__mdt dateCompare = queryRule('Q_Date_Compare');
    dateCompare.SourceQuery__c = 'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} LIMIT 1';
    dateCompare.SourceQueryField__c = 'CloseDate';
    dateCompare.ComparisonOperator__c = 'LESS_THAN_OR_EQUAL';
    dateCompare.ExpectedValueSource__c = 'RECORD_FORMULA';
    dateCompare.ExpectedRecordFormula__c = 'TODAY() + 60';
    assertStatus(
      evaluator.evaluate(dateCompare, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt textOrder = queryRule('Q_Text_Order');
    textOrder.ComparisonOperator__c = 'GREATER_THAN';
    textOrder.ExpectedFixedValue__c = 'Alpha';
    assertReason(
      evaluator.evaluate(textOrder, accountRecord.Id, accountRecord),
      'INCOMPATIBLE_COMPARISON_TYPES'
    );

    Record_Health_Check_Rule__mdt isBlank = queryRule('Q_IsBlank');
    isBlank.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    isBlank.SourceQueryField__c = 'Description';
    isBlank.ComparisonOperator__c = 'IS_BLANK';
    isBlank.ExpectedValueSource__c = null;
    assertStatus(
      evaluator.evaluate(isBlank, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt isNotBlank = queryRule('Q_IsNotBlank');
    isNotBlank.ComparisonOperator__c = 'IS_NOT_BLANK';
    isNotBlank.ExpectedValueSource__c = null;
    RecordHealthCheckResult isNotBlankResult = evaluator.evaluate(
      isNotBlank,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(isNotBlankResult, 'PASS');
    System.assertNotEquals(
      null,
      isNotBlankResult.expectedValueSource,
      'Unary query checks should still expose an Expected value-source row.'
    );
    System.assertEquals(
      'Comparison operator',
      isNotBlankResult.expectedValueSource.sourceLabel
    );
    System.assertEquals(
      'to not be blank',
      isNotBlankResult.expectedValueSource.rawValueLabel
    );

    Record_Health_Check_Rule__mdt nullAsBlank = queryRule('Q_Null_As_Blank');
    nullAsBlank.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    nullAsBlank.SourceQueryField__c = 'Description';
    nullAsBlank.ComparisonOperator__c = 'EQUALS';
    nullAsBlank.ExpectedFixedValue__c = '';
    nullAsBlank.EmptyValueHandling__c = 'AS_BLANK';
    assertStatus(
      evaluator.evaluate(nullAsBlank, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt nullNoMatch = nullAsBlank.clone();
    nullNoMatch.DeveloperName = 'Q_Null_No_Match';
    nullNoMatch.EmptyValueHandling__c = 'AS_NO_MATCH';
    assertStatus(
      evaluator.evaluate(nullNoMatch, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt anyPass = queryRule('Q_Any_Pass');
    anyPass.SourceQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!record.Id}';
    anyPass.SourceQueryField__c = 'Email';
    anyPass.QueryResultHandling__c = 'ANY_ROW_PASSES';
    anyPass.ComparisonOperator__c = 'CONTAINS';
    anyPass.ExpectedFixedValue__c = '@example.com';
    assertStatus(
      evaluator.evaluate(anyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt anyFail = anyPass.clone();
    anyFail.DeveloperName = 'Q_Any_Fail';
    anyFail.ExpectedFixedValue__c = '@missing.example';
    assertStatus(
      evaluator.evaluate(anyFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt allFail = anyPass.clone();
    allFail.DeveloperName = 'Q_All_Fail';
    allFail.QueryResultHandling__c = 'ALL_ROWS_PASS';
    assertStatus(
      evaluator.evaluate(allFail, accountRecord.Id, accountRecord),
      'PASS'
    );

    // allBlankFail exercises IsNotBlank + AllRowsPass expecting FAIL because at
    // least one Contact email is blank. The shared factory gives every seeded
    // Contact an email, so add a deterministic blank-email Contact for this
    // assertion and remove it afterward so later checks see the original data.
    Contact blankEmailContact = RecordHealthCheckTestDataFactory.createContact(
      new Contact(
        LastName = 'Blank Email Coverage',
        AccountId = accountRecord.Id
      )
    );
    Record_Health_Check_Rule__mdt allBlankFail = queryRule('Q_All_Blank_Fail');
    allBlankFail.SourceQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!record.Id}';
    allBlankFail.SourceQueryField__c = 'Email';
    allBlankFail.QueryResultHandling__c = 'ALL_ROWS_PASS';
    allBlankFail.ComparisonOperator__c = 'IS_NOT_BLANK';
    allBlankFail.ExpectedValueSource__c = null;
    allBlankFail.EmptyValueHandling__c = 'AS_NO_MATCH';
    assertStatus(
      evaluator.evaluate(allBlankFail, accountRecord.Id, accountRecord),
      'FAIL'
    );
    delete blankEmailContact;

    Record_Health_Check_Rule__mdt anyAllSkipped = queryRule(
      'Q_Any_All_Skipped'
    );
    anyAllSkipped.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    anyAllSkipped.SourceQueryField__c = 'Description';
    anyAllSkipped.QueryResultHandling__c = 'ANY_ROW_PASSES';
    anyAllSkipped.ComparisonOperator__c = 'EQUALS';
    anyAllSkipped.ExpectedFixedValue__c = 'anything';
    anyAllSkipped.EmptyValueHandling__c = 'SKIP_RECORD';
    anyAllSkipped.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(anyAllSkipped, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    // A PRESENT row whose field-under-test is null with the empty-value handling set
    // to Skip is indeterminate because of the null VALUE, not because of zero
    // rows. It must SKIP even when WhenZeroRows = Fail; the null value must not
    // be routed through the WhenZeroRows path.
    Record_Health_Check_Rule__mdt nullSkipNotFail = queryRule(
      'Q_Null_Skip_Not_Fail'
    );
    nullSkipNotFail.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    nullSkipNotFail.SourceQueryField__c = 'Description';
    nullSkipNotFail.ComparisonOperator__c = 'EQUALS';
    nullSkipNotFail.ExpectedFixedValue__c = 'anything';
    nullSkipNotFail.EmptyValueHandling__c = 'SKIP_RECORD';
    nullSkipNotFail.NoRowsResult__c = 'FAIL';
    assertStatus(
      evaluator.evaluate(nullSkipNotFail, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt emptyPass = queryRule('Q_Empty_Pass');
    emptyPass.SourceQuery__c = 'SELECT Id FROM Contact WHERE AccountId = null';
    emptyPass.SourceQueryField__c = 'Id';
    emptyPass.NoRowsResult__c = 'PASS';
    assertStatus(
      evaluator.evaluate(emptyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt emptyUnable = emptyPass.clone();
    emptyUnable.DeveloperName = 'Q_Empty_Unable';
    emptyUnable.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    RecordHealthCheckResult emptyUnableResult = evaluator.evaluate(
      emptyUnable,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(emptyUnableResult, 'UNABLE_TO_EVALUATE');
    System.assertEquals('NO_ROWS_RETURNED', emptyUnableResult.reasonCode);

    Record_Health_Check_Rule__mdt emptySkip = emptyPass.clone();
    emptySkip.DeveloperName = 'Q_Empty_Skip';
    emptySkip.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(emptySkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt queryResult = queryRule('Q_Query_Result');
    queryResult.ExpectedValueSource__c = 'COMPARISON_QUERY';
    queryResult.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    queryResult.ComparisonQueryField__c = 'BillingCity';
    assertStatus(
      evaluator.evaluate(queryResult, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt queryResultMultiple = queryResult.clone();
    queryResultMultiple.DeveloperName = 'Q_Query_Result_Multiple';
    queryResultMultiple.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    assertReason(
      evaluator.evaluate(queryResultMultiple, accountRecord.Id, accountRecord),
      'MULTIPLE_ROWS_RETURNED'
    );

    Record_Health_Check_Rule__mdt listContains = queryRule('Q_List_Contains');
    listContains.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    listContains.FindInListFormula__c = 'BillingCity';
    listContains.SourceQuery__c = null;
    listContains.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    listContains.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    listContains.ComparisonQueryField__c = 'MailingCity';
    assertStatus(
      evaluator.evaluate(listContains, accountRecord.Id, accountRecord),
      'PASS'
    );

    // List checks read only FindInListFormula__c — PassConditionFormula__c is ignored (no fallback).
    // A valid FindInListFormula__c passes even when PassConditionFormula__c holds a non-matching value.
    Record_Health_Check_Rule__mdt listIgnoresPassFail = listContains.clone();
    listIgnoresPassFail.DeveloperName = 'Q_List_Ignores_PassFail';
    listIgnoresPassFail.PassConditionFormula__c = '"Missing City"';
    assertStatus(
      evaluator.evaluate(listIgnoresPassFail, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt listDoesNotContain = listContains.clone();
    listDoesNotContain.DeveloperName = 'Q_List_Does_Not_Contain';
    listDoesNotContain.ComparisonOperator__c = 'LIST_CONTAINS_NONE';
    listDoesNotContain.FindInListFormula__c = '"Missing City"';
    assertStatus(
      evaluator.evaluate(listDoesNotContain, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt listDoesContainFail = listContains.clone();
    listDoesContainFail.DeveloperName = 'Q_List_Does_Contain_Fail';
    listDoesContainFail.ComparisonOperator__c = 'LIST_CONTAINS_NONE';
    assertStatus(
      evaluator.evaluate(listDoesContainFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt listEmptyPass = listContains.clone();
    listEmptyPass.DeveloperName = 'Q_List_Empty_Pass';
    listEmptyPass.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = null';
    listEmptyPass.NoRowsResult__c = 'PASS';
    assertStatus(
      evaluator.evaluate(listEmptyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt badMode = queryRule('Q_Bad_Mode_Runtime');
    badMode.QueryResultHandling__c = 'SomethingElse';
    assertReason(
      evaluator.evaluate(badMode, accountRecord.Id, accountRecord),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt compareAsLists = queryRule(
      'Q_Compare_As_Lists_Runtime'
    );
    compareAsLists.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    assertReason(
      evaluator.evaluate(compareAsLists, accountRecord.Id, accountRecord),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt invalidField = queryRule('Q_Invalid_Field');
    invalidField.SourceQueryField__c = 'NotAField__c';
    assertReason(
      evaluator.evaluate(invalidField, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt missingField = queryRule('Q_Missing_Field');
    missingField.SourceQueryField__c = null;
    assertReason(
      evaluator.evaluate(missingField, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt missingBind = queryRule('Q_Missing_Bind');
    missingBind.SourceQuery__c = 'SELECT Id FROM Account WHERE Id = {!record.DoesNotExist__c}';
    assertReason(
      evaluator.evaluate(missingBind, accountRecord.Id, accountRecord),
      'MISSING_BIND_VALUE'
    );

    Record_Health_Check_Rule__mdt badKeyword = queryRule('Q_Bad_Keyword');
    badKeyword.SourceQuery__c = 'SELECT Id FROM Account WHERE Name = DELETE';
    assertReason(
      evaluator.evaluate(badKeyword, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt badPhrase = queryRule('Q_Bad_Phrase');
    badPhrase.SourceQuery__c = 'SELECT Id FROM Account ALL ROWS';
    assertReason(
      evaluator.evaluate(badPhrase, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt maxRows = queryRule('Q_Max_Rows');
    maxRows.SourceQuery__c = 'SELECT Id FROM Contact WHERE AccountId = {!record.Id}';
    maxRows.SourceQueryField__c = 'Id';
    maxRows.QueryResultHandling__c = 'ANY_ROW_PASSES';
    maxRows.MaxQueryRows__c = 1;
    assertReason(
      evaluator.evaluate(maxRows, accountRecord.Id, accountRecord),
      'GOVERNOR_LIMIT_RISK'
    );
  }

  @IsTest
  static void dualSoqlEvaluatorCoversSingleValueListAndErrorBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckCompareQueriesEvaluator evaluator = new RecordHealthCheckCompareQueriesEvaluator();

    assertStatus(
      evaluator.evaluate(
        validDualRule('D_Counts_Equal'),
        accountRecord.Id,
        accountRecord
      ),
      'PASS'
    );

    Record_Health_Check_Rule__mdt notEquals = validDualRule('D_Not_Equals');
    notEquals.ComparisonOperator__c = 'NOT_EQUALS';
    notEquals.ComparisonQuery__c = 'SELECT COUNT(Id) totalCount FROM Opportunity WHERE AccountId = {!record.Id}';
    assertStatus(
      evaluator.evaluate(notEquals, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt contains = validDualRule('D_Contains');
    contains.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    contains.SourceQueryField__c = 'BillingCity';
    contains.ComparisonQuery__c = 'SELECT BillingState FROM Account WHERE Id = {!record.Id}';
    contains.ComparisonQueryField__c = 'BillingState';
    contains.ComparisonOperator__c = 'DOES_NOT_CONTAIN';
    assertStatus(
      evaluator.evaluate(contains, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt containsPositive = validDualRule(
      'D_Contains_Positive'
    );
    containsPositive.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    containsPositive.SourceQueryField__c = 'BillingCity';
    containsPositive.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    containsPositive.ComparisonQueryField__c = 'BillingCity';
    containsPositive.ComparisonOperator__c = 'CONTAINS';
    assertStatus(
      evaluator.evaluate(containsPositive, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt numericOrder = validDualRule(
      'D_Numeric_Order'
    );
    numericOrder.SourceQuery__c = 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}';
    numericOrder.SourceQueryField__c = 'AnnualRevenue';
    numericOrder.ComparisonQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    numericOrder.ComparisonOperator__c = 'GREATER_THAN';
    assertStatus(
      evaluator.evaluate(numericOrder, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt dateOrder = validDualRule('D_Date_Order');
    dateOrder.SourceQuery__c = 'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} LIMIT 1';
    dateOrder.SourceQueryField__c = 'CloseDate';
    dateOrder.ComparisonQuery__c = 'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} LIMIT 1';
    dateOrder.ComparisonQueryField__c = 'CloseDate';
    dateOrder.ComparisonOperator__c = 'LESS_THAN_OR_EQUAL';
    assertStatus(
      evaluator.evaluate(dateOrder, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt nullSkip = validDualRule('D_Null_Skip');
    nullSkip.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    nullSkip.SourceQueryField__c = 'Description';
    nullSkip.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    nullSkip.ComparisonQueryField__c = 'BillingCity';
    nullSkip.EmptyValueHandling__c = 'SKIP_RECORD';
    nullSkip.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(nullSkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt nullFail = nullSkip.clone();
    nullFail.DeveloperName = 'D_Null_Fail';
    nullFail.EmptyValueHandling__c = 'AS_NO_MATCH';
    assertStatus(
      evaluator.evaluate(nullFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt nullBlank = nullSkip.clone();
    nullBlank.DeveloperName = 'D_Null_Blank';
    nullBlank.EmptyValueHandling__c = 'AS_BLANK';
    nullBlank.ComparisonOperator__c = 'EQUALS';
    nullBlank.ComparisonQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    nullBlank.ComparisonQueryField__c = 'Description';
    assertStatus(
      evaluator.evaluate(nullBlank, accountRecord.Id, accountRecord),
      'PASS'
    );

    // a zero-row query in OneResult is governed by
    // NoRowsResult__c, NOT by the null-value behavior. The impossible Name filter
    // guarantees an empty primary regardless of org data. An empty side with
    // Treat as not matching (AS_NO_MATCH) must honor NoRowsResult__c, not fail by default.
    Record_Health_Check_Rule__mdt emptyPrimarySkip = validDualRule(
      'D_Empty_Primary_Skip'
    );
    emptyPrimarySkip.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id} AND Name = \'__rhc_no_match__\'';
    emptyPrimarySkip.SourceQueryField__c = 'BillingCity';
    emptyPrimarySkip.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    emptyPrimarySkip.ComparisonQueryField__c = 'BillingCity';
    emptyPrimarySkip.ComparisonOperator__c = 'EQUALS';
    emptyPrimarySkip.EmptyValueHandling__c = 'AS_NO_MATCH';
    emptyPrimarySkip.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(emptyPrimarySkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt emptyPrimaryFail = emptyPrimarySkip.clone();
    emptyPrimaryFail.DeveloperName = 'D_Empty_Primary_Fail';
    emptyPrimaryFail.NoRowsResult__c = 'FAIL';
    assertStatus(
      evaluator.evaluate(emptyPrimaryFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    // WhenZeroRows = UnableToEvaluate on an empty side surfaces NO_ROWS_RETURNED.
    Record_Health_Check_Rule__mdt emptyPrimaryUnable = emptyPrimarySkip.clone();
    emptyPrimaryUnable.DeveloperName = 'D_Empty_Primary_Unable';
    emptyPrimaryUnable.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    RecordHealthCheckResult unableResult = evaluator.evaluate(
      emptyPrimaryUnable,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(unableResult, 'UNABLE_TO_EVALUATE');
    System.assertEquals('NO_ROWS_RETURNED', unableResult.reasonCode);

    // An invalid query field surfaces through the compare-queries runQuery error path.
    Record_Health_Check_Rule__mdt badQuery = emptyPrimarySkip.clone();
    badQuery.DeveloperName = 'D_Bad_Query';
    badQuery.SourceQuery__c = 'SELECT NoSuchField__zzz FROM Account WHERE Id = {!record.Id}';
    badQuery.SourceQueryField__c = 'NoSuchField__zzz';
    RecordHealthCheckResult badQueryResult = evaluator.evaluate(
      badQuery,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(badQueryResult, 'UNABLE_TO_EVALUATE');

    Record_Health_Check_Rule__mdt listOverlap = validDualRule('D_List_Overlap');
    listOverlap.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    listOverlap.ComparisonOperator__c = 'LISTS_OVERLAP';
    listOverlap.SourceQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    listOverlap.SourceQueryField__c = 'MailingCity';
    listOverlap.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    listOverlap.ComparisonQueryField__c = 'BillingCity';
    assertStatus(
      evaluator.evaluate(listOverlap, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt containsAll = listOverlap.clone();
    containsAll.DeveloperName = 'D_List_Contains_All';
    containsAll.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    assertStatus(
      evaluator.evaluate(containsAll, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt containsAllPass = listOverlap.clone();
    containsAllPass.DeveloperName = 'D_List_Contains_All_Pass';
    containsAllPass.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    containsAllPass.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    containsAllPass.ComparisonQueryField__c = 'MailingCity';
    assertStatus(
      evaluator.evaluate(containsAllPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt exactMatch = listOverlap.clone();
    exactMatch.DeveloperName = 'D_Exact_Match';
    exactMatch.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    exactMatch.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    exactMatch.ComparisonQueryField__c = 'MailingCity';
    assertStatus(
      evaluator.evaluate(exactMatch, accountRecord.Id, accountRecord),
      'PASS'
    );

    // CompareAsLists where every primary value is null and dropped by
    // SkipRecordsWithMissingValue → empty list with non-empty rows → SKIPPED
    // (indeterminate), not a silent FAIL from comparing empty sets.
    Record_Health_Check_Rule__mdt allNullSkip = listOverlap.clone();
    allNullSkip.DeveloperName = 'D_List_All_Null_Skip';
    allNullSkip.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    allNullSkip.SourceQueryField__c = 'Description';
    allNullSkip.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    allNullSkip.ComparisonQueryField__c = 'BillingCity';
    allNullSkip.EmptyValueHandling__c = 'SKIP_RECORD';
    assertStatus(
      evaluator.evaluate(allNullSkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    // Treat as not matching (AS_NO_MATCH) keeps null values as distinct sentinels (non-empty
    // list), so an all-null primary cannot overlap a real comparison value.
    Record_Health_Check_Rule__mdt allNullNoMatch = allNullSkip.clone();
    allNullNoMatch.DeveloperName = 'D_List_All_Null_NoMatch';
    allNullNoMatch.EmptyValueHandling__c = 'AS_NO_MATCH';
    assertStatus(
      evaluator.evaluate(allNullNoMatch, accountRecord.Id, accountRecord),
      'FAIL'
    );

    // TreatMissingAsBlank coerces a null value to '' (a matchable blank).
    Record_Health_Check_Rule__mdt allNullBlank = allNullSkip.clone();
    allNullBlank.DeveloperName = 'D_List_All_Null_Blank';
    allNullBlank.EmptyValueHandling__c = 'AS_BLANK';
    allNullBlank.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    allNullBlank.ComparisonQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    allNullBlank.ComparisonQueryField__c = 'Description';
    assertStatus(
      evaluator.evaluate(allNullBlank, accountRecord.Id, accountRecord),
      'PASS'
    );

    // WhenZeroRows = Pass on a genuinely empty side.
    Record_Health_Check_Rule__mdt emptyPass = listOverlap.clone();
    emptyPass.DeveloperName = 'D_List_Empty_Pass';
    emptyPass.SourceQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id} AND LastName = \'__rhc_no_match__\'';
    emptyPass.NoRowsResult__c = 'PASS';
    assertStatus(
      evaluator.evaluate(emptyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    // OneResult FAIL with a blank MessageWhenFailed falls back to the default text.
    Record_Health_Check_Rule__mdt blankMsgFail = validDualRule(
      'D_Blank_Msg_Fail'
    );
    blankMsgFail.SourceQuery__c = 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}';
    blankMsgFail.SourceQueryField__c = 'AnnualRevenue';
    blankMsgFail.ComparisonQuery__c = 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}';
    blankMsgFail.ComparisonQueryField__c = 'AnnualRevenue';
    blankMsgFail.ComparisonOperator__c = 'GREATER_THAN';
    blankMsgFail.FailureMessage__c = null;
    RecordHealthCheckResult blankMsgResult = evaluator.evaluate(
      blankMsgFail,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(blankMsgResult, 'FAIL');
    System.assertEquals('Check failed.', blankMsgResult.message);

    // A template-invalid query (disallowed access level) surfaces through the
    // compare-queries runQuery TemplateException path.
    Record_Health_Check_Rule__mdt templateBad = validDualRule('D_Template_Bad');
    templateBad.SourceQuery__c = 'SELECT Id FROM Account WHERE Id = {!record.Id} WITH SYSTEM_MODE';
    RecordHealthCheckResult templateBadResult = evaluator.evaluate(
      templateBad,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(templateBadResult, 'UNABLE_TO_EVALUATE');

    Record_Health_Check_Rule__mdt exactMismatch = exactMatch.clone();
    exactMismatch.DeveloperName = 'D_Exact_Mismatch';
    exactMismatch.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    exactMismatch.ComparisonQueryField__c = 'BillingCity';
    assertStatus(
      evaluator.evaluate(exactMismatch, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt listsNoOverlap = listOverlap.clone();
    listsNoOverlap.DeveloperName = 'D_Lists_No_Overlap';
    listsNoOverlap.ComparisonQuery__c = 'SELECT BillingState FROM Account WHERE Id = {!record.Id}';
    listsNoOverlap.ComparisonQueryField__c = 'BillingState';
    assertStatus(
      evaluator.evaluate(listsNoOverlap, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check_Rule__mdt emptyListPass = listOverlap.clone();
    emptyListPass.DeveloperName = 'D_Empty_List_Pass';
    emptyListPass.SourceQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = null';
    emptyListPass.NoRowsResult__c = 'PASS';
    assertStatus(
      evaluator.evaluate(emptyListPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt emptyListUnable = emptyListPass.clone();
    emptyListUnable.DeveloperName = 'D_Empty_List_Unable';
    emptyListUnable.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    assertStatus(
      evaluator.evaluate(emptyListUnable, accountRecord.Id, accountRecord),
      'UNABLE_TO_EVALUATE'
    );

    Record_Health_Check_Rule__mdt emptyListSkip = emptyListPass.clone();
    emptyListSkip.DeveloperName = 'D_Empty_List_Skip';
    emptyListSkip.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(emptyListSkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt multipleRows = validDualRule(
      'D_Multiple_Rows'
    );
    multipleRows.SourceQuery__c = 'SELECT Id FROM Contact WHERE AccountId = {!record.Id}';
    multipleRows.SourceQueryField__c = 'Id';
    assertReason(
      evaluator.evaluate(multipleRows, accountRecord.Id, accountRecord),
      'MULTIPLE_ROWS_RETURNED'
    );

    Record_Health_Check_Rule__mdt missingFieldName = validDualRule(
      'D_Missing_Field_Name'
    );
    missingFieldName.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    missingFieldName.SourceQueryField__c = null;
    assertReason(
      evaluator.evaluate(missingFieldName, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt badFieldName = listOverlap.clone();
    badFieldName.DeveloperName = 'D_Bad_Field_Name';
    badFieldName.SourceQueryField__c = 'Missing__c';
    assertReason(
      evaluator.evaluate(badFieldName, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt invalidMode = validDualRule(
      'D_Invalid_Mode_Runtime'
    );
    invalidMode.QueryResultHandling__c = 'Bogus';
    assertReason(
      evaluator.evaluate(invalidMode, accountRecord.Id, accountRecord),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt invalidListOperator = listOverlap.clone();
    invalidListOperator.DeveloperName = 'D_Invalid_List_Operator_Runtime';
    invalidListOperator.ComparisonOperator__c = 'EQUALS';
    assertReason(
      evaluator.evaluate(invalidListOperator, accountRecord.Id, accountRecord),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt incompatible = validDualRule(
      'D_Incompatible'
    );
    incompatible.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    incompatible.SourceQueryField__c = 'BillingCity';
    incompatible.ComparisonQuery__c = 'SELECT BillingState FROM Account WHERE Id = {!record.Id}';
    incompatible.ComparisonQueryField__c = 'BillingState';
    incompatible.ComparisonOperator__c = 'GREATER_THAN';
    assertReason(
      evaluator.evaluate(incompatible, accountRecord.Id, accountRecord),
      'INCOMPATIBLE_COMPARISON_TYPES'
    );

    Record_Health_Check_Rule__mdt maxRows = validDualRule('D_Max_Rows');
    maxRows.SourceQuery__c = 'SELECT Id FROM Contact WHERE AccountId = {!record.Id}';
    maxRows.SourceQueryField__c = 'Id';
    maxRows.MaxQueryRows__c = 1;
    assertReason(
      evaluator.evaluate(maxRows, accountRecord.Id, accountRecord),
      'GOVERNOR_LIMIT_RISK'
    );
  }

  @IsTest
  static void formulaEvaluatorCoversPassFailUnableAndMergeFields() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    Record_Health_Check_Rule__mdt passRule = baseRule('F_Pass', 'FORMULA');
    passRule.PassConditionFormula__c = 'NOT(ISBLANK(BillingCity))';
    assertStatus(
      evaluator.evaluate(passRule, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check_Rule__mdt failRule = baseRule('F_Fail', 'FORMULA');
    failRule.PassConditionFormula__c = 'ISBLANK(BillingCity)';
    failRule.FailureMessage__c = '{!record.Name} city is {!record.BillingCity}.';
    RecordHealthCheckResult failResult = evaluator.evaluate(
      failRule,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(failResult, 'FAIL');
    System.assert(failResult.message.contains(accountRecord.Name));
    // Formula checks surface the expression as the pass/fail condition, unquoted
    // and under its own "Passes when" key rather than framed as an expected value.
    System.assertEquals(
      'ISBLANK(BillingCity)',
      failResult.expectedValue,
      'Formula FAIL should expose the formula as the pass/fail condition'
    );
    System.assertEquals(
      'Passes when',
      failResult.expectedValueLabel,
      'Formula FAIL condition carries the "Passes when" key'
    );

    Record_Health_Check_Rule__mdt nonBoolean = baseRule(
      'F_Non_Boolean',
      'FORMULA'
    );
    nonBoolean.PassConditionFormula__c = 'BillingCity';
    assertReason(
      evaluator.evaluate(nonBoolean, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );

    String[] reasonOut = new List<String>{ '' };
    System.assertEquals(
      true,
      evaluator.evaluateApplicabilityFormula(
        'NOT(ISBLANK(BillingCity))',
        accountRecord,
        reasonOut
      )
    );
    System.assertEquals(
      null,
      evaluator.evaluateApplicabilityFormula(
        'BillingCity',
        accountRecord,
        reasonOut
      )
    );
    System.assertEquals('INVALID_FORMULA', reasonOut[0]);

    System.assertEquals(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord)
    );
    System.assertEquals(
      accountRecord.AnnualRevenue,
      evaluator.resolveFormulaSingleValue('AnnualRevenue', accountRecord)
    );
    System.assertNotEquals(
      null,
      evaluator.resolveFormulaSingleValue('TODAY()', accountRecord)
    );
    System.assertNotEquals(
      null,
      evaluator.resolveFormulaSingleValue('NOW()', accountRecord)
    );
    System.assertEquals(
      null,
      evaluator.resolveMergeFields(null, accountRecord)
    );

    try {
      evaluator.resolveFormulaSingleValue(
        'Definitely_Not_A_Field__c',
        accountRecord
      );
      System.assert(false, 'Expected invalid formula exception.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException ex) {
      System.assertEquals('FIELD_NOT_ACCESSIBLE', ex.reasonCode);
    }

    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 95;
    try {
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord);
      System.assert(false, 'Expected FormulaEval limit guard.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException ex) {
      System.assertEquals('FORMULA_EVAL_LIMIT', ex.reasonCode);
    } finally {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    }
  }

  @IsTest
  static void formulaEvaluatorHonorsDeclaredReturnType() {
    // a declared single-value return type (FormulaResultType__c) resolves
    // the formula in a single FormulaEval call instead of probing up to eight types.
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    // Each picklist value maps to its FormulaReturnType; Auto/blank/unknown → null.
    System.assertEquals(
      formulaeval.FormulaReturnType.STRING,
      evaluator.mapDeclaredReturnType('TEXT')
    );
    System.assertEquals(
      formulaeval.FormulaReturnType.DECIMAL,
      evaluator.mapDeclaredReturnType('NUMBER')
    );
    System.assertEquals(
      formulaeval.FormulaReturnType.BOOLEAN,
      evaluator.mapDeclaredReturnType('BOOLEAN')
    );
    System.assertEquals(
      formulaeval.FormulaReturnType.DATE,
      evaluator.mapDeclaredReturnType('DATE')
    );
    System.assertEquals(
      formulaeval.FormulaReturnType.DATETIME,
      evaluator.mapDeclaredReturnType('DATETIME')
    );
    System.assertEquals(null, evaluator.mapDeclaredReturnType('AUTO'));
    System.assertEquals(null, evaluator.mapDeclaredReturnType(null));
    System.assertEquals(null, evaluator.mapDeclaredReturnType('Bogus'));

    // Correct declaration ('TEXT' for a text field) → exactly one FormulaEval call.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    System.assertEquals(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord, 'TEXT')
    );
    System.assertEquals(
      1,
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount,
      'Declared Text type should resolve a string formula in one FormulaEval call.'
    );

    // Auto (no declared type) probes multiple types but resolves the same value.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    System.assertEquals(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord, null)
    );
    System.assert(
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount > 1,
      'Auto (no declared type) should probe multiple return types.'
    );

    // A mis-declared type ('NUMBER' for a text field) degrades to a full probe
    // and still returns the correct value rather than failing the check.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    System.assertEquals(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue(
        'BillingCity',
        accountRecord,
        'NUMBER'
      )
    );
    System.assert(
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount > 1,
      'A wrong declared type should fall back to probing and still resolve.'
    );
  }

  @IsTest
  static void engineHelpersCoverApplicabilityAndRecordLoading() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    Record_Health_Check_Rule__mdt always = queryRule('E_Always');
    always.ApplicabilityMode__c = 'ALL_RECORDS';
    System.assertEquals(
      null,
      engine.checkApplicability(always, accountRecord.Id, accountRecord)
    );

    Record_Health_Check_Rule__mdt formulaSkip = queryRule('E_Formula_Skip');
    formulaSkip.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    formulaSkip.ApplicabilityFormula__c = 'FALSE';
    assertStatus(
      engine.checkApplicability(formulaSkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt formulaPass = formulaSkip.clone();
    formulaPass.DeveloperName = 'E_Formula_Pass';
    formulaPass.ApplicabilityFormula__c = 'TRUE';
    System.assertEquals(
      null,
      engine.checkApplicability(formulaPass, accountRecord.Id, accountRecord)
    );

    Record_Health_Check_Rule__mdt formulaUnable = formulaSkip.clone();
    formulaUnable.DeveloperName = 'E_Formula_Unable';
    formulaUnable.ApplicabilityFormula__c = 'BillingCity';
    assertReason(
      engine.checkApplicability(formulaUnable, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );

    Record_Health_Check_Rule__mdt soqlPass = queryRule('E_SOQL_Pass');
    soqlPass.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
    soqlPass.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    soqlPass.ApplicabilityCountOperator__c = 'GREATER_THAN';
    soqlPass.ApplicabilityCountThreshold__c = 0;
    System.assertEquals(
      null,
      engine.checkApplicability(soqlPass, accountRecord.Id, accountRecord)
    );

    Record_Health_Check_Rule__mdt soqlSkip = soqlPass.clone();
    soqlSkip.DeveloperName = 'E_SOQL_Skip';
    soqlSkip.ApplicabilityCountOperator__c = 'EQUALS';
    soqlSkip.ApplicabilityCountThreshold__c = 999;
    assertStatus(
      engine.checkApplicability(soqlSkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check_Rule__mdt soqlMissing = soqlPass.clone();
    soqlMissing.DeveloperName = 'E_SOQL_Missing';
    soqlMissing.ApplicabilityCountQuery__c = null;
    assertReason(
      engine.checkApplicability(soqlMissing, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check_Rule__mdt soqlBadOperator = soqlPass.clone();
    soqlBadOperator.DeveloperName = 'E_SOQL_Bad_Operator';
    soqlBadOperator.ApplicabilityCountOperator__c = 'Around';
    assertReason(
      engine.checkApplicability(
        soqlBadOperator,
        accountRecord.Id,
        accountRecord
      ),
      'INVALID_OPERATOR'
    );

    Record_Health_Check_Rule__mdt invalidMode = soqlPass.clone();
    invalidMode.DeveloperName = 'E_Invalid_Mode';
    invalidMode.ApplicabilityMode__c = 'Bogus';
    assertReason(
      engine.checkApplicability(invalidMode, accountRecord.Id, accountRecord),
      'INVALID_CONFIG'
    );

    System.assertEquals(
      true,
      engine.applyApplicabilityComparison('EQUALS', 1, 1)
    );
    System.assertEquals(
      true,
      engine.applyApplicabilityComparison('NOT_EQUALS', 1, 2)
    );
    System.assertEquals(
      true,
      engine.applyApplicabilityComparison('GREATER_THAN_OR_EQUAL', 2, 2)
    );
    System.assertEquals(
      true,
      engine.applyApplicabilityComparison('LESS_THAN', 1, 2)
    );
    System.assertEquals(
      true,
      engine.applyApplicabilityComparison('LESS_THAN_OR_EQUAL', 2, 2)
    );
    System.assertEquals(
      null,
      engine.applyApplicabilityComparison('Nope', 1, 1)
    );

    Record_Health_Check_Rule__mdt fieldRule = queryRule('E_Field_Collection');
    fieldRule.PassConditionFormula__c = 'AND(NOT(ISBLANK(BillingCity)), NOT(ISBLANK(Parent.BillingCity)))';
    fieldRule.FailureMessage__c = '{!record.Name} {!record.BillingCity} {!record.Parent.BillingCity}';
    fieldRule.UnableToEvaluateMessage__c = '{!record.Phone}';
    fieldRule.ApplicabilityNotMetMessage__c = '{!record.AccountNumber} is outside this policy.';
    fieldRule.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    fieldRule.ApplicabilityFormula__c = 'NOT(ISBLANK(Website))';
    Set<String> fields = engine.collectRecordFields(
      fieldRule,
      Account.SObjectType
    );
    System.assert(fields.contains('Id'));
    System.assert(fields.contains('BillingCity'));
    System.assert(fields.contains('Parent.BillingCity'));
    System.assert(fields.contains('AccountNumber'));
    System.assertNotEquals(
      null,
      engine.loadRecord(accountRecord.Id, fieldRule)
    );
  }

  /* Example Apex plug-ins are exercised through integration fixtures. Core
   * coverage must not compile against or depend on those fixture classes. */
  @IsTest
  static void apexDispatcherCoversCorePluginBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator();

    assertReason(
      evaluator.evaluate(
        apexRule('A_Blank', null, null),
        accountRecord.Id,
        accountRecord
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    assertReason(
      evaluator.evaluate(
        apexRule('A_Missing', 'MissingClassName', null),
        accountRecord.Id,
        accountRecord
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    assertReason(
      evaluator.evaluate(
        apexRule('A_Not_Interface', 'RecordHealthCheckResult', null),
        accountRecord.Id,
        accountRecord
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    Record_Health_Check_Rule__mdt finalizeRule = apexRule(
      'A_Finalize',
      'CoreTestPlugin',
      null
    );
    RecordHealthCheckResult fallback = new RecordHealthCheckResult();
    RecordHealthCheckResult invalidStatus = new RecordHealthCheckResult();
    invalidStatus.status = 'NOT_REAL';
    assertReason(
      evaluator.finalizeApexResult(
        finalizeRule,
        accountRecord,
        fallback,
        invalidStatus
      ),
      'APEX_EVALUATOR_ERROR'
    );

    RecordHealthCheckResult skippedStatus = new RecordHealthCheckResult();
    skippedStatus.status = 'SKIPPED';
    assertStatus(
      evaluator.finalizeApexResult(
        finalizeRule,
        accountRecord,
        new RecordHealthCheckResult(),
        skippedStatus
      ),
      'SKIPPED'
    );
    RecordHealthCheckResult missingActual = new RecordHealthCheckResult();
    missingActual.status = 'PASS';
    missingActual.expectedValue = '0 missing';
    RecordHealthCheckResult missingActualResult = evaluator.finalizeApexResult(
      finalizeRule,
      accountRecord,
      new RecordHealthCheckResult(),
      missingActual
    );
    assertReason(missingActualResult, 'APEX_EVALUATOR_ERROR');
    System.assert(
      missingActualResult.detailMessage.contains('result.actualValue'),
      missingActualResult.detailMessage
    );

    RecordHealthCheckResult missingExpected = new RecordHealthCheckResult();
    missingExpected.status = 'FAIL';
    missingExpected.actualValue = '1 missing';
    RecordHealthCheckResult missingExpectedResult = evaluator.finalizeApexResult(
      finalizeRule,
      accountRecord,
      new RecordHealthCheckResult(),
      missingExpected
    );
    assertReason(missingExpectedResult, 'APEX_EVALUATOR_ERROR');
    System.assert(
      missingExpectedResult.detailMessage.contains('result.expectedValue'),
      missingExpectedResult.detailMessage
    );
  }

  // Evaluating every check of all packaged Check Sets in a single transaction
  // exceeds the 100-SOQL governor limit (88 checks, each loading the record).
  // Production runs each Check Set in its own request, so the sweep is split
  // across several @IsTest methods (separate transactions) grouped to stay
  // under the limit while still exercising every packaged check.
  private static void sweepPackagedConfigs(
    List<String> checkSetDeveloperNames
  ) {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Map<String, RecordHealthCheckDefinitionResponse> responsesByConfig = new Map<String, RecordHealthCheckDefinitionResponse>();
    for (String checkSetDeveloperName : checkSetDeveloperNames) {
      try {
        responsesByConfig.put(
          checkSetDeveloperName,
          RecordHealthCheckController.getCheckDefinitions(
            checkSetDeveloperName,
            accountRecord.Id,
            'cov-run'
          )
        );
      } catch (Exception ex) {
        System.assert(
          false,
          'Packaged config failed to load: ' +
            checkSetDeveloperName +
            ' ' +
            ex.getMessage()
        );
      }
    }

    System.assert(
      !responsesByConfig.isEmpty(),
      'Expected packaged definition responses.'
    );
    for (String checkSetDeveloperName : responsesByConfig.keySet()) {
      for (
        RecordHealthCheckDefinition definition : responsesByConfig.get(
            checkSetDeveloperName
          )
          .checks
      ) {
        RecordHealthCheckResult result = RecordHealthCheckController.evaluateCheck(
          checkSetDeveloperName,
          definition.developerName,
          accountRecord.Id,
          'cov-run',
          RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
        );
        System.assertNotEquals(null, result.status);
      }
    }
  }

  @IsTest
  static void engineAndControllerCoverPackagedMetadataPaths() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    sweepPackagedConfigs(
      new List<String>{
        'Account_Query_Coverage',
        'Account_Relationships',
        'Account_Data_Quality'
      }
    );
  }

  @IsTest
  static void engineAndControllerCoverPackagedMetadataPathsGroupTwo() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    sweepPackagedConfigs(
      new List<String>{
        'Account_Everyday_Use_Cases',
        'Account_Aggregate_Coverage'
      }
    );
  }

  @IsTest
  static void engineAndControllerCoverPackagedMetadataPathsGroupThree() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    sweepPackagedConfigs(
      new List<String>{ 'Account_Compare_Queries', 'Account_Advanced_Checks' }
    );
  }

  @IsTest
  static void engineAndControllerCoverErrorAndBoundaryPaths() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    sweepPackagedConfigs(
      new List<String>{
        'Account_Compliance_Audit',
        'Account_AppComp_Coverage',
        'Account_Formula_Coverage'
      }
    );

    assertReason(
      engine.evaluate('Missing_Config', 'Missing_Check', accountRecord.Id),
      'RULE_NOT_FOUND'
    );
    assertReason(
      engine.evaluate(
        'Account_Data_Quality',
        'Missing_Check',
        accountRecord.Id
      ),
      'RULE_NOT_FOUND'
    );
    assertReason(
      engine.evaluate(
        'Account_Data_Quality',
        'Account_QC_IsNotBlank',
        UserInfo.getUserId()
      ),
      'RULE_NOT_FOUND'
    );
    assertReason(
      engine.evaluate('Account_Data_Quality', 'Account_DQ_BillingCity', null),
      'NO_RECORD_CONTEXT'
    );

    try {
      RecordHealthCheckController.getCheckDefinitions(
        'Missing_Config',
        accountRecord.Id,
        'cov-run'
      );
      System.assert(false, 'Expected missing config exception.');
    } catch (AuraHandledException ex) {
      System.assert(ex.getMessage().contains('CONFIG_NOT_FOUND'));
    }

    RecordHealthCheckConfigService originalService = RecordHealthCheckController.configService;
    RecordHealthCheckEngine originalEngine = RecordHealthCheckController.engine;
    try {
      RecordHealthCheckController.configService = null;
      try {
        RecordHealthCheckController.getCheckDefinitions(
          'Account_Data_Quality',
          accountRecord.Id,
          'cov-run'
        );
        System.assert(false, 'Expected generic definition exception.');
      } catch (AuraHandledException ex) {
        // an unexpected internal failure (here a null configService
        // NPE) surfaces as LOAD_FAILED, not CONFIG_NOT_FOUND, which stays
        // reserved for the explicit not-found ConfigException path.
        System.assert(
          ex.getMessage().contains('LOAD_FAILED'),
          'Expected LOAD_FAILED for unexpected load error, got: ' +
          ex.getMessage()
        );
      }

      RecordHealthCheckController.engine = null;
      RecordHealthCheckResult boundaryResult = RecordHealthCheckController.evaluateCheck(
        'Account_Data_Quality',
        'Account_DQ_BillingCity',
        accountRecord.Id,
        'cov-run',
        RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
      );
      assertReason(boundaryResult, 'APEX_EVALUATOR_ERROR');
    } finally {
      RecordHealthCheckController.configService = originalService;
      RecordHealthCheckController.engine = originalEngine;
    }
  }

  @IsTest
  static void mergeTokensResolveForNonFormulaCheckMessages() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    // {!record.FieldName} merge tokens in UnableToEvaluateMessage__c and FailureMessage__c
    // must resolve for non-Formula check types too. The packaged Query check
    // Account_QC_ERB_UnableToEvaluate carries
    // "{!record.Name} has no open cases to evaluate. …" — the literal token must never
    // reach the UI. Isolated in its own test so it has fresh governor limits.
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult result = RecordHealthCheckController.evaluateCheck(
      'Account_Query_Coverage',
      'Account_QC_ERB_UnableToEvaluate',
      accountRecord.Id,
      'merge-token-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      result.message,
      'Expected a user-facing message for the ERB check.'
    );
    System.assert(
      !result.message.contains('{!'),
      'Merge tokens must be resolved before reaching the UI: ' + result.message
    );
    if (result.status == 'UNABLE_TO_EVALUATE' || result.status == 'FAIL') {
      System.assert(
        result.message.contains(accountRecord.Name),
        'Resolved message should include the account name: ' + result.message
      );
    }
  }

  @IsTest
  static void evaluatorHelpersCoverRemainingEdgeBranches() {
    Account accountRecord = [
      SELECT Id, Name, BillingCity, BillingState, Description, AnnualRevenue
      FROM Account
      WHERE Id = :RecordHealthCheckTestDataFactory.getHealthyAccount().Id
    ];
    List<SObject> accountRows = new List<SObject>{ accountRecord };
    List<SObject> duplicateRows = new List<SObject>{
      accountRecord,
      accountRecord
    };
    List<SObject> emptyRows = new List<SObject>();

    RecordHealthCheckSoqlEvaluator soql = new RecordHealthCheckSoqlEvaluator();
    Exception queryException;
    try {
      Database.query('SELECT Missing__c FROM Account');
    } catch (System.QueryException ex) {
      queryException = ex;
    }
    System.assertNotEquals(null, queryException);
    assertReason(
      soql.applyEvaluationException(
        queryRule('Isolated_Query_Exception'),
        new RecordHealthCheckResult(),
        queryException
      ),
      'INVALID_SOQL_TEMPLATE'
    );
    assertReason(
      soql.applyEvaluationException(
        queryRule('Isolated_Evaluator_Exception'),
        new RecordHealthCheckResult(),
        new RecordHealthCheckEvaluatorException(
          'ISOLATED_SOQL',
          'isolated evaluator error'
        )
      ),
      'ISOLATED_SOQL'
    );
    assertReason(
      soql.applyEvaluationException(
        queryRule('Isolated_Generic_Exception'),
        new RecordHealthCheckResult(),
        new IllegalArgumentException('generic SOQL error')
      ),
      'APEX_EVALUATOR_ERROR'
    );
    Record_Health_Check_Rule__mdt query = queryRule('Helper_Query');
    query.NoRowsResult__c = 'FAIL';

    soql.validateNoDisallowedKeywords(
      'SELECT Last_Update__c FROM Account WHERE IsDeleted = false'
    );
    try {
      soql.validateNoDisallowedKeywords('SELECT Id FROM Account FOR UPDATE');
      System.assert(false, 'Expected disallowed phrase.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    System.assertEquals(
      1,
      soql.runQuery('SELECT COUNT() FROM Contact WHERE AccountId = null', 1)
        .size()
    );
    try {
      soql.runQuery('SELECT Id FROM Account', 0);
      System.assert(false, 'Expected row cap exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('GOVERNOR_LIMIT_RISK', ex.reasonCode);
    }
    try {
      soql.runQuery('SELECT NotAField__c FROM Account', 1);
      System.assert(false, 'Expected invalid query exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    System.assertEquals(
      accountRecord.BillingCity,
      soql.readQueryFieldValue(accountRecord, 'BillingCity')
    );
    try {
      soql.readQueryFieldValue(accountRecord, null);
      System.assert(false, 'Expected missing field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    System.assertEquals(
      1,
      soql.resolveFieldList(accountRows, 'BillingCity').size()
    );

    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applyUnaryComparison('IS_BLANK', ' ')
    );
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applyUnaryComparison(
        'IS_NOT_BLANK',
        null
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applyUnaryComparison('Bogus', 'x');
      System.assert(false, 'Expected an invalid unary operator exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'EQUALS',
        5,
        '5',
        query
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'GREATER_THAN_OR_EQUAL',
        5,
        5,
        query
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'LESS_THAN',
        Date.today(),
        Date.today().addDays(1),
        query
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'LESS_THAN_OR_EQUAL',
        Datetime.now(),
        Datetime.now().addSeconds(1),
        query
      )
    );
    Record_Health_Check_Rule__mdt missingMeansNoMatch = query.clone();
    missingMeansNoMatch.EmptyValueHandling__c = 'AS_NO_MATCH';
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        'x',
        missingMeansNoMatch
      )
    );
    query.EmptyValueHandling__c = 'AS_BLANK';
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        '',
        query
      )
    );
    query.EmptyValueHandling__c = 'SKIP_RECORD';
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        '',
        query
      )
    );

    Record_Health_Check_Rule__mdt emptyPassRule = queryRule(
      'Helper_Empty_Pass'
    );
    emptyPassRule.NoRowsResult__c = 'PASS';
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        emptyPassRule,
        emptyRows,
        'x',
        null
      )
    );
    Record_Health_Check_Rule__mdt anySkipped = queryRule('Helper_Any_Skipped');
    anySkipped.QueryResultHandling__c = 'ANY_ROW_PASSES';
    anySkipped.EmptyValueHandling__c = 'SKIP_RECORD';
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        anySkipped,
        new List<Object>{ null },
        'x',
        null
      )
    );
    Record_Health_Check_Rule__mdt allSkipped = anySkipped.clone();
    allSkipped.DeveloperName = 'Helper_All_Skipped';
    allSkipped.QueryResultHandling__c = 'ALL_ROWS_PASS';
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        allSkipped,
        new List<Object>{ null },
        'x',
        null
      )
    );
    Record_Health_Check_Rule__mdt badMode = anySkipped.clone();
    badMode.DeveloperName = 'Helper_Bad_Mode';
    badMode.QueryResultHandling__c = 'Nope';
    try {
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        badMode,
        new List<Object>{ 'x' },
        'x',
        null
      );
      System.assert(false, 'Expected invalid mode.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }

    query.EmptyValueHandling__c = 'AS_NO_MATCH';
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_ANY',
        null,
        new List<Object>{ 'a' },
        query
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_NONE',
        null,
        new List<Object>{ 'a' },
        query
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applyListComparison(
        'BadList',
        'a',
        new List<Object>{ 'a' },
        query
      );
      System.assert(false, 'Expected invalid list operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling('AS_NO_MATCH')
    );
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling('SKIP_RECORD')
    );
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling(null)
    );
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('FAIL')
    );
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior(
        'UNABLE_TO_EVALUATE'
      )
    );
    System.assertEquals(
      'FAIL',
      soql.buildEmptyOrNullResult(query, new RecordHealthCheckResult(), null)
        .status
    );
    query.NoRowsResult__c = 'PASS';
    System.assertEquals(
      'PASS',
      soql.buildEmptyOrNullResult(query, new RecordHealthCheckResult(), null)
        .status
    );
    query.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    assertReason(
      soql.buildEmptyOrNullResult(query, new RecordHealthCheckResult(), null),
      'NO_ROWS_RETURNED'
    );
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.isNumericObject(Decimal.valueOf('1.5'))
    );
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.isNumericObject('1.5')
    );

    // ── Actual-vs-expected description helpers ──────────────────────────────
    System.assertEquals(
      'to equal',
      RecordHealthCheckComparisonEngine.operatorLabel('EQUALS')
    );
    System.assertEquals(
      'at least',
      RecordHealthCheckComparisonEngine.operatorLabel('GREATER_THAN_OR_EQUAL')
    );
    // Unknown operator falls back to the raw API name
    System.assertEquals(
      'Mystery',
      RecordHealthCheckComparisonEngine.operatorLabel('Mystery')
    );
    System.assertEquals(
      '(blank)',
      RecordHealthCheckComparisonEngine.formatValue(null)
    );
    System.assertEquals(
      '(blank)',
      RecordHealthCheckComparisonEngine.formatValue('   ')
    );
    System.assertEquals(
      'Technology',
      RecordHealthCheckComparisonEngine.formatValue('Technology')
    );
    // Values are unquoted because the UI chip visually distinguishes them.
    System.assertEquals('1', RecordHealthCheckComparisonEngine.formatValue(1));
    // Booleans read Yes/No, whether they arrive as a typed Boolean (checkbox
    // field, boolean formula) or as a metadata operand string.
    System.assertEquals(
      'Yes',
      RecordHealthCheckComparisonEngine.formatValue(true)
    );
    System.assertEquals(
      'No',
      RecordHealthCheckComparisonEngine.formatValue(false)
    );
    System.assertEquals(
      'Yes',
      RecordHealthCheckComparisonEngine.formatValue('true')
    );
    System.assertEquals(
      'No',
      RecordHealthCheckComparisonEngine.formatValue('False')
    );
    // Typed numbers gain thousands separators; digit-only strings retain their
    // exact spelling because they may be postal codes, years, or identifiers.
    System.assertEquals(
      '70,000',
      RecordHealthCheckComparisonEngine.formatValue(70000.0)
    );
    System.assertEquals(
      'to equal 100,000',
      RecordHealthCheckComparisonEngine.describeExpectedForActual(
        'EQUALS',
        '100000',
        Decimal.valueOf('100000')
      )
    );
    System.assertEquals(
      'to equal 0012345',
      RecordHealthCheckComparisonEngine.describeExpectedForActual(
        'EQUALS',
        '0012345',
        '0012345'
      )
    );
    System.assertEquals(
      '500000',
      RecordHealthCheckComparisonEngine.formatValue('500000')
    );
    System.assertEquals(
      '0012345',
      RecordHealthCheckComparisonEngine.formatValue('0012345')
    );
    System.assertEquals(
      '90210',
      RecordHealthCheckComparisonEngine.formatValue('90210')
    );
    System.assertEquals(
      '70,000.5',
      RecordHealthCheckComparisonEngine.formatValue(70000.5)
    );
    System.assertEquals(
      '-1,234,567',
      RecordHealthCheckComparisonEngine.formatValue(-1234567)
    );
    // Multi-select picklist text (semicolon-delimited) reads comma-separated.
    System.assertEquals(
      'Hot, Warm, Cold',
      RecordHealthCheckComparisonEngine.formatValue('Hot;Warm;Cold')
    );
    // Dates/datetimes render in the user's locale — assert the raw ISO shape is
    // gone (no dashes) rather than a locale-specific literal, so the test is not
    // brittle across orgs. Both the typed value and the ISO operand string
    // humanize identically.
    String typedDate = RecordHealthCheckComparisonEngine.formatValue(
      Date.newInstance(2026, 7, 4)
    );
    System.assert(
      typedDate.contains('2026') && !typedDate.contains('-'),
      'Typed Date should be locale-formatted, got ' + typedDate
    );
    System.assertEquals(
      typedDate,
      RecordHealthCheckComparisonEngine.formatValue('2026-07-04'),
      'ISO date operand string should humanize like the typed Date'
    );
    String typedDatetime = RecordHealthCheckComparisonEngine.formatValue(
      Datetime.newInstance(2026, 7, 4, 17, 30, 0)
    );
    System.assert(
      typedDatetime.contains('2026') && !typedDatetime.contains('T'),
      'Typed Datetime should be locale-formatted, got ' + typedDatetime
    );
    // Non-numeric, non-temporal text (letters, codes) is left exactly as-is.
    System.assertEquals(
      '1-800-CALL',
      RecordHealthCheckComparisonEngine.formatValue('1-800-CALL')
    );
    System.assertEquals(
      '(none)',
      RecordHealthCheckComparisonEngine.formatList(new List<Object>())
    );
    System.assertEquals(
      '[A, B]',
      RecordHealthCheckComparisonEngine.formatList(new List<Object>{ 'A', 'B' })
    );
    // Over the preview cap, the list is truncated with a total count
    List<Object> big = new List<Object>();
    for (Integer i = 0; i < 12; i++) {
      big.add(i);
    }
    System.assert(
      RecordHealthCheckComparisonEngine.formatList(big).contains('(12 total)'),
      'Long lists should show a total count'
    );
    System.assertEquals(
      'to equal Technology',
      RecordHealthCheckComparisonEngine.describeExpected('EQUALS', 'Technology')
    );
    // Unary operators have no operand
    System.assertEquals(
      'to not be blank',
      RecordHealthCheckComparisonEngine.describeExpected('IS_NOT_BLANK', null)
    );
    System.assertEquals(
      'to be one of [North, South]',
      RecordHealthCheckComparisonEngine.describeExpectedList(
        'LIST_CONTAINS_ANY',
        new List<Object>{ 'North', 'South' }
      )
    );

    RecordHealthCheckCompareQueriesEvaluator compareQueries = new RecordHealthCheckCompareQueriesEvaluator();
    assertReason(
      compareQueries.applyEvaluationException(
        validDualRule('Isolated_Dual_Query_Exception'),
        new RecordHealthCheckResult(),
        queryException
      ),
      'INVALID_SOQL_TEMPLATE'
    );
    assertReason(
      compareQueries.applyEvaluationException(
        validDualRule('Isolated_Dual_Evaluator_Exception'),
        new RecordHealthCheckResult(),
        new RecordHealthCheckEvaluatorException(
          'ISOLATED_DUAL',
          'isolated compare-queries error'
        )
      ),
      'ISOLATED_DUAL'
    );
    assertReason(
      compareQueries.applyEvaluationException(
        validDualRule('Isolated_Dual_Generic_Exception'),
        new RecordHealthCheckResult(),
        new IllegalArgumentException('generic compare-queries error')
      ),
      'APEX_EVALUATOR_ERROR'
    );
    Record_Health_Check_Rule__mdt dualRule = validDualRule('Helper_Dual');
    dualRule.NoRowsResult__c = 'FAIL';
    dualRule.SourceQueryField__c = 'BillingCity';
    dualRule.ComparisonQueryField__c = 'BillingCity';
    dualRule.EmptyValueHandling__c = 'AS_NO_MATCH';

    System.assertEquals(
      false,
      compareQueries.evaluateSingleVsSingle(dualRule, emptyRows, accountRows)
    );
    dualRule.EmptyValueHandling__c = 'AS_BLANK';
    System.assertEquals(
      true,
      compareQueries.evaluateSingleVsSingle(dualRule, emptyRows, emptyRows)
    );
    dualRule.EmptyValueHandling__c = null;
    System.assertEquals(
      null,
      compareQueries.evaluateSingleVsSingle(dualRule, emptyRows, accountRows)
    );
    try {
      compareQueries.resolveSingleValue(duplicateRows, 'Id', 'primary');
      System.assert(false, 'Expected multiple row exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('MULTIPLE_ROWS_RETURNED', ex.reasonCode);
    }
    try {
      compareQueries.resolveSingleValue(accountRows, null, 'primary');
      System.assert(false, 'Expected missing field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Record_Health_Check_Rule__mdt dualList = validDualRule('Helper_Dual_List');
    dualList.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualList.SourceQueryField__c = 'BillingCity';
    dualList.ComparisonQueryField__c = 'BillingState';
    dualList.ComparisonOperator__c = 'LISTS_OVERLAP';
    System.assertEquals(
      false,
      compareQueries.evaluateListVsList(dualList, accountRows, accountRows)
    );
    dualList.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    dualList.ComparisonQueryField__c = 'BillingCity';
    System.assertEquals(
      true,
      compareQueries.evaluateListVsList(dualList, accountRows, accountRows)
    );
    dualList.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    System.assertEquals(
      true,
      compareQueries.evaluateListVsList(dualList, accountRows, accountRows)
    );
    dualList.ComparisonOperator__c = 'BadList';
    try {
      compareQueries.evaluateListVsList(dualList, accountRows, accountRows);
      System.assert(false, 'Expected invalid compare-queries list operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
    try {
      compareQueries.toStringList(accountRows, null, 'primary', 'AS_BLANK');
      System.assert(false, 'Expected missing list field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      compareQueries.toStringList(
        accountRows,
        'Missing__c',
        'primary',
        'AS_BLANK'
      );
      System.assert(false, 'Expected invalid list field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'NOT_EQUALS',
        'a',
        'b'
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'CONTAINS',
        'abc',
        'b'
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'DOES_NOT_CONTAIN',
        'abc',
        'z'
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        2,
        2
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'LESS_THAN_OR_EQUAL',
        Datetime.now(),
        Datetime.now().addSeconds(1)
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'LESS_THAN',
        Date.today(),
        Date.today().addDays(1)
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'Nope',
        'a',
        'b'
      );
      System.assert(false, 'Expected invalid single-value operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
    try {
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN',
        'a',
        'b'
      );
      System.assert(false, 'Expected incompatible single-value operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }

    System.assertEquals(
      false,
      compareQueries.frequencyMapsEqual(
        compareQueries.toFrequencyMap(new List<String>{ 'a' }),
        compareQueries.toFrequencyMap(new List<String>{ 'a', 'a' })
      )
    );
    try {
      RecordHealthCheckComparisonEngine.valuesEqual(
        Date.today(),
        String.valueOf(Date.today())
      );
      System.assert(false, 'Expected Date coercion incompatibility.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assert(
        ex.reasonCode == 'INCOMPATIBLE_COMPARISON_TYPES',
        'Expected a typed comparison error.'
      );
    }
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.isNumericObject(Decimal.valueOf('1'))
    );
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.isNumericObject('1')
    );
    try {
      compareQueries.runQuery('SELECT Id FROM Account', 0);
      System.assert(false, 'Expected compare-queries row cap exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('GOVERNOR_LIMIT_RISK', ex.reasonCode);
    }
    try {
      compareQueries.runQuery('SELECT Missing__c FROM Account', 1);
      System.assert(false, 'Expected compare-queries invalid query exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('FAIL')
    );
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('SKIP')
    );
    System.assertEquals(
      'FAIL',
      compareQueries.buildEmptyOrNullResult(
          dualRule,
          new RecordHealthCheckResult()
        )
        .status
    );
    dualRule.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    assertReason(
      compareQueries.buildEmptyOrNullResult(
        dualRule,
        new RecordHealthCheckResult()
      ),
      'NO_ROWS_RETURNED'
    );

    RecordHealthCheckFormulaEvaluator formula = new RecordHealthCheckFormulaEvaluator();
    Record_Health_Check_Rule__mdt formulaMessageRule = baseRule(
      'Formula_Message',
      'FORMULA'
    );
    formulaMessageRule.UnableToEvaluateMessage__c = null;
    System.assertEquals(
      'This check could not be evaluated. Contact your administrator.',
      formula.safeCannotEvaluateMessage(formulaMessageRule)
    );
    System.assertEquals(
      'INVALID_FORMULA',
      formula.classifyFormulaException(
        new RecordHealthCheckFormulaEvaluator.FormulaEvaluationException(
          'X',
          'ordinary parse problem'
        )
      )
    );
    System.assertEquals(
      'FIELD_NOT_ACCESSIBLE',
      formula.classifyFormulaException(
        new RecordHealthCheckFormulaEvaluator.FormulaEvaluationException(
          'X',
          'access denied'
        )
      )
    );
  }

  @IsTest
  static void isolatedResultAndRoutingHelpersCoverDefensiveBranches() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = [
      SELECT Id, Name, BillingCity, BillingState, Description, AnnualRevenue
      FROM Account
      WHERE Id = :RecordHealthCheckTestDataFactory.getHealthyAccount().Id
    ];

    RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
    Record_Health_Check_Set__mdt validSet = new Record_Health_Check_Set__mdt(
      DeveloperName = 'Isolated_Set',
      MasterLabel = 'Isolated Set',
      IsActive__c = true,
      ObjectApiName__c = 'Account',
      PassedChecksDisplay__c = 'SHOW_EACH_CHECK',
      SkippedChecksDisplay__c = 'SHOW_COUNT_ONLY',
      CardRunMode__c = 'RUN_ON_REQUEST',
      CardRevealMode__c = 'ALL_AT_ONCE',
      FoundExpectedDisplay__c = 'ON_DEMAND'
    );
    configService.validateCheckSetForDefinition(
      validSet,
      'Isolated_Set',
      accountRecord.Id
    );

    List<Record_Health_Check_Set__mdt> invalidSets = new List<Record_Health_Check_Set__mdt>();
    List<String> invalidReasons = new List<String>();
    Record_Health_Check_Set__mdt inactiveSet = validSet.clone();
    inactiveSet.IsActive__c = false;
    invalidSets.add(inactiveSet);
    invalidReasons.add(RecordHealthCheckConfigService.RC_CONFIG_INACTIVE);
    Record_Health_Check_Set__mdt blankObjectSet = validSet.clone();
    blankObjectSet.ObjectApiName__c = null;
    invalidSets.add(blankObjectSet);
    // a blank Base Object is now INVALID_CONFIG, not CONFIG_NOT_FOUND.
    invalidReasons.add(RecordHealthCheckConfigService.RC_INVALID_CONFIG);
    Record_Health_Check_Set__mdt mismatchSet = validSet.clone();
    mismatchSet.ObjectApiName__c = 'Contact';
    invalidSets.add(mismatchSet);
    invalidReasons.add(RecordHealthCheckConfigService.RC_OBJECT_MISMATCH);
    Record_Health_Check_Set__mdt successSet = validSet.clone();
    successSet.PassedChecksDisplay__c = 'Maybe';
    invalidSets.add(successSet);
    invalidReasons.add(RecordHealthCheckConfigService.RC_INVALID_CONFIG);
    Record_Health_Check_Set__mdt skippedSet = validSet.clone();
    skippedSet.SkippedChecksDisplay__c = 'Maybe';
    invalidSets.add(skippedSet);
    invalidReasons.add(RecordHealthCheckConfigService.RC_INVALID_CONFIG);
    Record_Health_Check_Set__mdt triggerSet = validSet.clone();
    triggerSet.CardRunMode__c = 'Sometimes';
    invalidSets.add(triggerSet);
    invalidReasons.add(RecordHealthCheckConfigService.RC_INVALID_CONFIG);
    Record_Health_Check_Set__mdt revealSet = validSet.clone();
    revealSet.CardRevealMode__c = 'Eventually';
    invalidSets.add(revealSet);
    invalidReasons.add(RecordHealthCheckConfigService.RC_INVALID_CONFIG);
    for (Integer i = 0; i < invalidSets.size(); i++) {
      try {
        configService.validateCheckSetForDefinition(
          invalidSets[i],
          'Isolated_Set',
          accountRecord.Id
        );
        System.assert(false, 'Expected invalid Check Set at index ' + i);
      } catch (RecordHealthCheckConfigService.ConfigException ex) {
        System.assertEquals(invalidReasons[i], ex.reasonCode);
      }
    }
    try {
      configService.validateActiveRulesForDefinition(
        new List<Record_Health_Check_Rule__mdt>(),
        'Isolated_Set'
      );
      System.assert(false, 'Expected no-active-checks error.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      System.assertEquals(
        RecordHealthCheckConfigService.RC_NO_ACTIVE_CHECKS,
        ex.reasonCode
      );
    }
    List<Record_Health_Check_Rule__mdt> thirtyRules = new List<Record_Health_Check_Rule__mdt>();
    for (Integer i = 0; i < 30; i++) {
      thirtyRules.add(baseRule('Rule_' + i, 'FORMULA'));
    }
    System.assertEquals(
      25,
      configService.selectRulesForRun(thirtyRules).size()
    );

    RecordHealthCheckFormulaEvaluator formula = new RecordHealthCheckFormulaEvaluator();
    Record_Health_Check_Rule__mdt formulaRule = baseRule(
      'Isolated_Formula',
      'FORMULA'
    );
    assertReason(
      formula.applyEvaluationResult(
        formulaRule,
        accountRecord,
        new RecordHealthCheckResult(),
        null
      ),
      'INVALID_FORMULA'
    );
    assertReason(
      formula.applyEvaluationException(
        formulaRule,
        new RecordHealthCheckResult(),
        new IllegalArgumentException('isolated formula error')
      ),
      'INVALID_FORMULA'
    );
    assertStatus(
      formula.applyEvaluationResult(
        formulaRule,
        accountRecord,
        new RecordHealthCheckResult(),
        true
      ),
      'PASS'
    );
    RecordHealthCheckResult formulaFail = formula.applyEvaluationResult(
      formulaRule,
      accountRecord,
      new RecordHealthCheckResult(),
      false
    );
    assertStatus(formulaFail, 'FAIL');
    System.assert(formulaFail.message.contains(accountRecord.Name));
    assertReason(
      formula.applyEvaluationResult(
        formulaRule,
        accountRecord,
        new RecordHealthCheckResult(),
        'not boolean'
      ),
      'INVALID_FORMULA'
    );

    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator();
    Record_Health_Check_Rule__mdt apex = apexRule(
      'Isolated_Apex',
      'TestOnlyRule',
      null
    );
    RecordHealthCheckContext context = new RecordHealthCheckContext();
    context.recordId = accountRecord.Id;
    context.record = accountRecord;
    assertReason(
      evaluator.invokeAndFinalize(
        new ThrowingRule(),
        context,
        apex,
        accountRecord,
        new RecordHealthCheckResult()
      ),
      'APEX_EVALUATOR_ERROR'
    );
    assertReason(
      evaluator.invokeAndFinalize(
        new NullRule(),
        context,
        apex,
        accountRecord,
        new RecordHealthCheckResult()
      ),
      'APEX_EVALUATOR_ERROR'
    );
    RecordHealthCheckResult blankFailure = new RecordHealthCheckResult();
    blankFailure.status = 'FAIL';
    blankFailure.actualValue = '1 issue';
    blankFailure.expectedValue = '0 issues';
    apex.FailureMessage__c = null;
    System.assertEquals(
      'Check failed.',
      evaluator.finalizeApexResult(
          apex,
          accountRecord,
          new RecordHealthCheckResult(),
          blankFailure
        )
        .message
    );
    apex.UnableToEvaluateMessage__c = null;
    assertReason(
      evaluator.evaluate(apex, accountRecord.Id, accountRecord),
      'APEX_CLASS_NOT_FOUND'
    );
    assertReason(
      evaluator.evaluate(
        apexRule('A_Interface', 'RecordHealthCheckRule', null),
        accountRecord.Id,
        accountRecord
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    Record_Health_Check_Rule__mdt invalidArrayParameters = apexRule(
      'A_Array_Params',
      'AccountHasRecentActivityCheck',
      null
    );
    invalidArrayParameters.ApexParametersJson__c = '["not-an-object"]';
    assertReason(
      evaluator.evaluate(
        invalidArrayParameters,
        accountRecord.Id,
        accountRecord
      ),
      'INVALID_APEX_PARAMETERS'
    );
    Record_Health_Check_Rule__mdt malformedParameters = apexRule(
      'A_Bad_Params',
      'AccountHasRecentActivityCheck',
      null
    );
    malformedParameters.ApexParametersJson__c = '{bad json';
    assertReason(
      evaluator.evaluate(malformedParameters, accountRecord.Id, accountRecord),
      'INVALID_APEX_PARAMETERS'
    );
    assertReason(
      evaluator.evaluate(
        apexRule('A_No_Record', 'AccountHasRecentActivityCheck', null),
        null,
        accountRecord
      ),
      'APEX_EVALUATOR_ERROR'
    );

    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    System.assertEquals(
      false,
      engine
        .validateCheckSetContext(
          null,
          'Isolated_Set',
          'Isolated_Check',
          accountRecord.Id
        )
        .showDiagnostics
    );
    Record_Health_Check_Set__mdt activeContextSet = new Record_Health_Check_Set__mdt(
      DeveloperName = 'Isolated_Context_Set',
      MasterLabel = 'Isolated Context Set',
      IsActive__c = true,
      ShowDiagnostics__c = true,
      ObjectApiName__c = 'Account'
    );
    System.assertEquals(
      true,
      engine
        .validateCheckSetContext(
          activeContextSet,
          'Isolated_Set',
          'Isolated_Check',
          accountRecord.Id
        )
        .showDiagnostics
    );
    Record_Health_Check_Set__mdt inactiveContextSet = activeContextSet.clone();
    inactiveContextSet.IsActive__c = false;
    assertReason(
      engine
        .validateCheckSetContext(
          inactiveContextSet,
          'Isolated_Set',
          'Isolated_Check',
          accountRecord.Id
        )
        .result,
      'CONFIG_INACTIVE'
    );
    Record_Health_Check_Set__mdt mismatchContextSet = activeContextSet.clone();
    mismatchContextSet.ObjectApiName__c = 'Contact';
    assertReason(
      engine
        .validateCheckSetContext(
          mismatchContextSet,
          'Isolated_Set',
          'Isolated_Check',
          accountRecord.Id
        )
        .result,
      'OBJECT_MISMATCH'
    );
    assertStatus(
      engine.routeEvaluator(formulaRule, accountRecord.Id, accountRecord),
      'PASS'
    );
    assertStatus(
      engine.routeEvaluator(
        queryRule('Isolated_Query'),
        accountRecord.Id,
        accountRecord
      ),
      'PASS'
    );
    assertStatus(
      engine.routeEvaluator(
        validDualRule('Isolated_Dual'),
        accountRecord.Id,
        accountRecord
      ),
      'PASS'
    );
    RecordHealthCheckResult routedApex = engine.routeEvaluator(
      apexRule(
        'Isolated_Routed_Apex',
        'AccountHasRecentActivityCheck',
        '{"daysBack":90}'
      ),
      accountRecord.Id,
      accountRecord
    );
    System.assert(
      routedApex.status == 'PASS' || routedApex.status == 'FAIL',
      'Expected the Apex route to evaluate.'
    );
    assertReason(
      engine.routeEvaluator(
        baseRule('Isolated_Invalid_Type', 'Bogus'),
        accountRecord.Id,
        accountRecord
      ),
      'INVALID_CHECK_TYPE'
    );
    assertStatus(
      engine.evaluate(
        'Account_Advanced_Checks',
        'Account_Adv_ContactHasEmail',
        accountRecord.Id
      ),
      'PASS'
    );
    Account accountWithoutContacts = RecordHealthCheckTestDataFactory.createAccount(
      'No Contacts Account'
    );
    RecordHealthCheckResult dependencySkipped = engine.evaluate(
      'Account_Advanced_Checks',
      'Account_Adv_ContactHasEmail',
      accountWithoutContacts.Id
    );
    assertStatus(dependencySkipped, 'SKIPPED');
    assertReason(
      dependencySkipped,
      RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET
    );

    Account deletedAccount = RecordHealthCheckTestDataFactory.createDeletedAccount(
      'Deleted Coverage Account'
    );
    assertReason(
      engine.evaluate(
        'Account_Data_Quality',
        'Account_DQ_BillingCity',
        deletedAccount.Id
      ),
      RecordHealthCheckReasonCodes.CANNOT_EVALUATE
    );
    assertReason(
      engine.evaluate(
        'Account_Data_Quality',
        'Account_DQ_BillingCity',
        UserInfo.getUserId()
      ),
      'OBJECT_MISMATCH'
    );
    Account circularDependencyAccount = RecordHealthCheckTestDataFactory.createAccount(
      'Circular Dependency Account'
    );
    assertReason(
      new RecordHealthCheckEngine()
        .doEvaluate(
          'Account_Advanced_Checks',
          'Account_Adv_ContactHasEmail',
          circularDependencyAccount.Id,
          new Set<String>{ 'Account_Adv_HasContact' },
          new RecordHealthCheckLogger(
            'coverage-run',
            'Account_Advanced_Checks',
            circularDependencyAccount.Id
          )
        ),
      'CIRCULAR_DEPENDENCY'
    );

    RecordHealthCheckResult debugResult = new RecordHealthCheckResult();
    debugResult.detailMessage = 'admin detail';
    RecordHealthCheckAccess.viewDetailsPermissionOverride = true;
    System.assertEquals(
      'admin detail',
      engine.applyShowDiagnostics(debugResult, true).adminDetailMessage
    );
    RecordHealthCheckResult noDebugResult = new RecordHealthCheckResult();
    noDebugResult.detailMessage = 'hidden detail';
    System.assertEquals(
      null,
      engine.applyShowDiagnostics(noDebugResult, false).adminDetailMessage
    );
    RecordHealthCheckAccess.viewDetailsPermissionOverride = null;
    Set<String> blankFieldSet = new Set<String>();
    engine.addReadableField(blankFieldSet, Account.SObjectType, null);
    System.assertEquals(0, blankFieldSet.size());

    Record_Health_Check_Rule__mdt skippedRule = queryRule('Isolated_Skipped');
    skippedRule.ApplicabilityMode__c = 'Unexpected';
    assertStatus(engine.buildSkippedResult(skippedRule), 'SKIPPED');
    skippedRule.UnableToEvaluateMessage__c = null;
    assertReason(
      engine.buildUnableResult(
        skippedRule,
        'ISOLATED_REASON',
        'isolated detail'
      ),
      'ISOLATED_REASON'
    );

    RecordHealthCheckSoqlEvaluator soql = new RecordHealthCheckSoqlEvaluator();
    try {
      soql.bindTokens(null, accountRecord);
      System.assert(false, 'Expected blank template error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    System.assertEquals(
      'SELECT Id FROM Account WHERE Description = null',
      soql.bindTokens(
        'SELECT Id FROM Account WHERE Description = {!record.Description}',
        accountRecord
      )
    );
    Opportunity opportunityRecord = [
      SELECT Id, CloseDate, CreatedDate
      FROM Opportunity
      WHERE AccountId = :accountRecord.Id
      LIMIT 1
    ];
    System.assert(
      soql.bindTokens(
          'SELECT Id FROM Opportunity WHERE CloseDate = {!record.CloseDate}',
          opportunityRecord
        )
        .contains(String.valueOf(opportunityRecord.CloseDate))
    );
    System.assert(
      soql.bindTokens(
          'SELECT Id FROM Opportunity WHERE CreatedDate = {!record.CreatedDate}',
          opportunityRecord
        )
        .contains('T')
    );
    User currentUser = [
      SELECT Id, IsActive
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    System.assert(
      soql.bindTokens(
          'SELECT Id FROM User WHERE IsActive = {!record.IsActive}',
          currentUser
        )
        .contains('true')
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.valuesEqual(null, null)
    );
    try {
      RecordHealthCheckComparisonEngine.valuesEqual(
        Decimal.valueOf('1'),
        'not numeric'
      );
      System.assert(false, 'Expected numeric parse error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_ANY',
        'missing',
        new List<Object>{ 'present' },
        queryRule('Isolated_List')
      )
    );
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_NONE',
        'present',
        new List<Object>{ 'present' },
        queryRule('Isolated_List_Not')
      )
    );
    Record_Health_Check_Rule__mdt skipEmpty = queryRule('Isolated_Empty_Skip');
    skipEmpty.NoRowsResult__c = 'SKIP';
    assertStatus(
      soql.buildEmptyOrNullResult(
        skipEmpty,
        new RecordHealthCheckResult(),
        null
      ),
      'SKIPPED'
    );
    System.assertEquals(
      null,
      soql.resolveFieldPath(new Account(Name = 'No Parent'), 'Parent.Name')
    );
    System.assertEquals(
      false,
      soql.isMultiSelectPicklist(accountRecord, 'Parent.Name')
    );
    System.assertEquals(
      '(\'Alpha\', \'Beta\')',
      soql.buildMultiSelectIncludesClause('Alpha;; Beta;')
    );
    Record_Health_Check_Rule__mdt namingRule = queryRule('Naming');
    namingRule.SourceQuery__c = null;
    System.assertEquals('records', soql.pluralizeObject(namingRule));
    namingRule.SourceQuery__c = 'SELECT Id FROM Category';
    System.assertEquals('Categories', soql.pluralizeObject(namingRule));
    namingRule.SourceQuery__c = 'SELECT Id FROM Box';
    System.assertEquals('Boxes', soql.pluralizeObject(namingRule));
    namingRule.SourceQuery__c = 'SELECT Id FROM Widget';
    System.assertEquals('Widgets', soql.pluralizeObject(namingRule));

    Record_Health_Check_Rule__mdt sourceRule = queryRule('Sources');
    sourceRule.ExpectedValueSource__c = 'FIXED_VALUE';
    System.assertEquals(
      'Fixed value',
      soql.describeComparisonSource(sourceRule)
    );
    sourceRule.ExpectedValueSource__c = 'RECORD_FORMULA';
    System.assertEquals(
      'Formula on this record',
      soql.describeComparisonSource(sourceRule)
    );
    sourceRule.ExpectedValueSource__c = 'COMPARISON_QUERY';
    sourceRule.ComparisonQueryField__c = 'Amount';
    System.assertEquals(
      'Comparison query (Amount)',
      soql.describeComparisonSource(sourceRule)
    );
    sourceRule.ExpectedValueSource__c = 'UNRECOGNIZED';
    System.assertEquals('Amount', soql.describeComparisonSource(sourceRule));
    sourceRule.ComparisonQueryField__c = null;
    System.assertEquals(
      'Comparison',
      soql.describeComparisonSource(sourceRule)
    );

    System.assertEquals(
      true,
      soql.coerceFallbackValue(currentUser, 'IsActive', 'true')
    );
    System.assertEquals(
      Date.today(),
      soql.coerceFallbackValue(
        opportunityRecord,
        'CloseDate',
        String.valueOf(Date.today())
      )
    );
    System.assertEquals(
      42,
      soql.coerceFallbackValue(accountRecord, 'NumberOfEmployees', '42')
    );
    System.assertEquals(
      Decimal.valueOf('12.5'),
      soql.coerceFallbackValue(accountRecord, 'AnnualRevenue', '12.5')
    );
    System.assertEquals(
      Time.newInstance(9, 8, 7, 120),
      soql.parseTimeFallback('09:08:07.12Z')
    );
    System.assertEquals(
      Schema.DisplayType.STRING,
      soql.terminalFieldType(accountRecord, 'MissingField')
    );
    System.assertEquals(
      Schema.DisplayType.STRING,
      soql.terminalFieldType(accountRecord, 'Parent.Name')
    );
    System.assertEquals(
      null,
      soql.coerceFallbackValue(accountRecord, 'Name', '  ')
    );
    System.assertEquals(
      Time.newInstance(9, 8, 7, 123),
      soql.parseTimeFallback('09:08:07.1239')
    );
    try {
      soql.coerceFallbackValue(currentUser, 'IsActive', 'maybe');
      System.assert(false, 'Expected invalid Boolean fallback to fail.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('MISSING_BIND_VALUE', ex.reasonCode);
    }
    try {
      soql.parseTimeFallback('09:08');
      System.assert(false, 'Expected invalid time fallback to fail.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('MISSING_BIND_VALUE', ex.reasonCode);
    }

    System.assertEquals(null, engine.describeFieldPath(null, 'Name'));
    System.assertEquals(0, engine.scanFormulaFieldTokens(null).size());
    engine.resolveEvalResultMessage(
      null,
      queryRule('Null_Result'),
      accountRecord
    );
    Record_Health_Check_Rule__mdt defaultMessageRule = queryRule(
      'Default_Message'
    );
    defaultMessageRule.FailureMessage__c = null;
    RecordHealthCheckResult defaultMessageResult = new RecordHealthCheckResult();
    defaultMessageResult.status = 'FAIL';
    engine.resolveEvalResultMessage(
      defaultMessageResult,
      defaultMessageRule,
      accountRecord
    );
    System.assertEquals('Check failed.', defaultMessageResult.message);
    defaultMessageRule.ActionUrl__c =
      '/lightning/r/Account/' + accountRecord.Id;
    defaultMessageRule.ActionLabel__c = null;
    engine.populateRemediationAction(
      defaultMessageResult,
      defaultMessageRule,
      accountRecord
    );
    System.assertEquals('Fix this', defaultMessageResult.actionLabel);

    RecordHealthCheckCompareQueriesEvaluator compareQueries = new RecordHealthCheckCompareQueriesEvaluator();
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.valuesEqual(null, null)
    );
    try {
      RecordHealthCheckComparisonEngine.valuesEqual(
        Decimal.valueOf('1'),
        'not numeric'
      );
      System.assert(false, 'Expected compare-queries numeric parse error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('PASS')
    );
    Record_Health_Check_Rule__mdt dualSkip = validDualRule(
      'Isolated_Dual_Skip'
    );
    dualSkip.NoRowsResult__c = 'SKIP';
    assertStatus(
      compareQueries.buildEmptyOrNullResult(
        dualSkip,
        new RecordHealthCheckResult()
      ),
      'SKIPPED'
    );
  }

  @IsTest
  static void formulaEvaluatorCoversNullAndMergeFieldBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    String[] reasonCode = new List<String>{ null };

    System.assertEquals(
      null,
      evaluator.evaluateApplicabilityFormula('NULL', accountRecord, reasonCode)
    );
    System.assertEquals('INVALID_FORMULA', reasonCode[0]);

    Account nullTextAccount = new Account(Name = 'null');
    System.assertEquals(
      'Name: ',
      evaluator.resolveMergeFields('Name: {!record.Name}', nullTextAccount)
    );
    RecordHealthCheckResult result = evaluator.applyEvaluationException(
      baseRule('Formula_Limit', 'FORMULA'),
      new RecordHealthCheckResult(),
      new RecordHealthCheckFormulaEvaluator.FormulaEvaluationException(
        'FORMULA_EVAL_LIMIT',
        'limit'
      )
    );
    assertReason(result, 'FORMULA_EVAL_LIMIT');
  }

  @IsTest
  static void configServiceCoversRemainingValidationBranches() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Record_Health_Check_Set__mdt invalidObject = new Record_Health_Check_Set__mdt(
      DeveloperName = 'Invalid_Object',
      IsActive__c = true,
      ObjectApiName__c = 'Missing__c'
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
  static void metadataValidatorCoversRemainingValidationBranches() {
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    Id setId = Id.valueOf('m00000000000003');
    List<Record_Health_Check_Rule__mdt> rules = new List<Record_Health_Check_Rule__mdt>();

    for (Integer i = 0; i < 26; i++) {
      Record_Health_Check_Rule__mdt limitRule = baseRule(
        'Limit_Rule_' + i,
        'FORMULA'
      );
      limitRule.Record_Health_Check_Set__c = setId;
      limitRule.EvaluationOrder__c = i;
      if (i == 0) {
        limitRule.PrerequisiteRule__c = 'Limit_Rule_25';
      }
      rules.add(limitRule);
    }

    Record_Health_Check_Rule__mdt rule = baseRule(
      'Metadata_App_Formula',
      'FORMULA'
    );
    rule.Record_Health_Check_Set__c = setId;
    rule.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    rule.ApplicabilityFormula__c = null;
    rules.add(rule);

    for (Integer variant = 0; variant < 4; variant++) {
      rule = baseRule('Metadata_App_Soql_' + variant, 'FORMULA');
      rule.Record_Health_Check_Set__c = setId;
      rule.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
      if (variant > 0) {
        rule.ApplicabilityCountQuery__c = variant == 1
          ? 'SELECT Id FROM Account'
          : 'SELECT COUNT(Id) FROM Account';
      }
      if (variant > 1) {
        rule.ApplicabilityCountOperator__c = variant == 2
          ? 'Around'
          : 'GREATER_THAN';
      }
      rules.add(rule);
    }

    rule = queryRule('Metadata_Query_Missing_Primary_Field');
    rule.Record_Health_Check_Set__c = setId;
    rule.SourceQueryField__c = null;
    rules.add(rule);
    rule = queryRule('Metadata_Query_Invalid_Mode');
    rule.Record_Health_Check_Set__c = setId;
    rule.QueryResultHandling__c = 'Nope';
    rules.add(rule);
    rule = queryRule('Metadata_Query_Invalid_Source');
    rule.Record_Health_Check_Set__c = setId;
    rule.ExpectedValueSource__c = 'Magic';
    rules.add(rule);
    rule = queryRule('Metadata_Query_Result_Missing_Field');
    rule.Record_Health_Check_Set__c = setId;
    rule.ExpectedValueSource__c = 'COMPARISON_QUERY';
    rule.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    rule.ComparisonQueryField__c = null;
    rules.add(rule);
    rule = apexRule('Metadata_Apex_Invalid', 'String', '[]');
    rule.Record_Health_Check_Set__c = setId;
    rules.add(rule);
    rule = validDualRule('Metadata_Dual_Missing_Fields');
    rule.Record_Health_Check_Set__c = setId;
    rule.SourceQuery__c = 'SELECT BillingCity FROM Account';
    rule.SourceQueryField__c = null;
    rule.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    rule.ComparisonQueryField__c = null;
    rules.add(rule);

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = validator.validateRecords(
      new List<Record_Health_Check_Set__mdt>{
        new Record_Health_Check_Set__mdt(
          DeveloperName = String.valueOf(setId),
          ObjectApiName__c = 'Missing__c',
          CardTitle__c = 'Invalid',
          CardRunMode__c = 'RUN_ON_REQUEST',
          CardRevealMode__c = 'ALL_AT_ONCE',
          PassedChecksDisplay__c = 'SHOW_EACH_CHECK',
          SkippedChecksDisplay__c = 'SHOW_EACH_CHECK'
        )
      },
      rules
    );
    Set<String> reasonCodes = new Set<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      reasonCodes.add(issue.reasonCode);
    }
    System.assert(reasonCodes.contains('CHECK_LIMIT_EXCEEDED'));
    System.assert(reasonCodes.contains('DEPENDENCY_NOT_IN_RUN'));
    System.assert(reasonCodes.contains('INVALID_APEX_PARAMETERS'));
  }

  @IsTest
  static void engineAndSoqlCoverRemainingDefensiveBranches() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    RecordHealthCheckEngine throwingEngine = new RecordHealthCheckEngine();
    throwingEngine.configService = null;
    assertReason(
      throwingEngine.evaluate(
        'Account_Data_Quality',
        'Account_DQ_BillingCity',
        accountRecord.Id
      ),
      'APEX_EVALUATOR_ERROR'
    );

    RecordHealthCheckResult invalidMetadata = new RecordHealthCheckResult();
    invalidMetadata.status = 'UNABLE_TO_EVALUATE';
    invalidMetadata.reasonCode = 'INVALID_CONFIG';
    invalidMetadata.detailMessage = 'forced invalid metadata';
    RecordHealthCheckEngine invalidMetadataEngine = new RecordHealthCheckEngine();
    invalidMetadataEngine.validationResultOverride = invalidMetadata;
    assertReason(
      invalidMetadataEngine.evaluate(
        'Account_Data_Quality',
        'Account_DQ_BillingCity',
        accountRecord.Id
      ),
      'INVALID_CONFIG'
    );

    Account dependencyAccount = RecordHealthCheckTestDataFactory.createAccount(
      'Cached Circular Dependency Account'
    );
    RecordHealthCheckResult circularPrerequisite = new RecordHealthCheckResult();
    circularPrerequisite.status = 'UNABLE_TO_EVALUATE';
    circularPrerequisite.reasonCode = 'CIRCULAR_DEPENDENCY';
    RecordHealthCheckEngine.transactionResultCache.put(
      'Account_Advanced_Checks|' +
        dependencyAccount.Id +
        '|Account_Adv_HasContact',
      circularPrerequisite
    );
    assertReason(
      new RecordHealthCheckEngine()
        .evaluate(
          'Account_Advanced_Checks',
          'Account_Adv_ContactHasEmail',
          dependencyAccount.Id
        ),
      'CIRCULAR_DEPENDENCY'
    );
    RecordHealthCheckEngine.transactionResultCache.clear();

    Record_Health_Check_Rule__mdt applicability = baseRule(
      'Engine_App_Non_SingleValue',
      'FORMULA'
    );
    applicability.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
    applicability.ApplicabilityCountQuery__c = 'SELECT Id FROM Account';
    assertReason(
      engine.checkSoqlApplicability(applicability, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );
    applicability.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Contact';
    assertReason(
      engine.checkSoqlApplicability(applicability, accountRecord),
      'INVALID_CONFIG'
    );
    applicability.ApplicabilityCountThreshold__c = 0;
    applicability.ApplicabilityCountOperator__c = 'Nope';
    assertReason(
      engine.checkSoqlApplicability(applicability, accountRecord),
      'INVALID_OPERATOR'
    );
    applicability.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Missing__c';
    assertReason(
      engine.checkSoqlApplicability(applicability, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );
    applicability.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Contact WHERE AccountId = {!record.Missing__c}';
    assertReason(
      engine.checkSoqlApplicability(applicability, accountRecord),
      'MISSING_BIND_VALUE'
    );

    applicability.ApplicabilityMode__c = 'Other';
    System.assertEquals(
      'SKIPPED',
      engine.buildSkippedResult(applicability).status
    );
    applicability.UnableToEvaluateMessage__c = null;
    System.assertEquals(
      'This check could not be evaluated. Contact your administrator.',
      engine.buildUnableResult(applicability, 'TEST', 'detail').message
    );

    Set<String> plannedFields = new Set<String>();
    engine.addReadableField(plannedFields, Account.SObjectType, null);
    engine.addReadableField(plannedFields, Account.SObjectType, 'Parent.Name');
    engine.addReadableField(plannedFields, Account.SObjectType, 'Bogus.Name');
    engine.addReadableField(plannedFields, Account.SObjectType, 'Name');
    System.assert(plannedFields.contains('Parent.Name'));
    System.assert(plannedFields.contains('Name'));

    RecordHealthCheckTestDataFactory.createAccount('Second Query Account');
    RecordHealthCheckSoqlEvaluator soql = new RecordHealthCheckSoqlEvaluator();
    Record_Health_Check_Rule__mdt invalidListFormula = queryRule(
      'Soql_Invalid_List_Formula'
    );
    invalidListFormula.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    invalidListFormula.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    invalidListFormula.SourceQuery__c = null;
    invalidListFormula.FindInListFormula__c = 'Not A Formula(';
    invalidListFormula.ComparisonQuery__c = 'SELECT MailingCity FROM Contact';
    invalidListFormula.ComparisonQueryField__c = 'MailingCity';
    assertReason(
      soql.evaluate(invalidListFormula, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );
    Record_Health_Check_Rule__mdt query = queryRule(
      'Soql_Multiple_Primary_Rows'
    );
    query.SourceQuery__c = 'SELECT Name FROM Account';
    query.SourceQueryField__c = 'Name';
    assertReason(
      soql.evaluate(query, accountRecord.Id, accountRecord),
      'MULTIPLE_ROWS_RETURNED'
    );

    query = queryRule('Soql_Invalid_Comparison_Formula');
    query.ExpectedValueSource__c = 'RECORD_FORMULA';
    query.ExpectedRecordFormula__c = 'Not A Formula(';
    assertReason(
      soql.evaluate(query, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );
    query = queryRule('Soql_Empty_Comparison_Query');
    query.ExpectedValueSource__c = 'COMPARISON_QUERY';
    query.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Name = \'does not exist\'';
    query.ComparisonQueryField__c = 'BillingCity';
    assertStatus(soql.evaluate(query, accountRecord.Id, accountRecord), 'FAIL');

    try {
      soql.runQuery('', 1);
      System.assert(false, 'Expected a template error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      soql.resolveFieldList(new List<SObject>{ accountRecord }, null);
      System.assert(false, 'Expected a missing field error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'Nope',
        'a',
        'b',
        query
      );
      System.assert(false, 'Expected an invalid operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
    query.EmptyValueHandling__c = 'AS_BLANK';
    RecordHealthCheckComparisonEngine.applyListComparison(
      'LIST_CONTAINS_ANY',
      null,
      new List<Object>{ '' },
      query
    );
    query.EmptyValueHandling__c = 'SKIP_RECORD';
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_ANY',
        null,
        new List<Object>{ 'a' },
        query
      )
    );
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('SKIP')
    );
    System.assertEquals(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior(null)
    );
    query.NoRowsResult__c = 'FAIL';
    query.FailureMessage__c = null;
    System.assertEquals(
      'No matching records found.',
      soql.buildEmptyOrNullResult(query, new RecordHealthCheckResult(), null)
        .message
    );
    System.assertEquals(
      false,
      soql.isMultiSelectPicklist(accountRecord, 'Bogus.Name')
    );
    Account child = (Account) JSON.deserialize(
      '{"attributes":{"type":"Account"},"Parent":{"attributes":{"type":"Account"},"Name":"Parent"}}',
      Account.class
    );
    System.assertEquals('Parent', soql.resolveFieldPath(child, 'Parent.Name'));
    query.UnableToEvaluateMessage__c = null;
    System.assertEquals(
      'This check could not be evaluated. Contact your administrator.',
      soql.safeCannotEvaluateMessage(query)
    );
  }

  private static void assertConfigException(
    RecordHealthCheckConfigService service,
    Record_Health_Check_Set__mdt checkSet,
    Id recordId,
    String reasonCode
  ) {
    try {
      service.validateCheckSetForDefinition(
        checkSet,
        checkSet.DeveloperName,
        recordId
      );
      System.assert(false, 'Expected a config exception.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      System.assertEquals(reasonCode, ex.reasonCode);
    }
  }

  private static Record_Health_Check_Rule__mdt baseRule(
    String developerName,
    String checkType
  ) {
    return new Record_Health_Check_Rule__mdt(
      DeveloperName = developerName,
      MasterLabel = developerName,
      CheckTitle__c = developerName,
      EvaluationType__c = checkType,
      FailureSeverity__c = 'WARNING',
      PassConditionFormula__c = checkType == 'FORMULA' ? 'TRUE' : null,
      FailureMessage__c = 'Apex failure for {!record.Name}',
      UnableToEvaluateMessage__c = 'Cannot evaluate test rule.',
      EvaluationOrder__c = 10,
      ApplicabilityMode__c = 'ALL_RECORDS',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'SKIP_RECORD'
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
    RecordHealthCheckResult result,
    String reasonCode
  ) {
    System.assertNotEquals(null, result, 'Expected an unable result.');
    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals(reasonCode, result.reasonCode);
  }

  private static void assertStatus(
    RecordHealthCheckResult result,
    String status
  ) {
    System.assertNotEquals(null, result, 'Expected a result.');
    System.assertEquals(
      status,
      result.status,
      'Unexpected detail: ' + result.detailMessage
    );
  }

  @IsTest
  static void formulaFieldPlanningScansTokensAndExpandsDependencies() {
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    // scanFormulaFieldTokens: relationship paths captured whole, function words
    // and double-quoted literals excluded, single fields kept, de-duplicated.
    List<String> tokens = engine.scanFormulaFieldTokens(
      'AND(NOT(ISBLANK(BillingCity)), CONTAINS(Website, "example.com"), NOT(ISBLANK(Parent.BillingCity)))'
    );
    Set<String> tokenSet = new Set<String>(tokens);
    System.assert(
      tokenSet.contains('BillingCity'),
      tokens + ' should keep BillingCity'
    );
    System.assert(
      tokenSet.contains('Website'),
      tokens + ' should keep Website'
    );
    System.assert(
      tokenSet.contains('Parent.BillingCity'),
      tokens + ' should keep the relationship path whole'
    );
    System.assert(!tokenSet.contains('AND'), 'Function words must be excluded');
    System.assert(
      !tokenSet.contains('CONTAINS'),
      'Function words must be excluded'
    );
    System.assert(
      !tokenSet.contains('example'),
      'Masked string-literal contents must not be scanned as fields'
    );

    // describeFieldPath: single field, relationship path, case-insensitivity
    // and null for a non-existent path.
    System.assertNotEquals(
      null,
      engine.describeFieldPath(Account.SObjectType, 'BillingCity')
    );
    System.assertNotEquals(
      null,
      engine.describeFieldPath(Account.SObjectType, 'Parent.Name'),
      'Relationship paths must resolve'
    );
    System.assertNotEquals(
      null,
      engine.describeFieldPath(Account.SObjectType, 'billingcity'),
      'Field lookup must be case-insensitive'
    );
    System.assertEquals(
      null,
      engine.describeFieldPath(Account.SObjectType, 'No_Such_Field__c'),
      'A missing field must resolve to null, not throw'
    );
    System.assertEquals(
      null,
      engine.describeFieldPath(Account.SObjectType, 'Bogus.Name'),
      'A missing relationship must resolve to null'
    );

    // collectRecordFields: a formula over plain + relationship operands still
    // plans every operand (the recursive walk must not drop fields that are not
    // calculated), regardless of operand case.
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'AND(NOT(ISBLANK(billingcity)), NOT(ISBLANK(Parent.BillingCity)))'
    );
    Set<String> planned = engine.collectRecordFields(rule, Account.SObjectType);
    System.assert(planned.contains('Id'));
    System.assert(
      planned.contains('billingcity'),
      'Case-insensitive operand must be planned: ' + planned
    );
    System.assert(
      planned.contains('Parent.BillingCity'),
      'Relationship operand must be planned: ' + planned
    );

    // Calculated-field dependency expansion: when the org exposes any formula
    // field on Account, a check that references only that field must also plan
    // the fields ITS definition depends on — otherwise FormulaEval cannot
    // regenerate it. Deterministic where such a field exists; a no-op assertion
    // otherwise so the test stays green on orgs without Account formula fields.
    Schema.DescribeFieldResult calcField = findCalculatedAccountField();
    if (calcField != null) {
      List<String> nestedTokens = engine.scanFormulaFieldTokens(
        calcField.getCalculatedFormula()
      );
      Record_Health_Check_Rule__mdt calcRule = new Record_Health_Check_Rule__mdt(
        EvaluationType__c = 'FORMULA',
        PassConditionFormula__c = 'NOT(ISBLANK(' + calcField.getName() + '))'
      );
      Set<String> calcPlanned = engine.collectRecordFields(
        calcRule,
        Account.SObjectType
      );
      System.assert(
        calcPlanned.contains(calcField.getName()),
        'The formula field itself must be planned: ' + calcPlanned
      );
      for (String dep : nestedTokens) {
        // Only single-segment, real Account fields are expected in the SELECT;
        // relationship and literal tokens are validated by the scans above.
        if (
          !dep.contains('.') &&
          engine.describeFieldPath(Account.SObjectType, dep) != null
        ) {
          System.assert(
            calcPlanned.contains(dep),
            'Dependency ' +
              dep +
              ' of ' +
              calcField.getName() +
              ' must be planned: ' +
              calcPlanned
          );
        }
      }
    }
  }

  // Returns any calculated (formula) field on Account the running org exposes, or
  // null if there are none — used to exercise dependency expansion deterministically
  // where possible without requiring a packaged test formula field.
  private static Schema.DescribeFieldResult findCalculatedAccountField() {
    for (
      Schema.SObjectField f : Account.SObjectType.getDescribe(
          SObjectDescribeOptions.DEFERRED
        )
        .fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult d = f.getDescribe();
      if (d.isCalculated() && String.isNotBlank(d.getCalculatedFormula())) {
        return d;
      }
    }
    return null;
  }

  @IsTest
  static void formulaCheckPopulatesFoundAndExpectedFromSingleValueFormulas() {
    Account a = RecordHealthCheckTestDataFactory.createAccount(
      new Account(Name = 'Balance Co', NumberOfEmployees = 100)
    );
    Account record = [
      SELECT Id, NumberOfEmployees, AnnualRevenue
      FROM Account
      WHERE Id = :a.Id
    ];
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    // Found + Expected resolve from explicit single-value formulas, formatted like
    // Query checks.
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'NumberOfEmployees > 0',
      DisplayFoundFormula__c = 'BLANKVALUE(NumberOfEmployees, 0)',
      DisplayExpectedFormula__c = 'BLANKVALUE(NumberOfEmployees, 0) + 5',
      FormulaResultType__c = 'NUMBER'
    );
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    evaluator.applyFoundExpectedValues(rule, record, result);
    System.assert(
      result.actualValue != null && result.actualValue.contains('100'),
      'Found should be the resolved left-side single value: ' +
      result.actualValue
    );
    System.assert(
      result.expectedValue != null && result.expectedValue.contains('105'),
      'Expected should be the resolved right-side single value: ' +
      result.expectedValue
    );

    // Blank Found/Expected → original behavior: no Found, Expected echoes the
    // boolean formula text.
    Record_Health_Check_Rule__mdt plain = new Record_Health_Check_Rule__mdt(
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'NumberOfEmployees > 0'
    );
    RecordHealthCheckResult plainResult = new RecordHealthCheckResult();
    evaluator.applyFoundExpectedValues(plain, record, plainResult);
    System.assertEquals(
      null,
      plainResult.actualValue,
      'No Found formula → no Found value'
    );
    System.assertEquals(
      'NumberOfEmployees > 0',
      plainResult.expectedValue,
      'Expected echoes the unquoted Pass/Fail formula when no Expected formula'
    );
    System.assertEquals(
      'Passes when',
      plainResult.expectedValueLabel,
      'Echoed pass/fail condition carries the "Passes when" key, not "Expected"'
    );

    // An unresolvable Found/Expected formula degrades to the default — it must
    // never throw or change pass/fail.
    Record_Health_Check_Rule__mdt bad = new Record_Health_Check_Rule__mdt(
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'NumberOfEmployees > 0',
      DisplayFoundFormula__c = 'No_Such_Field__c + 1'
    );
    RecordHealthCheckResult badResult = new RecordHealthCheckResult();
    evaluator.applyFoundExpectedValues(bad, record, badResult);
    System.assertEquals(
      null,
      badResult.actualValue,
      'Unresolvable Found formula leaves Found empty'
    );
    System.assertEquals(
      'NumberOfEmployees > 0',
      badResult.expectedValue,
      'Falls back to the formula echo when Expected is blank'
    );

    // End-to-end: evaluate() wires Found/Expected onto a real PASS result.
    RecordHealthCheckResult full = evaluator.evaluate(rule, record.Id, record);
    System.assertEquals('PASS', full.status);
    System.assert(
      full.actualValue != null && full.actualValue.contains('100'),
      'evaluate() should surface Found: ' + full.actualValue
    );

    // collectRecordFields plans the operands of BOTH new formulas (so Task 2's
    // dependency expansion applies to them too).
    Record_Health_Check_Rule__mdt planRule = new Record_Health_Check_Rule__mdt(
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'NumberOfEmployees > 0',
      DisplayFoundFormula__c = 'BLANKVALUE(NumberOfEmployees, 0)',
      DisplayExpectedFormula__c = 'BLANKVALUE(AnnualRevenue, 0)'
    );
    Set<String> planned = new RecordHealthCheckEngine()
      .collectRecordFields(planRule, Account.SObjectType);
    System.assert(
      planned.contains('NumberOfEmployees'),
      'Found-formula operand must be planned: ' + planned
    );
    System.assert(
      planned.contains('AnnualRevenue'),
      'Expected-formula operand must be planned: ' + planned
    );
  }

  private static void assertReason(
    RecordHealthCheckResult result,
    String reasonCode
  ) {
    System.assertNotEquals(null, result, 'Expected a result.');
    System.assertEquals(
      reasonCode,
      result.reasonCode,
      'Unexpected status/detail: ' + result.status + ' ' + result.detailMessage
    );
  }
}
