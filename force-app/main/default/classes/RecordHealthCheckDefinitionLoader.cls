/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Loads and validates Check Set definitions for the runtime service.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckDefinitionLoader {
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.validDisplayModes;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.validTriggerModes;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.validRevealModes;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.validComparisonDisplays;
  private static final Integer FRAMEWORK_MAX_CHECKS = RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
  private static final String RC_CONFIG_NOT_FOUND = RecordHealthCheckConfigService.RC_CONFIG_NOT_FOUND;
  private static final String RC_CONFIG_INACTIVE = RecordHealthCheckConfigService.RC_CONFIG_INACTIVE;
  private static final String RC_INVALID_CONFIG = RecordHealthCheckConfigService.RC_INVALID_CONFIG;
  private static final String RC_OBJECT_MISMATCH = RecordHealthCheckConfigService.RC_OBJECT_MISMATCH;
  private static final String RC_NO_RECORD_CONTEXT = RecordHealthCheckConfigService.RC_NO_RECORD_CONTEXT;
  private static final String RC_NO_ACTIVE_CHECKS = RecordHealthCheckConfigService.RC_NO_ACTIVE_CHECKS;

  /**
   * Loads and validates a Check Set and its active rules.
   * Throws ConfigException for component-level failures (CONFIG_NOT_FOUND,
   * CONFIG_INACTIVE, OBJECT_MISMATCH, NO_RECORD_CONTEXT, NO_ACTIVE_CHECKS).
   * Returns a fully filled-in RecordHealthCheckDefinitionResponse on success.
   */
  public static RecordHealthCheckDefinitionResponse getDefinitionResponse(
    RecordHealthCheckConfigService service,
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
      throw new RecordHealthCheckConfigService.ConfigException(
        'No Check Set is selected for this Record Health Check component.',
        RC_CONFIG_NOT_FOUND
      );
    }

    if (recordId == null) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'This component needs a record page context before it can run health checks.',
        RC_NO_RECORD_CONTEXT
      );
    }

    // Load Check Set
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check_Set__mdt> checkSets = [
      SELECT
        QualifiedApiName,
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
      WHERE QualifiedApiName = :checkSetDeveloperName
      LIMIT 1
    ];

    if (checkSets.isEmpty()) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' + checkSetDeveloperName + '" was not found.',
        RC_CONFIG_NOT_FOUND
      );
    }

    Record_Health_Check_Set__mdt checkSet = checkSets[0];
    String resolvedDeveloperName = checkSet.DeveloperName;
    validateCheckSetForDefinition(checkSet, resolvedDeveloperName, recordId);

    // Load active rules — only the fields needed to build RecordHealthCheckDefinition.
    // Full evaluation fields are fetched per-rule at evaluation time via loadRule().
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check_Rule__mdt> allRules = [
      SELECT
        QualifiedApiName,
        DeveloperName,
        CheckTitle__c,
        CheckDescription__c,
        Category__c,
        EvaluationOrder__c,
        PrerequisiteRule__c
      FROM Record_Health_Check_Rule__mdt
      WHERE
        Record_Health_Check_Set__r.QualifiedApiName = :checkSetDeveloperName
        AND IsActive__c = TRUE
      ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC
    ];

    validateActiveRulesForDefinition(allRules, resolvedDeveloperName);

    Integer totalAvailable = allRules.size();
    Boolean checksOmitted = totalAvailable > FRAMEWORK_MAX_CHECKS;
    List<Record_Health_Check_Rule__mdt> rulesForRun = selectRulesForRun(
      allRules
    );
    Integer inactiveRuleCount = countInactiveRules(resolvedDeveloperName);

    // Build response
    RecordHealthCheckDefinitionResponse response = new RecordHealthCheckDefinitionResponse();
    response.checkSetQualifiedApiName = checkSet.QualifiedApiName;
    // Card Title is a required presentation contract validated above.
    response.displayTitle = definitionTitle(checkSet);
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
      comparisonDisplay(checkSet)
    );
    response.stopOnFirstError = checkSet.StopOnSystemError__c;
    response.showDiagnostics = canShowDiagnostics(checkSet);
    response.totalAvailableCheckCount = totalAvailable;
    response.frameworkMaxChecks = RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
    response.checksOmittedByLimit = checksOmitted;
    response.inactiveRuleCount = inactiveRuleCount;
    // Rule names are configuration detail, so they ride along only for the
    // diagnostics audience that already sees troubleshooting fields.
    response.inactiveRuleLabels = (response.showDiagnostics == true &&
      inactiveRuleCount > 0)
      ? inactiveRuleLabels(resolvedDeveloperName)
      : new List<String>();

    // Log WARN when active rules exceed FRAMEWORK_MAX_CHECKS, so truncation is
    // visible server-side and not only in the LWC "First 25 of N shown" badge.
    if (checksOmitted) {
      logCheckLimitExceeded(resolvedDeveloperName, recordId, totalAvailable);
    }

    response.checks = new List<RecordHealthCheckDefinition>();

    for (Record_Health_Check_Rule__mdt rule : rulesForRun) {
      RecordHealthCheckDefinition def = new RecordHealthCheckDefinition();
      def.qualifiedApiName = rule.QualifiedApiName;
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

  public static void logCheckLimitExceeded(
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

  public static void validateCheckSetForDefinition(
    Record_Health_Check_Set__mdt checkSet,
    String checkSetDeveloperName,
    Id recordId
  ) {
    if (checkSet.IsActive__c == false) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Check Set "' + checkSetDeveloperName + '" is inactive.',
        RC_CONFIG_INACTIVE
      );
    }

    if (String.isBlank(checkSet.ObjectApiName__c)) {
      // A blank Base Object misconfigures an existing Check Set; it does not mean
      // the Check Set is missing, so classify it as INVALID_CONFIG.
      throw new RecordHealthCheckConfigService.ConfigException(
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
      throw new RecordHealthCheckConfigService.ConfigException(
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
      throw new RecordHealthCheckConfigService.ConfigException(
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
      throw new RecordHealthCheckConfigService.ConfigException(
        'Passed Checks Display "' +
          checkSet.PassedChecksDisplay__c +
          '" is not recognized. Valid values: SHOW_EACH_CHECK, SHOW_COUNT_ONLY.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_DISPLAY_MODES.contains(checkSet.SkippedChecksDisplay__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Skipped Checks Display "' +
          checkSet.SkippedChecksDisplay__c +
          '" is not recognized. Valid values: SHOW_EACH_CHECK, SHOW_COUNT_ONLY.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_TRIGGER_MODES.contains(checkSet.CardRunMode__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'When Checks Run "' +
          checkSet.CardRunMode__c +
          '" is not recognized. Valid values: RUN_ON_LOAD, RUN_ON_REQUEST.',
        RC_INVALID_CONFIG
      );
    }
    if (!VALID_REVEAL_MODES.contains(checkSet.CardRevealMode__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Reveal Mode "' +
          checkSet.CardRevealMode__c +
          '" is not recognized. Valid values: ALL_AT_ONCE, ONE_BY_ONE.',
        RC_INVALID_CONFIG
      );
    }
    if (String.isBlank(checkSet.CardTitle__c)) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Card Title is required on Check Set "' + checkSetDeveloperName + '".',
        RC_INVALID_CONFIG
      );
    }
    if (
      String.isBlank(checkSet.FoundExpectedDisplay__c) ||
      !VALID_COMPARISON_DISPLAYS.contains(checkSet.FoundExpectedDisplay__c)
    ) {
      throw new RecordHealthCheckConfigService.ConfigException(
        'Found/Expected Display "' +
          checkSet.FoundExpectedDisplay__c +
          '" is not recognized. Valid values: ON_DEMAND, FAILURES_ONLY, ALL_ROWS.',
        RC_INVALID_CONFIG
      );
    }
  }

  public static void validateActiveRulesForDefinition(
    List<Record_Health_Check_Rule__mdt> rules,
    String checkSetDeveloperName
  ) {
    if (rules.isEmpty()) {
      Integer inactiveCount = countInactiveRules(checkSetDeveloperName);
      String detail = inactiveCount > 0
        ? ' (' + inactiveCount + ' inactive)'
        : '';
      throw new RecordHealthCheckConfigService.ConfigException(
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
  public static Integer countInactiveRules(String checkSetDeveloperName) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    return [
      SELECT COUNT()
      FROM Record_Health_Check_Rule__mdt
      WHERE
        Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
        AND IsActive__c = FALSE
    ];
  }

  /**
   * Display names of the inactive Rules, for the diagnostics "N Inactive"
   * tooltip. Capped at the framework check limit so a long-neglected Check Set
   * cannot grow an unbounded tooltip; the pill still shows the exact count.
   */
  public static List<String> inactiveRuleLabels(String checkSetDeveloperName) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is framework setup data; access is enforced by RecordHealthCheckAccess before definitions are exposed.
    List<Record_Health_Check_Rule__mdt> inactiveRules = [
      SELECT DeveloperName, MasterLabel, CheckTitle__c
      FROM Record_Health_Check_Rule__mdt
      WHERE
        Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
        AND IsActive__c = FALSE
      ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC
      LIMIT :FRAMEWORK_MAX_CHECKS
    ];
    return inactiveRuleLabelsFrom(inactiveRules);
  }

  public static List<String> inactiveRuleLabelsFrom(
    List<Record_Health_Check_Rule__mdt> inactiveRules
  ) {
    List<String> labels = new List<String>();
    for (Record_Health_Check_Rule__mdt rule : inactiveRules) {
      labels.add(
        String.isNotBlank(rule.CheckTitle__c)
          ? rule.CheckTitle__c
          : (String.isNotBlank(rule.MasterLabel)
              ? rule.MasterLabel
              : rule.DeveloperName)
      );
    }
    return labels;
  }

  public static String definitionTitle(Record_Health_Check_Set__mdt checkSet) {
    return checkSet.CardTitle__c;
  }

  public static String comparisonDisplay(
    Record_Health_Check_Set__mdt checkSet
  ) {
    return checkSet.FoundExpectedDisplay__c;
  }

  public static Boolean canShowDiagnostics(
    Record_Health_Check_Set__mdt checkSet
  ) {
    return checkSet.ShowDiagnostics__c == true &&
      RecordHealthCheckAccess.canViewDetails();
  }

  public static List<Record_Health_Check_Rule__mdt> selectRulesForRun(
    List<Record_Health_Check_Rule__mdt> allRules
  ) {
    List<Record_Health_Check_Rule__mdt> rulesForRun = new List<Record_Health_Check_Rule__mdt>();
    Integer rulesToInclude = Math.min(FRAMEWORK_MAX_CHECKS, allRules.size());
    for (Integer i = 0; i < rulesToInclude; i++) {
      rulesForRun.add(allRules[i]);
    }
    return rulesForRun;
  }
}
