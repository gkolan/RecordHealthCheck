/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckSoqlEvaluator {
  private static final Pattern FROM_OBJECT_PATTERN = Pattern.compile(
    '(?is)\\bFROM\\s+([A-Za-z0-9_]+)'
  );
  private static final Integer DEFAULT_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();

  public RecordHealthCheckSoqlEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    formulaEvaluator.withRunContext(value);
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
    result.evaluatorType = 'QUERY';

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
    Boolean isListOperator =
      rule.ComparisonOperator__c == 'LIST_CONTAINS_ANY' ||
      rule.ComparisonOperator__c == 'LIST_CONTAINS_NONE';
    Boolean isUnaryOperator =
      rule.ComparisonOperator__c == 'IS_BLANK' ||
      rule.ComparisonOperator__c == 'IS_NOT_BLANK';
    Integer maxRows = rule.MaxQueryRows__c != null
      ? (Integer) rule.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;

    // ── Resolve primary value / list ──────────────────────────────────────
    Object primaryValue = null;
    List<Object> primaryList = null;

    if (isListOperator) {
      // List-membership mode: primary side comes from FindInListFormula__c.
      try {
        primaryValue = formulaEvaluator.resolveFormulaSingleValue(
          rule.FindInListFormula__c,
          record,
          rule.FormulaResultType__c
        );
      } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException fex) {
        throw new RecordHealthCheckEvaluatorException(
          fex.reasonCode,
          fex.getMessage()
        );
      }
    } else {
      // Tiers 3–5, 8: primary side from SourceQuery__c
      String soql = bindTokens(rule.SourceQuery__c, record);
      List<SObject> rows = runQuery(soql, maxRows);

      if (rule.QueryResultHandling__c == 'ONE_RESULT') {
        if (rows.isEmpty()) {
          // Aggregate COUNT() always returns 1 row (with count=0), so this branch
          // is only reached by non-aggregate queries with no matching rows.
          // Route through configured EmptyResultBehavior rather than returning 0.
          return buildEmptyOrNullResult(rule, result, null);
        } else if (rows.size() > 1) {
          throw new RecordHealthCheckEvaluatorException(
            'MULTIPLE_ROWS_RETURNED',
            'OneResult check returned ' + rows.size() + ' rows.'
          );
        } else {
          primaryValue = readQueryFieldValue(rows[0], rule.SourceQueryField__c);
        }
      } else {
        // AnyRowPasses, AllRowsPass, CompareAsLists
        primaryList = resolveFieldList(rows, rule.SourceQueryField__c);
      }
    }

    // ── Resolve comparison value / list ───────────────────────────────────
    Object comparisonValue = null;
    List<Object> comparisonList = null;
    // distinguishes a null comparison that came from a comparison
    // query returning zero rows (→ NoRowsResult__c) from one where the field was
    // simply null on a present row (→ null-value, handled by EmptyValueHandling__c).
    Boolean comparisonQueryWasEmpty = false;

    if (!isUnaryOperator) {
      if (isListOperator) {
        // Comparison side: query result list
        String compSoql = bindTokens(rule.ComparisonQuery__c, record);
        List<SObject> compRows = runQuery(compSoql, maxRows);
        comparisonList = resolveFieldList(
          compRows,
          rule.ComparisonQueryField__c
        );
      } else if (rule.ExpectedValueSource__c == 'FIXED_VALUE') {
        comparisonValue = rule.ExpectedFixedValue__c;
      } else if (rule.ExpectedValueSource__c == 'RECORD_FORMULA') {
        try {
          comparisonValue = formulaEvaluator.resolveFormulaSingleValue(
            rule.ExpectedRecordFormula__c,
            record,
            rule.FormulaResultType__c
          );
        } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException fex) {
          throw new RecordHealthCheckEvaluatorException(
            fex.reasonCode,
            fex.getMessage()
          );
        }
      } else if (rule.ExpectedValueSource__c == 'COMPARISON_QUERY') {
        String compSoql = bindTokens(rule.ComparisonQuery__c, record);
        List<SObject> compRows = runQuery(compSoql, maxRows);
        if (compRows.isEmpty()) {
          comparisonValue = null;
          comparisonQueryWasEmpty = true;
        } else if (compRows.size() == 1) {
          comparisonValue = readQueryFieldValue(
            compRows[0],
            rule.ComparisonQueryField__c
          );
        } else {
          throw new RecordHealthCheckEvaluatorException(
            'MULTIPLE_ROWS_RETURNED',
            'Comparison Query returned ' +
              compRows.size() +
              ' rows for a single-value comparison. ' +
              'Add a LIMIT 1 clause or use AnyRowPasses/AllRowsPass mode.'
          );
        }
      }
    }

    // ── Apply operator ──────────────────────────────────────────────────
    Boolean passed;

    if (isListOperator) {
      passed = RecordHealthCheckComparisonEngine.applyListComparison(
        rule.ComparisonOperator__c,
        primaryValue,
        comparisonList,
        rule
      );
    } else if (primaryList != null) {
      // Multi-row primary (AnyRowPasses / AllRowsPass / CompareAsLists)
      passed = RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        rule,
        primaryList,
        comparisonValue,
        comparisonList
      );
    } else if (isUnaryOperator) {
      passed = RecordHealthCheckComparisonEngine.applyUnaryComparison(
        rule.ComparisonOperator__c,
        primaryValue
      );
    } else {
      passed = RecordHealthCheckComparisonEngine.applySingleComparison(
        rule.ComparisonOperator__c,
        primaryValue,
        comparisonValue,
        rule
      );
    }

    if (passed == null) {
      // An indeterminate operator result has two distinct causes that must NOT
      // be treated alike. A genuine zero-rows result is governed by
      // NoRowsResult__c; a present-but-null value is governed by the empty-value
      // handling (EmptyValueHandling__c) and resolves to SKIPPED. Routing the
      // second through NoRowsResult__c makes "null value + no-rows = Fail"
      // wrongly FAIL, so the two are separated below.
      Boolean zeroRows;
      if (isListOperator) {
        // List operator's comparison side is a query; the primary is a single-value.
        // Indeterminate is zero-rows only when that query returned no rows.
        zeroRows = (comparisonList == null || comparisonList.isEmpty());
      } else if (primaryList != null) {
        // Multi-row primary: empty list = zero rows; a non-empty list that still
        // resolved to null means every row's value was null-skipped.
        zeroRows = primaryList.isEmpty();
      } else {
        // OneResult / single single-value: an empty PRIMARY result was already routed
        // above, so the only zero-rows cause left is an empty comparison query.
        zeroRows = comparisonQueryWasEmpty;
      }
      return zeroRows
        ? buildEmptyOrNullResult(rule, result, primaryList)
        : buildNullIndeterminateResult(result);
    }

    // Capture what the record produced vs what the rule required so the UI can
    // show the comparison on a non-passing row.
    if (primaryList != null && rule.QueryResultHandling__c == 'ALL_ROWS_PASS') {
      // "Every row must pass" over many rows: a raw value dump does not scale, so
      // summarize as a count ("1 of 5 Contacts did not pass"). An admin can
      // override the phrasing per rule for friendlier wording.
      Integer totalRows = primaryList.size();
      Integer failingRows = RecordHealthCheckComparisonEngine.countFailingRows(
        rule,
        primaryList,
        comparisonValue
      );
      result.actualValue = String.isNotBlank(rule.DisplayFoundText__c)
        ? resolveSummaryTemplate(
            rule.DisplayFoundText__c,
            failingRows,
            totalRows,
            record
          )
        : deriveFoundSummary(rule, failingRows, totalRows);
      result.expectedValue = String.isNotBlank(rule.DisplayExpectedText__c)
        ? resolveSummaryTemplate(
            rule.DisplayExpectedText__c,
            failingRows,
            totalRows,
            record
          )
        : RecordHealthCheckComparisonEngine.describeExpectedForActual(
            rule.ComparisonOperator__c,
            comparisonValue,
            firstDisplayValue(primaryValue, primaryList),
            rule.DisplayValueFormat__c
          );
    } else {
      String rawActualValue = primaryList != null
        ? RecordHealthCheckComparisonEngine.formatList(
            primaryList,
            rule.DisplayValueFormat__c
          )
        : RecordHealthCheckComparisonEngine.formatValue(
            primaryValue,
            rule.DisplayValueFormat__c
          );
      String rawExpectedValue;
      if (isListOperator) {
        rawExpectedValue = RecordHealthCheckComparisonEngine.describeExpectedList(
          rule.ComparisonOperator__c,
          comparisonList,
          rule.DisplayValueFormat__c
        );
      } else {
        rawExpectedValue = RecordHealthCheckComparisonEngine.describeExpectedForActual(
          rule.ComparisonOperator__c,
          comparisonValue,
          firstDisplayValue(primaryValue, primaryList),
          rule.DisplayValueFormat__c
        );
      }
      result.actualValue = String.isNotBlank(rule.DisplayFoundText__c)
        ? resolveSingleValueTemplate(
            rule.DisplayFoundText__c,
            rawActualValue,
            rawExpectedValue,
            record
          )
        : rawActualValue;
      result.expectedValue = String.isNotBlank(rule.DisplayExpectedText__c)
        ? resolveSingleValueTemplate(
            rule.DisplayExpectedText__c,
            rawActualValue,
            rawExpectedValue,
            record
          )
        : rawExpectedValue;
    }

    // Value source — where each side came from and its raw value/row count, so an
    // entitled viewer can tell a true value from an empty/converted one.
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      describePrimarySource(rule),
      primaryList != null
        ? RecordHealthCheckValueSource.rowCount(primaryList.size())
        : rawLabel(primaryValue),
      null
    );
    if (isUnaryOperator) {
      // A unary operator has no comparison value or source, so the "source" of
      // the requirement is the operator itself. Labeling it 'Operator' (not
      // 'Expected requirement') avoids the row reading "Expected Expected …" once
      // the UI prefixes it with the "Expected" caption.
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        'Comparison operator',
        result.expectedValue,
        null
      );
    } else {
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        describeComparisonSource(rule),
        isListOperator
          ? RecordHealthCheckValueSource.rowCount(
              comparisonList == null ? 0 : comparisonList.size()
            )
          : rawLabel(comparisonValue),
        null
      );
    }

    if (passed) {
      result.status = 'PASS';
    } else {
      result.status = 'FAIL';
      result.severity = rule.FailureSeverity__c;
      result.message = formulaEvaluator.resolveMergeFields(
        rule.FailureMessage__c,
        record,
        rule,
        result,
        true
      );
    }
    return result;
  }

  // ─── Token binding ──────────────────────────────────────────

  /**
   * Replaces {!record.FieldName} tokens with the record's field values.
   * Values are returned as a Map so Database.query can use them as bind vars.
   * Since Apex dynamic SOQL only supports real bind variables in code scope
   * we inject field values directly — but we use String.escapeSingleQuotes
   * for string values and typed formatting for non-strings to prevent injection.
   */
  @TestVisible
  public String bindTokens(String soqlTemplate, SObject record) {
    if (String.isBlank(soqlTemplate)) {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_SOQL_TEMPLATE',
        'SOQL template is blank.'
      );
    }

    // Validate no disallowed DML keywords using word-boundary matching
    // so field names like IsDeleted or Last_Update__c are not false-positives.
    validateNoDisallowedKeywords(soqlTemplate);

    RecordHealthCheckTemplateService.assertValid(
      soqlTemplate,
      RecordHealthCheckTemplateService.SURFACE_SOQL
    );
    List<RecordHealthCheckToken> tokens = RecordHealthCheckTemplateService.parse(
      soqlTemplate
    );
    String bound = '';
    Integer lastEnd = 0;

    for (RecordHealthCheckToken token : tokens) {
      String fieldPath = token.propertyPath;

      Object fieldValue;
      try {
        fieldValue = resolveFieldPath(record, fieldPath);
      } catch (System.SObjectException ex) {
        throw new RecordHealthCheckEvaluatorException(
          'MISSING_BIND_VALUE',
          'Field "' + fieldPath + '" could not be resolved on the record.'
        );
      }
      if (
        (fieldValue == null ||
        (fieldValue instanceof String &&
        String.isBlank((String) fieldValue))) && token.fallbackValue != null
      ) {
        fieldValue = coerceFallbackValue(
          record,
          fieldPath,
          token.fallbackValue
        );
      }

      // A token can appear quoted ('{!record.Field}') AND unquoted ({!record.Field}) in the same
      // template, so resolve both quoting contexts independently. For most types the
      // two replacements are identical; only a multi-select picklist differs — its
      // unquoted form expands to an INCLUDES list while its quoted form keeps the
      // raw 'A;B;C' value.
      Boolean quotedToken =
        token.startIndex > 0 &&
        token.endIndex < soqlTemplate.length() &&
        soqlTemplate.substring(token.startIndex - 1, token.startIndex) ==
        '\'' &&
        soqlTemplate.substring(token.endIndex, token.endIndex + 1) == '\'';
      Boolean insideStringLiteral = isInsideStringLiteral(
        soqlTemplate,
        token.startIndex
      );

      // Safe substitution — each Apex type maps to the correct SOQL literal format.
      String unquotedReplacement;
      String quotedReplacement;
      String embeddedLiteralReplacement;
      if (fieldValue == null) {
        // Quoted context strips the outer quotes so the literal is a bare SOQL null.
        unquotedReplacement = 'null';
        quotedReplacement = 'null';
        embeddedLiteralReplacement = '';
      } else if (fieldValue instanceof Date) {
        // SOQL Date literals: yyyy-MM-dd — no quotes required or allowed
        unquotedReplacement = String.valueOf((Date) fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (fieldValue instanceof DateTime) {
        // SOQL DateTime literals: yyyy-MM-ddTHH:mm:ssZ — no quotes required or allowed
        unquotedReplacement = ((DateTime) fieldValue)
          .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (fieldValue instanceof Time) {
        // SOQL Time literals: HH:mm:ss.SSSz — no quotes required or allowed
        unquotedReplacement = String.valueOf((Time) fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (fieldValue instanceof Boolean) {
        // SOQL Boolean literals: true / false — no quotes
        unquotedReplacement = String.valueOf((Boolean) fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (
        fieldValue instanceof Integer ||
        fieldValue instanceof Long ||
        fieldValue instanceof Double ||
        fieldValue instanceof Decimal
      ) {
        // SOQL numeric literals — no quotes; Decimal handles Currency and Percent fields
        unquotedReplacement = String.valueOf(fieldValue);
        quotedReplacement = unquotedReplacement;
      } else {
        // String, Id, Picklist, Text Area, Auto Number, Encrypted Text, etc.
        String rawStr = String.valueOf(fieldValue);
        // Default: quoted string with single-quote escaping prevents injection.
        // Multi-select picklist in QUOTED context keeps the raw 'A;B;C' value
        // suitable for exact-match (=) or INCLUDES ('A;B') AND-semantics queries.
        String quotedStr = '\'' + String.escapeSingleQuotes(rawStr) + '\'';
        quotedReplacement = quotedStr;
        embeddedLiteralReplacement = String.escapeSingleQuotes(rawStr);
        if (isMultiSelectPicklist(record, fieldPath) && rawStr.contains(';')) {
          // Multi-select picklist in UNQUOTED context
          // Template: WHERE Regions__c INCLUDES {!record.Regions__c}
          // Value: 'North;South'
          // Result: WHERE Regions__c INCLUDES ('North', 'South')
          // Each semicolon-delimited value is individually quoted and comma-joined.
          // An all-semicolon value (';' or ';;') has no segments after filtering, which
          // would produce '()' — invalid SOQL (INCLUDES ()). Empty quotedVals instead
          // raise MISSING_BIND_VALUE, same as an unresolved token.
          unquotedReplacement = buildMultiSelectIncludesClause(rawStr);
        } else {
          unquotedReplacement = quotedStr;
        }
      }

      // Build from original matcher spans so inserted field values are never scanned
      // for later {!record.token} text. Quoted tokens consume their outer quotes because
      // Date/Time/numeric/null replacements must stay unquoted.
      if (quotedToken) {
        bound +=
          soqlTemplate.substring(lastEnd, token.startIndex - 1) +
          quotedReplacement;
        lastEnd = token.endIndex + 1;
      } else if (insideStringLiteral) {
        bound +=
          soqlTemplate.substring(lastEnd, token.startIndex) +
          embeddedLiteralReplacement;
        lastEnd = token.endIndex;
      } else {
        bound +=
          soqlTemplate.substring(lastEnd, token.startIndex) +
          unquotedReplacement;
        lastEnd = token.endIndex;
      }
    }

    return bound + soqlTemplate.substring(lastEnd);
  }

  private static Boolean isInsideStringLiteral(String source, Integer indexAt) {
    Boolean inQuote = false;
    for (Integer i = 0; i < indexAt; i++) {
      String ch = source.substring(i, i + 1);
      if (ch == '\\' && inQuote && i + 1 < indexAt) {
        i++;
      } else if (ch == '\'') {
        inQuote = !inQuote;
      }
    }
    return inQuote;
  }

  /**
   * Rejects SOQL containing DML/dangerous keywords matched as whole words only.
   * Uses \b word-boundary so field names like IsDeleted or Last_Update__c
   * do not trigger a false positive on DELETE or UPDATE.
   * Multi-word phrases (FOR UPDATE, ALL ROWS) are still matched literally.
   */
  @TestVisible
  private void validateNoDisallowedKeywords(String soql) {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(soql);
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  // ─── Query execution with row-cap safety ───────────────────

  @TestVisible
  private List<SObject> runQuery(String soql, Integer maxRows) {
    return RecordHealthCheckQueryEvaluatorSupport.runQuery(soql, maxRows);
  }

  // ─── Value resolution helpers ─────────────────────────────────────────────

  @TestVisible
  private Object readQueryFieldValue(SObject row, String fieldName) {
    try {
      return RecordHealthCheckValueResolver.singleValueFromRow(row, fieldName);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  @TestVisible
  private List<Object> resolveFieldList(List<SObject> rows, String fieldName) {
    try {
      return RecordHealthCheckValueResolver.singleValueList(rows, fieldName);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  // ─── Empty / null result behavior ────────────────────────────────────────

  @TestVisible
  private RecordHealthCheckResult buildEmptyOrNullResult(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckResult result,
    List<Object> primaryList
  ) {
    // A displayed "Found 0" is ambiguous: it could be a real zero or an empty
    // result set. Record which one it was, so the value source note reads e.g.
    // "Contacts → 0 rows (query returned no matching rows)".
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      describePrimarySource(rule),
      RecordHealthCheckValueSource.rowCount(
        primaryList != null ? primaryList.size() : 0
      ),
      'query returned no matching rows'
    );

    return RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
      rule,
      result,
      result.actualValueSource
    );
  }

  /**
   * Builds a result for a present-but-null value the operator could not
   * decide. Reaching this point means the empty-value handling (EmptyValueHandling__c)
   * resolved to Skip — Pass/Fail/Treat as not matching (AS_NO_MATCH) all yield a determinate
   * boolean earlier — so the check is reported as SKIPPED. This is deliberately
   * NOT governed by NoRowsResult__c, which applies only to empty result sets.
   */
  @TestVisible
  private RecordHealthCheckResult buildNullIndeterminateResult(
    RecordHealthCheckResult result
  ) {
    return RecordHealthCheckQueryEvaluatorSupport.buildNullIndeterminateResult(
      result
    );
  }

  // ─── Value source helpers ───────────────────────────────────────────────────

  // Derived Found summary for an "every record must pass" check when the admin
  // authored no override: "1 of 5 Contacts did not pass".
  private String deriveFoundSummary(
    Record_Health_Check_Rule__mdt rule,
    Integer failing,
    Integer total
  ) {
    return failing +
      ' of ' +
      total +
      ' ' +
      pluralizeObject(rule) +
      ' did not pass';
  }

  // Resolves an admin-authored summary through the shared token context.
  private String resolveSummaryTemplate(
    String template,
    Integer failing,
    Integer total,
    SObject record
  ) {
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withResult(new RecordHealthCheckResult(), true);
    context.failedRecordCount = failing;
    context.totalRecordCount = total;
    return RecordHealthCheckTemplateService.resolveDisplay(template, context);
  }

  // Applies business-facing labels to a single query value while preserving the
  // raw values in the merge context and in diagnostic value-source details.
  private String resolveSingleValueTemplate(
    String template,
    String foundValue,
    String expectedValue,
    SObject record
  ) {
    RecordHealthCheckResult rawResult = new RecordHealthCheckResult();
    rawResult.actualValue = foundValue;
    rawResult.expectedValue = expectedValue;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withResult(rawResult, true);
    return RecordHealthCheckTemplateService.resolveDisplay(template, context);
  }

  // Best-effort object label from the query's FROM clause, pluralized; falls back
  // to a generic noun when the object cannot be parsed.
  @TestVisible
  private String pluralizeObject(Record_Health_Check_Rule__mdt rule) {
    String objectName;
    if (String.isNotBlank(rule.SourceQuery__c)) {
      Matcher m = FROM_OBJECT_PATTERN.matcher(rule.SourceQuery__c);
      if (m.find()) {
        objectName = m.group(1);
      }
    }
    if (String.isBlank(objectName)) {
      return 'records';
    }
    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
    if (objectType != null)
      return objectType.getDescribe().getLabelPlural();
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

  // Names the primary/Found source: a field, the value under test, or a generic
  // query-result label when neither is configured.
  private String describePrimarySource(Record_Health_Check_Rule__mdt rule) {
    if (String.isNotBlank(rule.SourceQueryField__c)) {
      return rule.SourceQueryField__c;
    }
    if (String.isNotBlank(rule.FindInListFormula__c)) {
      return 'Value under test';
    }
    return 'Query result';
  }

  // Names the source of the "Expected" operand.
  @TestVisible
  private String describeComparisonSource(Record_Health_Check_Rule__mdt rule) {
    if (rule.ExpectedValueSource__c == 'FIXED_VALUE') {
      return 'Fixed value';
    }
    if (rule.ExpectedValueSource__c == 'RECORD_FORMULA') {
      return 'Formula on this record';
    }
    if (rule.ExpectedValueSource__c == 'COMPARISON_QUERY') {
      return String.isNotBlank(rule.ComparisonQueryField__c)
        ? 'Comparison query (' + rule.ComparisonQueryField__c + ')'
        : 'Comparison query';
    }
    if (String.isNotBlank(rule.ComparisonQueryField__c)) {
      return rule.ComparisonQueryField__c;
    }
    return 'Comparison';
  }

  // Raw single-value label that renders null explicitly rather than as an empty string.
  private String rawLabel(Object value) {
    return value == null ? 'null' : String.valueOf(value);
  }

  private Object firstDisplayValue(Object singleValue, List<Object> values) {
    if (singleValue != null)
      return singleValue;
    if (values != null) {
      for (Object value : values) {
        if (value != null)
          return value;
      }
    }
    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /**
   * Builds the parenthesized INCLUDES operand for an unquoted multi-select token.
   * Test-visible so semicolon-only values can be verified without a live field.
   */
  @TestVisible
  private String buildMultiSelectIncludesClause(String rawStr) {
    List<String> quotedVals = new List<String>();
    for (String v : rawStr.split(';')) {
      // drop empty segments so 'A;' / 'A;;B' do not inject '' entries.
      if (String.isBlank(v)) {
        continue;
      }
      quotedVals.add('\'' + String.escapeSingleQuotes(v.trim()) + '\'');
    }
    if (quotedVals.isEmpty()) {
      throw new RecordHealthCheckEvaluatorException(
        'MISSING_BIND_VALUE',
        'Multi-select value has no non-empty segments after splitting on ";".'
      );
    }
    return '(' + String.join(quotedVals, ', ') + ')';
  }

  @TestVisible
  private Boolean isMultiSelectPicklist(SObject record, String fieldPath) {
    List<String> parts = fieldPath.split('\\.');
    Schema.SObjectType currentType = record.getSObjectType();
    for (Integer i = 0; i < parts.size(); i++) {
      Map<String, Schema.SObjectField> fieldMap = RecordHealthCheckDescribeCache.fieldMap(
        currentType
      );
      if (i == parts.size() - 1) {
        Schema.SObjectField field = fieldMap.get(parts[i]);
        return field != null &&
          RecordHealthCheckDescribeCache.describeField(field).getType() ==
          Schema.DisplayType.MULTIPICKLIST;
      }
      Schema.SObjectField relationshipField;
      for (Schema.SObjectField candidate : fieldMap.values()) {
        Schema.DescribeFieldResult description = RecordHealthCheckDescribeCache.describeField(
          candidate
        );
        if (
          description.getRelationshipName() != null &&
          description.getRelationshipName().equalsIgnoreCase(parts[i])
        ) {
          relationshipField = candidate;
          break;
        }
      }
      if (relationshipField == null)
        return false;
      List<Schema.SObjectType> referenceTypes = RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo();
      if (referenceTypes.isEmpty())
        return false;
      currentType = selectReferenceType(referenceTypes, parts[i + 1]);
    }
    return false;
  }

  /** Converts an explicit SOQL-token fallback to the terminal field's native type. */
  @TestVisible
  private Object coerceFallbackValue(
    SObject record,
    String fieldPath,
    String fallbackValue
  ) {
    if (String.isBlank(fallbackValue))
      return null;
    Schema.DisplayType fieldType = terminalFieldType(record, fieldPath);
    String trimmed = fallbackValue.trim();
    try {
      if (fieldType == Schema.DisplayType.BOOLEAN) {
        if (trimmed.toLowerCase() != 'true' && trimmed.toLowerCase() != 'false')
          throw new RecordHealthCheckEvaluatorException(
            'MISSING_BIND_VALUE',
            'Boolean fallback must be true or false.'
          );
        return Boolean.valueOf(trimmed);
      }
      if (fieldType == Schema.DisplayType.DATE)
        return Date.valueOf(trimmed);
      if (fieldType == Schema.DisplayType.DATETIME) {
        String normalized = trimmed.replace('T', ' ').replace('Z', '');
        return Datetime.valueOfGmt(normalized);
      }
      if (fieldType == Schema.DisplayType.TIME)
        return parseTimeFallback(trimmed);
      if (fieldType == Schema.DisplayType.INTEGER)
        return Integer.valueOf(trimmed);
      if (
        fieldType == Schema.DisplayType.CURRENCY ||
        fieldType == Schema.DisplayType.DOUBLE ||
        fieldType == Schema.DisplayType.PERCENT
      )
        return Decimal.valueOf(trimmed);
      return fallbackValue;
    } catch (Exception ex) {
      throw new RecordHealthCheckEvaluatorException(
        'MISSING_BIND_VALUE',
        'Fallback "' +
          fallbackValue +
          '" is not valid for field "' +
          fieldPath +
          '".'
      );
    }
  }

  @TestVisible
  private Time parseTimeFallback(String value) {
    String normalized = value.endsWith('Z')
      ? value.substring(0, value.length() - 1)
      : value;
    List<String> parts = normalized.split(':');
    if (parts.size() != 3)
      throw new RecordHealthCheckEvaluatorException(
        'MISSING_BIND_VALUE',
        'Time fallback must use HH:mm:ss or HH:mm:ss.SSS.'
      );
    List<String> secondParts = parts[2].split('\\.');
    Integer milliseconds = 0;
    if (secondParts.size() > 1) {
      String fraction = secondParts[1];
      while (fraction.length() < 3)
        fraction += '0';
      if (fraction.length() > 3)
        fraction = fraction.substring(0, 3);
      milliseconds = Integer.valueOf(fraction);
    }
    return Time.newInstance(
      Integer.valueOf(parts[0]),
      Integer.valueOf(parts[1]),
      Integer.valueOf(secondParts[0]),
      milliseconds
    );
  }

  @TestVisible
  private Schema.DisplayType terminalFieldType(
    SObject record,
    String fieldPath
  ) {
    List<String> parts = fieldPath.split('\\.');
    Schema.SObjectType currentType = record.getSObjectType();
    for (Integer i = 0; i < parts.size(); i++) {
      Map<String, Schema.SObjectField> fieldMap = RecordHealthCheckDescribeCache.fieldMap(
        currentType
      );
      if (i == parts.size() - 1) {
        Schema.SObjectField terminal = fieldMap.get(parts[i]);
        return terminal == null
          ? Schema.DisplayType.STRING
          : RecordHealthCheckDescribeCache.describeField(terminal).getType();
      }
      Schema.SObjectField relationshipField;
      for (Schema.SObjectField candidate : fieldMap.values()) {
        Schema.DescribeFieldResult description = RecordHealthCheckDescribeCache.describeField(
          candidate
        );
        if (
          description.getRelationshipName() != null &&
          description.getRelationshipName().equalsIgnoreCase(parts[i])
        ) {
          relationshipField = candidate;
          break;
        }
      }
      if (relationshipField == null)
        return Schema.DisplayType.STRING;
      List<Schema.SObjectType> referenceTypes = RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo();
      if (referenceTypes.isEmpty())
        return Schema.DisplayType.STRING;
      currentType = selectReferenceType(referenceTypes, parts[i + 1]);
    }
    return Schema.DisplayType.STRING;
  }

  private Schema.SObjectType selectReferenceType(
    List<Schema.SObjectType> candidates,
    String nextPathPart
  ) {
    for (Schema.SObjectType candidate : candidates) {
      Map<String, Schema.SObjectField> fields = RecordHealthCheckDescribeCache.fieldMap(
        candidate
      );
      if (fields.get(nextPathPart) != null)
        return candidate;
      for (Schema.SObjectField field : fields.values()) {
        String relationshipName = RecordHealthCheckDescribeCache.describeField(
            field
          )
          .getRelationshipName();
        if (
          relationshipName != null &&
          relationshipName.equalsIgnoreCase(nextPathPart)
        )
          return candidate;
      }
    }
    return candidates[0];
  }

  /**
   * Resolves a field path that may include relationship traversal
   * (e.g. "Account.Name", "Parent.ShippingCity", "Owner.IsActive").
   * Traverses getSObject() for each relationship segment; returns null
   * if any intermediate relationship is null rather than throwing.
   */
  @TestVisible
  private Object resolveFieldPath(SObject record, String fieldPath) {
    if (!fieldPath.contains('.')) {
      return record.get(fieldPath);
    }
    List<String> parts = fieldPath.split('\\.');
    SObject current = record;
    for (Integer i = 0; i < parts.size() - 1; i++) {
      current = current.getSObject(parts[i]);
      if (current == null) {
        return null;
      }
    }
    return current.get(parts[parts.size() - 1]);
  }

  @TestVisible
  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return RecordHealthCheckQueryEvaluatorSupport.safeCannotEvaluateMessage(
      rule
    );
  }
}
