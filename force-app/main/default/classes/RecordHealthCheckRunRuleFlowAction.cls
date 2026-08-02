/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Bulk Flow adapter for qualified Rule requests. */
public with sharing class RecordHealthCheckRunRuleFlowAction {
  /** One Flow input for a qualified Rule evaluation. */
  public class Request {
    @InvocableVariable(
      required=true
      label='Rule Qualified API Name'
      description='QualifiedApiName of the Rule to run.'
    )
    public String ruleQualifiedApiName;

    @InvocableVariable(required=true label='Record ID')
    public Id recordId;

    @InvocableVariable(
      required=true
      label='Event Publication'
      description='Required: NONE, ACTIONABLE, or ALL.'
    )
    public String eventPublication;
  }

  /** One aligned Flow output for a Rule request. */
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
    @InvocableVariable(label='Reason Code')
    public String reasonCode;
    @InvocableVariable(label='Result JSON')
    public String resultJson;
  }

  /**
   * Runs each valid Rule request in bulk and returns an output at the same index.
   *
   * @param requests Flow requests to validate and evaluate.
   * @return Aligned success or recoverable-error responses.
   */
  @InvocableMethod(
    label='Run Record Health Check Rule'
    description='Runs one qualified Record Health Check Rule for each input record.'
    category='Record Health Check'
  )
  public static List<Response> runRule(List<Request> requests) {
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
      String key = groupKey(input.ruleQualifiedApiName, input.eventPublication);
      if (!idsByGroup.containsKey(key)) {
        idsByGroup.put(key, new List<Id>());
      }
      idsByGroup.get(key).add(input.recordId);
    }
    Map<String, String> groupErrors = new Map<String, String>();
    for (String key : idsByGroup.keySet()) {
      try {
        List<Object> parts = (List<Object>) JSON.deserializeUntyped(key);
        RecordHealthCheckRequest request = RecordHealthCheckRequest.forRule(
            (String) parts[0],
            idsByGroup.get(key)
          )
          .withExecutionOrigin(RecordHealthCheckExecutionOrigin.FLOW)
          .withEventPublication(
            RecordHealthCheckFlowSupport.publication((String) parts[1])
          );
        RecordHealthCheckResponse groupedResponse = RecordHealthCheck.evaluate(
          request
        );
        resultsByGroup.put(key, groupedResponse);
        itemsByRecordByGroup.put(
          key,
          RecordHealthCheckFlowSupport.itemsByRecord(groupedResponse)
        );
      } catch (Exception ex) {
        groupErrors.put(key, 'The Rule request could not be evaluated.');
      }
    }

    List<Response> outputs = new List<Response>();
    for (Integer index = 0; index < requests.size(); index++) {
      if (errorsByIndex.containsKey(index)) {
        outputs.add(errorsByIndex.get(index));
        continue;
      }
      Request input = requests[index];
      String key = groupKey(input.ruleQualifiedApiName, input.eventPublication);
      if (groupErrors.containsKey(key)) {
        outputs.add(errorResponse('EXECUTION', groupErrors.get(key)));
        continue;
      }
      try {
        List<RecordHealthCheckResultItem> items = itemsByRecordByGroup.get(key)
          .get(input.recordId);
        if (items == null || items.isEmpty()) {
          throw new RecordHealthCheckFlowSupport.FlowSupportException(
            'No aligned Rule result was returned.'
          );
        }
        RecordHealthCheckResultItem item = items[0];
        Response output = new Response();
        output.isSuccess = true;
        output.contractVersion = '2.0';
        output.status = item.evaluation.status;
        output.reasonCode = item.evaluation.reasonCode;
        output.resultJson = JSON.serialize(item);
        outputs.add(output);
      } catch (Exception ex) {
        outputs.add(
          errorResponse('EXECUTION', 'No aligned Rule result was returned.')
        );
      }
    }
    return outputs;
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
      String.isBlank(input.ruleQualifiedApiName) ||
      input.recordId == null
    ) {
      throw new FlowRequestException(
        'A Rule Qualified API Name and Record ID are required.'
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
