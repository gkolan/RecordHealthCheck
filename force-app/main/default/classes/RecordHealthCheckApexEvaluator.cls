/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckApexEvaluator {
  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();

  public RecordHealthCheckApexEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    formulaEvaluator.withRunContext(value);
    return this;
  }

  // ─── Public entry point ───────────────────────────────────────────────────

  public RecordHealthCheckInternalResult evaluate(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record
  ) {
    if (recordId == null) {
      RecordHealthCheckInternalResult result = baseResult(rule);
      result.status = RecordHealthCheckStatus.ERROR;
      result.reasonCode = 'APEX_EVALUATOR_ERROR';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = 'No record context was provided to the Apex evaluator.';
      return result;
    }
    Map<Id, RecordHealthCheckInternalResult> results = evaluateScope(
      rule,
      new List<Id>{ recordId },
      new Map<Id, SObject>{ recordId => record },
      RecordHealthCheckDescribeCache.objectApiName(recordId),
      null,
      null
    );
    return results.get(recordId);
  }

  /** Instantiates and invokes one Apex plugin exactly once for a complete scope. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check_Rule__mdt rule,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    String objectApiName,
    String checkSetDeveloperName,
    String runId
  ) {
    if (String.isBlank(rule.ApexClass__c)) {
      return scopeError(
        rule,
        recordIds,
        'APEX_CLASS_NOT_FOUND',
        'Apex Class Name is blank.'
      );
    }
    Type evaluatorType = Type.forName(rule.ApexClass__c);
    if (evaluatorType == null) {
      return scopeError(
        rule,
        recordIds,
        'APEX_CLASS_NOT_FOUND',
        'Class "' + rule.ApexClass__c + '" was not found.'
      );
    }

    Object instance = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      rule.ApexClass__c
    );
    try {
      if (instance == null) {
        instance = RecordHealthCheckPluginDispatch.instantiate(evaluatorType);
      }
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      return scopeError(
        rule,
        recordIds,
        'APEX_CLASS_NOT_FOUND',
        ex.getMessage()
      );
    }
    if (!(instance instanceof RecordHealthCheckRule)) {
      return scopeError(
        rule,
        recordIds,
        'APEX_CLASS_NOT_FOUND',
        'The configured class does not implement RecordHealthCheckRule.'
      );
    }

    Map<String, Object> parameters = new Map<String, Object>();
    if (String.isNotBlank(rule.ApexParametersJson__c)) {
      try {
        Object parsed = JSON.deserializeUntyped(rule.ApexParametersJson__c);
        if (!(parsed instanceof Map<String, Object>)) {
          return scopeError(
            rule,
            recordIds,
            'INVALID_APEX_PARAMETERS',
            'ApexParametersJson__c must be a JSON object.'
          );
        }
        parameters = (Map<String, Object>) parsed;
      } catch (JSONException ex) {
        return scopeError(
          rule,
          recordIds,
          'INVALID_APEX_PARAMETERS',
          ex.getMessage()
        );
      }
    }

    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      objectApiName,
      recordIds,
      parameters,
      rule.DeveloperName,
      checkSetDeveloperName,
      runId
    );
    Map<Id, RecordHealthCheckOutcome> outcomes;
    try {
      outcomes = RecordHealthCheckPluginDispatch.run(
        (RecordHealthCheckRule) instance,
        scope
      );
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      return scopeError(rule, recordIds, ex.reasonCode, ex.getMessage());
    }

    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult fallback = baseResult(rule);
      RecordHealthCheckOutcome outcome = outcomes.get(recordId);
      if (
        outcome != null &&
        RecordHealthCheckStatus.ERROR.equals(outcome.status) &&
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING.equals(
          outcome.reasonCode
        )
      ) {
        fallback.status = RecordHealthCheckStatus.ERROR;
        fallback.reasonCode = outcome.reasonCode;
        fallback.message = safeCannotEvaluateMessage(rule);
        fallback.detailMessage = 'The plugin returned no result for this record.';
        results.put(recordId, fallback);
      } else {
        results.put(
          recordId,
          RecordHealthCheckApexResultFinalizer.finalizeResult(
            rule,
            loadedRecords.get(recordId),
            fallback,
            RecordHealthCheckApexResultFinalizer.toInternalResult(
              outcome,
              fallback
            ),
            formulaEvaluator
          )
        );
      }
    }
    return results;
  }

  private Map<Id, RecordHealthCheckInternalResult> scopeError(
    Record_Health_Check_Rule__mdt rule,
    List<Id> recordIds,
    String reasonCode,
    String detail
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult result = baseResult(rule);
      result.status = reasonCode != null && reasonCode.startsWith('PLUGIN_')
        ? RecordHealthCheckStatus.ERROR
        : RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
      result.reasonCode = reasonCode;
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = detail;
      results.put(recordId, result);
    }
    return results;
  }

  private RecordHealthCheckInternalResult baseResult(
    Record_Health_Check_Rule__mdt rule
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.ruleDeveloperName = rule.DeveloperName;
    result.label = rule.CheckTitle__c;
    result.priority = rule.EvaluationOrder__c;
    result.evaluatorType = 'APEX';
    return result;
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
