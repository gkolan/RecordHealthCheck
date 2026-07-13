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

  // ─── Public entry point ───────────────────────────────────────────────────

  public RecordHealthCheckResult evaluate(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record
  ) {
    Long startMs = System.currentTimeMillis();
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.checkDeveloperName = rule.DeveloperName;
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

    Object instance;
    try {
      instance = evaluatorType.newInstance();
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

    // 3. Build context and invoke
    RecordHealthCheckContext context = new RecordHealthCheckContext();
    context.recordId = recordId;
    context.objectApiName = RecordHealthCheckDescribeCache.objectApiName(
      recordId
    );
    context.record = record;
    context.parameters = parameters;
    context.checkDeveloperName = rule.DeveloperName;

    return invokeAndFinalize(
      (RecordHealthCheckRule) instance,
      context,
      rule,
      record,
      result
    );
  }

  @TestVisible
  private RecordHealthCheckResult invokeAndFinalize(
    RecordHealthCheckRule evaluator,
    RecordHealthCheckContext context,
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckResult fallbackResult
  ) {
    RecordHealthCheckResult apexResult;
    try {
      apexResult = evaluator.evaluate(context);
    } catch (Exception ex) {
      // Pluggable Apex must catch its own exceptions, but if it doesn't
      // we catch here and return ERROR with a safe message.
      fallbackResult.status = 'ERROR';
      fallbackResult.reasonCode = 'APEX_EVALUATOR_ERROR';
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage = ex.getMessage();
      return fallbackResult;
    }

    if (apexResult == null) {
      fallbackResult.status = 'ERROR';
      fallbackResult.reasonCode = 'APEX_EVALUATOR_ERROR';
      fallbackResult.message = safeCannotEvaluateMessage(rule);
      fallbackResult.detailMessage =
        '"' +
        rule.ApexClass__c +
        '" returned a null result.';
      return fallbackResult;
    }

    return finalizeApexResult(rule, record, fallbackResult, apexResult);
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
    apexResult.checkDeveloperName = rule.DeveloperName;
    apexResult.label = rule.CheckTitle__c;
    apexResult.priority = rule.EvaluationOrder__c;
    apexResult.evaluatorType = 'APEX';

    return apexResult;
  }

  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
