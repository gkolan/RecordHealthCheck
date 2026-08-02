/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCDualQueryEdgeBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void dualQueryCoversRemainingEdgeBranches() {
    List<SObject> emptyRows = new List<SObject>();
    List<SObject> accountRows = new List<SObject>();
    accountRows.add(
      [
        SELECT Id, BillingCity, BillingState
        FROM Account
        LIMIT 1
      ]
    );
    List<SObject> duplicateRows = new List<SObject>{
      accountRows[0],
      accountRows[0]
    };
    Record_Health_Check_Rule__mdt dualRule = validDualRule('Helper_Dual');
    dualRule.NoRowsResult__c = 'FAIL';
    dualRule.SourceQueryField__c = 'BillingCity';
    dualRule.ComparisonQueryField__c = 'BillingCity';
    dualRule.EmptyValueHandling__c = 'AS_NO_MATCH';

    Assert.areEqual(
      false,
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        dualRule,
        emptyRows,
        accountRows
      )
    );
    dualRule.EmptyValueHandling__c = 'AS_BLANK';
    Assert.areEqual(
      true,
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        dualRule,
        emptyRows,
        emptyRows
      )
    );
    dualRule.EmptyValueHandling__c = null;
    Assert.areEqual(
      null,
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        dualRule,
        emptyRows,
        accountRows
      )
    );
    try {
      RecordHealthCheckCompareQuerySupport.resolveSingleValue(
        duplicateRows,
        'Id',
        'primary'
      );
      Assert.isTrue(false, 'Expected multiple row exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('MULTIPLE_ROWS_RETURNED', ex.reasonCode);
    }
    try {
      RecordHealthCheckCompareQuerySupport.resolveSingleValue(
        accountRows,
        null,
        'primary'
      );
      Assert.isTrue(false, 'Expected missing field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Record_Health_Check_Rule__mdt dualList = validDualRule('Helper_Dual_List');
    dualList.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualList.SourceQueryField__c = 'BillingCity';
    dualList.ComparisonQueryField__c = 'BillingState';
    dualList.ComparisonOperator__c = 'LISTS_OVERLAP';
    Assert.areEqual(
      false,
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      )
    );
    dualList.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    dualList.ComparisonQueryField__c = 'BillingCity';
    Assert.areEqual(
      true,
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      )
    );
    dualList.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    Assert.areEqual(
      true,
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      )
    );
    dualList.ComparisonOperator__c = 'BadList';
    try {
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      );
      Assert.isTrue(false, 'Expected invalid compare-queries list operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    try {
      RecordHealthCheckCompareQuerySupport.toStringList(
        accountRows,
        null,
        'primary',
        'AS_BLANK'
      );
      Assert.isTrue(false, 'Expected missing list field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      RecordHealthCheckCompareQuerySupport.toStringList(
        accountRows,
        'Missing__c',
        'primary',
        'AS_BLANK'
      );
      Assert.isTrue(false, 'Expected invalid list field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'NOT_EQUALS',
        'a',
        'b'
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'CONTAINS',
        'abc',
        'b'
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'DOES_NOT_CONTAIN',
        'abc',
        'z'
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        2,
        2
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'LESS_THAN_OR_EQUAL',
        Datetime.now(),
        Datetime.now().addSeconds(1)
      )
    );
    Assert.areEqual(
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
      Assert.isTrue(false, 'Expected invalid single-value operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    try {
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN',
        'a',
        'b'
      );
      Assert.isTrue(false, 'Expected incompatible single-value operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }

    Assert.areEqual(
      false,
      RecordHealthCheckCompareQuerySupport.frequencyMapsEqual(
        RecordHealthCheckCompareQuerySupport.toFrequencyMap(
          new List<String>{ 'a' }
        ),
        RecordHealthCheckCompareQuerySupport.toFrequencyMap(
          new List<String>{ 'a', 'a' }
        )
      )
    );
    try {
      RecordHealthCheckComparisonEngine.valuesEqual(
        Date.today(),
        String.valueOf(Date.today())
      );
      Assert.isTrue(false, 'Expected Date coercion incompatibility.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.isTrue(
        ex.reasonCode == 'INCOMPATIBLE_COMPARISON_TYPES',
        'Expected a typed comparison error.'
      );
    }
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.isNumericObject(Decimal.valueOf('1'))
    );
    Assert.areEqual(false, RecordHealthCheckValueResolver.isNumericObject('1'));
    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(
        'SELECT Id FROM Account',
        0
      );
      Assert.isTrue(false, 'Expected compare-queries row cap exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('GOVERNOR_LIMIT_RISK', ex.reasonCode);
    }
    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(
        'SELECT Missing__c FROM Account',
        1
      );
      Assert.isTrue(false, 'Expected compare-queries invalid query exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('FAIL')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('SKIP')
    );
    Assert.areEqual(
      'FAIL',
      RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
          dualRule,
          new RecordHealthCheckInternalResult(),
          null
        )
        .status
    );
    dualRule.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    assertReason(
      RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
        dualRule,
        new RecordHealthCheckInternalResult(),
        null
      ),
      'NO_ROWS_RETURNED'
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
        'FormulaResultType__c' => 'AUTO',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD'
      }
    );
  }

  @IsTest
  static void evaluatorMapsPlatformQueryFailuresToStableConfigurationResult() {
    Account accountRecord = [SELECT Id, Name FROM Account LIMIT 1];
    Record_Health_Check_Rule__mdt rule = validDualRule('Invalid_Query');
    rule.SourceQuery__c = 'SELECT DefinitelyMissing__c FROM Account';

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluate(rule, accountRecord.Id, accountRecord);
    Test.stopTest();

    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      result.reasonCode,
      'A platform QueryException must map to the stable template reason.'
    );
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

  private static void assertStatus(
    RecordHealthCheckInternalResult result,
    String status
  ) {
    Assert.areNotEqual(null, result, 'Expected a result.');
    Assert.areEqual(
      status,
      result.status,
      'Unexpected detail: ' + result.detailMessage
    );
  }

  private static void assertReason(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected a result.');
    Assert.areEqual(
      reasonCode,
      result.reasonCode,
      'Unexpected status/detail: ' + result.status + ' ' + result.detailMessage
    );
  }
}
