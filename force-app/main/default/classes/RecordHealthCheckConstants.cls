/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Single source of truth for the framework's valid-value sets and numeric caps.
 * These were previously duplicated, verbatim, in both RecordHealthCheckConfigService
 * (runtime validation) and RecordHealthCheckMetadataValidator (deploy-time audit).
 * Duplication meant adding a new operator, behavior, or mode required editing
 * several files in lockstep — and missing one let the two validators silently
 * disagree. Centralizing them here removes that drift risk and makes the framework
 * easier to extend: add a value once and every validator sees it.
 * Public Set properties return defensive copies. Callers may safely mutate the
 * returned Set without changing the framework's canonical values for the
 * transaction.
 * Operator/behavior *logic* (the if-chains in the engine and evaluators)
 * intentionally lives with the code that applies it; only the enumerations of
 * legal values live here.
 */
public with sharing class RecordHealthCheckConstants {
  // ─── Numeric caps ──────────────────────────────────────────────────────────

  /** Maximum active checks the LWC will run for one Check Set. */
  public static final Integer FRAMEWORK_MAX_CHECKS = 25;

  /** Maximum rows any single check query may return before it is rejected. */
  public static final Integer FRAMEWORK_MAX_ROWS = 2000;

  // ─── Check Set level ───────────────────────────────────────────────────────

  private static final Set<String> VALID_DISPLAY_MODES_INTERNAL = new Set<String>{
    'SHOW_EACH_CHECK',
    'SHOW_COUNT_ONLY'
  };
  public static Set<String> VALID_DISPLAY_MODES {
    get {
      return new Set<String>(VALID_DISPLAY_MODES_INTERNAL);
    }
  }
  private static final Set<String> VALID_TRIGGER_MODES_INTERNAL = new Set<String>{
    'RUN_ON_LOAD',
    'RUN_ON_REQUEST'
  };
  public static Set<String> VALID_TRIGGER_MODES {
    get {
      return new Set<String>(VALID_TRIGGER_MODES_INTERNAL);
    }
  }
  private static final Set<String> VALID_REVEAL_MODES_INTERNAL = new Set<String>{
    'ALL_AT_ONCE',
    'ONE_BY_ONE'
  };
  public static Set<String> VALID_REVEAL_MODES {
    get {
      return new Set<String>(VALID_REVEAL_MODES_INTERNAL);
    }
  }
  private static final Set<String> VALID_COMPARISON_DISPLAYS_INTERNAL = new Set<String>{
    'ON_DEMAND',
    'FAILURES_ONLY',
    'ALL_ROWS'
  };
  public static Set<String> VALID_COMPARISON_DISPLAYS {
    get {
      return new Set<String>(VALID_COMPARISON_DISPLAYS_INTERNAL);
    }
  }

  // ─── Rule level ────────────────────────────────────────────────────────────

  private static final Set<String> VALID_CHECK_TYPES_INTERNAL = new Set<String>{
    'FORMULA',
    'QUERY',
    'APEX',
    'COMPARE_TWO_QUERIES'
  };
  public static Set<String> VALID_CHECK_TYPES {
    get {
      return new Set<String>(VALID_CHECK_TYPES_INTERNAL);
    }
  }

  private static final Set<String> VALID_COMPARATORS_INTERNAL = new Set<String>{
    'EQUALS',
    'NOT_EQUALS',
    'GREATER_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN',
    'LESS_THAN_OR_EQUAL',
    'CONTAINS',
    'DOES_NOT_CONTAIN',
    'IS_BLANK',
    'IS_NOT_BLANK',
    'LIST_CONTAINS_ANY',
    'LIST_CONTAINS_NONE',
    'LISTS_OVERLAP',
    'LISTS_CONTAIN_ALL',
    'LISTS_MATCH_EXACTLY'
  };
  public static Set<String> VALID_COMPARATORS {
    get {
      return new Set<String>(VALID_COMPARATORS_INTERNAL);
    }
  }

  /** Comparators valid only on CheckType CompareTwoQueries (list-vs-list). */
  private static final Set<String> DUAL_QUERY_COMPARATORS_INTERNAL = new Set<String>{
    'LISTS_OVERLAP',
    'LISTS_CONTAIN_ALL',
    'LISTS_MATCH_EXACTLY'
  };
  public static Set<String> DUAL_QUERY_COMPARATORS {
    get {
      return new Set<String>(DUAL_QUERY_COMPARATORS_INTERNAL);
    }
  }

  private static final Set<String> VALID_NULL_BEHAVIORS_INTERNAL = new Set<String>{
    'AS_NO_MATCH',
    'SKIP_RECORD',
    'AS_BLANK'
  };
  public static Set<String> VALID_NULL_BEHAVIORS {
    get {
      return new Set<String>(VALID_NULL_BEHAVIORS_INTERNAL);
    }
  }

  private static final Set<String> VALID_EMPTY_BEHAVIORS_INTERNAL = new Set<String>{
    'PASS',
    'FAIL',
    'SKIP',
    'UNABLE_TO_EVALUATE'
  };
  public static Set<String> VALID_EMPTY_BEHAVIORS {
    get {
      return new Set<String>(VALID_EMPTY_BEHAVIORS_INTERNAL);
    }
  }

  public static Set<String> VALID_SEVERITIES {
    get {
      return new Set<String>{ 'CRITICAL', 'WARNING', 'INFO' };
    }
  }
  public static Set<String> VALID_COMPARISON_VALUE_SOURCES {
    get {
      return new Set<String>{
        'FIXED_VALUE',
        'RECORD_FORMULA',
        'COMPARISON_QUERY'
      };
    }
  }
  public static Set<String> VALID_MULTIPLE_RECORDS_HANDLING {
    get {
      return new Set<String>{
        'ONE_RESULT',
        'ANY_ROW_PASSES',
        'ALL_ROWS_PASS',
        'COMPARE_AS_LISTS'
      };
    }
  }

  // ─── Applicability gate ────────────────────────────────────────────────────

  private static final Set<String> VALID_APPLICABILITY_MODES_INTERNAL = new Set<String>{
    'ALL_RECORDS',
    'WHEN_FORMULA_TRUE',
    'WHEN_COUNT_QUERY_MATCHES'
  };
  public static Set<String> VALID_APPLICABILITY_MODES {
    get {
      return new Set<String>(VALID_APPLICABILITY_MODES_INTERNAL);
    }
  }

  /**
   * Comparators legal on ApplicabilityCountOperator__c (SOQL applicability mode).
   * The applicability gate counts rows and compares the count to an integer
   * threshold, so only the ordered/equality comparators apply — not the text or
   * list operators in VALID_COMPARATORS. Mirrors
   * RecordHealthCheckEngine.applyApplicabilityComparison.
   */
  private static final Set<String> VALID_APPLICABILITY_COMPARATORS_INTERNAL = new Set<String>{
    'EQUALS',
    'NOT_EQUALS',
    'GREATER_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN',
    'LESS_THAN_OR_EQUAL'
  };
  public static Set<String> VALID_APPLICABILITY_COMPARATORS {
    get {
      return new Set<String>(VALID_APPLICABILITY_COMPARATORS_INTERNAL);
    }
  }

  // ─── LWC wire contract (v2 CMDT → legacy DTO strings) ──────────────────────
  // Check Set picklists store v2 API values; the LWC still compares against the
  // original Automatic/Manual, Show/Hide, etc. strings. Map at the Apex boundary.

  public static String toLwcTriggerMode(String cardRunMode) {
    return cardRunMode == 'RUN_ON_LOAD' ? 'Automatic' : 'Manual';
  }

  public static String toLwcRevealMode(String cardRevealMode) {
    return cardRevealMode == 'ONE_BY_ONE' ? 'OneAtATime' : 'AllAtOnce';
  }

  public static String toLwcDisplayMode(String displayMode) {
    return displayMode == 'SHOW_COUNT_ONLY' ? 'Hide' : 'Show';
  }

  public static String toLwcComparisonDisplay(String foundExpectedDisplay) {
    if (foundExpectedDisplay == 'FAILURES_ONLY') {
      return 'FailuresOnly';
    }
    if (foundExpectedDisplay == 'ALL_ROWS') {
      return 'AllRows';
    }
    return 'OnDemand';
  }

  public static String toLwcSeverity(String failureSeverity) {
    if (failureSeverity == 'WARNING') {
      return 'Warning';
    }
    if (failureSeverity == 'INFO') {
      return 'Info';
    }
    if (failureSeverity == 'CRITICAL') {
      return 'Error';
    }
    return failureSeverity;
  }

  public static String toLwcEvaluatorType(String evaluationType) {
    if (evaluationType == 'FORMULA') {
      return 'Formula';
    }
    if (evaluationType == 'QUERY') {
      return 'Query';
    }
    if (evaluationType == 'APEX') {
      return 'Apex';
    }
    if (evaluationType == 'COMPARE_TWO_QUERIES') {
      return 'CompareTwoQueries';
    }
    return evaluationType;
  }
}
