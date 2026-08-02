/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared execution and empty-result behavior for both SOQL evaluators. */
public with sharing class RecordHealthCheckQueryEvaluatorSupport {
  private static final Pattern FROM_OBJECT_PATTERN = Pattern.compile(
    '(?is)\\bFROM\\s+([A-Za-z0-9_]+)'
  );

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

  public static RecordHealthCheckInternalResult buildEmptyResult(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckInternalResult result,
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

  public static RecordHealthCheckInternalResult buildNullIndeterminateResult(
    RecordHealthCheckInternalResult result
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

  /** Returns a best-effort plural label for the source query's object. */
  public static String pluralizeObject(Record_Health_Check_Rule__mdt rule) {
    String objectName;
    if (String.isNotBlank(rule.SourceQuery__c)) {
      Matcher matcher = FROM_OBJECT_PATTERN.matcher(rule.SourceQuery__c);
      if (matcher.find()) {
        objectName = matcher.group(1);
      }
    }
    if (String.isBlank(objectName)) {
      return 'records';
    }
    Schema.SObjectType objectType = RecordHealthCheckDescribeCache.resolveSObjectType(
      objectName
    );
    if (objectType != null) {
      return RecordHealthCheckDescribeCache.describeSObject(objectType)
        .getLabelPlural();
    }
    String lower = objectName.toLowerCase();
    if (
      lower.endsWith('y') &&
      !'aeiou'.contains(lower.substring(lower.length() - 2, lower.length() - 1))
    ) {
      return objectName.substring(0, objectName.length() - 1) + 'ies';
    }
    if (
      lower.endsWith('s') ||
      lower.endsWith('x') ||
      lower.endsWith('z') ||
      lower.endsWith('ch') ||
      lower.endsWith('sh')
    ) {
      return objectName + 'es';
    }
    return objectName + 's';
  }
}
