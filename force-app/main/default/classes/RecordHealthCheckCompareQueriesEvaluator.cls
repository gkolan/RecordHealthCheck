/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckCompareQueriesEvaluator {
  private static final Integer DEFAULT_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // placeholder representing a missing value under Treat as not matching (AS_NO_MATCH) in a
  // list comparison. The reserved leading-space token will not realistically
  // collide with field data, and toStringList appends the side + a per-null index
  // so every missing value is distinct — a null then matches nothing, not even
  // another null. See toStringList.
  private static final String MISSING_NO_MATCH_PLACEHOLDER = ' __rhc_missing__:';

  // Delegate token binding and query execution to the existing SOQL evaluator
  private RecordHealthCheckSoqlEvaluator soqlEvaluator = new RecordHealthCheckSoqlEvaluator();

  public RecordHealthCheckCompareQueriesEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    soqlEvaluator.withRunContext(value);
    return this;
  }

  // ─── Public entry point ───────────────────────────────────────────────────

  public RecordHealthCheckResult evaluate(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record
  ) {
    Long startMs = System.currentTimeMillis();
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.ruleDeveloperName = rule.DeveloperName;
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
      // Single-result mode: both sides resolve to one value.
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
      // List-result mode: both sides resolve to lists; list set operations
      passed = evaluateListVsList(rule, primaryRows, comparisonRows);
    } else {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_OPERATOR',
        'Compare two queries does not support How To Interpret Query Results "' +
          mode +
          '".' +
          ' Use Expect one row or aggregate result, or Compare query results as lists.'
      );
    }

    if (passed == null) {
      // Separate a genuine zero-row result (governed by NoRowsResult__c) from a
      // present-row null value (governed by EmptyValueHandling__c). OneResult
      // routes empty queries above; CompareAsLists returns null for an empty side.
      Boolean zeroRows = primaryRows.isEmpty() || comparisonRows.isEmpty();
      return zeroRows
        ? buildEmptyOrNullResult(rule, result)
        : buildNullIndeterminateResult(result);
    }

    // Capture actual vs expected from the rows already fetched (no extra query)
    // so the UI can show the comparison on a non-passing row.
    setComparisonValues(
      rule,
      record,
      result,
      primaryRows,
      comparisonRows,
      mode
    );

    if (passed) {
      result.status = 'PASS';
    } else {
      result.status = 'FAIL';
      result.severity = rule.FailureSeverity__c;
      // Merge-field resolution is handled by the engine; this evaluator still
      // supplies the unresolved template for the shared finalization path.
      result.message = String.isNotBlank(rule.FailureMessage__c)
        ? rule.FailureMessage__c
        : 'Check failed.';
    }
    return result;
  }

  // ─── Actual vs expected display values ────────────────────────────────────

  /**
   * Sets result.actualValue / result.expectedValue from the rows already
   * fetched. Called only after the operator returned a determinate boolean, so
   * resolveSingleValue cannot throw here for the OneResult path.
   */
  @TestVisible
  private void setComparisonValues(
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckResult result,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    String mode
  ) {
    // The primary row decides the format when the author left Display: Value
    // Format on Auto, and names the currency its amounts are in. Both sides use
    // that one choice so the two chips read in the same units.
    SObject primaryRow = primaryRows.isEmpty() ? null : primaryRows[0];
    String displayFormat = RecordHealthCheckDisplayFormat.formatForRow(
      rule.DisplayValueFormat__c,
      primaryRow,
      rule.SourceQueryField__c
    );
    // When the primary query read the record the card is on, that record's
    // currency is this amount's currency.
    String displayIsoCode = RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
      primaryRow,
      record
    );

    // The two sides are separate queries and can hold separate currencies — a
    // pipeline total converted to the corporate currency against a record's own
    // amount, for instance. They share one format, but each keeps its own
    // currency so neither number is labelled with the other's.
    SObject comparisonRow = comparisonRows.isEmpty() ? null : comparisonRows[0];
    String comparisonIsoCode = RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
      comparisonRow,
      record
    );

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
      Object displayPrimaryValue = RecordHealthCheckDisplayFormat.valueForDisplay(
        primaryValue,
        rule.DisplayValueFormat__c,
        primaryRow,
        rule.SourceQueryField__c
      );
      Object displayComparisonValue = RecordHealthCheckDisplayFormat.valueForDisplay(
        comparisonValue,
        rule.DisplayValueFormat__c,
        comparisonRow,
        rule.ComparisonQueryField__c
      );
      result.actualValue = RecordHealthCheckComparisonEngine.formatValue(
        displayPrimaryValue,
        displayFormat,
        displayIsoCode
      );
      result.expectedValue = RecordHealthCheckComparisonEngine.describeExpected(
        rule.ComparisonOperator__c,
        displayComparisonValue,
        displayFormat,
        comparisonIsoCode
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
      List<Object> primaryList = RecordHealthCheckValueResolver.singleValueList(
        primaryRows,
        rule.SourceQueryField__c
      );
      List<Object> comparisonList = RecordHealthCheckValueResolver.singleValueList(
        comparisonRows,
        rule.ComparisonQueryField__c
      );
      List<Object> displayPrimaryList = RecordHealthCheckDisplayFormat.valuesForDisplay(
        primaryList,
        rule.DisplayValueFormat__c,
        primaryRows,
        rule.SourceQueryField__c
      );
      List<Object> displayComparisonList = RecordHealthCheckDisplayFormat.valuesForDisplay(
        comparisonList,
        rule.DisplayValueFormat__c,
        comparisonRows,
        rule.ComparisonQueryField__c
      );
      // Each entry is labelled with the currency of the row it came from, so a
      // list mixing currencies does not read as if it were all in the first
      // row's.
      result.actualValue = RecordHealthCheckComparisonEngine.formatList(
        displayPrimaryList,
        displayFormat,
        RecordHealthCheckDisplayFormat.currencyIsoCodesFor(primaryRows, record)
      );
      result.expectedValue = RecordHealthCheckComparisonEngine.describeExpectedList(
        rule.ComparisonOperator__c,
        displayComparisonList,
        displayFormat,
        RecordHealthCheckDisplayFormat.currencyIsoCodesFor(
          comparisonRows,
          record
        )
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

    // Author wording replaces what the Framework wrote on either side. The value
    // source details above keep the raw values for a diagnostics viewer.
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      rule,
      record,
      result
    );
  }

  // Prefers the field name (what the viewer recognizes) as the value source
  // source, falling back to the query role when no field is configured.
  private String provenanceSource(String field, String fallback) {
    return String.isNotBlank(field) ? field : fallback;
  }

  // ─── Single-value vs single-value ────────────────────────────────────────

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
      if (nb == 'SKIP_RECORD') {
        return null;
      }
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
      return RecordHealthCheckValueResolver.singleValueFromRow(
        rows[0],
        fieldName
      );
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  // ─── List vs list ────────────────────────────────────────────────────────

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
        if (comparisonSet.contains(val)) {
          return true;
        }
      }
      return false;
    }

    if (operator == 'LISTS_CONTAIN_ALL') {
      // Every primary value appears in the comparison list.
      for (String val : primarySet) {
        if (!comparisonSet.contains(val)) {
          return false;
        }
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
      'INVALID_OPERATOR',
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
        Object val : RecordHealthCheckValueResolver.singleValueList(
          rows,
          fieldName
        )
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
          // Converting to '' (the old behavior) let two null fields "match" as
          // blanks and wrongly satisfy ListsOverlap / ExactListMatch. Write a
          // unique, non-data placeholder instead so each null stays distinct.
          values.add(
            MISSING_NO_MATCH_PLACEHOLDER + side + ':' + missingIndex++
          );
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
    if (left.size() != right.size()) {
      return false;
    }
    for (String key : left.keySet()) {
      if (!right.containsKey(key) || right.get(key) != left.get(key)) {
        return false;
      }
    }
    return true;
  }

  // ─── Query execution with row-cap safety ─────────────────────────────────

  @TestVisible
  private List<SObject> runQuery(String soql, Integer maxRows) {
    return RecordHealthCheckQueryEvaluatorSupport.runQuery(soql, maxRows);
  }

  // ─── Empty/null result helpers ────────────────────────────────────────────

  @TestVisible
  private RecordHealthCheckResult buildEmptyOrNullResult(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result
  ) {
    return RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
      rule,
      result,
      null
    );
  }

  /**
   * result for a present-but-null value (both queries returned
   * rows, but a field under test was null and the empty-value handling resolves to Skip).
   * Reported as SKIPPED and deliberately NOT governed by NoRowsResult__c.
   */
  @TestVisible
  private RecordHealthCheckResult buildNullIndeterminateResult(
    RecordHealthCheckResult result
  ) {
    return RecordHealthCheckQueryEvaluatorSupport.buildNullIndeterminateResult(
      result
    );
  }

  @TestVisible
  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return RecordHealthCheckQueryEvaluatorSupport.safeCannotEvaluateMessage(
      rule
    );
  }
}
