/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Shared operator + null/empty-behavior engine for the SOQL evaluators.
 * The single-value operator core (Equals / NotEquals / Contains / ordered), value
 * equality, and EmptyResultBehavior resolution live here as pure static
 * functions so single-query and compare-queries checks compare values identically.
 * The richer single-query operators (multi-row, list, unary, NullBehavior-
 * aware) live here too, giving all operator logic one home.
 * Throws RecordHealthCheckEvaluatorException so both evaluators map the same
 * reason codes onto UNABLE_TO_EVALUATE results.
 */
public with sharing class RecordHealthCheckComparisonEngine {
  // ─── Single-value operator core (shared by both evaluators) ───────────────────

  /**
   * The single-value operator core: Equals / NotEquals / Contains / DoesNotContain
   * and the ordered operators. No NullBehavior handling — callers that need it
   * use applySingleComparison. Ordered comparisons defer to the value resolver's
   * typed ladder (Decimal → DateTime) so values never compare lexicographically.
   */
  public static Boolean applySingleValueComparison(
    String operator,
    Object primary,
    Object comparison
  ) {
    String pStr = String.valueOf(primary);
    String cStr = String.valueOf(comparison);

    if (operator == 'EQUALS')
      return valuesEqual(primary, comparison);
    if (operator == 'NOT_EQUALS')
      return !valuesEqual(primary, comparison);
    if (operator == 'CONTAINS')
      return pStr.contains(cStr);
    if (operator == 'DOES_NOT_CONTAIN')
      return !pStr.contains(cStr);

    if (
      operator != 'GREATER_THAN' &&
      operator != 'GREATER_THAN_OR_EQUAL' &&
      operator != 'LESS_THAN' &&
      operator != 'LESS_THAN_OR_EQUAL'
    ) {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_OPERATOR',
        'Comparison operator "' + operator + '" is not recognized.'
      );
    }

    try {
      return RecordHealthCheckValueResolver.applyOrdered(
        operator,
        primary,
        comparison
      );
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  public static Boolean valuesEqual(Object primary, Object comparison) {
    try {
      return RecordHealthCheckValueResolver.valuesEqual(primary, comparison);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  /**
   * Returns true (Pass), false (Fail), null (Skip or UnableToEvaluate).
   * Null signals the caller to use EmptyResultBehavior to set the final status.
   */
  public static Boolean resolveEmptyBehavior(String behavior) {
    if (behavior == 'PASS')
      return true;
    if (behavior == 'FAIL')
      return false;
    if (behavior == 'SKIP')
      return null;
    if (behavior == 'UNABLE_TO_EVALUATE')
      return null;
    // No explicit config — treat as indeterminate (Skip is the CMT default)
    return null;
  }

  // ─── Single-query operators (NullBehavior-aware) ────────────────────────

  public static Boolean applyUnaryComparison(String operator, Object value) {
    Boolean isBlank = (value == null || String.valueOf(value).trim() == '');
    if (operator == 'IS_BLANK')
      return isBlank;
    if (operator == 'IS_NOT_BLANK')
      return !isBlank;
    // An unrecognized unary operator is a configuration error, not an
    // indeterminate value. Fail loudly so it surfaces as UNABLE rather than
    // being misrouted into the empty/zero-rows behavior.
    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'Unary operator "' + operator + '" is not recognized.'
    );
  }

  public static Boolean applySingleComparison(
    String operator,
    Object primary,
    Object comparison,
    Record_Health_Check_Rule__mdt rule
  ) {
    // Handle null per EmptyValueHandling__c
    if (primary == null || comparison == null) {
      if (rule.EmptyValueHandling__c == 'AS_BLANK') {
        // Substitute null with '' and continue with the real operator
        primary = primary != null ? primary : '';
        comparison = comparison != null ? comparison : '';
      } else {
        return applyEmptyValueHandling(rule.EmptyValueHandling__c);
      }
    }

    return applySingleValueComparison(operator, primary, comparison);
  }

  public static Boolean applyMultiRecordComparison(
    Record_Health_Check_Rule__mdt rule,
    List<Object> primaryList,
    Object comparisonValue,
    List<Object> comparisonList
  ) {
    if (primaryList.isEmpty()) {
      return resolveEmptyBehavior(rule.NoRowsResult__c);
    }

    String mode = rule.QueryResultHandling__c;

    if (mode == 'ANY_ROW_PASSES') {
      Boolean sawEvaluableRecord = false;
      for (Object val : primaryList) {
        Boolean match = applyRecordComparison(rule, val, comparisonValue);
        if (match == null)
          continue;
        sawEvaluableRecord = true;
        if (match == true)
          return true;
      }
      if (!sawEvaluableRecord)
        return null;
      return false;
    }

    if (mode == 'ALL_ROWS_PASS') {
      Boolean sawEvaluableRecord = false;
      for (Object val : primaryList) {
        Boolean match = applyRecordComparison(rule, val, comparisonValue);
        if (match == null)
          continue;
        sawEvaluableRecord = true;
        if (match != true)
          return false;
      }
      if (!sawEvaluableRecord)
        return null;
      return true;
    }

    if (mode == 'COMPARE_AS_LISTS') {
      // CompareAsLists requires two separate queries — use CheckType CompareTwoQueries.
      // ConfigService.validateQueryRule blocks this at config time; guard at runtime too.
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_OPERATOR',
        'Compare query results as lists is only supported when Check Type is Compare two queries.'
      );
    }

    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'How To Interpret Query Results "' + mode + '" is not recognized.'
    );
  }

  /**
   * Counts rows in a multi-row primary list that fail the per-row operator, for
   * building a readable "N of M …" summary. Rows the empty-value handling skips (row
   * operator returns null) are not counted as failing.
   */
  public static Integer countFailingRows(
    Record_Health_Check_Rule__mdt rule,
    List<Object> primaryList,
    Object comparisonValue
  ) {
    Integer failing = 0;
    if (primaryList == null) {
      return 0;
    }
    for (Object val : primaryList) {
      if (applyRecordComparison(rule, val, comparisonValue) == false) {
        failing++;
      }
    }
    return failing;
  }

  public static Boolean applyRecordComparison(
    Record_Health_Check_Rule__mdt rule,
    Object primary,
    Object comparison
  ) {
    if (primary == null && rule.EmptyValueHandling__c == 'SKIP_RECORD') {
      return null;
    }
    if (
      rule.ComparisonOperator__c == 'IS_BLANK' ||
      rule.ComparisonOperator__c == 'IS_NOT_BLANK'
    ) {
      return applyUnaryComparison(rule.ComparisonOperator__c, primary);
    }
    return applySingleComparisonNullSafe(
      rule.ComparisonOperator__c,
      primary,
      comparison,
      rule
    );
  }

  public static Boolean applySingleComparisonNullSafe(
    String operator,
    Object primary,
    Object comparison,
    Record_Health_Check_Rule__mdt rule
  ) {
    if (primary == null) {
      String nb = rule.EmptyValueHandling__c;
      if (nb == 'SKIP_RECORD')
        return null;
      if (nb == 'AS_NO_MATCH')
        return false;
      if (nb == 'AS_BLANK')
        primary = '';
    }
    return applySingleComparison(operator, primary, comparison, rule);
  }

  public static Boolean applyListComparison(
    String operator,
    Object primaryValue,
    List<Object> comparisonList,
    Record_Health_Check_Rule__mdt rule
  ) {
    if (comparisonList == null || comparisonList.isEmpty()) {
      return resolveEmptyBehavior(rule.NoRowsResult__c);
    }

    if (primaryValue == null) {
      if (rule.EmptyValueHandling__c == 'AS_BLANK') {
        primaryValue = '';
      } else if (rule.EmptyValueHandling__c == 'AS_NO_MATCH') {
        return operator == 'LIST_CONTAINS_NONE';
      } else {
        return null;
      }
    }
    String pStr = String.valueOf(primaryValue);

    if (operator == 'LIST_CONTAINS_ANY') {
      // case-insensitive comparison
      String pLower = pStr.toLowerCase();
      for (Object item : comparisonList) {
        if (item != null && String.valueOf(item).toLowerCase() == pLower)
          return true;
      }
      return false;
    }

    if (operator == 'LIST_CONTAINS_NONE') {
      // case-insensitive comparison
      String pLower = pStr.toLowerCase();
      for (Object item : comparisonList) {
        if (item != null && String.valueOf(item).toLowerCase() == pLower)
          return false;
      }
      return true;
    }

    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'Comparison operator "' + operator + '" is not valid for list operations.'
    );
  }

  // ─── Human-readable comparison descriptions (actual vs expected) ──────────
  // These build the actualValue / expectedValue strings shown alongside a
  // non-passing result so the user sees what the record produced versus what
  // the rule required, without an admin hand-authoring it into FailureMessage__c.

  private static final Integer LIST_PREVIEW_CAP = 10;

  /**
   * Maps a operator API name to a sentence-friendly verb phrase. The phrases
   * are designed to read naturally after the word "expected" when the LWC wraps
   * the comparison as "Found {actualValue}, expected {expectedValue}" — e.g.
   * "expected to equal …", "expected at least 2", "expected to be one of […]".
   */
  public static String operatorLabel(String operator) {
    if (operator == 'EQUALS')
      return 'to equal';
    if (operator == 'NOT_EQUALS')
      return 'to not equal';
    if (operator == 'CONTAINS')
      return 'to contain';
    if (operator == 'DOES_NOT_CONTAIN')
      return 'to not contain';
    if (operator == 'GREATER_THAN')
      return 'more than';
    if (operator == 'GREATER_THAN_OR_EQUAL')
      return 'at least';
    if (operator == 'LESS_THAN')
      return 'less than';
    if (operator == 'LESS_THAN_OR_EQUAL')
      return 'at most';
    if (operator == 'IS_BLANK')
      return 'to be blank';
    if (operator == 'IS_NOT_BLANK')
      return 'to not be blank';
    if (operator == 'LIST_CONTAINS_ANY')
      return 'to be one of';
    if (operator == 'LIST_CONTAINS_NONE')
      return 'to be none of';
    if (operator == 'LISTS_OVERLAP')
      return 'to overlap with';
    if (operator == 'LISTS_CONTAIN_ALL')
      return 'to contain all of';
    if (operator == 'LISTS_MATCH_EXACTLY')
      return 'to exactly match';
    // an unknown operator falls back to its
    // raw API name. Config validation blocks unknown operators upstream, so this
    // is purely defensive; surfacing the literal name keeps a misconfiguration
    // diagnosable rather than dressing it up as a sentence fragment ("using …").
    return operator;
  }

  /**
   * Renders a single value for display; null/blank shows as "(blank)". Non-blank
   * values are returned without decorative quotes because the comparison chip's
   * background and horizontal padding already distinguish values from prose.
   *
   * Values are humanized for readability: typed numbers gain thousands
   * separators, Booleans read Yes/No, and dates/datetimes render in the running
   * user's locale and time zone. Typed values (a checkbox or datetime field, a
   * single-value formula) are converted directly. Boolean and temporal metadata
   * strings are recognized textually; numeric metadata strings require actual-value
   * type context through describeExpectedForActual so identifiers stay unchanged.
   */
  public static String formatValue(Object value) {
    if (value == null)
      return '(blank)';

    // Typed values carry their Apex type here, so humanize them before
    // String.valueOf flattens them into a raw, unformatted string.
    if (value instanceof Boolean) {
      return ((Boolean) value) ? 'Yes' : 'No';
    }
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      // .format() honors the user's locale and time zone; String.valueOf would
      // return a raw GMT "2026-07-04 17:30:00".
      return ((Datetime) value).format();
    }

    // Only values that retain a numeric Apex type are safe to group. A digit-only
    // String may instead be a postal code, year, or identifier whose spelling is
    // significant (including leading zeroes).
    if (
      value instanceof Integer ||
      value instanceof Long ||
      value instanceof Decimal ||
      value instanceof Double
    ) {
      return humanizeNumber(String.valueOf(value));
    }

    String s = String.valueOf(value);
    if (s == null || s.trim() == '')
      return '(blank)';
    String humanized = humanizeString(s);
    if (humanized != null)
      s = humanized;
    return s;
  }

  /**
   * Humanizes a raw display string that arrived without its Apex type (a metadata
   * operand, or a value already flattened by String.valueOf). Tries each shape in
   * order and returns the first match, or null when the text should stand as-is.
   * Number is tried first (its pattern excludes the others); Boolean before date;
   * multi-select last since only it keys off a delimiter that plain text may hold.
   */
  private static String humanizeString(String s) {
    String asBoolean = humanizeBooleanText(s);
    if (asBoolean != null)
      return asBoolean;
    String asDate = humanizeDateText(s);
    if (asDate != null)
      return asDate;
    return humanizeMultiSelect(s);
  }

  // Matches a plain integer or decimal (optionally signed) when an actual numeric
  // value provides type context. Anything else stays untouched so IDs, codes, and
  // pre-formatted text keep their exact spelling.
  private static final Pattern NUMERIC_PATTERN = Pattern.compile(
    '^-?\\d+(\\.\\d+)?$'
  );

  // ISO date (YYYY-MM-DD) and datetime (date + space/T + HH:MM:SS) — the shapes a
  // date/datetime operand or a String.valueOf'd temporal value takes. Trailing
  // fractional seconds / zone offsets are tolerated but ignored; groups feed
  // Date/Datetime.newInstance so parsing is deterministic and never locale-bound.
  private static final Pattern DATE_PATTERN = Pattern.compile(
    '^(\\d{4})-(\\d{2})-(\\d{2})$'
  );
  private static final Pattern DATETIME_PATTERN = Pattern.compile(
    '^(\\d{4})-(\\d{2})-(\\d{2})[ T](\\d{2}):(\\d{2}):(\\d{2}).*$'
  );

  /** Boolean operand text → Yes/No; null when the string is not a boolean. */
  private static String humanizeBooleanText(String raw) {
    String s = raw.trim();
    if (s.equalsIgnoreCase('true'))
      return 'Yes';
    if (s.equalsIgnoreCase('false'))
      return 'No';
    return null;
  }

  /**
   * ISO date/datetime text → the running user's locale/time-zone format (e.g.
   * "7/4/2026" or "7/4/2026, 5:30 PM"). Returns null when the string is not an
   * ISO temporal value so ordinary text is left alone.
   */
  private static String humanizeDateText(String raw) {
    String s = raw.trim();
    Matcher dt = DATETIME_PATTERN.matcher(s);
    if (dt.matches()) {
      return Datetime.newInstance(
          Integer.valueOf(dt.group(1)),
          Integer.valueOf(dt.group(2)),
          Integer.valueOf(dt.group(3)),
          Integer.valueOf(dt.group(4)),
          Integer.valueOf(dt.group(5)),
          Integer.valueOf(dt.group(6))
        )
        .format();
    }
    Matcher d = DATE_PATTERN.matcher(s);
    if (d.matches()) {
      return Date.newInstance(
          Integer.valueOf(d.group(1)),
          Integer.valueOf(d.group(2)),
          Integer.valueOf(d.group(3))
        )
        .format();
    }
    return null;
  }

  /**
   * Semicolon-delimited multi-select picklist text → a comma-separated list
   * ("Hot;Warm;Cold" → "Hot, Warm, Cold"). Returns null when there is no
   * delimiter so single values fall through unchanged.
   */
  private static String humanizeMultiSelect(String raw) {
    if (!raw.contains(';'))
      return null;
    List<String> cleaned = new List<String>();
    for (String part : raw.split(';')) {
      String trimmed = part.trim();
      if (trimmed != '')
        cleaned.add(trimmed);
    }
    return cleaned.isEmpty() ? null : String.join(cleaned, ', ');
  }

  /**
   * Renders a bare number for humans: groups the integer part with thousands
   * separators and drops a fractional part that is all zeros, so a Decimal
   * "70000.0" reads "70,000" and a metadata operand string "500000" reads
   * "500,000". A genuine fraction like "70000.5" keeps its digits ("70,000.5").
   * Returns null when the input is not a plain number, signalling the caller to
   * leave the original string alone.
   */
  private static String humanizeNumber(String raw) {
    if (raw == null)
      return null;
    String s = raw.trim();
    if (!NUMERIC_PATTERN.matcher(s).matches())
      return null;

    Boolean negative = s.startsWith('-');
    if (negative)
      s = s.substring(1);

    String intPart = s;
    String fracPart = '';
    Integer dot = s.indexOf('.');
    if (dot >= 0) {
      intPart = s.substring(0, dot);
      // Trim trailing zeros so a scale-1 Decimal's ".0" disappears while real
      // fractional digits survive.
      fracPart = s.substring(dot + 1).replaceFirst('0+$', '');
    }

    // Insert a comma before every group of three digits that is followed only by
    // complete groups of three — standard right-to-left thousands grouping.
    String grouped = intPart.replaceAll('(\\d)(?=(\\d{3})+$)', '$1,');

    String out = (negative ? '-' : '') + grouped;
    if (fracPart != '')
      out += '.' + fracPart;
    return out;
  }

  /** Renders a list for display, capped so a large query result stays readable. */
  public static String formatList(List<Object> values) {
    if (values == null || values.isEmpty())
      return '(none)';
    List<String> parts = new List<String>();
    for (Integer i = 0; i < values.size() && i < LIST_PREVIEW_CAP; i++) {
      parts.add(formatValue(values[i]));
    }
    String joined = '[' + String.join(parts, ', ');
    if (values.size() > LIST_PREVIEW_CAP) {
      // Ellipsis sits inside the bracket without an extra comma gap.
      joined += ' … (' + values.size() + ' total)';
    }
    return joined + ']';
  }

  /** Expected-value description: operator phrase plus the comparison operand. */
  public static String describeExpected(String operator, Object comparison) {
    if (operator == 'IS_BLANK' || operator == 'IS_NOT_BLANK') {
      return operatorLabel(operator);
    }
    return operatorLabel(operator) + ' ' + formatValue(comparison);
  }

  /**
   * Describes an expected operand using the actual value's retained Apex type.
   * Fixed Custom Metadata operands arrive as strings; when the actual value is
   * numeric, parsing an otherwise numeric operand restores symmetric grouping.
   * String actual values remain untouched so postal codes and identifiers keep
   * their exact spelling and leading zeroes.
   */
  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual
  ) {
    Object displayComparison = comparison;
    if (
      isNumericValue(actual) &&
      comparison instanceof String &&
      NUMERIC_PATTERN.matcher(String.valueOf(comparison).trim()).matches()
    ) {
      displayComparison = Decimal.valueOf(String.valueOf(comparison).trim());
    }
    return describeExpected(operator, displayComparison);
  }

  private static Boolean isNumericValue(Object value) {
    return value instanceof Integer ||
      value instanceof Long ||
      value instanceof Decimal ||
      value instanceof Double;
  }

  /** Expected-value description for list operators (operand is a list). */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison
  ) {
    return operatorLabel(operator) + ' ' + formatList(comparison);
  }

  public static Boolean applyEmptyValueHandling(String nullBehavior) {
    if (nullBehavior == 'AS_NO_MATCH')
      return false;
    if (nullBehavior == 'SKIP_RECORD')
      return null;
    // blank EmptyValueHandling__c aligns with CMT field default (SkipRecordsWithMissingValue → Skip)
    return null;
  }
}
