/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckCompareQueriesEvaluator {
  private static final Integer DEFAULT_MAX_ROWS = 2000;

  // sentinel representing a missing value under Treat as not matching (AS_NO_MATCH) in a
  // list comparison. The reserved leading-space token will not realistically
  // collide with field data, and toStringList appends the side + a per-null index
  // so every missing value is distinct — a null then matches nothing, not even
  // another null. See toStringList.
  private static final String MISSING_NO_MATCH_SENTINEL = ' __rhc_missing__:';

  // Delegate token binding and query execution to the existing SOQL evaluator
  private RecordHealthCheckSoqlEvaluator soqlEvaluator = new RecordHealthCheckSoqlEvaluator();

  // ─── Public entry point ───────────────────────────────────────────────────

  public RecordHealthCheckResult evaluate(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record
  ) {
    Long startMs = System.currentTimeMillis();
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.checkDeveloperName = rule.DeveloperName;
    result.label = rule.CheckTitle__c;
    result.priority = rule.EvaluationOrder__c;
    result.evaluatorType = 'COMPARE_TWO_QUERIES';

    try {
      result = doEvaluate(rule, recordId, record, result);
    } catch (Exception ex) {
      result = applyEvaluationException(rule, result, ex);
    }

    result.durationMs = System.currentTimeMillis() - startMs;
    return result;
  }

  @TestVisible
  private RecordHealthCheckResult applyEvaluationException(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result,
    Exception ex
  ) {
    if (ex instanceof RecordHealthCheckEvaluatorException) {
      RecordHealthCheckEvaluatorException evaluatorException = (RecordHealthCheckEvaluatorException) ex;
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = evaluatorException.reasonCode;
    } else if (ex instanceof System.QueryException) {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'INVALID_SOQL_TEMPLATE';
    } else {
      result.status = 'ERROR';
      result.reasonCode = 'APEX_EVALUATOR_ERROR';
    }
    result.message = safeCannotEvaluateMessage(rule);
    result.detailMessage = ex.getMessage();
    return result;
  }

  // ─── Core evaluation ──────────────────────────────────────────────────────

  private RecordHealthCheckResult doEvaluate(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record,
    RecordHealthCheckResult result
  ) {
    Integer maxRows = rule.MaxQueryRows__c != null
      ? (Integer) rule.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;

    String primarySoql = soqlEvaluator.bindTokens(rule.SourceQuery__c, record);
    String comparisonSoql = soqlEvaluator.bindTokens(
      rule.ComparisonQuery__c,
      record
    );

    List<SObject> primaryRows = runQuery(primarySoql, maxRows);
    List<SObject> comparisonRows = runQuery(comparisonSoql, maxRows);

    String mode = rule.QueryResultHandling__c;
    Boolean passed;

    if (mode == 'ONE_RESULT') {
      // Tier 7 — both sides resolve to a single value.
      // a zero-row query is governed by NoRowsResult__c, NOT by the
      // null-value behavior (EmptyValueHandling__c). evaluateSingleVsSingle
      // collapses an empty query and a present-but-null field to the same null
      // so without this early route an empty side with Treat as not matching (AS_NO_MATCH) would
      // wrongly FAIL (and TreatMissingAsBlank would wrongly compare '') instead
      // of honoring NoRowsResult__c. Mirrors the single-query evaluator, which
      // routes an empty primary to buildEmptyOrNullResult up front.
      if (primaryRows.isEmpty() || comparisonRows.isEmpty()) {
        return buildEmptyOrNullResult(rule, result);
      }
      passed = evaluateSingleVsSingle(rule, primaryRows, comparisonRows);
    } else if (mode == 'COMPARE_AS_LISTS') {
      // Tier 9 — both sides resolve to lists; list-vs-list set operations
      passed = evaluateListVsList(rule, primaryRows, comparisonRows);
    } else {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_COMPARATOR',
        'Compare two queries does not support How To Interpret Query Results "' +
          mode +
          '".' +
          ' Use Expect one row or aggregate result (Tier 7) or Compare query results as lists (Tier 9).'
      );
    }

    if (passed == null) {
      // separate a genuine zero-rows result (governed by
      // NoRowsResult__c) from a present-but-null value (governed by the null
      // behavior, resolving to SKIPPED). For OneResult an empty query is already
      // A null here is a present-row null field, not a zero-row query result.
      // CompareAsLists returns null when a side is empty (zero rows).
      Boolean zeroRows = primaryRows.isEmpty() || comparisonRows.isEmpty();
      return zeroRows
        ? buildEmptyOrNullResult(rule, result)
        : buildNullIndeterminateResult(rule, result);
    }

    // Capture actual vs expected from the rows already fetched (no extra query)
    // so the UI can show the comparison on a non-passing row.
    setComparisonValues(rule, result, primaryRows, comparisonRows, mode);

    if (passed) {
      result.status = 'PASS';
    } else {
      result.status = 'FAIL';
      result.severity = rule.FailureSeverity__c;
      // Merge-field resolution is handled by the Engine
      // but the SOQL evaluator also sets it here for consistency
      result.message = String.isNotBlank(rule.FailureMessage__c)
        ? rule.FailureMessage__c
        : 'Check failed.';
    }
    return result;
  }

  // ─── Actual vs expected display values ────────────────────────────────────

  /**
   * Populates result.actualValue / result.expectedValue from the rows already
   * fetched. Called only after the operator returned a determinate boolean, so
   * resolveSingleValue cannot throw here for the OneResult path.
   */
  @TestVisible
  private void setComparisonValues(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    String mode
  ) {
    if (mode == 'ONE_RESULT') {
      Object primaryValue = resolveSingleValue(
        primaryRows,
        rule.SourceQueryField__c,
        'primary'
      );
      Object comparisonValue = resolveSingleValue(
        comparisonRows,
        rule.ComparisonQueryField__c,
        'comparison'
      );
      result.actualValue = RecordHealthCheckComparisonEngine.formatValue(
        primaryValue
      );
      result.expectedValue = RecordHealthCheckComparisonEngine.describeExpected(
        rule.ComparisonOperator__c,
        comparisonValue
      );
      result.actualValueSource = new RecordHealthCheckValueSource.Detail(
        provenanceSource(rule.SourceQueryField__c, 'Primary query'),
        primaryValue == null ? 'null' : String.valueOf(primaryValue),
        RecordHealthCheckValueSource.rowCount(primaryRows.size())
      );
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        provenanceSource(rule.ComparisonQueryField__c, 'Comparison query'),
        comparisonValue == null ? 'null' : String.valueOf(comparisonValue),
        RecordHealthCheckValueSource.rowCount(comparisonRows.size())
      );
    } else {
      // CompareAsLists — show both result sets
      List<Object> primaryList = RecordHealthCheckValueResolver.scalarList(
        primaryRows,
        rule.SourceQueryField__c
      );
      List<Object> comparisonList = RecordHealthCheckValueResolver.scalarList(
        comparisonRows,
        rule.ComparisonQueryField__c
      );
      result.actualValue = RecordHealthCheckComparisonEngine.formatList(
        primaryList
      );
      result.expectedValue = RecordHealthCheckComparisonEngine.describeExpectedList(
        rule.ComparisonOperator__c,
        comparisonList
      );
      result.actualValueSource = new RecordHealthCheckValueSource.Detail(
        provenanceSource(rule.SourceQueryField__c, 'Primary query'),
        RecordHealthCheckValueSource.rowCount(primaryList.size()),
        null
      );
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        provenanceSource(rule.ComparisonQueryField__c, 'Comparison query'),
        RecordHealthCheckValueSource.rowCount(comparisonList.size()),
        null
      );
    }
  }

  // Prefers the field name (what the viewer recognizes) as the value source
  // source, falling back to the query role when no field is configured.
  private String provenanceSource(String field, String fallback) {
    return String.isNotBlank(field) ? field : fallback;
  }

  // ─── Tier 7 — single-value vs single-value ────────────────────────────────

  @TestVisible
  private Boolean evaluateSingleVsSingle(
    Record_Health_Check_Rule__mdt rule,
    List<SObject> primaryRows,
    List<SObject> comparisonRows
  ) {
    // Both sides must resolve to exactly one row (or an aggregate)
    Object primaryValue = resolveSingleValue(
      primaryRows,
      rule.SourceQueryField__c,
      'primary'
    );
    Object comparisonValue = resolveSingleValue(
      comparisonRows,
      rule.ComparisonQueryField__c,
      'comparison'
    );

    if (primaryValue == null || comparisonValue == null) {
      String nb = rule.EmptyValueHandling__c;
      if (nb == 'SKIP_RECORD')
        return null;
      if (nb == 'AS_BLANK') {
        primaryValue = primaryValue != null ? primaryValue : '';
        comparisonValue = comparisonValue != null ? comparisonValue : '';
      } else if (nb == 'AS_NO_MATCH') {
        return false;
      } else {
        // blank EmptyValueHandling__c aligns with CMT field default (SkipRecordsWithMissingValue → Skip)
        return null;
      }
    }

    return RecordHealthCheckComparisonEngine.applySingleValueComparison(
      rule.ComparisonOperator__c,
      primaryValue,
      comparisonValue
    );
  }

  @TestVisible
  private Object resolveSingleValue(
    List<SObject> rows,
    String fieldName,
    String side
  ) {
    if (rows.isEmpty()) {
      // SELECT COUNT(Id) always returns 1 row even with 0 matching records
      // so this branch is only reached by non-aggregate queries with no rows.
      return null; // NullBehavior on the caller decides what to do
    }
    if (rows.size() > 1) {
      throw new RecordHealthCheckEvaluatorException(
        'MULTIPLE_ROWS_RETURNED',
        'CompareTwoQueries OneResult: ' +
          side +
          ' query returned ' +
          rows.size() +
          ' rows.'
      );
    }
    try {
      return RecordHealthCheckValueResolver.scalarFromRow(rows[0], fieldName);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  // ─── Tier 9 — list vs list ────────────────────────────────────────────────

  @TestVisible
  private Boolean evaluateListVsList(
    Record_Health_Check_Rule__mdt rule,
    List<SObject> primaryRows,
    List<SObject> comparisonRows
  ) {
    if (primaryRows.isEmpty() || comparisonRows.isEmpty()) {
      return RecordHealthCheckComparisonEngine.resolveEmptyBehavior(
        rule.NoRowsResult__c
      );
    }

    List<String> primaryList = toStringList(
      primaryRows,
      rule.SourceQueryField__c,
      'primary',
      rule.EmptyValueHandling__c
    );
    List<String> comparisonList = toStringList(
      comparisonRows,
      rule.ComparisonQueryField__c,
      'comparison',
      rule.EmptyValueHandling__c
    );

    // rows existed (the zero-row guard above already returned), but a
    // side's values were ALL null and dropped by SkipRecordsWithMissingValue
    // leaving an empty list. That is indeterminate — every value under test was
    // missing — not a determinate FAIL/PASS from comparing empty sets. Return
    // null so the empty-value handling governs it (SKIPPED via buildNullIndeterminateResult)
    // rather than silently FAILing ListsOverlap / passing ListContainsAll.
    if (primaryList.isEmpty() || comparisonList.isEmpty()) {
      return null;
    }

    // normalise to lowercase so set operations are case-insensitive
    Set<String> primarySet = new Set<String>();
    for (String s : primaryList) {
      primarySet.add(s != null ? s.toLowerCase() : '');
    }
    Set<String> comparisonSet = new Set<String>();
    for (String s : comparisonList) {
      comparisonSet.add(s != null ? s.toLowerCase() : '');
    }

    String operator = rule.ComparisonOperator__c;

    if (operator == 'LISTS_OVERLAP') {
      // At least one value appears in both lists.
      for (String val : primarySet) {
        if (comparisonSet.contains(val))
          return true;
      }
      return false;
    }

    if (operator == 'LISTS_CONTAIN_ALL') {
      // Every primary value appears in the comparison list.
      for (String val : primarySet) {
        if (!comparisonSet.contains(val))
          return false;
      }
      return true;
    }

    if (operator == 'LISTS_MATCH_EXACTLY') {
      // Exact means same normalized values and the same duplicate counts.
      return frequencyMapsEqual(
        toFrequencyMap(primaryList),
        toFrequencyMap(comparisonList)
      );
    }

    throw new RecordHealthCheckEvaluatorException(
      'INVALID_COMPARATOR',
      'Comparison operator "' +
        operator +
        '" is not valid for Compare as lists on Compare two queries.' +
        ' Use Lists overlap, List contains all, or Exact list match.'
    );
  }

  @TestVisible
  private List<String> toStringList(
    List<SObject> rows,
    String fieldName,
    String side,
    String nullBehavior
  ) {
    List<String> values = new List<String>();
    Integer missingIndex = 0;
    try {
      for (
        Object val : RecordHealthCheckValueResolver.scalarList(rows, fieldName)
      ) {
        if (val != null) {
          values.add(String.valueOf(val));
          continue;
        }
        // Null handling depends on the configured empty-value handling.
        if (nullBehavior == 'SKIP_RECORD') {
          // Drop the missing value from the list entirely.
          continue;
        }
        if (nullBehavior == 'AS_NO_MATCH') {
          // A missing value must match nothing — not even another missing value.
          // Coercing to '' (the old behavior) let two null fields "match" as
          // blanks and wrongly satisfy ListsOverlap / ExactListMatch. Emit a
          // unique, non-data sentinel instead so each null stays distinct.
          values.add(MISSING_NO_MATCH_SENTINEL + side + ':' + missingIndex++);
          continue;
        }
        // TreatMissingAsBlank and the CMT blank default treat a missing value as
        // a matchable blank.
        values.add('');
      }
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
    return values;
  }

  @TestVisible
  private Map<String, Integer> toFrequencyMap(List<String> values) {
    Map<String, Integer> frequencies = new Map<String, Integer>();
    for (String value : values) {
      String normalized = value != null ? value.toLowerCase() : '';
      Integer currentCount = frequencies.containsKey(normalized)
        ? frequencies.get(normalized)
        : 0;
      frequencies.put(normalized, currentCount + 1);
    }
    return frequencies;
  }

  @TestVisible
  private Boolean frequencyMapsEqual(
    Map<String, Integer> left,
    Map<String, Integer> right
  ) {
    if (left.size() != right.size())
      return false;
    for (String key : left.keySet()) {
      if (!right.containsKey(key) || right.get(key) != left.get(key))
        return false;
    }
    return true;
  }

  // ─── Query execution with row-cap safety ─────────────────────────────────

  @TestVisible
  private List<SObject> runQuery(String soql, Integer maxRows) {
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
    } catch (System.QueryException qex) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckValueResolver.classifyQueryException(qex),
        qex.getMessage()
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

  // ─── Empty/null result helpers ────────────────────────────────────────────

  @TestVisible
  private RecordHealthCheckResult buildEmptyOrNullResult(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result
  ) {
    String behavior = rule.NoRowsResult__c;
    if (behavior == 'PASS' || behavior == 'Pass') {
      result.status = 'PASS';
    } else if (behavior == 'FAIL' || behavior == 'Fail') {
      result.status = 'FAIL';
      result.severity = rule.FailureSeverity__c;
      result.message = String.isNotBlank(rule.FailureMessage__c)
        ? rule.FailureMessage__c
        : 'No matching records found.';
    } else if (
      behavior == 'UNABLE_TO_EVALUATE' ||
      behavior == 'UnableToEvaluate'
    ) {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'NO_ROWS_RETURNED';
      result.message = safeCannotEvaluateMessage(rule);
    } else {
      result.status = 'SKIPPED';
      result.reasonCode = 'APPLICABILITY_NOT_MET';
      result.message = 'Check skipped: empty result per configuration.';
    }
    return result;
  }

  /**
   * result for a present-but-null value (both queries returned
   * rows, but a field under test was null and the empty-value handling resolves to Skip).
   * Reported as SKIPPED and deliberately NOT governed by NoRowsResult__c.
   */
  @TestVisible
  private RecordHealthCheckResult buildNullIndeterminateResult(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result
  ) {
    result.status = 'SKIPPED';
    result.reasonCode = 'VALUE_IS_EMPTY';
    result.message = 'Check skipped: the value under test was empty.';
    return result;
  }

  @TestVisible
  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
