/**
 * Focused evaluator behavior and regression tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCDualQueryBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
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
    RecordHealthCheckInternalResult unableResult = evaluator.evaluate(
      emptyPrimaryUnable,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(unableResult, 'UNABLE_TO_EVALUATE');
    Assert.areEqual('NO_ROWS_RETURNED', unableResult.reasonCode);

    // An invalid query field surfaces through the compare-queries runQuery error path.
    Record_Health_Check_Rule__mdt badQuery = emptyPrimarySkip.clone();
    badQuery.DeveloperName = 'D_Bad_Query';
    badQuery.SourceQuery__c = 'SELECT NoSuchField__zzz FROM Account WHERE Id = {!record.Id}';
    badQuery.SourceQueryField__c = 'NoSuchField__zzz';
    RecordHealthCheckInternalResult badQueryResult = evaluator.evaluate(
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

    // Treat as not matching (AS_NO_MATCH) keeps null values as distinct placeholders (non-empty
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
    RecordHealthCheckInternalResult blankMsgResult = evaluator.evaluate(
      blankMsgFail,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(blankMsgResult, 'FAIL');
    Assert.areEqual('Check failed.', blankMsgResult.message);

    // A template-invalid query (disallowed access level) surfaces through the
    // compare-queries runQuery TemplateException path.
    Record_Health_Check_Rule__mdt templateBad = validDualRule('D_Template_Bad');
    templateBad.SourceQuery__c = 'SELECT Id FROM Account WHERE Id = {!record.Id} WITH SYSTEM_MODE';
    RecordHealthCheckInternalResult templateBadResult = evaluator.evaluate(
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
