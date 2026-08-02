/**
 * Evaluates Record Health Check requests and persists actionable observations.
 */
public with sharing class RecordHealthCheckCaptureService {
  public static final String SOURCE_APEX = 'APEX';
  public static final String SOURCE_FLOW = 'FLOW';
  public static final String SOURCE_QUEUEABLE = 'QUEUEABLE';
  public static final String SOURCE_BATCH = 'BATCH';

  /**
   * Evaluates one Check Set and captures its run and actionable outcomes.
   *
   * @param checkSetQualifiedApiName QualifiedApiName of the Check Set.
   * @param recordIds Record IDs to evaluate.
   * @param source Exact entry path for operational reporting.
   * @param asyncJobId Optional Queueable or Batch job ID.
   * @return The complete Framework response.
   */
  public static RecordHealthCheckResponse runCheckSet(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    String source,
    Id asyncJobId
  ) {
    validate(checkSetQualifiedApiName, recordIds, source);
    String runId = newRunId(source);
    Record_Health_Check_Run__c runRecord = openRun(
      runId,
      checkSetQualifiedApiName.trim(),
      source,
      recordIds.size(),
      asyncJobId
    );
    try {
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            checkSetQualifiedApiName.trim(),
            recordIds
          )
          .withRunId(runId)
          .withExecutionOrigin(executionOrigin(source))
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
          .withEventPublication(RecordHealthCheckEventPublication.NONE)
      );
      persistResponse(
        runRecord,
        checkSetQualifiedApiName.trim(),
        source,
        response
      );
      return response;
    } catch (Exception ex) {
      persistThrownFailure(
        runRecord,
        checkSetQualifiedApiName.trim(),
        source,
        ex
      );
      throw new CaptureException('Captured health check execution failed.', ex);
    }
  }

  /**
   * Persists a Queueable failure from its Finalizer transaction.
   *
   * @param checkSetQualifiedApiName QualifiedApiName requested by the job.
   * @param asyncJobId Failed Queueable job ID.
   * @param failure Unhandled parent-job exception, when Salesforce supplies it.
   */
  public static void captureQueueableFailure(
    String checkSetQualifiedApiName,
    Id asyncJobId,
    Exception failure
  ) {
    String runId = 'rhc-queueable-finalizer-' + asyncJobId;
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(
      Run_Id__c = runId,
      Source__c = SOURCE_QUEUEABLE,
      Status__c = 'ERROR',
      Check_Set_Qualified_Api_Name__c = checkSetQualifiedApiName,
      Async_Job_Id__c = asyncJobId,
      Requested_By_User_Id__c = UserInfo.getUserId(),
      Started_At__c = System.now(),
      Completed_At__c = System.now(),
      System_Error_Count__c = 1,
      Contract_Version__c = '2.0'
    );
    Database.UpsertResult runResult = Database.upsert(
      runRecord,
      Record_Health_Check_Run__c.Fields.Run_Id__c,
      false
    );
    requireSuccess(runResult, 'QUEUEABLE_FINALIZER_RUN_CAPTURE_FAILED');
    runRecord.Id = runResult.getId();
    String message = failure == null
      ? 'The Queueable job ended without a reported exception.'
      : failure.getMessage();
    upsertObservations(
      new List<Record_Health_Check_Observation__c>{
        new Record_Health_Check_Observation__c(
          Run__c = runRecord.Id,
          Capture_Key__c = hashKey(runId + '|FINALIZER'),
          Observation_Type__c = 'FRAMEWORK_ERROR',
          Source__c = SOURCE_QUEUEABLE,
          Status__c = 'ERROR',
          Error_Code__c = 'QUEUEABLE_UNHANDLED_EXCEPTION',
          Check_Set_Qualified_Api_Name__c = checkSetQualifiedApiName,
          Occurred_At__c = System.now(),
          Message__c = message,
          Exception_Type__c = failure == null ? null : failure.getTypeName(),
          Stack_Trace__c = failure == null
            ? null
            : failure.getStackTraceString(),
          Contains_Restricted_Detail__c = true,
          Contract_Version__c = '2.0'
        )
      }
    );
  }

  /** Captures actionable Framework Rule Result lifecycle events. */
  public static void captureRuleEvents(
    List<Record_Health_Check_Rule_Result__e> events
  ) {
    Map<String, String> sourceByRunId = new Map<String, String>();
    for (Record_Health_Check_Rule_Result__e eventRecord : events) {
      if (isActionable(eventRecord.Status__c)) {
        sourceByRunId.put(eventRecord.RunId__c, eventRecord.Source__c);
      }
    }
    Map<String, Id> runRecordIds = ensureRuns(sourceByRunId);
    List<Record_Health_Check_Observation__c> observations = new List<Record_Health_Check_Observation__c>();
    for (Record_Health_Check_Rule_Result__e eventRecord : events) {
      if (!isActionable(eventRecord.Status__c)) {
        continue;
      }
      observations.add(
        new Record_Health_Check_Observation__c(
          Run__c = runRecordIds.get(eventRecord.RunId__c),
          Capture_Key__c = eventRecord.EventId__c,
          Event_Id__c = eventRecord.EventId__c,
          Observation_Type__c = 'RULE_RESULT',
          Source__c = eventRecord.Source__c,
          Status__c = eventRecord.Status__c,
          Severity__c = eventRecord.Severity__c,
          Reason_Code__c = eventRecord.ReasonCode__c,
          Check_Set_Qualified_Api_Name__c = eventRecord.CheckSetQualifiedApiName__c,
          Rule_Qualified_Api_Name__c = eventRecord.RuleQualifiedApiName__c,
          Record_Id__c = eventRecord.RecordId__c,
          Occurred_At__c = eventRecord.OccurredAt__c,
          Contains_Restricted_Detail__c = eventRecord.ContainsRestrictedDetail__c,
          Contract_Version__c = eventRecord.ContractVersion__c,
          Framework_Version__c = eventRecord.FrameworkVersion__c,
          Raw_Payload__c = JSON.serialize(eventRecord)
        )
      );
    }
    upsertObservations(observations);
  }

  /** Captures terminal Framework Set Run lifecycle events. */
  public static void captureSetEvents(
    List<Record_Health_Check_Set_Run__e> events
  ) {
    List<Record_Health_Check_Run__c> runs = new List<Record_Health_Check_Run__c>();
    for (Record_Health_Check_Set_Run__e eventRecord : events) {
      runs.add(
        new Record_Health_Check_Run__c(
          Run_Id__c = eventRecord.RunId__c,
          Source__c = eventRecord.Source__c,
          Status__c = overallStatus(
            integerValue(eventRecord.PassedCount__c),
            integerValue(eventRecord.FailedCount__c),
            integerValue(eventRecord.SkippedCount__c),
            integerValue(eventRecord.UnableCount__c),
            integerValue(eventRecord.SystemErrorCount__c)
          ),
          Check_Set_Qualified_Api_Name__c = eventRecord.CheckSetQualifiedApiName__c,
          Completed_At__c = eventRecord.OccurredAt__c,
          Rule_Count__c = eventRecord.EligibleRuleCount__c,
          Passed_Count__c = eventRecord.PassedCount__c,
          Failed_Count__c = eventRecord.FailedCount__c,
          Skipped_Count__c = eventRecord.SkippedCount__c,
          Unable_Count__c = eventRecord.UnableCount__c,
          System_Error_Count__c = eventRecord.SystemErrorCount__c,
          Contract_Version__c = eventRecord.ContractVersion__c,
          Framework_Version__c = eventRecord.FrameworkVersion__c,
          Last_Event_Id__c = eventRecord.EventId__c
        )
      );
    }
    upsertRuns(runs);
  }

  /** Captures enabled Framework framework Error Log events. */
  public static void captureErrorEvents(
    List<Record_Health_Check_Log__e> events
  ) {
    Map<String, String> sourceByRunId = new Map<String, String>();
    for (Record_Health_Check_Log__e eventRecord : events) {
      sourceByRunId.put(
        eventRecord.RunId__c,
        inferSource(eventRecord.RunId__c)
      );
    }
    Map<String, Id> runRecordIds = ensureRuns(sourceByRunId);
    List<Record_Health_Check_Observation__c> observations = new List<Record_Health_Check_Observation__c>();
    for (Record_Health_Check_Log__e eventRecord : events) {
      observations.add(
        new Record_Health_Check_Observation__c(
          Run__c = runRecordIds.get(eventRecord.RunId__c),
          Capture_Key__c = eventRecord.EventId__c,
          Event_Id__c = eventRecord.EventId__c,
          Observation_Type__c = 'FRAMEWORK_ERROR',
          Source__c = inferSource(eventRecord.RunId__c),
          Status__c = 'ERROR',
          Error_Code__c = eventRecord.Code__c,
          Check_Set_Qualified_Api_Name__c = eventRecord.CheckSetDeveloperName__c,
          Rule_Qualified_Api_Name__c = eventRecord.RuleDeveloperName__c,
          Record_Id__c = eventRecord.RecordId__c,
          Occurred_At__c = eventRecord.OccurredAt__c,
          Message__c = eventRecord.Message__c,
          Exception_Type__c = eventRecord.ExceptionType__c,
          Stack_Trace__c = eventRecord.StackTrace__c,
          User_Id__c = eventRecord.UserId__c,
          Contains_Restricted_Detail__c = true,
          Contract_Version__c = eventRecord.ContractVersion__c,
          Framework_Version__c = eventRecord.FrameworkVersion__c,
          Raw_Payload__c = JSON.serialize(eventRecord)
        )
      );
    }
    upsertObservations(observations);
  }

  private static Record_Health_Check_Run__c openRun(
    String runId,
    String checkSetQualifiedApiName,
    String source,
    Integer recordCount,
    Id asyncJobId
  ) {
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(
      Run_Id__c = runId,
      Source__c = source,
      Status__c = 'IN_PROGRESS',
      Check_Set_Qualified_Api_Name__c = checkSetQualifiedApiName,
      Async_Job_Id__c = asyncJobId,
      Requested_By_User_Id__c = UserInfo.getUserId(),
      Started_At__c = System.now(),
      Record_Count__c = recordCount,
      Contract_Version__c = '2.0'
    );
    Database.UpsertResult result = Database.upsert(
      runRecord,
      Record_Health_Check_Run__c.Fields.Run_Id__c,
      false
    );
    requireSuccess(result, 'RUN_CAPTURE_FAILED');
    runRecord.Id = result.getId();
    return runRecord;
  }

  private static void persistResponse(
    Record_Health_Check_Run__c runRecord,
    String checkSetQualifiedApiName,
    String source,
    RecordHealthCheckResponse response
  ) {
    List<Record_Health_Check_Observation__c> observations = new List<Record_Health_Check_Observation__c>();
    for (RecordHealthCheckResultItem item : response.results) {
      if (
        item == null ||
        item.evaluation == null ||
        !isActionable(item.evaluation.status)
      ) {
        continue;
      }
      RecordHealthCheckEvaluationResult evaluation = item.evaluation;
      RecordHealthCheckResultDisplay display = item.display;
      observations.add(
        new Record_Health_Check_Observation__c(
          Run__c = runRecord.Id,
          Capture_Key__c = directCaptureKey(response.runId, evaluation),
          Observation_Type__c = 'RULE_RESULT',
          Source__c = source,
          Status__c = evaluation.status,
          Severity__c = evaluation.severity,
          Reason_Code__c = evaluation.reasonCode,
          Check_Set_Qualified_Api_Name__c = checkSetQualifiedApiName,
          Rule_Qualified_Api_Name__c = evaluation.ruleQualifiedApiName,
          Record_Id__c = evaluation.recordId == null
            ? null
            : String.valueOf(evaluation.recordId),
          Occurred_At__c = System.now(),
          Message__c = display == null ? null : display.renderedMessage,
          Fix_Instructions__c = display == null ? null : display.renderedFix,
          Found_Value_JSON__c = evaluation.found == null
            ? null
            : JSON.serialize(evaluation.found),
          Expected_Value_JSON__c = evaluation.expected == null
            ? null
            : JSON.serialize(evaluation.expected),
          Found_Display_Value__c = display == null
            ? null
            : display.foundDisplayValue,
          Expected_Display_Value__c = display == null
            ? null
            : display.expectedDisplayValue,
          Comparison_Operator__c = evaluation.comparisonOperator,
          Action_Label__c = display == null ? null : display.actionLabel,
          Action_URL__c = display == null ? null : display.actionUrl,
          Contains_Restricted_Detail__c = display != null &&
            display.adminDetail != null &&
            display.adminDetail.containsRestrictedDetail,
          Contract_Version__c = '2.0',
          Raw_Payload__c = JSON.serialize(item)
        )
      );
    }
    upsertObservations(observations);
    runRecord.Status__c = overallStatus(response.summary);
    runRecord.Completed_At__c = System.now();
    runRecord.Rule_Count__c = response.ruleQualifiedApiNames.size();
    runRecord.Passed_Count__c = response.summary.passed;
    runRecord.Failed_Count__c = response.summary.failed;
    runRecord.Skipped_Count__c = response.summary.skipped;
    runRecord.Unable_Count__c = response.summary.unable;
    runRecord.System_Error_Count__c = response.summary.systemError;
    Database.update(runRecord, AccessLevel.USER_MODE);
  }

  private static void persistThrownFailure(
    Record_Health_Check_Run__c runRecord,
    String checkSetQualifiedApiName,
    String source,
    Exception ex
  ) {
    upsertObservations(
      new List<Record_Health_Check_Observation__c>{
        new Record_Health_Check_Observation__c(
          Run__c = runRecord.Id,
          Capture_Key__c = hashKey(runRecord.Run_Id__c + '|THROWN'),
          Observation_Type__c = 'FRAMEWORK_ERROR',
          Source__c = source,
          Status__c = 'ERROR',
          Error_Code__c = 'CAPTURED_EXECUTION_EXCEPTION',
          Check_Set_Qualified_Api_Name__c = checkSetQualifiedApiName,
          Occurred_At__c = System.now(),
          Message__c = ex.getMessage(),
          Exception_Type__c = ex.getTypeName(),
          Stack_Trace__c = ex.getStackTraceString(),
          Contains_Restricted_Detail__c = true,
          Contract_Version__c = '2.0'
        )
      }
    );
    runRecord.Status__c = 'ERROR';
    runRecord.Completed_At__c = System.now();
    runRecord.System_Error_Count__c = 1;
    Database.update(runRecord, AccessLevel.USER_MODE);
  }

  private static Map<String, Id> ensureRuns(Map<String, String> sourceByRunId) {
    Map<String, Id> result = new Map<String, Id>();
    if (sourceByRunId.isEmpty()) {
      return result;
    }
    for (Record_Health_Check_Run__c existing : [
      SELECT Id, Run_Id__c
      FROM Record_Health_Check_Run__c
      WHERE Run_Id__c IN :sourceByRunId.keySet()
      WITH USER_MODE
    ]) {
      result.put(existing.Run_Id__c, existing.Id);
    }
    List<Record_Health_Check_Run__c> missing = new List<Record_Health_Check_Run__c>();
    for (String runId : sourceByRunId.keySet()) {
      if (!result.containsKey(runId)) {
        missing.add(
          new Record_Health_Check_Run__c(
            Run_Id__c = runId,
            Source__c = normalizedSource(sourceByRunId.get(runId)),
            Status__c = 'IN_PROGRESS',
            Started_At__c = System.now()
          )
        );
      }
    }
    if (!missing.isEmpty()) {
      Database.UpsertResult[] inserted = Database.upsert(
        missing,
        Record_Health_Check_Run__c.Fields.Run_Id__c,
        false
      );
      for (Integer index = 0; index < inserted.size(); index++) {
        requireSuccess(inserted[index], 'RUN_EVENT_CAPTURE_FAILED');
        result.put(missing[index].Run_Id__c, inserted[index].getId());
      }
    }
    return result;
  }

  private static void upsertRuns(List<Record_Health_Check_Run__c> runs) {
    if (runs.isEmpty()) {
      return;
    }
    Map<String, Record_Health_Check_Run__c> uniqueByRunId = new Map<String, Record_Health_Check_Run__c>();
    for (Record_Health_Check_Run__c runRecord : runs) {
      uniqueByRunId.put(runRecord.Run_Id__c, runRecord);
    }
    Database.UpsertResult[] results = Database.upsert(
      uniqueByRunId.values(),
      Record_Health_Check_Run__c.Fields.Run_Id__c,
      false
    );
    for (Database.UpsertResult result : results) {
      requireSuccess(result, 'RUN_EVENT_CAPTURE_FAILED');
    }
  }

  private static void upsertObservations(
    List<Record_Health_Check_Observation__c> observations
  ) {
    if (observations.isEmpty()) {
      return;
    }
    Map<String, Record_Health_Check_Observation__c> uniqueByCaptureKey = new Map<String, Record_Health_Check_Observation__c>();
    for (Record_Health_Check_Observation__c observation : observations) {
      uniqueByCaptureKey.put(observation.Capture_Key__c, observation);
    }
    Database.UpsertResult[] results = Database.upsert(
      uniqueByCaptureKey.values(),
      Record_Health_Check_Observation__c.Fields.Capture_Key__c,
      false
    );
    for (Database.UpsertResult result : results) {
      requireSuccess(result, 'OBSERVATION_CAPTURE_FAILED');
    }
  }

  private static void requireSuccess(
    Database.UpsertResult result,
    String code
  ) {
    if (result.isSuccess()) {
      return;
    }
    throw new CaptureException(
      code + ': ' + JSON.serialize(result.getErrors())
    );
  }

  private static String directCaptureKey(
    String runId,
    RecordHealthCheckEvaluationResult evaluation
  ) {
    return hashKey(
      runId + '|' + evaluation.recordId + '|' + evaluation.ruleQualifiedApiName
    );
  }

  private static String hashKey(String value) {
    return 'RHC-' +
      EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(value))
      );
  }

  private static String newRunId(String source) {
    return 'rhc-' +
      source.toLowerCase().replace('_', '-') +
      '-' +
      Datetime.now().getTime() +
      '-' +
      String.valueOf(Crypto.getRandomInteger()).replace('-', '').left(8);
  }

  private static String inferSource(String runId) {
    if (String.isBlank(runId)) {
      return 'UNKNOWN';
    }
    String lowered = runId.toLowerCase();
    if (lowered.startsWith('rhc-flow-')) {
      return SOURCE_FLOW;
    }
    if (lowered.startsWith('rhc-queueable-')) {
      return SOURCE_QUEUEABLE;
    }
    if (lowered.startsWith('rhc-batch-')) {
      return SOURCE_BATCH;
    }
    if (lowered.startsWith('rhc-apex-')) {
      return SOURCE_APEX;
    }
    return 'UNKNOWN';
  }

  private static String normalizedSource(String source) {
    return String.isBlank(source) ? 'UNKNOWN' : source;
  }

  private static RecordHealthCheckExecutionOrigin executionOrigin(
    String source
  ) {
    if (source == SOURCE_FLOW) {
      return RecordHealthCheckExecutionOrigin.FLOW;
    }
    if (source == SOURCE_QUEUEABLE) {
      return RecordHealthCheckExecutionOrigin.QUEUEABLE;
    }
    if (source == SOURCE_BATCH) {
      return RecordHealthCheckExecutionOrigin.BATCH;
    }
    return RecordHealthCheckExecutionOrigin.APEX_API;
  }

  private static Boolean isActionable(String status) {
    return status == 'FAIL' ||
      status == 'UNABLE_TO_EVALUATE' ||
      status == 'ERROR';
  }

  private static String overallStatus(RecordHealthCheckRunSummary summary) {
    return overallStatus(
      summary.passed,
      summary.failed,
      summary.skipped,
      summary.unable,
      summary.systemError
    );
  }

  private static String overallStatus(
    Integer passed,
    Integer failed,
    Integer skipped,
    Integer unable,
    Integer systemError
  ) {
    if (systemError > 0) {
      return 'ERROR';
    }
    if (unable > 0) {
      return 'UNABLE_TO_EVALUATE';
    }
    if (failed > 0) {
      return 'FAIL';
    }
    if (passed > 0) {
      return 'PASS';
    }
    return 'SKIPPED';
  }

  private static Integer integerValue(Decimal value) {
    return value == null ? 0 : value.intValue();
  }

  private static void validate(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    String source
  ) {
    if (String.isBlank(checkSetQualifiedApiName)) {
      throw new CaptureException('Check Set QualifiedApiName is required.');
    }
    if (recordIds == null || recordIds.isEmpty()) {
      throw new CaptureException('At least one record ID is required.');
    }
    if (String.isBlank(source)) {
      throw new CaptureException('Capture source is required.');
    }
  }

  /** Capture persistence or request failure. */
  public class CaptureException extends Exception {
  }
}
