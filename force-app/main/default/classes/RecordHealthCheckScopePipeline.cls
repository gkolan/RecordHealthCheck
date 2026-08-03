/**
 * Scope-based execution pipeline for the public request contract.
 */
public with sharing class RecordHealthCheckScopePipeline {
  private RecordHealthCheckEvaluatorRegistry evaluatorRegistry = new RecordHealthCheckEvaluatorRegistry();
  private RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
  private RecordHealthCheckScopePlanner scopePlanner = new RecordHealthCheckScopePlanner();
  private RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
  @TestVisible
  private Boolean planningFailureOverride = false;
  @TestVisible
  private static String evaluatorFailureOverride;

  /**
   * @param request Immutable qualified selection, record IDs, and options.
   * @return Ordered response with one item per record and selected Rule.
   */
  public RecordHealthCheckResponse evaluate(RecordHealthCheckRequest request) {
    if (request == null) {
      throw new ScopePipelineException(
        'A Record Health Check request is required.'
      );
    }

    Integer suppliedCount = request.recordIds.size();
    if (suppliedCount > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE) {
      throw new ScopePipelineException(
        'MAX_RECORDS_PER_SCOPE_EXCEEDED: suppliedCount=' +
          suppliedCount +
          ', ceiling=' +
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE
      );
    }
    List<Id> recordIds = dedupeRecordIds(request.recordIds);

    SelectionContext context = scopePlanner.resolveSelection(request.selection);
    scopePlanner.validateScope(context, recordIds);
    scopePlanner.enforceFormulaBudget(context.rules, recordIds.size());
    scopePlanner.enforceTransactionBudget(
      context.rules,
      recordIds.size(),
      request.options.eventPublication
    );

    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.runId = String.isBlank(request.options.runId)
      ? newRunId()
      : request.options.runId;
    response.recordIds.addAll(recordIds);
    for (Record_Health_Check_Rule__mdt rule : context.rules) {
      response.ruleQualifiedApiNames.add(rule.QualifiedApiName);
    }
    if (recordIds.isEmpty() || context.rules.isEmpty()) {
      return response;
    }

    RecordLoadPlan recordLoad = loadRecords(
      context.objectApiName,
      recordIds,
      context.rules
    );
    Map<Id, SObject> recordsById = recordLoad.recordsById;
    Map<String, RecordHealthCheckResultItem> itemsByIdentity = new Map<String, RecordHealthCheckResultItem>();
    for (Record_Health_Check_Rule__mdt rule : context.rules) {
      evaluateRule(
        rule,
        context,
        recordIds,
        recordsById,
        recordLoad.inaccessibleRuleNames.contains(rule.QualifiedApiName),
        request.options.resultMode,
        response.runId,
        itemsByIdentity
      );
    }

    List<RecordHealthCheckResultItem> allItems = new List<RecordHealthCheckResultItem>();
    for (Id recordId : recordIds) {
      for (Record_Health_Check_Rule__mdt rule : context.rules) {
        RecordHealthCheckResultItem item = itemsByIdentity.get(
          itemKey(recordId, rule.QualifiedApiName)
        );
        allItems.add(item);
        response.summary.add(item.evaluation.status);
        if (
          request.options.resultMode != RecordHealthCheckResultMode.SUMMARY ||
          RecordHealthCheckStatus.isActionable(item.evaluation.status)
        ) {
          response.results.add(item);
        }
      }
    }
    RecordHealthCheckResponse publicationEnvelope = new RecordHealthCheckResponse();
    publicationEnvelope.runId = response.runId;
    publicationEnvelope.recordIds.addAll(response.recordIds);
    publicationEnvelope.ruleQualifiedApiNames.addAll(
      response.ruleQualifiedApiNames
    );
    publicationEnvelope.results.addAll(allItems);
    publicationEnvelope.summary = response.summary;
    RecordHealthCheckLifecyclePublisher.publishResponse(
      publicationEnvelope,
      request.options.eventPublication,
      context.checkSetQualifiedApiName,
      String.valueOf(request.options.executionOrigin)
    );
    return response;
  }

  private RecordLoadPlan loadRecords(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check_Rule__mdt> rules
  ) {
    Set<String> fields = new Set<String>{ 'Id' };
    RecordLoadPlan result = new RecordLoadPlan();
    RecordHealthCheckFieldPlanner fieldPlanner = new RecordHealthCheckFieldPlanner();
    Schema.SObjectType objectType = recordIds[0].getSObjectType();
    for (Record_Health_Check_Rule__mdt rule : rules) {
      try {
        if (planningFailureOverride) {
          throw new RecordHealthCheckTemplateService.TemplateException(
            'Synthetic planning failure.'
          );
        }
        RecordHealthCheckFieldPlanner.FieldPlan fieldPlan = fieldPlanner.planRecordFields(
          rule,
          objectType
        );
        fields.addAll(fieldPlan.selectedFields);
        if (!fieldPlan.inaccessibleFields.isEmpty()) {
          result.inaccessibleRuleNames.add(rule.QualifiedApiName);
        }
      } catch (RecordHealthCheckTemplateService.TemplateException ex) {
        // Runtime validation turns this Rule into INVALID_CONFIG. Planning must
        // skip its fields so one malformed admin template cannot abort the
        // complete scope before per-Rule isolation begins.
        continue;
      }
    }
    List<String> orderedFields = new List<String>(fields);
    orderedFields.sort();
    String query =
      'SELECT ' +
      String.join(orderedFields, ', ') +
      ' FROM ' +
      objectApiName +
      ' WHERE Id IN :recordIds WITH USER_MODE';
    // code-analyzer-suppress-next-line ApexSOQLInjection: object and field identifiers are resolved from Schema describe metadata, recordIds is a bind variable, and the query runs WITH USER_MODE.
    List<SObject> records = Database.query(query);
    result.recordsById.putAll(new Map<Id, SObject>(records));
    return result;
  }

  @TestVisible
  private void loadRecordsForTest(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check_Rule__mdt> rules
  ) {
    loadRecords(objectApiName, recordIds, rules);
  }

  @TestVisible
  private void evaluateRule(
    Record_Health_Check_Rule__mdt rule,
    SelectionContext context,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    Boolean fieldAccessDenied,
    RecordHealthCheckResultMode resultMode,
    String runId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    List<Id> applicableIds = new List<Id>();
    Map<Id, RecordHealthCheckInternalResult> internalByRecordId = new Map<Id, RecordHealthCheckInternalResult>();
    RecordHealthCheckInternalResult invalidConfiguration = configService.validateRuleForEvaluation(
      rule
    );
    if (invalidConfiguration != null) {
      RecordHealthCheckConfigValidator.discardValidatedPlugin(
        rule.ApexClass__c
      );
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          resultSupport.copyResult(invalidConfiguration)
        );
      }
    }
    if (invalidConfiguration == null && fieldAccessDenied) {
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          recordsById.containsKey(recordId)
            ? resultSupport.unavailableResult(
                rule,
                RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE
              )
            : resultSupport.unavailableResult(rule, 'RECORD_NOT_VISIBLE')
        );
      }
    }
    Map<Id, RecordHealthCheckInternalResult> applicabilityByRecordId = invalidConfiguration ==
      null && !fieldAccessDenied
      ? resultSupport.applicabilityResults(rule, recordIds, recordsById)
      : new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      if (invalidConfiguration != null || fieldAccessDenied) {
        continue;
      }
      SObject record = recordsById.get(recordId);
      if (record == null) {
        internalByRecordId.put(
          recordId,
          resultSupport.unavailableResult(rule, 'RECORD_NOT_VISIBLE')
        );
      } else {
        RecordHealthCheckInternalResult prerequisiteBlock = resultSupport.findPrerequisiteBlock(
          rule,
          recordId,
          itemsByIdentity
        );
        if (prerequisiteBlock != null) {
          internalByRecordId.put(recordId, prerequisiteBlock);
          continue;
        }
        RecordHealthCheckInternalResult applicability = applicabilityByRecordId.get(
          recordId
        );
        if (applicability == null) {
          applicableIds.add(recordId);
        } else {
          internalByRecordId.put(recordId, applicability);
        }
      }
    }

    if (!applicableIds.isEmpty()) {
      try {
        if (evaluatorFailureOverride == 'SIDE_EFFECT') {
          RecordHealthCheckPluginDispatch.SideEffectException sideEffect = new RecordHealthCheckPluginDispatch.SideEffectException(
            'Synthetic plugin side effect.'
          );
          sideEffect.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
          sideEffect.effect = 'DML';
          sideEffect.reversible = true;
          throw sideEffect;
        }
        if (evaluatorFailureOverride == 'EVALUATOR') {
          throw new SyntheticEvaluatorException('Synthetic evaluator failure.');
        }
        internalByRecordId.putAll(
          evaluatorRegistry.evaluateScope(
            rule,
            applicableIds,
            recordsById,
            context,
            runId
          )
        );
      } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
        throw ex;
      } catch (RecordHealthCheckEvaluatorException ex) {
        internalByRecordId.putAll(
          resultSupport.unavailableForScope(rule, applicableIds, ex.reasonCode)
        );
      } catch (Exception ex) {
        internalByRecordId.putAll(
          resultSupport.unavailableForScope(
            rule,
            applicableIds,
            'APEX_EVALUATOR_ERROR'
          )
        );
      }
    }

    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult internalResult = internalByRecordId.get(
        recordId
      );
      resultSupport.finalizeDisplay(
        rule,
        recordsById.get(recordId),
        internalResult,
        context.showDiagnostics == true &&
          resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );
      itemsByIdentity.put(
        itemKey(recordId, rule.QualifiedApiName),
        resultSupport.toItem(rule, recordId, internalResult, resultMode)
      );
    }
  }

  private List<Id> dedupeRecordIds(List<Id> recordIds) {
    List<Id> ordered = new List<Id>();
    Set<Id> seen = new Set<Id>();
    for (Id recordId : recordIds) {
      if (recordId != null && seen.add(recordId)) {
        ordered.add(recordId);
      }
    }
    return ordered;
  }

  private String itemKey(Id recordId, String ruleQualifiedApiName) {
    return String.valueOf(recordId) + '|' + ruleQualifiedApiName;
  }

  private String newRunId() {
    return 'rhc-api-' +
      String.valueOf(Datetime.now().getTime()) +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  public class SelectionContext {
    public String checkSetQualifiedApiName;
    public String checkSetDeveloperName;
    public Boolean checkSetActive;
    public String objectApiName;
    public Boolean showDiagnostics;
    public List<Record_Health_Check_Rule__mdt> rules = new List<Record_Health_Check_Rule__mdt>();
  }

  public class ScopePipelineException extends Exception {
  }

  private class SyntheticEvaluatorException extends Exception {
  }

  private class RecordLoadPlan {
    private Map<Id, SObject> recordsById = new Map<Id, SObject>();
    private Set<String> inaccessibleRuleNames = new Set<String>();
  }
}
