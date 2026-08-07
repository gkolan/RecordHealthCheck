/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckMetadataValidatorTest {
  @IsTest
  static void validateRejectsUnrecognizedComparisonDisplay() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Bad_Comparison_Display',
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Bad Comparison Display',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'FoundExpectedDisplay__c' => 'Bogus'
      }
    );

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check_Rule__mdt>()
      );

    Boolean found = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (
        issue.componentName == 'Bad_Comparison_Display' &&
        issue.fieldName == 'FoundExpectedDisplay__c' &&
        issue.reasonCode == 'INVALID_CONFIG' &&
        issue.message.contains('Bogus')
      ) {
        found = true;
      }
    }

    Assert.isTrue(
      found,
      'Metadata validation should reject invalid FoundExpectedDisplay__c values.'
    );
  }
  @IsTest
  static void metadataValidatorCoversInvalidInMemoryMetadata() {
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    Id setAId = Id.valueOf('m00' + '000000000001');
    Id setBId = Id.valueOf('m00' + '000000000002');

    List<Record_Health_Check_Set__mdt> checkSets = new List<Record_Health_Check_Set__mdt>{
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{
          'DeveloperName' => String.valueOf(setAId),
          'MasterLabel' => 'Set A',
          'ObjectApiName__c' => '',
          'CardTitle__c' => '',
          'PassedChecksDisplay__c' => 'Maybe',
          'SkippedChecksDisplay__c' => 'Sometimes'
        }
      ),
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{
          'DeveloperName' => String.valueOf(setBId),
          'MasterLabel' => 'Set B',
          'ObjectApiName__c' => 'Account',
          'CardTitle__c' => 'Set B'
        }
      )
    };

    Record_Health_Check_Rule__mdt missingBasics = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'DeveloperName' => 'Missing_Basics',
        'MasterLabel' => 'Missing Basics',
        'Record_Health_Check_Set__c' => setAId
      }
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

    Assert.isTrue(issues.size() > 20, 'Expected broad validation coverage.');
    Set<String> reasonCodes = new Set<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      reasonCodes.add(issue.reasonCode);
    }
    Assert.isTrue(reasonCodes.contains('MISSING_REQUIRED_FIELD'));
    Assert.isTrue(reasonCodes.contains('INVALID_CHECK_TYPE'));
    Assert.isTrue(reasonCodes.contains('INVALID_CONFIG'));
    Assert.isTrue(reasonCodes.contains('INVALID_OPERATOR'));
    Assert.isTrue(reasonCodes.contains('INVALID_DEPENDENCY'));
  }

  @IsTest
  static void metadataValidatorCoversRemainingValidationBranches() {
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    Id setId = Id.valueOf('m00' + '000000000003');
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
        RecordHealthCheckTestDataFactory.checkSet(
          new Map<String, Object>{
            'DeveloperName' => String.valueOf(setId),
            'ObjectApiName__c' => 'Missing__c',
            'CardTitle__c' => 'Invalid',
            'CardRunMode__c' => 'RUN_ON_REQUEST',
            'CardRevealMode__c' => 'ALL_AT_ONCE',
            'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
            'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
          }
        )
      },
      rules
    );
    Set<String> reasonCodes = new Set<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      reasonCodes.add(issue.reasonCode);
    }
    Assert.isTrue(reasonCodes.contains('CHECK_LIMIT_EXCEEDED'));
    Assert.isTrue(reasonCodes.contains('DEPENDENCY_NOT_IN_RUN'));
    Assert.isTrue(reasonCodes.contains('INVALID_APEX_PARAMETERS'));
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
}
