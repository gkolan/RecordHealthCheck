/** Flow action that evaluates a Check Set and persists actionable observations. */
public with sharing class RecordHealthCheckCaptureFlowAction {
  public class Request {
    @InvocableVariable(required=true label='Check Set Qualified API Name')
    public String checkSetQualifiedApiName;
    @InvocableVariable(required=true label='Record ID')
    public Id recordId;
  }

  public class Response {
    @InvocableVariable(label='Run Record ID')
    public Id runRecordId;
    @InvocableVariable(label='Run ID')
    public String runId;
    @InvocableVariable(label='Status')
    public String status;
    @InvocableVariable(label='Failed Count')
    public Integer failedCount;
    @InvocableVariable(label='Unable Count')
    public Integer unableCount;
    @InvocableVariable(label='System Error Count')
    public Integer systemErrorCount;
    @InvocableVariable(label='Result JSON')
    public String resultJson;
    @InvocableVariable(label='Success')
    public Boolean isSuccess;
    @InvocableVariable(label='Error Message')
    public String errorMessage;
    @InvocableVariable(label='Error Type')
    public String errorType;
  }

  /** Runs and captures one Check Set request for every Flow input row. */
  @InvocableMethod(
    label='Run and Capture Record Health Check Set'
    description='Runs a qualified Check Set and stores every failed, unable, or system-error outcome.'
    category='Record Health Check'
  )
  public static List<Response> runAndCapture(List<Request> requests) {
    List<Response> outputs = new List<Response>();
    Set<String> successfulRunIds = new Set<String>();
    if (requests == null) {
      return outputs;
    }
    for (Request request : requests) {
      Response output = new Response();
      try {
        RecordHealthCheckResponse result = RecordHealthCheckCaptureService.runCheckSet(
          request.checkSetQualifiedApiName,
          new List<Id>{ request.recordId },
          RecordHealthCheckCaptureService.SOURCE_FLOW,
          null
        );
        output.runId = result.runId;
        output.status = overallStatus(result.summary);
        output.failedCount = result.summary.failed;
        output.unableCount = result.summary.unable;
        output.systemErrorCount = result.summary.systemError;
        output.resultJson = JSON.serialize(result);
        output.isSuccess = true;
        successfulRunIds.add(result.runId);
      } catch (Exception ex) {
        output.isSuccess = false;
        output.errorMessage = ex.getMessage();
        output.errorType = ex.getTypeName();
      }
      outputs.add(output);
    }
    Map<String, Id> recordIdByRunId = new Map<String, Id>();
    if (!successfulRunIds.isEmpty()) {
      for (
        SObject row : Database.queryWithBinds(
          'SELECT Id, Run_Id__c FROM Record_Health_Check_Run__c ' +
          'WHERE Run_Id__c IN :runIds',
          new Map<String, Object>{ 'runIds' => successfulRunIds },
          AccessLevel.USER_MODE
        )
      ) {
        Record_Health_Check_Run__c runRecord = (Record_Health_Check_Run__c) row;
        recordIdByRunId.put(runRecord.Run_Id__c, runRecord.Id);
      }
    }
    for (Response output : outputs) {
      if (output.isSuccess) {
        output.runRecordId = recordIdByRunId.get(output.runId);
      }
    }
    return outputs;
  }

  private static String overallStatus(RecordHealthCheckRunSummary summary) {
    if (summary.systemError > 0) {
      return 'ERROR';
    }
    if (summary.unable > 0) {
      return 'UNABLE_TO_EVALUATE';
    }
    if (summary.failed > 0) {
      return 'FAIL';
    }
    if (summary.passed > 0) {
      return 'PASS';
    }
    return 'SKIPPED';
  }
}
