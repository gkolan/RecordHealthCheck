/** Builds applicability and public result representations for scope runs. */
public with sharing class RecordHealthCheckScopeResultSupport {
  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();

  public void finalizeDisplay(
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckInternalResult result,
    Boolean showDiagnostics
  ) {
    if (result == null) {
      return;
    }
    if (record != null && String.isNotBlank(result.message)) {
      result.message = formulaEvaluator.resolveMergeFields(
        result.message,
        record,
        rule,
        result,
        true
      );
    }
    if (result.status == RecordHealthCheckStatus.FAIL && record != null) {
      result.fixInstructions = String.isBlank(rule.FixMessage__c)
        ? null
        : formulaEvaluator.resolveMergeFields(
            rule.FixMessage__c,
            record,
            rule,
            result,
            true
          );
      if (String.isNotBlank(rule.ActionUrl__c)) {
        try {
          String url = sanitizeActionUrl(
            formulaEvaluator.resolveUrlMergeFields(
              rule.ActionUrl__c,
              record,
              rule,
              result
            )
          );
          if (url != null) {
            result.actionUrl = url;
            result.actionLabel = String.isBlank(rule.ActionLabel__c)
              ? 'Fix this'
              : formulaEvaluator.resolveMergeFields(
                  rule.ActionLabel__c,
                  record,
                  rule,
                  result,
                  true
                );
          }
        } catch (RecordHealthCheckTemplateService.TemplateException error) {
          result.detailMessage = error.getMessage();
        }
      }
    }
    Boolean restricted = RecordHealthCheckReasonCodes.isDiagnosticsOnly(
      result.reasonCode
    );
    if (showDiagnostics && RecordHealthCheckAccess.canViewDetails()) {
      result.adminDetail = new RecordHealthCheckAdminDetail();
      result.adminDetail.containsRestrictedDetail = restricted;
      result.adminDetail.reasonCode = result.reasonCode;
      result.adminDetail.message = result.detailMessage;
      RecordHealthCheckDiagnosticTrace.populate(
        rule,
        record,
        result,
        result.adminDetail
      );
    }
    if (restricted) {
      result.reasonCode = RecordHealthCheckReasonCodes.CANNOT_EVALUATE;
    }
  }

  public String sanitizeActionUrl(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String url = value.trim();
    if (
      url.length() > 2000 ||
      url.contains('\n') ||
      url.contains('\r') ||
      url.contains('\t') ||
      url.contains('\\') ||
      url.startsWith('//')
    ) {
      return null;
    }
    return url.startsWith('/') || url.toLowerCase().startsWith('https://')
      ? url
      : null;
  }

  public RecordHealthCheckInternalResult findPrerequisiteBlock(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    String prerequisiteName = rule.PrerequisiteRule__c;
    if (String.isBlank(prerequisiteName)) {
      return null;
    }
    RecordHealthCheckResultItem prior = itemsByIdentity.get(
      itemKey(recordId, prerequisiteName)
    );
    if (
      prior == null &&
      String.isNotBlank(rule.QualifiedApiName) &&
      rule.QualifiedApiName.contains('__')
    ) {
      String namespacePrefix = rule.QualifiedApiName.substringBefore('__');
      prior = itemsByIdentity.get(
        itemKey(recordId, namespacePrefix + '__' + prerequisiteName)
      );
    }
    if (prior == null) {
      // A qualified single-Rule request intentionally has no results from the
      // rest of its owning Check Set. Missing history is unknown, not evidence
      // that the prerequisite failed. Full Check Set requests still enforce
      // every prerequisite that produced a prior result.
      return null;
    }
    if (
      prior.evaluation != null &&
      RecordHealthCheckStatus.PASS.equals(prior.evaluation.status)
    ) {
      return null;
    }
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.SKIPPED;
    result.reasonCode = RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET;
    result.message =
      'Skipped because Prerequisite Rule "' +
      prerequisiteName +
      '" did not pass.';
    return result;
  }

  public RecordHealthCheckInternalResult applicabilityResult(
    Record_Health_Check_Rule__mdt rule,
    SObject record
  ) {
    if (
      String.isBlank(rule.ApplicabilityMode__c) ||
      rule.ApplicabilityMode__c == 'ALL_RECORDS'
    ) {
      return null;
    }
    if (rule.ApplicabilityMode__c != 'WHEN_FORMULA_TRUE') {
      return unavailableResult(rule, 'APPLICABILITY_NOT_MIGRATED');
    }
    String[] reasonCode = new List<String>{ null };
    Boolean applies = formulaEvaluator.evaluateApplicabilityFormula(
      rule.ApplicabilityFormula__c,
      record,
      reasonCode
    );
    if (applies == true) {
      return null;
    }
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = applies == false
      ? RecordHealthCheckStatus.SKIPPED
      : RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    result.reasonCode = applies == false
      ? 'APPLICABILITY_NOT_MET'
      : reasonCode[0];
    result.message = applies == false
      ? rule.ApplicabilityNotMetMessage__c
      : rule.UnableToEvaluateMessage__c;
    return result;
  }

  public Map<Id, RecordHealthCheckInternalResult> applicabilityResults(
    Record_Health_Check_Rule__mdt rule,
    List<Id> recordIds,
    Map<Id, SObject> recordsById
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    if (rule.ApplicabilityMode__c != 'WHEN_COUNT_QUERY_MATCHES') {
      for (Id recordId : recordIds) {
        SObject record = recordsById.get(recordId);
        if (record != null) {
          RecordHealthCheckInternalResult result = applicabilityResult(
            rule,
            record
          );
          if (result != null) {
            results.put(recordId, result);
          }
        }
      }
      return results;
    }

    try {
      if (
        !RecordHealthCheckSoqlTemplate.isSingleCountQuery(
          rule.ApplicabilityCountQuery__c
        ) || rule.ApplicabilityCountThreshold__c == null
      ) {
        return unavailableForScope(rule, recordIds, 'INVALID_SOQL_TEMPLATE');
      }
      RecordHealthCheckBulkQuerySupport.Result scopeCounts = RecordHealthCheckBulkQuerySupport.execute(
        rule.ApplicabilityCountQuery__c,
        recordsById,
        RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      );
      for (Id recordId : recordIds) {
        if (!recordsById.containsKey(recordId)) {
          continue;
        }
        List<SObject> rows = scopeCounts.rowsByRecordId.get(recordId);
        Integer count = rows == null || rows.isEmpty()
          ? 0
          : aggregateCount((AggregateResult) rows[0]);
        Boolean applies = compareCount(
          rule.ApplicabilityCountOperator__c,
          count,
          (Integer) rule.ApplicabilityCountThreshold__c
        );
        if (applies == null) {
          results.put(recordId, unavailableResult(rule, 'INVALID_OPERATOR'));
        } else if (!applies) {
          results.put(
            recordId,
            rule.EvaluationType__c == 'COMPARE_TWO_QUERIES'
              ? RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
                  rule,
                  new RecordHealthCheckInternalResult(),
                  null
                )
              : skippedResult(rule)
          );
        }
      }
      return results;
    } catch (RecordHealthCheckEvaluatorException ex) {
      return unavailableForScope(rule, recordIds, ex.reasonCode);
    } catch (Exception ex) {
      return unavailableForScope(rule, recordIds, 'UNABLE_TO_EVALUATE');
    }
  }

  public Integer aggregateCount(AggregateResult row) {
    Map<String, Object> values = row.getPopulatedFieldsAsMap();
    for (String fieldName : values.keySet()) {
      if (!fieldName.equalsIgnoreCase('rhcCorrelation')) {
        return Integer.valueOf(String.valueOf(values.get(fieldName)));
      }
    }
    return 0;
  }

  public Boolean compareCount(
    String operator,
    Integer count,
    Integer threshold
  ) {
    if (operator == 'EQUALS') {
      return count == threshold;
    }
    if (operator == 'NOT_EQUALS') {
      return count != threshold;
    }
    if (operator == 'GREATER_THAN') {
      return count > threshold;
    }
    if (operator == 'GREATER_THAN_OR_EQUAL') {
      return count >= threshold;
    }
    if (operator == 'LESS_THAN') {
      return count < threshold;
    }
    if (operator == 'LESS_THAN_OR_EQUAL') {
      return count <= threshold;
    }
    return null;
  }

  public Map<Id, RecordHealthCheckInternalResult> unavailableForScope(
    Record_Health_Check_Rule__mdt rule,
    List<Id> recordIds,
    String reasonCode
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      results.put(recordId, unavailableResult(rule, reasonCode));
    }
    return results;
  }

  public RecordHealthCheckInternalResult skippedResult(
    Record_Health_Check_Rule__mdt rule
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.SKIPPED;
    result.reasonCode = RecordHealthCheckReasonCodes.NOT_APPLICABLE_BY_COUNT;
    result.message = String.isNotBlank(rule.ApplicabilityNotMetMessage__c)
      ? rule.ApplicabilityNotMetMessage__c
      : 'This check does not apply because its count threshold was not met.';
    return result;
  }

  public RecordHealthCheckInternalResult unavailableResult(
    Record_Health_Check_Rule__mdt rule,
    String reasonCode
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    result.reasonCode = reasonCode;
    result.message = rule.UnableToEvaluateMessage__c;
    return result;
  }

  public RecordHealthCheckInternalResult copyResult(
    RecordHealthCheckInternalResult source
  ) {
    return (RecordHealthCheckInternalResult) JSON.deserialize(
      JSON.serialize(source),
      RecordHealthCheckInternalResult.class
    );
  }

  public RecordHealthCheckResultItem toItem(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    RecordHealthCheckInternalResult internalResult,
    RecordHealthCheckResultMode resultMode
  ) {
    if (internalResult == null) {
      internalResult = unavailableResult(rule, 'UNABLE_TO_EVALUATE');
    }
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = recordId;
    evaluation.ruleQualifiedApiName = rule.QualifiedApiName;
    evaluation.status = internalResult.status;
    evaluation.severity = String.isBlank(internalResult.severity)
      ? internalResult.severity
      : RecordHealthCheckConstants.toLwcSeverity(internalResult.severity);
    evaluation.reasonCode = internalResult.reasonCode;
    evaluation.found = internalResult.evaluationFound != null
      ? internalResult.evaluationFound
      : internalResult.actualValue == null
          ? null
          : RecordHealthCheckValue.ofString(internalResult.actualValue);
    evaluation.expected = internalResult.evaluationExpected != null
      ? internalResult.evaluationExpected
      : internalResult.expectedValue == null
          ? null
          : RecordHealthCheckValue.ofString(internalResult.expectedValue);
    evaluation.comparisonOperator = internalResult.evaluationComparisonOperator;
    if (
      evaluation.comparisonOperator == null &&
      (rule.EvaluationType__c == 'QUERY' ||
      rule.EvaluationType__c == 'COMPARE_TWO_QUERIES')
    ) {
      evaluation.comparisonOperator = rule.ComparisonOperator__c;
    }

    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;
    if (resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY) {
      RecordHealthCheckResultDisplay display = new RecordHealthCheckResultDisplay();
      display.renderedMessage = internalResult.message;
      display.renderedFix = internalResult.fixInstructions;
      display.foundDisplayValue = internalResult.actualValue;
      Boolean hidesRawFormulaCondition =
        internalResult.expectedValueLabel ==
        RecordHealthCheckInternalResult.PASSES_WHEN_LABEL &&
        !RecordHealthCheckAccess.canViewDetails();
      display.expectedDisplayValue = hidesRawFormulaCondition
        ? null
        : internalResult.expectedValue;
      display.foundDisplayFormat = internalResult.actualDisplayFormat;
      display.expectedDisplayFormat = internalResult.expectedDisplayFormat;
      display.foundCurrencyIsoCode = internalResult.actualCurrencyIsoCode;
      display.expectedCurrencyIsoCode = internalResult.expectedCurrencyIsoCode;
      display.actionLabel = internalResult.actionLabel;
      display.actionUrl = internalResult.actionUrl;
      display.adminDetail = internalResult.adminDetail;
      item.display = display;
    }
    return item;
  }

  private String itemKey(Id recordId, String ruleQualifiedApiName) {
    return String.valueOf(recordId) + '|' + ruleQualifiedApiName;
  }
}
