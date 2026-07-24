/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckConfigService {
  // ─── Reason codes ──────────────────────────────────────────

  public static final String RC_CONFIG_NOT_FOUND = 'CONFIG_NOT_FOUND';
  public static final String RC_CONFIG_INACTIVE = 'CONFIG_INACTIVE';
  public static final String RC_OBJECT_MISMATCH = 'OBJECT_MISMATCH';
  public static final String RC_NO_RECORD_CONTEXT = 'NO_RECORD_CONTEXT';
  public static final String RC_NO_ACTIVE_CHECKS = 'NO_ACTIVE_CHECKS';
  public static final String RC_NO_ACTIVE_CHECK_SETS = 'NO_ACTIVE_CHECK_SETS';
  public static final String RC_INACTIVE_CHECK_SETS_ONLY = 'INACTIVE_CHECK_SETS_ONLY';
  public static final String RC_RULE_NOT_FOUND = 'RULE_NOT_FOUND';
  public static final String RC_RULE_INACTIVE = 'RULE_INACTIVE';
  public static final String RC_UNABLE_TO_EVALUATE = 'UNABLE_TO_EVALUATE';
  public static final String RC_INVALID_CONFIG = 'INVALID_CONFIG';

  // Valid-value sets and caps are owned by RecordHealthCheckConstants so this
  // runtime validator and RecordHealthCheckMetadataValidator (deploy-time) can
  // never drift. Local aliases keep the call sites below readable.
  // The per-type rule-validation decision tree lives in RecordHealthCheckRuleValidator;
  // this class keeps only the baseline checks below (inline) plus a first-fail adapter
  // (toResult). The operator/source/null-empty value sets live with those producers.
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.VALID_DISPLAY_MODES;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.VALID_TRIGGER_MODES;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.VALID_REVEAL_MODES;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.VALID_COMPARISON_DISPLAYS;
  private static final Set<String> VALID_APPLICABILITY_MODES = RecordHealthCheckConstants.VALID_APPLICABILITY_MODES;
  private static final Set<String> VALID_CHECK_TYPES = RecordHealthCheckConstants.VALID_CHECK_TYPES;
  private static final Set<String> VALID_SEVERITIES = RecordHealthCheckConstants.VALID_SEVERITIES;

  private static final Integer FRAMEWORK_MAX_CHECKS = RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // ─── Component-level exception ────────────────────────────────────────────

  public class ConfigException extends Exception {
    public String reasonCode;
    public ConfigException(String message, String reasonCode) {
      this(message);
      this.reasonCode = reasonCode;
    }
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /** Finds the parent Check Set for a Rule API name. */
  public String findCheckSetDeveloperName(String ruleDeveloperName) {
    ruleDeveloperName = RecordHealthCheckLogger.normalizeIdentifier(
      ruleDeveloperName,
      80
    );
    if (String.isBlank(ruleDeveloperName)) {
      return null;
    }
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced before rule evaluation.
    List<Record_Health_Check_Rule__mdt> rules = [
      SELECT Record_Health_Check_Set__r.DeveloperName
      FROM Record_Health_Check_Rule__mdt
      WHERE DeveloperName = :ruleDeveloperName
      LIMIT 1
    ];
    return rules.isEmpty()
      ? null
      : rules[0].Record_Health_Check_Set__r.DeveloperName;
  }

  /**
   * Reports whether any Check Sets target the given object API name.
   * Used when the LWC has no Check Set selected, so the setup banner can say
   * choose one, activate one, or create one.
   */
  public RecordHealthCheckSetAvailability getCheckSetAvailabilityForObject(
    String objectApiName
  ) {
    RecordHealthCheckSetAvailability availability = new RecordHealthCheckSetAvailability();
    if (String.isBlank(objectApiName)) {
      return availability;
    }
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    for (Record_Health_Check_Set__mdt checkSet : [
      SELECT ObjectApiName__c, IsActive__c
      FROM Record_Health_Check_Set__mdt
    ]) {
      if (!objectApiName.equalsIgnoreCase(checkSet.ObjectApiName__c)) {
        continue;
      }
      if (checkSet.IsActive__c == true) {
        availability.hasActive = true;
      } else {
        availability.hasInactive = true;
      }
      if (availability.hasActive && availability.hasInactive) {
        break;
      }
    }
    return availability;
  }

  /**
   * @deprecated Prefer getCheckSetAvailabilityForObject; kept for callers that
   * only need the active-set boolean.
   */
  public Boolean hasActiveCheckSetForObject(String objectApiName) {
    return getCheckSetAvailabilityForObject(objectApiName).hasActive;
  }

  /**
   * Loads and validates a Check Set and its active rules.
   * Throws ConfigException for component-level failures (CONFIG_NOT_FOUND
   * CONFIG_INACTIVE, OBJECT_MISMATCH, NO_RECORD_CONTEXT, NO_ACTIVE_CHECKS).
   * Returns a fully populated RecordHealthCheckDefinitionResponse on success.
   */
  public RecordHealthCheckDefinitionResponse getDefinitionResponse(
    String checkSetDeveloperName,
    Id recordId
  ) {
    // Normalize at the service boundary so whitespace/blank is rejected before SOQL;
    // blank → CONFIG_NOT_FOUND.
    checkSetDeveloperName = RecordHealthCheckLogger.normalizeIdentifier(
      checkSetDeveloperName,
      80
    );
    if (String.isBlank(checkSetDeveloperName)) {
      throw new ConfigException(
        'No Check Set is selected for this Record Health Check component.',
        RC_CONFIG_NOT_FOUND
      );
    }

    if (recordId == null) {
      throw new ConfigException(
        'This component needs a record page context before it can run health checks.',
        RC_NO_RECORD_CONTEXT
      );
    }

    // Load Check Set
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT
        DeveloperName,
        MasterLabel,
        CardTitle__c,
        CardSubtitle__c,
        ObjectApiName__c,
        IsActive__c,
        CardRunMode__c,
        PassedChecksDisplay__c,
        SkippedChecksDisplay__c,
        CardRevealMode__c,
        FoundExpectedDisplay__c,
        StopOnSystemError__c,
        ShowDiagnostics__c
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = :checkSetDeveloperName
      LIMIT 1
    ];

    if (checkSets.isEmpty()) {
      throw new ConfigException(
        'Check Set "' + checkSetDeveloperName + '" was not found.',
        RC_CONFIG_NOT_FOUND
      );
    }

    Record_Health_Check_Set__mdt checkSet = checkSets[0];
    validateCheckSetForDefinition(checkSet, checkSetDeveloperName, recordId);

    // Load active rules — only the fields needed to build RecordHealthCheckDefinition.
    // Full evaluation fields are fetched per-rule at evaluation time via loadRule().
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check_Rule__mdt> allRules = [
      SELECT
        DeveloperName,
        CheckTitle__c,
        CheckDescription__c,
        Category__c,
        EvaluationOrder__c,
        PrerequisiteRule__c
      FROM Record_Health_Check_Rule__mdt
      WHERE
        Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
        AND IsActive__c = TRUE
      ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC
    ];

    validateActiveRulesForDefinition(allRules, checkSetDeveloperName);

    Integer totalAvailable = allRules.size();
    Boolean checksOmitted = totalAvailable > FRAMEWORK_MAX_CHECKS;
    List<Record_Health_Check_Rule__mdt> rulesForRun = selectRulesForRun(
      allRules
    );
    Integer inactiveRuleCount = countInactiveRules(checkSetDeveloperName);

    // Build response
    RecordHealthCheckDefinitionResponse response = new RecordHealthCheckDefinitionResponse();
    // Prefer Card Title; fall back to MasterLabel / DeveloperName so the card
    // never renders a blank title when the admin left PanelHeading blank.
    response.displayTitle = String.isNotBlank(checkSet.CardTitle__c)
      ? checkSet.CardTitle__c
      : (String.isNotBlank(checkSet.MasterLabel)
          ? checkSet.MasterLabel
          : checkSet.DeveloperName);
    response.displayDescription = checkSet.CardSubtitle__c;
    response.triggerMode = RecordHealthCheckConstants.toLwcTriggerMode(
      checkSet.CardRunMode__c
    );
    response.revealMode = RecordHealthCheckConstants.toLwcRevealMode(
      checkSet.CardRevealMode__c
    );
    response.successDisplayMode = RecordHealthCheckConstants.toLwcDisplayMode(
      checkSet.PassedChecksDisplay__c
    );
    response.skippedDisplayMode = RecordHealthCheckConstants.toLwcDisplayMode(
      checkSet.SkippedChecksDisplay__c
    );
    response.comparisonDisplay = RecordHealthCheckConstants.toLwcComparisonDisplay(
      String.isBlank(checkSet.FoundExpectedDisplay__c)
        ? 'ON_DEMAND'
        : checkSet.FoundExpectedDisplay__c
    );
    response.stopOnFirstError = checkSet.StopOnSystemError__c;
    response.showDiagnostics =
      checkSet.ShowDiagnostics__c == true &&
      RecordHealthCheckAccess.canViewDebugDetails();
    response.totalAvailableCheckCount = totalAvailable;
    response.checksOmittedByLimit = checksOmitted;
    response.inactiveRuleCount = inactiveRuleCount;

    // Emit WARN when active rules exceed FRAMEWORK_MAX_CHECKS, so truncation is
    // visible server-side and not only in the LWC "First 25 of N shown" badge.
    if (checksOmitted) {
      logCheckLimitExceeded(checkSetDeveloperName, recordId, totalAvailable);
    }

    response.checks = new List<RecordHealthCheckDefinition>();

    for (Record_Health_Check_Rule__mdt rule : rulesForRun) {
      RecordHealthCheckDefinition def = new RecordHealthCheckDefinition();
      def.developerName = rule.DeveloperName;
      def.label = rule.CheckTitle__c;
      def.description = rule.CheckDescription__c;
      def.priority = rule.EvaluationOrder__c;
      def.dependsOnRuleDeveloperName = String.isNotBlank(
          rule.PrerequisiteRule__c
        )
        ? rule.PrerequisiteRule__c.trim()
        : null;
      response.checks.add(def);
    }

    return response;
  }

  @TestVisible
  private void logCheckLimitExceeded(
    String checkSetDeveloperName,
    Id recordId,
    Integer totalAvailable
  ) {
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.WARN,
      null,
      checkSetDeveloperName,
      recordId,
      null,
      'CHECK_LIMIT_EXCEEDED',
      new Map<String, Object>{
        'totalAvailable' => totalAvailable,
        'maxPerRun' => FRAMEWORK_MAX_CHECKS,
        'omitted' => totalAvailable - FRAMEWORK_MAX_CHECKS
      },
      null
    );
  }

  @TestVisible
  private void validateCheckSetForDefinition(
    Record_Health_Check_Set__mdt checkSet,
    String checkSetDeveloperName,
    Id recordId
  ) {
    if (checkSet.IsActive__c == false) {
      throw new ConfigException(
        'Check Set "' + checkSetDeveloperName + '" is inactive.',
        RC_CONFIG_INACTIVE
      );
    }

    if (String.isBlank(checkSet.ObjectApiName__c)) {
      // A blank Base Object is a misconfiguration of an existing Check Set, not a
      // missing Check Set — classify it as INVALID_CONFIG for consistency with the
      // Blank object name is INVALID_CONFIG, not CONFIG_NOT_FOUND.
      throw new ConfigException(
        'Check Set "' +
          checkSetDeveloperName +
          '" is missing its Record Object API Name.',
        RC_INVALID_CONFIG
      );
    }
    if (
      !RecordHealthCheckConfigValidator.isValidObjectApiName(
        checkSet.ObjectApiName__c
      )
    ) {
      throw new ConfigException(
        'Record Object API Name "' +
          checkSet.ObjectApiName__c +
          '" on Check Set "' +
          checkSetDeveloperName +
          '" is not valid.',
        RC_INVALID_CONFIG
      );
    }

    String recordObjectType = RecordHealthCheckDescribeCache.objectApiName(
      recordId
    );
    if (
      String.isBlank(recordObjectType) ||
      !recordObjectType.equalsIgnoreCase(checkSet.ObjectApiName__c)
    ) {
      throw new ConfigException(
        'Check Set "' +
          checkSetDeveloperName +
          '" is for "' +
          checkSet.ObjectApiName__c +
          '", but this page is for "' +
          recordObjectType +
          '".',
        RC_OBJECT_MISMATCH
      );
    }

    if (!VALID_DISPLAY_MODES.contains(checkSet.PassedChecksDisplay__c)) {
      throw new ConfigException(
        'Passed Checks Display "' +
          checkSet.PassedChecksDisplay__c +
          '" is not recognized. Valid values: SHOW_EACH_CHECK, SHOW_COUNT_ONLY.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_DISPLAY_MODES.contains(checkSet.SkippedChecksDisplay__c)) {
      throw new ConfigException(
        'Skipped Checks Display "' +
          checkSet.SkippedChecksDisplay__c +
          '" is not recognized. Valid values: SHOW_EACH_CHECK, SHOW_COUNT_ONLY.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_TRIGGER_MODES.contains(checkSet.CardRunMode__c)) {
      throw new ConfigException(
        'When Checks Run "' +
          checkSet.CardRunMode__c +
          '" is not recognized. Valid values: RUN_ON_LOAD, RUN_ON_REQUEST.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_REVEAL_MODES.contains(checkSet.CardRevealMode__c)) {
      throw new ConfigException(
        'Reveal Mode "' +
          checkSet.CardRevealMode__c +
          '" is not recognized. Valid values: ALL_AT_ONCE, ONE_BY_ONE.',
        RC_INVALID_CONFIG
      );
    }
    if (
      String.isNotBlank(checkSet.FoundExpectedDisplay__c) &&
      !VALID_COMPARISON_DISPLAYS.contains(checkSet.FoundExpectedDisplay__c)
    ) {
      throw new ConfigException(
        'Found/Expected Display "' +
          checkSet.FoundExpectedDisplay__c +
          '" is not recognized. Valid values: ON_DEMAND, FAILURES_ONLY, ALL_ROWS.',
        RC_INVALID_CONFIG
      );
    }
  }

  @TestVisible
  private void validateActiveRulesForDefinition(
    List<Record_Health_Check_Rule__mdt> rules,
    String checkSetDeveloperName
  ) {
    if (rules.isEmpty()) {
      Integer inactiveCount = countInactiveRules(checkSetDeveloperName);
      String detail = inactiveCount > 0
        ? ' (' + inactiveCount + ' inactive)'
        : '';
      throw new ConfigException(
        'Check Set "' +
          checkSetDeveloperName +
          '" has no active checks' +
          detail +
          '.',
        RC_NO_ACTIVE_CHECKS
      );
    }
  }

  /** Inactive Rules on the Check Set — omitted from the run, useful for admin UX. */
  private Integer countInactiveRules(String checkSetDeveloperName) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    return [
      SELECT COUNT()
      FROM Record_Health_Check_Rule__mdt
      WHERE
        Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
        AND IsActive__c = FALSE
    ];
  }

  @TestVisible
  private List<Record_Health_Check_Rule__mdt> selectRulesForRun(
    List<Record_Health_Check_Rule__mdt> allRules
  ) {
    List<Record_Health_Check_Rule__mdt> rulesForRun = new List<Record_Health_Check_Rule__mdt>();
    Integer rulesToInclude = Math.min(FRAMEWORK_MAX_CHECKS, allRules.size());
    for (Integer i = 0; i < rulesToInclude; i++) {
      rulesForRun.add(allRules[i]);
    }
    return rulesForRun;
  }

  /**
   * Validates a single rule's metadata configuration for runtime evaluation.
   * Returns a UNABLE_TO_EVALUATE RecordHealthCheckResult if the rule is invalid
   * or null if the rule is valid and may proceed to the evaluator.
   */
  public RecordHealthCheckResult validateRuleForEvaluation(
    Record_Health_Check_Rule__mdt rule
  ) {
    if (String.isBlank(rule.CheckTitle__c) || rule.EvaluationOrder__c == null) {
      return buildUnableResult(
        rule,
        RC_INVALID_CONFIG,
        'Check Title and Evaluation Order are required on every rule.'
      );
    }
    if (String.isBlank(rule.FailureMessage__c)) {
      return buildUnableResult(
        rule,
        RC_INVALID_CONFIG,
        'Message When Check Fails is required on every rule.'
      );
    }
    // Unknown check type
    if (!VALID_CHECK_TYPES.contains(rule.EvaluationType__c)) {
      return buildUnableResult(
        rule,
        'INVALID_CHECK_TYPE',
        'Evaluation Type "' + rule.EvaluationType__c + '" is not recognized.'
      );
    }

    // Severity required
    if (
      String.isBlank(rule.FailureSeverity__c) ||
      !VALID_SEVERITIES.contains(rule.FailureSeverity__c)
    ) {
      return buildUnableResult(
        rule,
        RC_INVALID_CONFIG,
        'Severity must be Error, Warning, or Info.'
      );
    }

    // ApplicabilityMode validation (null / blank == Always, which is valid)
    if (
      String.isNotBlank(rule.ApplicabilityMode__c) &&
      !VALID_APPLICABILITY_MODES.contains(rule.ApplicabilityMode__c)
    ) {
      return buildUnableResult(
        rule,
        'INVALID_CONFIG',
        'ApplicabilityMode "' +
          rule.ApplicabilityMode__c +
          '" is not recognized. Valid values: Always, Formula, SOQL.'
      );
    }

    // Applicability sub-field validation — surface a misconfigured gate here as a
    // clear config error rather than letting the engine reach it at evaluation time.
    RecordHealthCheckResult applicabilityIssue = validateApplicability(rule);
    if (applicabilityIssue != null) {
      return applicabilityIssue;
    }

    // Per-type required-field validation
    if (rule.EvaluationType__c == 'FORMULA') {
      return validateFormulaRule(rule);
    } else if (rule.EvaluationType__c == 'QUERY') {
      return validateQueryRule(rule);
    } else if (rule.EvaluationType__c == 'APEX') {
      return validateApexRule(rule);
    }
    // Baseline validation above rejects unknown types, so the only remaining
    // supported type is COMPARE_TWO_QUERIES.
    return validateCompareQueriesRule(rule);
  }

  /**
   * Loads an active Rule scoped to the named Check Set.
   * Returns null when the rule is missing, inactive, or belongs to a different set.
   */
  public Record_Health_Check_Rule__mdt loadRule(
    String ruleDeveloperName,
    String checkSetDeveloperName
  ) {
    return loadRule(ruleDeveloperName, checkSetDeveloperName, true);
  }

  /**
   * Loads a Rule scoped to the named Check Set. When requireActive is false,
   * inactive Rules are returned so callers can distinguish RULE_INACTIVE from
   * RULE_NOT_FOUND.
   */
  public Record_Health_Check_Rule__mdt loadRule(
    String ruleDeveloperName,
    String checkSetDeveloperName,
    Boolean requireActive
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before rule evaluation.
    List<Record_Health_Check_Rule__mdt> rules = [
      SELECT
        DeveloperName,
        MasterLabel,
        CheckTitle__c,
        CheckDescription__c,
        EvaluationOrder__c,
        IsActive__c,
        EvaluationType__c,
        FailureSeverity__c,
        PassConditionFormula__c,
        DisplayFoundFormula__c,
        DisplayExpectedFormula__c,
        FindInListFormula__c,
        FormulaResultType__c,
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
        Record_Health_Check_Set__c,
        Record_Health_Check_Set__r.DeveloperName,
        Record_Health_Check_Set__r.MasterLabel,
        Record_Health_Check_Set__r.CardTitle__c,
        Record_Health_Check_Set__r.CardSubtitle__c,
        Record_Health_Check_Set__r.IsActive__c,
        Record_Health_Check_Set__r.ObjectApiName__c,
        Record_Health_Check_Set__r.ShowDiagnostics__c
      FROM Record_Health_Check_Rule__mdt
      WHERE
        DeveloperName = :ruleDeveloperName
        AND Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
      LIMIT 1
    ];
    if (rules.isEmpty()) {
      return null;
    }
    Record_Health_Check_Rule__mdt rule = rules[0];
    if (requireActive == true && rule.IsActive__c != true) {
      return null;
    }
    RecordHealthCheckTokenIssue tokenIssue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      rule
    );
    if (tokenIssue != null) {
      throw new ConfigException(
        'Invalid merge token configuration on Rule "' +
          rule.DeveloperName +
          '": ' +
          tokenIssue.message,
        tokenIssue.reasonCode
      );
    }
    return rule;
  }

  // ─── Per-type validation — first-fail adapter over RecordHealthCheckRuleValidator ───
  // The per-type decision tree lives in RecordHealthCheckRuleValidator; these wrappers take
  // the FIRST finding (first-fail order) and map it via toResult. MaxRows and null/empty-behavior
  // are appended only for Query / CompareTwoQueries.

  /**
   * Validates the ApplicabilityMode gate (Formula / SOQL sub-fields). Returns null when the
   * gate is well-formed (or mode is Always/blank). Kept @TestVisible for parity with prior API.
   */
  @TestVisible
  private RecordHealthCheckResult validateApplicability(
    Record_Health_Check_Rule__mdt rule
  ) {
    return firstResult(
      RecordHealthCheckRuleValidator.applicabilityFindings(rule),
      rule
    );
  }

  private RecordHealthCheckResult validateFormulaRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    return firstResult(
      RecordHealthCheckRuleValidator.formulaFindings(rule),
      rule
    );
  }

  private RecordHealthCheckResult validateQueryRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<RecordHealthCheckRuleValidator.Finding> findings = RecordHealthCheckRuleValidator.queryFindings(
      rule
    );
    findings.addAll(RecordHealthCheckRuleValidator.maxRowsFindings(rule));
    findings.addAll(RecordHealthCheckRuleValidator.nullEmptyFindings(rule));
    return firstResult(findings, rule);
  }

  private RecordHealthCheckResult validateApexRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    return firstResult(RecordHealthCheckRuleValidator.apexFindings(rule), rule);
  }

  private RecordHealthCheckResult validateCompareQueriesRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<RecordHealthCheckRuleValidator.Finding> findings = RecordHealthCheckRuleValidator.compareQueriesFindings(
      rule
    );
    findings.addAll(RecordHealthCheckRuleValidator.maxRowsFindings(rule));
    findings.addAll(RecordHealthCheckRuleValidator.nullEmptyFindings(rule));
    return firstResult(findings, rule);
  }

  private RecordHealthCheckResult firstResult(
    List<RecordHealthCheckRuleValidator.Finding> findings,
    Record_Health_Check_Rule__mdt rule
  ) {
    return findings.isEmpty() ? null : toResult(findings[0], rule);
  }

  /**
   * Maps a shared Finding to this runtime path's UNABLE_TO_EVALUATE reason code and detail
   * message. This switch is the ONLY place the runtime output vocabulary lives — the decision
   * tree that produced the finding is shared. Reason codes and messages here are byte-for-byte
   * the originals so the engine and every pinned test see identical results.
   */
  private RecordHealthCheckResult toResult(
    RecordHealthCheckRuleValidator.Finding finding,
    Record_Health_Check_Rule__mdt rule
  ) {
    String val = finding.offendingValue;
    switch on finding.code {
      // ── Applicability gate ──
      when APPLICABILITY_FORMULA_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_FORMULA',
          'Applicability Formula is required when Applicability Mode is Formula.'
        );
      }
      when APPLICABILITY_SOQL_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Applicability SOQL is required when Applicability Mode is SOQL.'
        );
      }
      when APPLICABILITY_SOQL_NOT_SINGLE_VALUE {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Applicability SOQL must be a single COUNT() or COUNT(Id) query without GROUP BY.'
        );
      }
      when APPLICABILITY_OPERATOR_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Applicability comparison operator is required when Applicability Mode is SOQL.'
        );
      }
      when APPLICABILITY_OPERATOR_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Applicability comparison operator "' +
            val +
            '" is not recognized. Valid values: Equals, NotEquals, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual.'
        );
      }
      when APPLICABILITY_THRESHOLD_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_CONFIG',
          'Applicability Comparison Value is required when Applicability Mode is SOQL.'
        );
      }
      // ── Formula ──
      when FORMULA_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_FORMULA',
          'Formula checks require Formula to be populated.'
        );
      }
      // ── Query (single) ──
      when LIST_VALUE_TO_TEST_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_FORMULA',
          'List contains any and List contains none require Value To Test to provide the primary value.'
        );
      }
      when LIST_COMPARE_QUERY_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'List contains any and List contains none require Comparison Query to provide the list.'
        );
      }
      when LIST_COMPARE_FIELD_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query Field is required for list comparison queries.'
        );
      }
      when PRIMARY_QUERY_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Query checks require Source Query to be populated.'
        );
      }
      when PRIMARY_QUERY_FIELD_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Source Query Field is required for non-aggregate queries.'
        );
      }
      when DUAL_OPERATOR_ON_SINGLE {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Operator "' + val + '" requires Evaluation Type Compare two queries.'
        );
      }
      when OPERATOR_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Comparison operator "' + val + '" is not recognized.'
        );
      }
      when OPERATOR_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Comparison operator is required for Query checks.'
        );
      }
      when MULTI_ROWS_MISSING {
        return buildUnableResult(
          rule,
          RC_UNABLE_TO_EVALUATE,
          'How To Interpret Query Results is required for Query checks.'
        );
      }
      when MULTI_ROWS_INVALID {
        return buildUnableResult(
          rule,
          RC_INVALID_CONFIG,
          'How To Interpret Query Results "' + val + '" is not recognized.'
        );
      }
      when COMPARE_AS_LISTS_ON_SINGLE {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Compare query results as lists requires Evaluation Type Compare two queries, not Check records with a query.'
        );
      }
      when COMPARE_AGAINST_MISSING {
        return buildUnableResult(
          rule,
          RC_UNABLE_TO_EVALUATE,
          'Expected Value Comes From is required for Query checks except IsBlank/IsNotBlank.'
        );
      }
      when COMPARE_AGAINST_INVALID {
        return buildUnableResult(
          rule,
          RC_INVALID_CONFIG,
          'Expected Value Comes From "' + val + '" is not recognized.'
        );
      }
      when FIXED_VALUE_MISSING {
        return buildUnableResult(
          rule,
          RC_UNABLE_TO_EVALUATE,
          'Expected Value is required when Expected Value Comes From is A fixed value.'
        );
      }
      when RECORD_FORMULA_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_FORMULA',
          'Expected Formula (on this record) is required when Expected Value Comes From is A formula on this record.'
        );
      }
      when ANOTHER_QUERY_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query is required when Expected Value Comes From is Comparison query.'
        );
      }
      when ANOTHER_QUERY_FIELD_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query Field is required for non-aggregate comparison queries.'
        );
      }
      // ── Compare two queries ──
      when DUAL_PRIMARY_QUERY_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Compare two queries checks require Source Query to be populated.'
        );
      }
      when DUAL_COMPARE_QUERY_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Compare two queries checks require Comparison Query to be populated.'
        );
      }
      when DUAL_PRIMARY_FIELD_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Source Query Field is required for non-aggregate source queries.'
        );
      }
      when DUAL_COMPARE_FIELD_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query Field is required for non-aggregate comparison queries.'
        );
      }
      when DUAL_OPERATOR_MISSING {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Comparison operator is required for Compare two queries checks.'
        );
      }
      when DUAL_OPERATOR_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Comparison operator "' + val + '" is not recognized.'
        );
      }
      when DUAL_MULTI_ROWS_MISSING {
        return buildUnableResult(
          rule,
          RC_UNABLE_TO_EVALUATE,
          'How To Interpret Query Results is required for Compare two queries checks.'
        );
      }
      when DUAL_MULTI_ROWS_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Compare two queries requires How To Interpret Query Results to be Expect one row or aggregate result, or Compare query results as lists.'
        );
      }
      when DUAL_LIST_MODE_NEEDS_LIST_OPERATOR {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'Compare query results as lists mode requires a list operator: Lists overlap, List contains all, or Exact list match.'
        );
      }
      when DUAL_ONE_RESULT_NO_LIST_OPERATOR {
        return buildUnableResult(
          rule,
          'INVALID_OPERATOR',
          'List operators (Lists overlap, List contains all, Exact list match) require Compare query results as lists mode.'
        );
      }
      // ── Apex ──
      when APEX_CLASS_MISSING {
        return buildUnableResult(
          rule,
          'APEX_CLASS_NOT_FOUND',
          'Apex checks require Apex Class Name to be populated.'
        );
      }
      when APEX_CLASS_INVALID {
        return buildUnableResult(
          rule,
          'APEX_CLASS_NOT_FOUND',
          'Apex Class Name must identify an instantiable class implementing RecordHealthCheckRule.'
        );
      }
      when APEX_PARAMS_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_APEX_PARAMETERS',
          'Apex Parameters must contain valid JSON object syntax.'
        );
      }
      // ── Cross-type ──
      when MAX_ROWS_INVALID {
        return buildUnableResult(
          rule,
          'GOVERNOR_LIMIT_RISK',
          'Max Rows Override must be a whole number between 1 and ' +
            FRAMEWORK_MAX_ROWS +
            '.'
        );
      }
      when NULL_BEHAVIOR_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_CONFIG',
          'If Field Value Is Empty "' +
            val +
            '" is not recognized. Valid values: Ignore the record, Treat as blank, Treat as not matching.'
        );
      }
      when EMPTY_BEHAVIOR_INVALID {
        return buildUnableResult(
          rule,
          'INVALID_CONFIG',
          'No Rows Result "' +
            val +
            '" is not recognized. Valid values: PASS, FAIL, SKIP, UNABLE_TO_EVALUATE.'
        );
      }
      when else {
        // Every FindingCode is mapped above; this is defensive only.
        return buildUnableResult(
          rule,
          RC_INVALID_CONFIG,
          'This check could not be evaluated. Contact your administrator.'
        );
      }
    }
  }

  // ─── Result builder ───────────────────────────────────────────────────────

  private RecordHealthCheckResult buildUnableResult(
    Record_Health_Check_Rule__mdt rule,
    String reasonCode,
    String detail
  ) {
    RecordHealthCheckResult r = new RecordHealthCheckResult();
    r.ruleDeveloperName = rule.DeveloperName;
    r.label = rule.CheckTitle__c;
    r.status = 'UNABLE_TO_EVALUATE';
    r.reasonCode = reasonCode;
    r.detailMessage = detail;
    r.evaluatorType = rule.EvaluationType__c;
    r.priority = rule.EvaluationOrder__c;
    r.message = String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
    return r;
  }
}
