/** Builds the authorized, browser-facing trace for one Rule evaluation. */
public with sharing class RecordHealthCheckDiagnosticTrace {
  /**
   * Populates configuration and resolution snapshots on an authorized detail object.
   * @param rule Rule metadata used for the evaluation.
   * @param record Evaluated record with all planned merge fields loaded.
   * @param result Internal result after display finalization.
   * @param detail Authorized diagnostic response object to populate.
   */
  public static void populate(
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckAdminDetail detail
  ) {
    Map<String, Object> configuration = new Map<String, Object>();
    putValue(configuration, 'evaluationType', rule.EvaluationType__c);
    putValue(
      configuration,
      'passConditionFormula',
      rule.PassConditionFormula__c
    );
    putValue(configuration, 'sourceQueryTemplate', rule.SourceQuery__c);
    putValue(configuration, 'sourceQueryField', rule.SourceQueryField__c);
    putValue(configuration, 'comparisonQueryTemplate', rule.ComparisonQuery__c);
    putValue(
      configuration,
      'comparisonQueryField',
      rule.ComparisonQueryField__c
    );
    putValue(configuration, 'comparisonOperator', rule.ComparisonOperator__c);
    putValue(configuration, 'expectedValueSource', rule.ExpectedValueSource__c);
    putValue(configuration, 'expectedFixedValue', rule.ExpectedFixedValue__c);
    putValue(
      configuration,
      'expectedRecordFormula',
      rule.ExpectedRecordFormula__c
    );
    putValue(configuration, 'queryResultHandling', rule.QueryResultHandling__c);
    putValue(configuration, 'noRowsResult', rule.NoRowsResult__c);
    putValue(configuration, 'emptyValueHandling', rule.EmptyValueHandling__c);
    putValue(configuration, 'displayFoundFormula', rule.DisplayFoundFormula__c);
    putValue(
      configuration,
      'displayExpectedFormula',
      rule.DisplayExpectedFormula__c
    );
    putValue(configuration, 'displayFoundText', rule.DisplayFoundText__c);
    putValue(configuration, 'displayExpectedText', rule.DisplayExpectedText__c);
    putValue(configuration, 'displayValueFormat', rule.DisplayValueFormat__c);
    putValue(configuration, 'failureMessageTemplate', rule.FailureMessage__c);
    putValue(
      configuration,
      'unableMessageTemplate',
      rule.UnableToEvaluateMessage__c
    );
    putValue(configuration, 'fixMessageTemplate', rule.FixMessage__c);
    putValue(configuration, 'actionLabelTemplate', rule.ActionLabel__c);
    putValue(configuration, 'actionUrlTemplate', rule.ActionUrl__c);
    putValue(configuration, 'apexClass', rule.ApexClass__c);
    putValue(configuration, 'apexParametersJson', rule.ApexParametersJson__c);
    putValue(configuration, 'prerequisiteRule', rule.PrerequisiteRule__c);
    putValue(configuration, 'applicabilityMode', rule.ApplicabilityMode__c);
    putValue(
      configuration,
      'applicabilityFormula',
      rule.ApplicabilityFormula__c
    );
    putValue(configuration, 'maxQueryRows', rule.MaxQueryRows__c);

    Map<String, Object> resolution = new Map<String, Object>{
      'status' => result.status,
      'reasonCode' => result.reasonCode,
      'found' => result.actualValue,
      'expected' => result.expectedValue,
      'renderedMessage' => result.message,
      'renderedFix' => result.fixInstructions,
      'renderedActionLabel' => result.actionLabel,
      'renderedActionUrl' => result.actionUrl,
      'durationMs' => result.durationMs
    };
    Integer maxRows = rule.MaxQueryRows__c == null
      ? RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      : (Integer) rule.MaxQueryRows__c;
    addResolvedQuery(
      resolution,
      'sourceQuery',
      rule.SourceQuery__c,
      record,
      maxRows
    );
    addResolvedQuery(
      resolution,
      'comparisonQuery',
      rule.ComparisonQuery__c,
      record,
      maxRows
    );
    detail.configurationJson = JSON.serialize(configuration);
    detail.resolutionJson = JSON.serialize(resolution);
  }

  private static void addResolvedQuery(
    Map<String, Object> resolution,
    String key,
    String template,
    SObject record,
    Integer maxRows
  ) {
    if (String.isBlank(template) || record == null) {
      return;
    }
    try {
      String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
        template,
        record
      );
      resolution.put(key + 'AfterMerge', bound);
      resolution.put(
        key + 'PreparedPerRecordQuery',
        RecordHealthCheckSoqlTemplate.prepareForExecution(bound, maxRows)
      );
    } catch (Exception error) {
      resolution.put(key + 'ResolutionError', error.getMessage());
    }
  }

  private static void putValue(
    Map<String, Object> values,
    String key,
    Object value
  ) {
    if (value != null && String.isNotBlank(String.valueOf(value))) {
      values.put(key, value);
    }
  }
}
