/** Enforces and enriches the result contract returned by custom Apex Rules. */
public with sharing class RecordHealthCheckApexResultFinalizer {
  private static final Set<String> VALID_STATUSES = new Set<String>{
    'PASS',
    'FAIL',
    'SKIPPED',
    'UNABLE_TO_EVALUATE',
    'ERROR'
  };

  /** Converts a plugin outcome to the framework's internal result shape. */
  public static RecordHealthCheckInternalResult toInternalResult(
    RecordHealthCheckOutcome outcome,
    RecordHealthCheckInternalResult template
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.ruleDeveloperName = template.ruleDeveloperName;
    result.label = template.label;
    result.priority = template.priority;
    result.evaluatorType = template.evaluatorType;
    result.status = outcome.status;
    result.reasonCode = outcome.reasonCode;
    result.actualValue = renderValue(outcome.found);
    result.expectedValue = renderValue(outcome.expected);
    result.evaluationFound = outcome.found;
    result.evaluationExpected = outcome.expected;
    result.evaluationComparisonOperator = outcome.comparisonOperator;
    return result;
  }

  /** Renders the stored representation of one plugin value. */
  public static String renderValue(RecordHealthCheckValue value) {
    if (value == null) {
      return null;
    }
    if (value.isList()) {
      List<String> members = value.storedValues;
      return members == null ? null : String.join(members, ', ');
    }
    return value.storedValue;
  }

  /**
   * Validates one plugin result and applies framework-owned display metadata.
   *
   * @param rule Rule metadata governing the plugin result.
   * @param record Record evaluated by the plugin.
   * @param fallbackResult Safe framework result used for contract violations.
   * @param apexResult Result returned by the plugin.
   * @param formulaEvaluator Merge-token resolver carrying the current run context.
   * @return The finalized plugin result or the supplied safe fallback.
   */
  public static RecordHealthCheckInternalResult finalizeResult(
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckInternalResult fallbackResult,
    RecordHealthCheckInternalResult apexResult,
    RecordHealthCheckFormulaEvaluator formulaEvaluator
  ) {
    if (!VALID_STATUSES.contains(apexResult.status)) {
      return contractError(
        rule,
        fallbackResult,
        '"' +
          rule.ApexClass__c +
          '" returned an unsupported status: "' +
          apexResult.status +
          '". Expected one of PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR.'
      );
    }
    String displayContractError = applyTypedDisplayValues(apexResult);
    if (displayContractError != null) {
      return contractError(
        rule,
        fallbackResult,
        '"' + rule.ApexClass__c + '" ' + displayContractError
      );
    }
    if (
      (apexResult.status == 'PASS' || apexResult.status == 'FAIL') &&
      (String.isBlank(apexResult.actualValue) ||
      String.isBlank(apexResult.expectedValue))
    ) {
      return contractError(
        rule,
        fallbackResult,
        '"' +
          rule.ApexClass__c +
          '" returned ' +
          apexResult.status +
          ' without required Found / Expected values. Apex checks must set both result.actualValue and result.expectedValue for PASS and FAIL.'
      );
    }
    if (apexResult.status == 'FAIL') {
      apexResult.severity = rule.FailureSeverity__c;
      if (String.isBlank(apexResult.message)) {
        String resolved = formulaEvaluator.resolveMergeFields(
          rule.FailureMessage__c,
          record,
          rule,
          apexResult,
          true
        );
        apexResult.message = String.isNotBlank(resolved)
          ? resolved
          : 'Check failed.';
      }
    }
    apexResult.ruleDeveloperName = rule.DeveloperName;
    apexResult.label = rule.CheckTitle__c;
    apexResult.priority = rule.EvaluationOrder__c;
    apexResult.evaluatorType = 'APEX';
    return apexResult;
  }

  private static RecordHealthCheckInternalResult contractError(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckInternalResult fallbackResult,
    String detailMessage
  ) {
    fallbackResult.status = 'ERROR';
    fallbackResult.reasonCode = 'APEX_EVALUATOR_ERROR';
    fallbackResult.message = safeCannotEvaluateMessage(rule);
    fallbackResult.detailMessage = detailMessage;
    return fallbackResult;
  }

  private static String applyTypedDisplayValues(
    RecordHealthCheckInternalResult apexResult
  ) {
    if (
      String.isBlank(apexResult.actualValue) &&
      apexResult.actualDisplayValue != null
    ) {
      if (!isValidPluginFormat(apexResult.actualDisplayFormat)) {
        return 'returned an invalid actualDisplayFormat. Use a canonical uppercase format API name.';
      }
      apexResult.actualValue = RecordHealthCheckDisplayFormat.render(
        apexResult.actualDisplayValue,
        apexResult.actualDisplayFormat,
        apexResult.actualCurrencyIsoCode
      );
    }
    if (
      String.isBlank(apexResult.expectedValue) &&
      apexResult.expectedDisplayValue != null
    ) {
      if (!isValidPluginFormat(apexResult.expectedDisplayFormat)) {
        return 'returned an invalid expectedDisplayFormat. Use a canonical uppercase format API name.';
      }
      apexResult.expectedValue = RecordHealthCheckDisplayFormat.render(
        apexResult.expectedDisplayValue,
        apexResult.expectedDisplayFormat,
        apexResult.expectedCurrencyIsoCode
      );
    }
    return null;
  }

  private static Boolean isValidPluginFormat(String formatName) {
    return String.isBlank(formatName) ||
      RecordHealthCheckDisplayFormat.isFormatApiName(formatName);
  }

  private static String safeCannotEvaluateMessage(
    Record_Health_Check_Rule__mdt rule
  ) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
