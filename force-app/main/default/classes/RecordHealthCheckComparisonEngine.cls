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

    if (operator == 'EQUALS') {
      return valuesEqual(primary, comparison);
    }
    if (operator == 'NOT_EQUALS') {
      return !valuesEqual(primary, comparison);
    }
    if (operator == 'CONTAINS') {
      return pStr.contains(cStr);
    }
    if (operator == 'DOES_NOT_CONTAIN') {
      return !pStr.contains(cStr);
    }

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
    if (behavior == 'PASS') {
      return true;
    }
    if (behavior == 'FAIL') {
      return false;
    }
    if (behavior == 'SKIP') {
      return null;
    }
    if (behavior == 'UNABLE_TO_EVALUATE') {
      return null;
    }
    // No explicit config — treat as indeterminate (Skip is the CMT default)
    return null;
  }

  // ─── Single-query operators (NullBehavior-aware) ────────────────────────

  public static Boolean applyUnaryComparison(String operator, Object value) {
    Boolean isBlank = (value == null || String.valueOf(value).trim() == '');
    if (operator == 'IS_BLANK') {
      return isBlank;
    }
    if (operator == 'IS_NOT_BLANK') {
      return !isBlank;
    }
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
        if (match == null) {
          continue;
        }
        sawEvaluableRecord = true;
        if (match == true) {
          return true;
        }
      }
      if (!sawEvaluableRecord) {
        return null;
      }
      return false;
    }

    if (mode == 'ALL_ROWS_PASS') {
      Boolean sawEvaluableRecord = false;
      for (Object val : primaryList) {
        Boolean match = applyRecordComparison(rule, val, comparisonValue);
        if (match == null) {
          continue;
        }
        sawEvaluableRecord = true;
        if (match != true) {
          return false;
        }
      }
      if (!sawEvaluableRecord) {
        return null;
      }
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
      if (nb == 'SKIP_RECORD') {
        return null;
      }
      if (nb == 'AS_NO_MATCH') {
        return false;
      }
      if (nb == 'AS_BLANK') {
        primary = '';
      }
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
        if (item != null && String.valueOf(item).toLowerCase() == pLower) {
          return true;
        }
      }
      return false;
    }

    if (operator == 'LIST_CONTAINS_NONE') {
      // case-insensitive comparison
      String pLower = pStr.toLowerCase();
      for (Object item : comparisonList) {
        if (item != null && String.valueOf(item).toLowerCase() == pLower) {
          return false;
        }
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

  /**
   * Maps a operator API name to a sentence-friendly verb phrase. The phrases
   * are designed to read naturally after the word "expected" when the LWC wraps
   * the comparison as "Found {actualValue}, expected {expectedValue}" — e.g.
   * "expected to equal …", "expected at least 2", "expected to be one of […]".
   */
  public static String operatorLabel(String operator) {
    if (operator == 'EQUALS') {
      return System.Label.RHC_Operator_Equals;
    }
    if (operator == 'NOT_EQUALS') {
      return System.Label.RHC_Operator_NotEquals;
    }
    if (operator == 'CONTAINS') {
      return System.Label.RHC_Operator_Contains;
    }
    if (operator == 'DOES_NOT_CONTAIN') {
      return System.Label.RHC_Operator_DoesNotContain;
    }
    if (operator == 'GREATER_THAN') {
      return System.Label.RHC_Operator_GreaterThan;
    }
    if (operator == 'GREATER_THAN_OR_EQUAL') {
      return System.Label.RHC_Operator_GreaterThanOrEqual;
    }
    if (operator == 'LESS_THAN') {
      return System.Label.RHC_Operator_LessThan;
    }
    if (operator == 'LESS_THAN_OR_EQUAL') {
      return System.Label.RHC_Operator_LessThanOrEqual;
    }
    if (operator == 'IS_BLANK') {
      return System.Label.RHC_Operator_IsBlank;
    }
    if (operator == 'IS_NOT_BLANK') {
      return System.Label.RHC_Operator_IsNotBlank;
    }
    if (operator == 'LIST_CONTAINS_ANY') {
      return System.Label.RHC_Operator_ListContainsAny;
    }
    if (operator == 'LIST_CONTAINS_NONE') {
      return System.Label.RHC_Operator_ListContainsNone;
    }
    if (operator == 'LISTS_OVERLAP') {
      return System.Label.RHC_Operator_ListsOverlap;
    }
    if (operator == 'LISTS_CONTAIN_ALL') {
      return System.Label.RHC_Operator_ListsContainAll;
    }
    if (operator == 'LISTS_MATCH_EXACTLY') {
      return System.Label.RHC_Operator_ListsMatchExactly;
    }
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
   * This overload renders with Display: Value Format on "Auto". Callers that
   * have the Rule pass its DisplayValueFormat__c to the overload below.
   */
  public static String formatValue(Object value) {
    return formatValue(value, null);
  }

  /**
   * Renders a single value using the Rule's Display: Value Format.
   *
   * On "Auto" the value is humanized from its Apex type: numbers gain the
   * running user's grouping separators, Booleans read Yes/No, and dates and
   * date/times render in the user's locale and time zone. A named format
   * (Currency, Percent, Raw, …) overrides that and is applied instead. The
   * rendering rules live in RecordHealthCheckDisplayFormat.
   */
  public static String formatValue(Object value, String displayFormat) {
    return formatValue(value, displayFormat, null);
  }

  /**
   * Renders a single value using the Rule's Display: Value Format, showing a
   * Currency value in the currency named by `isoCode`. Leave `isoCode` blank to
   * use the running user's currency.
   */
  public static String formatValue(
    Object value,
    String displayFormat,
    String isoCode
  ) {
    return RecordHealthCheckDisplayFormat.render(value, displayFormat, isoCode);
  }

  /** Renders a list for display, capped so a large query result stays readable. */
  public static String formatList(List<Object> values) {
    return formatList(values, null);
  }

  public static String formatList(List<Object> values, String displayFormat) {
    return formatList(values, displayFormat, (String) null);
  }

  /**
   * Renders a list using the Rule's Display: Value Format, capped so a large
   * query result stays readable. Every entry uses the same format, so a list of
   * amounts reads consistently.
   */
  public static String formatList(
    List<Object> values,
    String displayFormat,
    String isoCode
  ) {
    return formatList(values, displayFormat, isoCode, null);
  }

  /**
   * Renders a list where each entry has its own currency, taken from the row it
   * came from — a list of amounts in euros and dollars is labelled entry by
   * entry rather than all in the first row's currency. `isoCodes` runs parallel
   * to `values`; an entry with no currency of its own falls back to `isoCode`.
   */
  public static String formatList(
    List<Object> values,
    String displayFormat,
    List<String> isoCodes
  ) {
    return formatList(values, displayFormat, null, isoCodes);
  }

  private static String formatList(
    List<Object> values,
    String displayFormat,
    String isoCode,
    List<String> isoCodes
  ) {
    if (values == null || values.isEmpty()) {
      return '(none)';
    }
    List<String> parts = new List<String>();
    for (
      Integer i = 0;
      i < values.size() &&
      i < RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP;
      i++
    ) {
      String entryIsoCode = isoCodes != null &&
        i < isoCodes.size()
        ? isoCodes[i]
        : null;
      parts.add(
        formatValue(
          values[i],
          displayFormat,
          String.isBlank(entryIsoCode) ? isoCode : entryIsoCode
        )
      );
    }
    String joined = '[' + String.join(parts, ', ');
    if (values.size() > RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP) {
      // Ellipsis sits inside the bracket without an extra comma gap.
      joined += ' … (' + values.size() + ' total)';
    }
    return joined + ']';
  }

  /** Expected-value description: operator phrase plus the comparison operand. */
  public static String describeExpected(String operator, Object comparison) {
    return describeExpected(operator, comparison, null);
  }

  public static String describeExpected(
    String operator,
    Object comparison,
    String displayFormat
  ) {
    return describeExpected(operator, comparison, displayFormat, null);
  }

  /** Expected-value description using the Rule's Display: Value Format. */
  public static String describeExpected(
    String operator,
    Object comparison,
    String displayFormat,
    String isoCode
  ) {
    if (operator == 'IS_BLANK' || operator == 'IS_NOT_BLANK') {
      return operatorLabel(operator);
    }
    return operatorLabel(operator) +
      ' ' +
      formatValue(comparison, displayFormat, isoCode);
  }

  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual
  ) {
    return describeExpectedForActual(operator, comparison, actual, null);
  }

  /**
   * Describes an expected operand so it reads in the same units as the Found
   * value. Fixed Custom Metadata operands arrive as strings; on "Auto", an
   * otherwise numeric operand is parsed back to a number when the actual value is
   * numeric, so Expected "100000" groups like Found "100,000". String actual
   * values are left untouched, keeping postal codes and identifiers exact. A
   * named format already renders both sides the same way and needs no alignment.
   */
  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual,
    String displayFormat
  ) {
    return describeExpectedForActual(
      operator,
      comparison,
      actual,
      displayFormat,
      null
    );
  }

  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual,
    String displayFormat,
    String isoCode
  ) {
    Object displayComparison = RecordHealthCheckDisplayFormat.alignExpectedToFound(
      comparison,
      actual,
      displayFormat
    );
    return describeExpected(
      operator,
      displayComparison,
      displayFormat,
      isoCode
    );
  }

  /** Expected-value description for list operators (operand is a list). */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison
  ) {
    return describeExpectedList(operator, comparison, null);
  }

  public static String describeExpectedList(
    String operator,
    List<Object> comparison,
    String displayFormat
  ) {
    return describeExpectedList(
      operator,
      comparison,
      displayFormat,
      (String) null
    );
  }

  /** Expected-value list description using the Rule's Display: Value Format. */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison,
    String displayFormat,
    String isoCode
  ) {
    return operatorLabel(operator) +
      ' ' +
      formatList(comparison, displayFormat, isoCode);
  }

  /**
   * Expected-value list description where each entry carries the currency of
   * the row it came from.
   */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison,
    String displayFormat,
    List<String> isoCodes
  ) {
    return operatorLabel(operator) +
      ' ' +
      formatList(comparison, displayFormat, isoCodes);
  }

  public static Boolean applyEmptyValueHandling(String nullBehavior) {
    if (nullBehavior == 'AS_NO_MATCH') {
      return false;
    }
    if (nullBehavior == 'SKIP_RECORD') {
      return null;
    }
    // blank EmptyValueHandling__c aligns with CMT field default (SkipRecordsWithMissingValue → Skip)
    return null;
  }
}
