/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Flow action over RecordHealthCheck.runRule. */
public with sharing class RecordHealthCheckRunRuleFlowAction {
  public class Request {
    @InvocableVariable(
      required=true
      label='Rule API Name'
      description='API name of the Rule to run.'
    )
    public String ruleDeveloperName;

    @InvocableVariable(
      required=true
      label='Record ID'
      description='Record to evaluate.'
    )
    public Id recordId;
  }

  public class Response {
    @InvocableVariable(label='Contract Version')
    public String contractVersion;
    @InvocableVariable(label='Status')
    public String status;
    @InvocableVariable(label='Reason Code')
    public String reasonCode;
    @InvocableVariable(
      label='Result JSON'
      description='Versioned structured Rule response for advanced Flow consumers.'
    )
    public String resultJson;
  }

  @InvocableMethod(
    label='Run Record Health Check Rule'
    description='Runs one Record Health Check Rule for each input record.'
    category='Record Health Check'
  )
  public static List<Response> runRule(List<Request> requests) {
    try {
      if (requests == null) {
        return new List<Response>();
      }
      validateRequestCount(requests.size());
      List<Response> responses = new List<Response>();
      for (Request request : requests) {
        RecordHealthCheckResult result = RecordHealthCheck.runRule(
          request.ruleDeveloperName,
          request.recordId,
          null,
          RecordHealthCheckLifecyclePublisher.SOURCE_FLOW
        );
        Response response = new Response();
        response.contractVersion = result.contractVersion;
        response.status = result.status;
        response.reasonCode = result.reasonCode;
        response.resultJson = JSON.serialize(result);
        responses.add(response);
      }
      return responses;
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  private static void validateRequestCount(Integer count) {
    if (count > RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL) {
      throw new RecordHealthCheck.RecordHealthCheckRequestException(
        'A request can include at most ' +
          RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL +
          ' records.'
      );
    }
    if (count > RecordHealthCheck.MAX_EVALUATIONS_PER_CALL) {
      throw new RecordHealthCheck.RecordHealthCheckRequestException(
        'This Flow request would run too many checks. Reduce the records and try again.'
      );
    }
  }
}
