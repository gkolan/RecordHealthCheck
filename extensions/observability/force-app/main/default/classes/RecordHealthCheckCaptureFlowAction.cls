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

    Map<String, Set<Id>> recordIdsByCheckSet = new Map<String, Set<Id>>();
    Map<String, List<Integer>> outputIndexesByCheckSet = new Map<String, List<Integer>>();
    for (Integer index = 0; index < requests.size(); index++) {
      Request request = requests[index];
      outputs.add(new Response());
      if (
        request == null ||
        String.isBlank(request.checkSetQualifiedApiName) ||
        request.recordId == null
      ) {
        outputs[index].isSuccess = false;
        outputs[index].errorType = 'INVALID_REQUEST';
        outputs[index]
          .errorMessage = 'Check Set Qualified API Name and Record ID are required.';
        continue;
      }
      String checkSetName = request.checkSetQualifiedApiName.trim();
      if (!recordIdsByCheckSet.containsKey(checkSetName)) {
        recordIdsByCheckSet.put(checkSetName, new Set<Id>());
        outputIndexesByCheckSet.put(checkSetName, new List<Integer>());
      }
      recordIdsByCheckSet.get(checkSetName).add(request.recordId);
      outputIndexesByCheckSet.get(checkSetName).add(index);
    }

    for (String checkSetName : recordIdsByCheckSet.keySet()) {
      try {
        RecordHealthCheckResponse result = RecordHealthCheckCaptureService.runCheckSet(
          checkSetName,
          new List<Id>(recordIdsByCheckSet.get(checkSetName)),
          RecordHealthCheckCaptureService.SOURCE_FLOW,
          null
        );
        for (Integer outputIndex : outputIndexesByCheckSet.get(checkSetName)) {
          RecordHealthCheckResponse recordResult = responseForRecord(
            result,
            requests[outputIndex].recordId
          );
          Response output = outputs[outputIndex];
          output.runId = result.runId;
          output.status = overallStatus(recordResult.summary);
          output.failedCount = recordResult.summary.failed;
          output.unableCount = recordResult.summary.unable;
          output.systemErrorCount = recordResult.summary.systemError;
          output.resultJson = JSON.serialize(recordResult);
          output.isSuccess = true;
        }
        successfulRunIds.add(result.runId);
      } catch (Exception ex) {
        for (Integer outputIndex : outputIndexesByCheckSet.get(checkSetName)) {
          Response output = outputs[outputIndex];
          output.isSuccess = false;
          output.errorMessage = ex.getMessage();
          output.errorType = ex.getTypeName();
        }
      }
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

  private static RecordHealthCheckResponse responseForRecord(
    RecordHealthCheckResponse source,
    Id recordId
  ) {
    RecordHealthCheckResponse result = new RecordHealthCheckResponse();
    result.runId = source.runId;
    result.recordIds.add(recordId);
    Set<String> ruleNames = new Set<String>();
    for (RecordHealthCheckResultItem item : source.results) {
      if (item?.evaluation?.recordId != recordId) {
        continue;
      }
      result.results.add(item);
      result.summary.add(item.evaluation.status);
      if (String.isNotBlank(item.evaluation.ruleQualifiedApiName)) {
        ruleNames.add(item.evaluation.ruleQualifiedApiName);
      }
    }
    result.ruleQualifiedApiNames.addAll(ruleNames);
    return result;
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
