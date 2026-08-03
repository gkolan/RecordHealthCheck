/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckMetadataValidator {
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.validDisplayModes;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.validTriggerModes;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.validRevealModes;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.validComparisonDisplays;
  private static final Set<String> VALID_APPLICABILITY_MODES = RecordHealthCheckConstants.validApplicabilityModes;
  private static final Set<String> VALID_CHECK_TYPES = RecordHealthCheckConstants.validCheckTypes;
  private static final Set<String> VALID_SEVERITIES = RecordHealthCheckConstants.validSeverities;
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // ─── Validation issue data holder ─────────────────────────────────────────

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
  // get out of sync. Local aliases keep the call sites below readable.
  // The per-type rule-validation decision tree lives in RecordHealthCheckRuleValidator;
  // this class keeps the baseline + Check Set + dependency-graph checks (inline) plus a
  // collect-all adapter (toIssue). The operator/source/null-empty value sets live with
  // those producers.
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
      issues.addAll(
        RHCMetadataDependencyValidator.validate(
          csName,
          setRules,
          rulesByDevName
        )
      );
    }

    return issues;
  }

  // ─── Check Set validation ─────────────────────────────────────────────────

  private List<ValidationIssue> validateCheckSet(
    Record_Health_Check_Set__mdt checkSet
  ) {
    return RecordHealthCheckMetadataSetValidator.validate(checkSet);
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
            '" is not recognized. Valid values: ALL_RECORDS, WHEN_FORMULA_TRUE, WHEN_COUNT_QUERY_MATCHES.',
          'INVALID_CONFIG'
        )
      );
    }

    // Applicability sub-field validation — parity with the runtime ConfigService
    // so a misconfigured gate is caught at deploy time, not first evaluation.
    issues.addAll(
      RecordHealthCheckMetadataIssueMapper.toIssues(
        RecordHealthCheckRuleValidator.applicabilityFindings(rule),
        rule
      )
    );

    if (rule.EvaluationType__c == 'FORMULA') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckRuleValidator.formulaFindings(rule),
          rule
        )
      );
    } else if (rule.EvaluationType__c == 'QUERY') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckRuleValidator.queryFindings(rule),
          rule
        )
      );
    } else if (rule.EvaluationType__c == 'APEX') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckRuleValidator.apexFindings(rule),
          rule
        )
      );
    } else if (rule.EvaluationType__c == 'COMPARE_TWO_QUERIES') {
      issues.addAll(
        RecordHealthCheckMetadataIssueMapper.toIssues(
          RecordHealthCheckRuleValidator.compareQueriesFindings(rule),
          rule
        )
      );
    }

    // MaxRows, empty-value handling, and empty-result behavior are validated for all
    // check types at top level. Shared producers report the findings; toIssue maps
    // each to this class's reason code / field.
    RecordHealthCheckMetadataIssueMapper.addIssues(
      issues,
      RecordHealthCheckRuleValidator.maxRowsFindings(rule),
      rule
    );
    RecordHealthCheckMetadataIssueMapper.addIssues(
      issues,
      RecordHealthCheckRuleValidator.nullEmptyFindings(rule),
      rule
    );

    return issues;
  }

  // ─── Dependency graph validation is delegated to RHCMetadataDependencyValidator. ───

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
