/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckMetadataValidator {
  // ─── Validation issue DTO ─────────────────────────────────────────────────

  public class ValidationIssue {
    public String severity; // ERROR, WARNING
    public String componentName; // DeveloperName of the CMT record
    public String fieldName; // field involved, null for cross-record issues
    public String message;
    public String reasonCode;

    public ValidationIssue(
      String severity,
      String componentName,
      String fieldName,
      String message,
      String reasonCode
    ) {
      this.severity = severity;
      this.componentName = componentName;
      this.fieldName = fieldName;
      this.message = message;
      this.reasonCode = reasonCode;
    }
  }

  // Valid-value sets and caps are owned by RecordHealthCheckConstants so this
  // deploy-time validator and RecordHealthCheckConfigService (runtime) can never
  // drift. Local aliases keep the call sites below readable.
  // The per-type rule-validation decision tree lives in RecordHealthCheckRuleValidator;
  // this class keeps the baseline + Check Set + dependency-graph checks (inline) plus a
  // collect-all adapter (toIssue). The operator/source/null-empty value sets live with
  // those producers.
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.VALID_DISPLAY_MODES;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.VALID_TRIGGER_MODES;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.VALID_REVEAL_MODES;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.VALID_COMPARISON_DISPLAYS;
  private static final Set<String> VALID_APPLICABILITY_MODES = RecordHealthCheckConstants.VALID_APPLICABILITY_MODES;
  private static final Set<String> VALID_CHECK_TYPES = RecordHealthCheckConstants.VALID_CHECK_TYPES;
  private static final Set<String> VALID_SEVERITIES = RecordHealthCheckConstants.VALID_SEVERITIES;
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // ─── Public API ───────────────────────────────────────────────────────────

  /**
   * Validates all active Check Sets and Rules in the org.
   * Returns a list of ValidationIssues — empty list means everything is valid.
   */
  public List<ValidationIssue> validate() {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Validator intentionally reads framework Custom Metadata setup records.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT
        DeveloperName,
        MasterLabel,
        ObjectApiName__c,
        IsActive__c,
        CardRunMode__c,
        CardRevealMode__c,
        FoundExpectedDisplay__c,
        PassedChecksDisplay__c,
        SkippedChecksDisplay__c,
        CardTitle__c
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE
    ];

    // code-analyzer-suppress-next-line ApexCRUDViolation: Validator intentionally reads framework Custom Metadata setup records.
    List<Record_Health_Check_Rule__mdt> allRules = [
      SELECT
        DeveloperName,
        MasterLabel,
        CheckTitle__c,
        EvaluationOrder__c,
        IsActive__c,
        EvaluationType__c,
        FailureSeverity__c,
        PassConditionFormula__c,
        FindInListFormula__c,
        SourceQuery__c,
        SourceQueryField__c,
        ExpectedValueSource__c,
        ExpectedFixedValue__c,
        ExpectedRecordFormula__c,
        ComparisonQuery__c,
        ComparisonQueryField__c,
        ComparisonOperator__c,
        QueryResultHandling__c,
        NoRowsResult__c,
        EmptyValueHandling__c,
        DisplayFoundText__c,
        DisplayExpectedText__c,
        FailureMessage__c,
        UnableToEvaluateMessage__c,
        ActionLabel__c,
        ActionUrl__c,
        FixMessage__c,
        ApexClass__c,
        ApexParametersJson__c,
        MaxQueryRows__c,
        PrerequisiteRule__c,
        ApplicabilityMode__c,
        ApplicabilityFormula__c,
        ApplicabilityNotMetMessage__c,
        ApplicabilityCountQuery__c,
        ApplicabilityCountOperator__c,
        ApplicabilityCountThreshold__c,
        Record_Health_Check_Set__c
      FROM Record_Health_Check_Rule__mdt
      WHERE IsActive__c = TRUE
      ORDER BY
        Record_Health_Check_Set__c ASC,
        EvaluationOrder__c ASC NULLS LAST,
        DeveloperName ASC
    ];

    return validateRecords(checkSets, allRules);
  }

  /**
   * Machine-readable entry point for setup tooling and CI.
   *
   * Deliberately not `@AuraEnabled`: this serializes the full validation
   * of every Check Set and Rule — query, Apex class, and formula surfaces —
   * which is admin/setup information, not per-record data. Exposing it to the
   * LWC/Aura surface would hand that config detail to any user who can invoke
   * component Apex, with no permission gate. CI and setup tooling call this
   * public static method directly from Apex (test, anonymous, or Tooling API),
   * so no Aura exposure is needed.
   */
  public static String validateAsJson() {
    return JSON.serialize(new RecordHealthCheckMetadataValidator().validate());
  }

  @TestVisible
  private List<ValidationIssue> validateRecords(
    List<Record_Health_Check_Set__mdt> checkSets,
    List<Record_Health_Check_Rule__mdt> allRules
  ) {
    List<ValidationIssue> issues = new List<ValidationIssue>();

    // Validate each Check Set on its own; dependency validation scopes by
    // Check Set Id below.
    for (Record_Health_Check_Set__mdt cs : checkSets) {
      issues.addAll(validateCheckSet(cs));
    }

    // Group rules by Check Set for dependency validation
    Map<String, List<Record_Health_Check_Rule__mdt>> rulesByCheckSet = new Map<String, List<Record_Health_Check_Rule__mdt>>();
    Map<String, Record_Health_Check_Rule__mdt> rulesByDevName = new Map<String, Record_Health_Check_Rule__mdt>();

    for (Record_Health_Check_Rule__mdt rule : allRules) {
      String csName = String.valueOf(rule.Record_Health_Check_Set__c);
      if (!rulesByCheckSet.containsKey(csName)) {
        rulesByCheckSet.put(csName, new List<Record_Health_Check_Rule__mdt>());
      }
      rulesByCheckSet.get(csName).add(rule);
      rulesByDevName.put(rule.DeveloperName, rule);
      issues.addAll(validateRule(rule));
    }

    // Dependency graph validation per Check Set
    for (String csName : rulesByCheckSet.keySet()) {
      List<Record_Health_Check_Rule__mdt> setRules = rulesByCheckSet.get(
        csName
      );
      if (setRules.size() > RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS) {
        issues.add(
          new ValidationIssue(
            'WARNING',
            csName,
            null,
            'Only the first ' +
              RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS +
              ' active rules are included in a run; remaining rules are omitted.',
            'CHECK_LIMIT_EXCEEDED'
          )
        );
        Set<String> included = new Set<String>();
        for (
          Integer i = 0;
          i < RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
          i++
        ) {
          included.add(setRules[i].DeveloperName);
        }
        for (
          Integer i = 0;
          i < RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
          i++
        ) {
          Record_Health_Check_Rule__mdt includedRule = setRules[i];
          if (
            String.isNotBlank(includedRule.PrerequisiteRule__c) &&
            !included.contains(includedRule.PrerequisiteRule__c.trim())
          ) {
            issues.add(
              new ValidationIssue(
                'WARNING',
                includedRule.DeveloperName,
                'PrerequisiteRule__c',
                'The dependency is outside the first-' +
                  RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS +
                  ' execution window, so this rule will be skipped.',
                'DEPENDENCY_NOT_IN_RUN'
              )
            );
          }
        }
      }
      issues.addAll(validateDependencyGraph(csName, setRules, rulesByDevName));
    }

    return issues;
  }

  // ─── Check Set validation ─────────────────────────────────────────────────

  private List<ValidationIssue> validateCheckSet(
    Record_Health_Check_Set__mdt cs
  ) {
    List<ValidationIssue> issues = new List<ValidationIssue>();

    if (String.isBlank(cs.ObjectApiName__c)) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'ObjectApiName__c',
          'Base Object API Name is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (
      String.isNotBlank(cs.ObjectApiName__c) &&
      !RecordHealthCheckConfigValidator.isValidObjectApiName(
        cs.ObjectApiName__c
      )
    ) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'ObjectApiName__c',
          'Object API Name does not identify an object in this org.',
          'INVALID_CONFIG'
        )
      );
    }

    if (String.isBlank(cs.CardTitle__c)) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'CardTitle__c',
          'Card Title is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }

    if (!VALID_DISPLAY_MODES.contains(cs.PassedChecksDisplay__c)) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'PassedChecksDisplay__c',
          'Passed Checks Display "' +
            cs.PassedChecksDisplay__c +
            '" is not recognized.',
          'INVALID_CONFIG'
        )
      );
    }

    if (!VALID_DISPLAY_MODES.contains(cs.SkippedChecksDisplay__c)) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'SkippedChecksDisplay__c',
          'Skipped Checks Display "' +
            cs.SkippedChecksDisplay__c +
            '" is not recognized.',
          'INVALID_CONFIG'
        )
      );
    }

    // Parity with RecordHealthCheckConfigService runtime validation so a Check
    // Set that deploys clean cannot still fail at definition-load time.
    if (!VALID_TRIGGER_MODES.contains(cs.CardRunMode__c)) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'CardRunMode__c',
          'When Checks Run "' +
            cs.CardRunMode__c +
            '" is not recognized. Valid values: RUN_ON_LOAD, RUN_ON_REQUEST.',
          'INVALID_CONFIG'
        )
      );
    }

    if (!VALID_REVEAL_MODES.contains(cs.CardRevealMode__c)) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'CardRevealMode__c',
          'Reveal Mode "' +
            cs.CardRevealMode__c +
            '" is not recognized. Valid values: ALL_AT_ONCE, ONE_BY_ONE.',
          'INVALID_CONFIG'
        )
      );
    }

    if (
      String.isNotBlank(cs.FoundExpectedDisplay__c) &&
      !VALID_COMPARISON_DISPLAYS.contains(cs.FoundExpectedDisplay__c)
    ) {
      issues.add(
        new ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'FoundExpectedDisplay__c',
          'Found/Expected Display "' +
            cs.FoundExpectedDisplay__c +
            '" is not recognized. Valid values: ON_DEMAND, FAILURES_ONLY, ALL_ROWS.',
          'INVALID_CONFIG'
        )
      );
    }

    return issues;
  }

  // ─── Rule validation ──────────────────────────────────────────────────────

  private List<ValidationIssue> validateRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<ValidationIssue> issues = new List<ValidationIssue>();
    RecordHealthCheckTokenIssue tokenIssue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      rule
    );
    if (tokenIssue != null) {
      issues.add(err(rule, null, tokenIssue.message, tokenIssue.reasonCode));
    }

    if (String.isBlank(rule.CheckTitle__c)) {
      issues.add(
        err(
          rule,
          'CheckTitle__c',
          'Check Title is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (rule.EvaluationOrder__c == null) {
      issues.add(
        err(
          rule,
          'EvaluationOrder__c',
          'Evaluation Order is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (
      String.isBlank(rule.FailureSeverity__c) ||
      !VALID_SEVERITIES.contains(rule.FailureSeverity__c)
    ) {
      issues.add(
        err(
          rule,
          'FailureSeverity__c',
          'Severity must be CRITICAL, WARNING, or INFO.',
          'INVALID_CONFIG'
        )
      );
    }
    if (String.isBlank(rule.FailureMessage__c)) {
      issues.add(
        err(
          rule,
          'FailureMessage__c',
          'Message When Check Fails is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (String.isBlank(rule.EvaluationType__c)) {
      issues.add(
        err(
          rule,
          'EvaluationType__c',
          'Evaluation Type is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
      return issues; // can't validate further without Check Type
    }

    if (!VALID_CHECK_TYPES.contains(rule.EvaluationType__c)) {
      issues.add(
        err(
          rule,
          'EvaluationType__c',
          'Evaluation Type "' + rule.EvaluationType__c + '" is not recognized.',
          'INVALID_CHECK_TYPE'
        )
      );
      return issues;
    }

    // ApplicabilityMode validation (null / blank == Always, which is valid)
    if (
      String.isNotBlank(rule.ApplicabilityMode__c) &&
      !VALID_APPLICABILITY_MODES.contains(rule.ApplicabilityMode__c)
    ) {
      issues.add(
        err(
          rule,
          'ApplicabilityMode__c',
          'ApplicabilityMode "' +
            rule.ApplicabilityMode__c +
            '" is not recognized. Valid values: Always, Formula, SOQL.',
          'INVALID_CONFIG'
        )
      );
    }

    // Applicability sub-field validation — parity with the runtime ConfigService
    // so a misconfigured gate is caught at deploy time, not first evaluation.
    issues.addAll(validateApplicability(rule));

    if (rule.EvaluationType__c == 'FORMULA') {
      issues.addAll(validateFormulaRule(rule));
    } else if (rule.EvaluationType__c == 'QUERY') {
      issues.addAll(validateQueryRule(rule));
    } else if (rule.EvaluationType__c == 'APEX') {
      issues.addAll(validateApexRule(rule));
    } else if (rule.EvaluationType__c == 'COMPARE_TWO_QUERIES') {
      issues.addAll(validateCompareQueriesRule(rule));
    }

    // MaxRows, empty-value handling, and empty-result behavior are validated for all
    // check types at top level. Shared producers emit the findings; toIssue maps
    // each to this class's reason code / field.
    addIssues(
      issues,
      RecordHealthCheckRuleValidator.maxRowsFindings(rule),
      rule
    );
    addIssues(
      issues,
      RecordHealthCheckRuleValidator.nullEmptyFindings(rule),
      rule
    );

    return issues;
  }

  /** Maps each shared Finding to a ValidationIssue and appends it to `issues`. */
  private void addIssues(
    List<ValidationIssue> issues,
    List<RecordHealthCheckRuleValidator.Finding> findings,
    Record_Health_Check_Rule__mdt rule
  ) {
    for (RecordHealthCheckRuleValidator.Finding finding : findings) {
      issues.add(toIssue(finding, rule));
    }
  }

  // ─── Per-type validation — collect-all adapter over RecordHealthCheckRuleValidator ───
  // The per-type decision tree lives in RecordHealthCheckRuleValidator; these wrappers collect
  // every finding and map each via toIssue. Issue order within a rule follows the shared
  // (ConfigService) ordering.

  private List<ValidationIssue> validateApplicability(
    Record_Health_Check_Rule__mdt rule
  ) {
    return toIssues(
      RecordHealthCheckRuleValidator.applicabilityFindings(rule),
      rule
    );
  }

  private List<ValidationIssue> validateFormulaRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    return toIssues(RecordHealthCheckRuleValidator.formulaFindings(rule), rule);
  }

  private List<ValidationIssue> validateQueryRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    return toIssues(RecordHealthCheckRuleValidator.queryFindings(rule), rule);
  }

  private List<ValidationIssue> validateApexRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    return toIssues(RecordHealthCheckRuleValidator.apexFindings(rule), rule);
  }

  private List<ValidationIssue> validateCompareQueriesRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    return toIssues(
      RecordHealthCheckRuleValidator.compareQueriesFindings(rule),
      rule
    );
  }

  private List<ValidationIssue> toIssues(
    List<RecordHealthCheckRuleValidator.Finding> findings,
    Record_Health_Check_Rule__mdt rule
  ) {
    List<ValidationIssue> issues = new List<ValidationIssue>();
    addIssues(issues, findings, rule);
    return issues;
  }

  /**
   * Maps a shared Finding to this deploy-time path's ERROR ValidationIssue (field name, message
   * reason code). This switch is the ONLY place MetadataValidator's output vocabulary lives — the
   * decision tree that produced the finding is shared. Field names / messages / reason codes here
   * are byte-for-byte the originals so packaged metadata still validates clean and the
   * reason-code-membership tests still pass.
   */
  private ValidationIssue toIssue(
    RecordHealthCheckRuleValidator.Finding finding,
    Record_Health_Check_Rule__mdt rule
  ) {
    String val = finding.offendingValue;
    switch on finding.code {
      // ── Applicability gate ──
      when APPLICABILITY_FORMULA_MISSING {
        return err(
          rule,
          'ApplicabilityFormula__c',
          'Applicability Formula is required when Applicability Mode is Formula.',
          'INVALID_FORMULA'
        );
      }
      when APPLICABILITY_SOQL_MISSING {
        return err(
          rule,
          'ApplicabilityCountQuery__c',
          'Applicability SOQL is required when Applicability Mode is SOQL.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when APPLICABILITY_SOQL_NOT_SINGLE_VALUE {
        return err(
          rule,
          'ApplicabilityCountQuery__c',
          'Applicability SOQL must be a single COUNT() or COUNT(Id) query without GROUP BY.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when APPLICABILITY_OPERATOR_MISSING {
        return err(
          rule,
          'ApplicabilityCountOperator__c',
          'Applicability comparison operator is required when Applicability Mode is SOQL.',
          'INVALID_OPERATOR'
        );
      }
      when APPLICABILITY_OPERATOR_INVALID {
        return err(
          rule,
          'ApplicabilityCountOperator__c',
          'Applicability comparison operator "' +
            val +
            '" is not recognized. Valid values: Equals, NotEquals, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual.',
          'INVALID_OPERATOR'
        );
      }
      when APPLICABILITY_THRESHOLD_MISSING {
        return err(
          rule,
          'ApplicabilityCountThreshold__c',
          'Applicability Comparison Value is required when Applicability Mode is SOQL.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      // ── Formula ──
      when FORMULA_MISSING {
        return err(
          rule,
          'PassConditionFormula__c',
          'Formula is required for Formula checks.',
          'INVALID_FORMULA'
        );
      }
      // ── Query (single) ──
      when LIST_VALUE_TO_TEST_MISSING {
        return err(
          rule,
          'FindInListFormula__c',
          'Value To Test is required as the primary value source for List contains any/List contains none.',
          'INVALID_FORMULA'
        );
      }
      when LIST_COMPARE_QUERY_MISSING {
        return err(
          rule,
          'ComparisonQuery__c',
          'Comparison Query is required as the list source for List contains any/List contains none.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when LIST_COMPARE_FIELD_MISSING {
        return err(
          rule,
          'ComparisonQueryField__c',
          'Comparison Query Field is required for list comparison queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when PRIMARY_QUERY_MISSING {
        return err(
          rule,
          'SourceQuery__c',
          'Source Query is required for Query checks (except List contains any/List contains none).',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when PRIMARY_QUERY_FIELD_MISSING {
        return err(
          rule,
          'SourceQueryField__c',
          'Source Query Field is required for non-aggregate queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_OPERATOR_ON_SINGLE {
        return err(
          rule,
          'ComparisonOperator__c',
          'Operator "' +
            val +
            '" requires Evaluation Type Compare two queries.',
          'INVALID_OPERATOR'
        );
      }
      when OPERATOR_INVALID {
        return err(
          rule,
          'ComparisonOperator__c',
          'Comparison operator "' + val + '" is not recognized.',
          'INVALID_OPERATOR'
        );
      }
      when OPERATOR_MISSING {
        return err(
          rule,
          'ComparisonOperator__c',
          'Comparison operator is required for Query checks.',
          'INVALID_OPERATOR'
        );
      }
      when MULTI_ROWS_MISSING {
        return err(
          rule,
          'QueryResultHandling__c',
          'How To Interpret Query Results is required for Query checks.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when MULTI_ROWS_INVALID {
        return err(
          rule,
          'QueryResultHandling__c',
          'How To Interpret Query Results "' + val + '" is not recognized.',
          'INVALID_CONFIG'
        );
      }
      when COMPARE_AS_LISTS_ON_SINGLE {
        return err(
          rule,
          'QueryResultHandling__c',
          'Compare query results as lists requires Evaluation Type Compare two queries, not Check records with a query.',
          'INVALID_OPERATOR'
        );
      }
      when COMPARE_AGAINST_MISSING {
        return err(
          rule,
          'ExpectedValueSource__c',
          'Expected Value Comes From is required for Query checks except IsBlank/IsNotBlank.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when COMPARE_AGAINST_INVALID {
        return err(
          rule,
          'ExpectedValueSource__c',
          'Expected Value Comes From "' + val + '" is not recognized.',
          'INVALID_CONFIG'
        );
      }
      when FIXED_VALUE_MISSING {
        return err(
          rule,
          'ExpectedFixedValue__c',
          'Expected Value is required when Expected Value Comes From is A fixed value.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when RECORD_FORMULA_MISSING {
        return err(
          rule,
          'ExpectedRecordFormula__c',
          'Expected Formula (on this record) is required when Expected Value Comes From is A formula on this record.',
          'INVALID_FORMULA'
        );
      }
      when ANOTHER_QUERY_MISSING {
        return err(
          rule,
          'ComparisonQuery__c',
          'Comparison Query is required when Expected Value Comes From is Comparison query.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when ANOTHER_QUERY_FIELD_MISSING {
        return err(
          rule,
          'ComparisonQueryField__c',
          'Comparison Query Field is required for non-aggregate queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      // ── Compare two queries ──
      when DUAL_PRIMARY_QUERY_MISSING {
        return err(
          rule,
          'SourceQuery__c',
          'Source Query is required for Compare two queries checks.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when DUAL_COMPARE_QUERY_MISSING {
        return err(
          rule,
          'ComparisonQuery__c',
          'Comparison Query is required for Compare two queries checks.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when DUAL_PRIMARY_FIELD_MISSING {
        return err(
          rule,
          'SourceQueryField__c',
          'Source Query Field is required for non-aggregate source queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_COMPARE_FIELD_MISSING {
        return err(
          rule,
          'ComparisonQueryField__c',
          'Comparison Query Field is required for non-aggregate comparison queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_OPERATOR_MISSING {
        return err(
          rule,
          'ComparisonOperator__c',
          'Comparison operator is required for Compare two queries checks.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_OPERATOR_INVALID {
        return err(
          rule,
          'ComparisonOperator__c',
          'Comparison operator "' + val + '" is not recognized.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_MULTI_ROWS_MISSING {
        return err(
          rule,
          'QueryResultHandling__c',
          'How To Interpret Query Results is required for Compare two queries checks.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_MULTI_ROWS_INVALID {
        return err(
          rule,
          'QueryResultHandling__c',
          'Compare two queries requires How To Interpret Query Results to be Expect one row or aggregate result, or Compare query results as lists.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_LIST_MODE_NEEDS_LIST_OPERATOR {
        return err(
          rule,
          'ComparisonOperator__c',
          'Compare query results as lists mode requires a list operator: Lists overlap, List contains all, or Exact list match.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_ONE_RESULT_NO_LIST_OPERATOR {
        return err(
          rule,
          'ComparisonOperator__c',
          'List operators (Lists overlap, List contains all, Exact list match) require Compare query results as lists mode.',
          'INVALID_OPERATOR'
        );
      }
      // ── Apex ──
      when APEX_CLASS_MISSING {
        return err(
          rule,
          'ApexClass__c',
          'Apex Class Name is required for Apex checks.',
          'APEX_CLASS_NOT_FOUND'
        );
      }
      when APEX_CLASS_INVALID {
        return err(
          rule,
          'ApexClass__c',
          'Apex Class Name must identify an instantiable class implementing RecordHealthCheckRule.',
          'APEX_CLASS_NOT_FOUND'
        );
      }
      when APEX_PARAMS_INVALID {
        return err(
          rule,
          'ApexParametersJson__c',
          'Apex Parameters must contain a valid JSON object.',
          'INVALID_APEX_PARAMETERS'
        );
      }
      // ── Cross-type ──
      when MAX_ROWS_INVALID {
        return err(
          rule,
          'MaxQueryRows__c',
          'Max Rows Override must be a whole number between 1 and ' +
            FRAMEWORK_MAX_ROWS +
            '.',
          'INVALID_CONFIG'
        );
      }
      when EMPTY_VALUE_HANDLING_INVALID {
        return err(
          rule,
          'EmptyValueHandling__c',
          'If Field Value Is Empty "' +
            val +
            '" is not recognized. Valid values: Ignore the record, Treat as blank, Treat as not matching.',
          'INVALID_CONFIG'
        );
      }
      when NO_ROWS_RESULT_INVALID {
        return err(
          rule,
          'NoRowsResult__c',
          'Empty Result Behavior "' +
            val +
            '" is not recognized. Valid values: Pass, Fail, Skip, UnableToEvaluate.',
          'INVALID_CONFIG'
        );
      }
      when else {
        // Every FindingCode is mapped above; this is defensive only.
        return err(
          rule,
          null,
          'This check could not be validated.',
          'INVALID_CONFIG'
        );
      }
    }
  }

  // ─── Dependency graph validation ──────────────────────────────────────────

  private List<ValidationIssue> validateDependencyGraph(
    String checkSetName,
    List<Record_Health_Check_Rule__mdt> rules,
    Map<String, Record_Health_Check_Rule__mdt> rulesByDevName
  ) {
    List<ValidationIssue> issues = new List<ValidationIssue>();
    Map<String, String> dependsOnMap = new Map<String, String>(); // devName → dependsOnDevName

    for (Record_Health_Check_Rule__mdt rule : rules) {
      if (String.isBlank(rule.PrerequisiteRule__c)) {
        continue;
      }

      String depDevName = rule.PrerequisiteRule__c.trim();
      Record_Health_Check_Rule__mdt dep = rulesByDevName.get(depDevName);

      if (dep == null) {
        issues.add(
          err(
            rule,
            'PrerequisiteRule__c',
            'Prerequisite Rule must reference an existing rule DeveloperName. ' +
              '"' +
              depDevName +
              '" was not found.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }

      // Must be in same Check Set. Use the relationship field value directly;
      // parent relationship traversal is not supported for all custom metadata operations.
      if (dep.Record_Health_Check_Set__c != rule.Record_Health_Check_Set__c) {
        issues.add(
          err(
            rule,
            'PrerequisiteRule__c',
            'Prerequisite Rule must reference a rule in the same Check Set. ' +
              '"' +
              depDevName +
              '" belongs to a different Check Set.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }

      // Must have strictly lower Priority
      if (
        dep != null &&
        dep.EvaluationOrder__c != null &&
        rule.EvaluationOrder__c != null &&
        dep.EvaluationOrder__c >= rule.EvaluationOrder__c
      ) {
        issues.add(
          err(
            rule,
            'PrerequisiteRule__c',
            'Prerequisite Rule must reference a rule with a strictly lower Evaluation Order. ' +
              '"' +
              depDevName +
              '" has Evaluation Order ' +
              dep.EvaluationOrder__c +
              ' which is not lower than this rule\'s Evaluation Order ' +
              rule.EvaluationOrder__c +
              '.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }

      dependsOnMap.put(rule.DeveloperName, depDevName);
    }

    // Cycle detection using DFS
    Set<String> visited = new Set<String>();
    Set<String> inStack = new Set<String>();

    for (String devName : dependsOnMap.keySet()) {
      if (!visited.contains(devName)) {
        List<String> cycle = detectCycle(
          devName,
          dependsOnMap,
          visited,
          inStack
        );
        if (!cycle.isEmpty()) {
          // cycle is the closed walk (e.g. [A, B, C, A]); the repeated start
          // node makes cycleStr read as a full loop ("A → B → C → A"). Dedupe
          // the members when emitting issues so each rule in the cycle gets
          // exactly one issue row rather than the start node getting two.
          // For display, drop the repeated closing node: "A → B → C" not "A → B → C → A".
          List<String> cycleForDisplay = new List<String>(cycle);
          if (
            cycleForDisplay.size() > 1 &&
            cycleForDisplay[0] == cycleForDisplay[cycleForDisplay.size() - 1]
          ) {
            cycleForDisplay.remove(cycleForDisplay.size() - 1);
          }
          String cycleStr = String.join(cycleForDisplay, ' → ');
          Set<String> reportedMembers = new Set<String>();
          for (String cycleMember : cycle) {
            if (!reportedMembers.add(cycleMember)) {
              continue;
            }
            Record_Health_Check_Rule__mdt r = rulesByDevName.get(cycleMember);
            if (r != null) {
              issues.add(
                err(
                  r,
                  'PrerequisiteRule__c',
                  'Dependency cycle detected: ' + cycleStr,
                  'INVALID_DEPENDENCY'
                )
              );
            }
          }
          break; // report once per set
        }
      }
    }

    return issues;
  }

  private List<String> detectCycle(
    String node,
    Map<String, String> dependsOnMap,
    Set<String> visited,
    Set<String> inStack
  ) {
    visited.add(node);
    inStack.add(node);

    String next = dependsOnMap.get(node);
    if (next != null) {
      if (!visited.contains(next)) {
        List<String> cycle = detectCycle(next, dependsOnMap, visited, inStack);
        if (!cycle.isEmpty()) {
          cycle.add(0, node);
          return cycle;
        }
      } else if (inStack.contains(next)) {
        return new List<String>{ node, next };
      }
    }

    inStack.remove(node);
    return new List<String>();
  }

  // ─── Convenience builder ──────────────────────────────────────────────────

  private ValidationIssue err(
    Record_Health_Check_Rule__mdt rule,
    String fieldName,
    String message,
    String reasonCode
  ) {
    return new ValidationIssue(
      'ERROR',
      rule.DeveloperName,
      fieldName,
      message,
      reasonCode
    );
  }
}
