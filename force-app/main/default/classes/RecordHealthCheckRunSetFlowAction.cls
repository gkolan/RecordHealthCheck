/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Bulk Flow adapter for qualified Check Set requests. */
public with sharing class RecordHealthCheckRunSetFlowAction {
  /** One Flow input for a qualified Check Set evaluation. */
  public class Request {
    @InvocableVariable(
      required=true
      label='Check Set Qualified API Name'
      description='QualifiedApiName of the Check Set to run.'
    )
    public String checkSetQualifiedApiName;

    @InvocableVariable(required=true label='Record ID')
    public Id recordId;

    @InvocableVariable(
      required=true
      label='Event Publication'
      description='Required: NONE, ACTIONABLE, or ALL.'
    )
    public String eventPublication;
  }

  /** One aligned Flow output for a Check Set request. */
  public class Response {
    @InvocableVariable(label='Success')
    public Boolean isSuccess;
    @InvocableVariable(label='Error Message')
    public String errorMessage;
    @InvocableVariable(label='Error Type')
    public String errorType;
    @InvocableVariable(label='Contract Version')
    public String contractVersion;
    @InvocableVariable(label='Status')
    public String status;
    @InvocableVariable(label='Passed Count')
    public Integer passedCount;
    @InvocableVariable(label='Failed Count')
    public Integer failedCount;
    @InvocableVariable(label='Skipped Count')
    public Integer skippedCount;
    @InvocableVariable(label='Unable Count')
    public Integer unableCount;
    @InvocableVariable(label='System Error Count')
    public Integer systemErrorCount;
    @InvocableVariable(label='Result JSON')
    public String resultJson;
  }

  /**
   * Runs each valid Check Set request in bulk and returns an output at the same index.
   *
   * @param requests Flow requests to validate and evaluate.
   * @return Aligned success or recoverable-error responses.
   */
  @InvocableMethod(
    label='Run Record Health Check Set'
    description='Runs one qualified Record Health Check Set for each input record.'
    category='Record Health Check'
  )
  public static List<Response> runSet(List<Request> requests) {
    if (requests == null) {
      return new List<Response>();
    }
    if (requests.size() > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE) {
      return errorResponses(
        requests.size(),
        'LIMIT',
        countError(requests.size())
      );
    }
    Map<String, List<Id>> idsByGroup = new Map<String, List<Id>>();
    Map<String, RecordHealthCheckResponse> resultsByGroup = new Map<String, RecordHealthCheckResponse>();
    Map<String, Map<Id, List<RecordHealthCheckResultItem>>> itemsByRecordByGroup = new Map<String, Map<Id, List<RecordHealthCheckResultItem>>>();
    Map<Integer, Response> errorsByIndex = new Map<Integer, Response>();
    for (Integer index = 0; index < requests.size(); index++) {
      Request input = requests[index];
      try {
        validateInput(input);
      } catch (FlowRequestException ex) {
        errorsByIndex.put(index, errorResponse('VALIDATION', ex.getMessage()));
        continue;
      }
      String key = groupKey(
        input.checkSetQualifiedApiName,
        input.eventPublication
      );
      if (!idsByGroup.containsKey(key)) {
        idsByGroup.put(key, new List<Id>());
      }
      idsByGroup.get(key).add(input.recordId);
    }
    Map<String, String> groupErrors = new Map<String, String>();
    for (String key : idsByGroup.keySet()) {
      try {
        List<Object> parts = (List<Object>) JSON.deserializeUntyped(key);
        RecordHealthCheckResponse groupedResponse = RecordHealthCheck.evaluate(
          RecordHealthCheckRequest.forCheckSet(
              (String) parts[0],
              idsByGroup.get(key)
            )
            .withExecutionOrigin(RecordHealthCheckExecutionOrigin.FLOW)
            .withEventPublication(
              RecordHealthCheckFlowSupport.publication((String) parts[1])
            )
        );
        resultsByGroup.put(key, groupedResponse);
        itemsByRecordByGroup.put(
          key,
          RecordHealthCheckFlowSupport.itemsByRecord(groupedResponse)
        );
      } catch (Exception ex) {
        groupErrors.put(key, 'The Check Set request could not be evaluated.');
      }
    }

    List<Response> outputs = new List<Response>();
    for (Integer index = 0; index < requests.size(); index++) {
      if (errorsByIndex.containsKey(index)) {
        outputs.add(errorsByIndex.get(index));
        continue;
      }
      Request input = requests[index];
      String key = groupKey(
        input.checkSetQualifiedApiName,
        input.eventPublication
      );
      if (groupErrors.containsKey(key)) {
        outputs.add(errorResponse('EXECUTION', groupErrors.get(key)));
        continue;
      }
      try {
        RecordHealthCheckResponse groupedResponse = resultsByGroup.get(key);
        RecordHealthCheckResponse individual = responseForRecord(
          groupedResponse,
          input.recordId,
          itemsByRecordByGroup.get(key)
        );
        Response output = new Response();
        output.isSuccess = true;
        output.contractVersion = '2.0';
        output.status = RecordHealthCheckFlowSupport.overallStatus(
          individual.summary
        );
        output.passedCount = individual.summary.passed;
        output.failedCount = individual.summary.failed;
        output.skippedCount = individual.summary.skipped;
        output.unableCount = individual.summary.unable;
        output.systemErrorCount = individual.summary.systemError;
        output.resultJson = JSON.serialize(individual);
        outputs.add(output);
      } catch (Exception ex) {
        // prettier-ignore
        outputs.add(errorResponse('EXECUTION', 'No aligned Check Set result was returned.'));
      }
    }
    return outputs;
  }

  private static RecordHealthCheckResponse responseForRecord(
    RecordHealthCheckResponse groupedResponse,
    Id recordId,
    Map<Id, List<RecordHealthCheckResultItem>> itemsByRecord
  ) {
    RecordHealthCheckResponse result = new RecordHealthCheckResponse();
    result.runId = groupedResponse.runId;
    result.recordIds.add(recordId);
    result.ruleQualifiedApiNames.addAll(groupedResponse.ruleQualifiedApiNames);
    List<RecordHealthCheckResultItem> items = itemsByRecord == null
      ? null
      : itemsByRecord.get(recordId);
    if (items == null) {
      return result;
    }
    for (RecordHealthCheckResultItem item : items) {
      result.results.add(item);
      result.summary.add(item.evaluation.status);
    }
    return result;
  }

  private static String groupKey(String name, String mode) {
    return JSON.serialize(
      new List<String>{
        name,
        RecordHealthCheckFlowSupport.normalizedPublication(mode)
      }
    );
  }

  private static String countError(Integer count) {
    return 'MAX_RECORDS_PER_SCOPE_EXCEEDED: suppliedCount=' +
      count +
      ', ceiling=' +
      RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
  }

  private static List<Response> errorResponses(
    Integer count,
    String errorType,
    String message
  ) {
    List<Response> outputs = new List<Response>();
    for (Integer index = 0; index < count; index++) {
      outputs.add(errorResponse(errorType, message));
    }
    return outputs;
  }

  private static Response errorResponse(String errorType, String message) {
    Response output = new Response();
    output.contractVersion = '2.0';
    output.isSuccess = false;
    output.errorType = errorType;
    output.errorMessage = message;
    return output;
  }

  private static void validateInput(Request input) {
    if (
      input == null ||
      String.isBlank(input.checkSetQualifiedApiName) ||
      input.recordId == null
    ) {
      throw new FlowRequestException(
        'A Check Set Qualified API Name and Record ID are required.'
      );
    }
    RecordHealthCheckFlowSupport.publication(
      RecordHealthCheckFlowSupport.normalizedPublication(input.eventPublication)
    );
  }

  /** Internal validation exception converted to a recoverable Flow response. */
  public class FlowRequestException extends Exception {
  }
}
