/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared execution and empty-result behavior for both SOQL evaluators. */
public with sharing class RecordHealthCheckQueryEvaluatorSupport {
  public static List<SObject> runQuery(String soql, Integer maxRows) {
    String queryToRun;
    try {
      queryToRun = RecordHealthCheckSoqlTemplate.prepareForExecution(
        soql,
        maxRows + 1
      );
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }

    List<SObject> rows;
    try {
      rows = Database.query(queryToRun);
    } catch (System.QueryException ex) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckValueResolver.classifyQueryException(ex),
        ex.getMessage()
      );
    }
    if (rows.size() > maxRows) {
      throw new RecordHealthCheckEvaluatorException(
        'GOVERNOR_LIMIT_RISK',
        'Query returned more than ' +
          maxRows +
          ' rows. Reduce scope or lower Max Rows Override.'
      );
    }
    return rows;
  }

  public static RecordHealthCheckResult buildEmptyResult(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result,
    RecordHealthCheckValueSource.Detail actualValueSource
  ) {
    result.actualValueSource = actualValueSource;
    String behavior = rule.NoRowsResult__c;
    if (behavior == 'PASS') {
      result.status = 'PASS';
    } else if (behavior == 'FAIL') {
      result.status = 'FAIL';
      result.severity = rule.FailureSeverity__c;
      result.message = String.isNotBlank(rule.FailureMessage__c)
        ? rule.FailureMessage__c
        : 'No matching records found.';
    } else if (behavior == 'UNABLE_TO_EVALUATE') {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'NO_ROWS_RETURNED';
      result.message = safeCannotEvaluateMessage(rule);
    } else {
      result.status = 'SKIPPED';
      result.reasonCode = 'APPLICABILITY_NOT_MET';
      result.message = 'Check skipped: no matching records.';
    }
    return result;
  }

  public static RecordHealthCheckResult buildNullIndeterminateResult(
    RecordHealthCheckResult result
  ) {
    result.status = 'SKIPPED';
    result.reasonCode = 'VALUE_IS_EMPTY';
    result.message = 'Check skipped: the value under test was empty.';
    return result;
  }

  public static String safeCannotEvaluateMessage(
    Record_Health_Check_Rule__mdt rule
  ) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
