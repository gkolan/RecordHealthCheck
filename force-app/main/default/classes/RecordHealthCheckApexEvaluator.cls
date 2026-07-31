/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckApexEvaluator {
  private static final Set<String> VALID_APEX_STATUSES = new Set<String>{
    'PASS',
    'FAIL',
    'SKIPPED',
    'UNABLE_TO_EVALUATE',
    'ERROR'
  };

  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();

  public RecordHealthCheckApexEvaluator withRunContext(
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
    result.evaluatorType = 'APEX';

    try {
      result = runApexCheck(rule, recordId, record, result);
    } catch (Exception ex) {
      // Last-resort catch — the inner dispatch should never surface here
      // but platform-level failures (e.g. Type.forName on a missing class
      // when already handled) must not escape the Controller boundary.
      result.status = 'ERROR';
      result.reasonCode = 'APEX_EVALUATOR_ERROR';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = ex.getMessage();
    }

    result.durationMs = System.currentTimeMillis() - startMs;
    return result;
  }

  // ─── Dispatch logic ───────────────────────────────────────────────────────

  private RecordHealthCheckResult runApexCheck(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record,
    RecordHealthCheckResult result
  ) {
    // 1. Resolve the Apex class
    if (String.isBlank(rule.ApexClass__c)) {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'APEX_CLASS_NOT_FOUND';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = 'Apex Class Name is blank.';
      return result;
    }

    Type evaluatorType = Type.forName(rule.ApexClass__c);
    if (evaluatorType == null) {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'APEX_CLASS_NOT_FOUND';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = 'Class "' + rule.ApexClass__c + '" was not found.';
      return result;
    }

    Object instance = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      rule.ApexClass__c
    );
    try {
      if (instance == null) {
        instance = evaluatorType.newInstance();
      }
    } catch (Exception ex) {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'APEX_CLASS_NOT_FOUND';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage =
        'Could not instantiate "' +
        rule.ApexClass__c +
        '": ' +
        ex.getMessage();
      return result;
    }

    if (!(instance instanceof RecordHealthCheckRule)) {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'APEX_CLASS_NOT_FOUND';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage =
        '"' +
        rule.ApexClass__c +
        '" does not implement RecordHealthCheckRule.';
      return result;
    }

    // 2. Parse ApexParametersJson__c
    Map<String, Object> parameters = new Map<String, Object>();
    if (String.isNotBlank(rule.ApexParametersJson__c)) {
      try {
        Object parsed = JSON.deserializeUntyped(rule.ApexParametersJson__c);
        if (parsed instanceof Map<String, Object>) {
          parameters = (Map<String, Object>) parsed;
        } else {
          result.status = 'UNABLE_TO_EVALUATE';
          result.reasonCode = 'INVALID_APEX_PARAMETERS';
          result.message = safeCannotEvaluateMessage(rule);
          result.detailMessage = 'ApexParametersJson__c must be a JSON object, not an array or single value.';
          return result;
        }
      } catch (JSONException jex) {
        result.status = 'UNABLE_TO_EVALUATE';
        result.reasonCode = 'INVALID_APEX_PARAMETERS';
        result.message = safeCannotEvaluateMessage(rule);
        result.detailMessage =
          'ApexParametersJson__c is not valid JSON: ' + jex.getMessage();
        return result;
      }
    }

    // A null recordId means there is no record context, so an Apex evaluator has
    // nothing to run against. Guard explicitly: the engine guarantees a non-null
    // recordId in the normal flow, but deriving objectApiName is now null-safe, so
    // without this a plugin would run against a passed-in record with a null
    // context recordId instead of failing cleanly.
    if (recordId == null) {
      result.status = 'ERROR';
      result.reasonCode = 'APEX_EVALUATOR_ERROR';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = 'No record context was provided to the Apex evaluator.';
      return result;
    }

    // 3. Build a scope and invoke.
    // The record page evaluates one record, but it does so through the same
    // bulk contract a two-hundred-record scan uses. Interactive evaluation is a
    // bulk evaluation whose scope happens to contain one record, not a
    // different API, path, or standard.
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      RecordHealthCheckDescribeCache.objectApiName(recordId),
      new List<Id>{ recordId },
      parameters,
      rule.DeveloperName,
      null,
      null
    );

    return invokeAndFinalize(
      (RecordHealthCheckRule) instance,
      scope,
      rule,
      record,
      result
    );
  }

  @TestVisible
  private RecordHealthCheckResult invokeAndFinalize(
    RecordHealthCheckRule evaluator,
    RecordHealthCheckScope scope,
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckResult fallbackResult
  ) {
    Id recordId = scope.recordIds[0];
    Map<Id, RecordHealthCheckOutcome> outcomes;
    try {
      outcomes = RecordHealthCheckPluginDispatch.run(evaluator, scope);
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      // The check broke its contract but changed nothing, so the failure is
      // attributable to the rule and can safely become a result.
      fallbackResult.status = RecordHealthCheckStatus.ERROR;
      fallbackResult.reasonCode = ex.reasonCode;
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage = ex.getMessage();
      return fallbackResult;
    }
    // RecordHealthCheckPluginDispatch.SideEffectException is deliberately NOT
    // caught. A check that changed something must fail the transaction so the
    // change rolls back; converting it into a result here would let the
    // mutation commit alongside the row reporting it.

    RecordHealthCheckOutcome outcome = outcomes.get(recordId);
    if (
      outcome != null &&
      RecordHealthCheckStatus.ERROR.equals(outcome.status) &&
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING.equals(
        outcome.reasonCode
      )
    ) {
      fallbackResult.status = RecordHealthCheckStatus.ERROR;
      fallbackResult.reasonCode = outcome.reasonCode;
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage =
        '"' +
        rule.ApexClass__c +
        '" returned no result for this record.';
      return fallbackResult;
    }

    return finalizeApexResult(
      rule,
      record,
      fallbackResult,
      toLegacyResult(outcome, fallbackResult)
    );
  }

  /**
   * Bridges an Outcome onto the 1.x result shape the rest of the engine still
   * speaks. The engine owns identity and severity, so only the verdict and its
   * values cross over; everything a plugin is not allowed to set stays unset.
   */
  private RecordHealthCheckResult toLegacyResult(
    RecordHealthCheckOutcome outcome,
    RecordHealthCheckResult template
  ) {
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.ruleDeveloperName = template.ruleDeveloperName;
    result.label = template.label;
    result.priority = template.priority;
    result.evaluatorType = template.evaluatorType;
    result.status = outcome.status;
    result.reasonCode = outcome.reasonCode;
    result.actualValue = renderValue(outcome.found);
    result.expectedValue = renderValue(outcome.expected);
    return result;
  }

  private String renderValue(RecordHealthCheckValue value) {
    if (value == null) {
      return null;
    }
    if (value.isList()) {
      List<String> members = value.storedValues;
      return members == null ? null : String.join(members, ', ');
    }
    return value.storedValue;
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  @TestVisible
  private RecordHealthCheckResult finalizeApexResult(
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckResult fallbackResult,
    RecordHealthCheckResult apexResult
  ) {
    // Validate the status the plugin returned. A custom class can return
    // any string; an unrecognized value would silently mislabel the row
    // in the LWC (it falls into the "Unable to Check" bucket). Reject it
    // with a clear config error instead.
    if (!VALID_APEX_STATUSES.contains(apexResult.status)) {
      fallbackResult.status = 'ERROR';
      fallbackResult.reasonCode = 'APEX_EVALUATOR_ERROR';
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage =
        '"' +
        rule.ApexClass__c +
        '" returned an unsupported status: "' +
        apexResult.status +
        '". Expected one of PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR.';
      return fallbackResult;
    }

    String displayContractError = applyTypedDisplayValues(apexResult);
    if (displayContractError != null) {
      fallbackResult.status = 'ERROR';
      fallbackResult.reasonCode = 'APEX_EVALUATOR_ERROR';
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage =
        '"' +
        rule.ApexClass__c +
        '" ' +
        displayContractError;
      return fallbackResult;
    }

    // Determinate Apex results must provide the comparison values the UI needs
    // for the standard Found / Expected display. The interface cannot enforce
    // field population at compile time, so the evaluator enforces it here.
    if (
      (apexResult.status == 'PASS' || apexResult.status == 'FAIL') &&
      (String.isBlank(apexResult.actualValue) ||
      String.isBlank(apexResult.expectedValue))
    ) {
      fallbackResult.status = 'ERROR';
      fallbackResult.reasonCode = 'APEX_EVALUATOR_ERROR';
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage =
        '"' +
        rule.ApexClass__c +
        '" returned ' +
        apexResult.status +
        ' without required Found / Expected values. Apex checks must set both result.actualValue and result.expectedValue for PASS and FAIL.';
      return fallbackResult;
    }

    // Post-process FAIL: metadata controls severity; a non-blank plugin message is
    // preserved, and FailureMessage__c only fills in when the plugin omitted one.
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

    // Ensure identifying fields are always set from metadata (Apex may omit them)
    apexResult.ruleDeveloperName = rule.DeveloperName;
    apexResult.label = rule.CheckTitle__c;
    apexResult.priority = rule.EvaluationOrder__c;
    apexResult.evaluatorType = 'APEX';

    return apexResult;
  }

  private static String applyTypedDisplayValues(
    RecordHealthCheckResult apexResult
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
    return (String.isBlank(formatName) ||
    RecordHealthCheckDisplayFormat.isFormatApiName(formatName));
  }

  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
