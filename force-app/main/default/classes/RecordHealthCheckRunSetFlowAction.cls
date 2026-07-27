/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Flow action over RecordHealthCheck.runSet. */
public with sharing class RecordHealthCheckRunSetFlowAction {
  public class Request {
    @InvocableVariable(
      required=true
      label='Check Set API Name'
      description='API name of the Check Set to run.'
    )
    public String checkSetDeveloperName;

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
    @InvocableVariable(
      label='Result JSON'
      description='Versioned structured Check Set response for advanced Flow consumers.'
    )
    public String resultJson;
  }

  @InvocableMethod(
    label='Run Record Health Check Set'
    description='Runs one complete Record Health Check Set for each input record.'
    category='Record Health Check'
  )
  public static List<Response> runSet(List<Request> requests) {
    if (requests == null) {
      return new List<Response>();
    }
    if (requests.size() > RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL) {
      throw new RecordHealthCheck.RecordHealthCheckRequestException(
        'A request can include at most ' +
          RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL +
          ' records.'
      );
    }
    Integer plannedEvaluations = 0;
    RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
    for (Request request : requests) {
      plannedEvaluations += configService
        .getDefinitionResponse(request.checkSetDeveloperName, request.recordId)
        .checks.size();
      if (plannedEvaluations > RecordHealthCheck.MAX_EVALUATIONS_PER_CALL) {
        throw new RecordHealthCheck.RecordHealthCheckRequestException(
          'This Flow request would run too many checks. Reduce the records or Rules and try again.'
        );
      }
    }
    List<Response> responses = new List<Response>();
    try {
      for (Request request : requests) {
        RecordHealthCheckSetResult result = RecordHealthCheck.runSet(
          request.checkSetDeveloperName,
          request.recordId,
          null,
          RecordHealthCheckLifecyclePublisher.SOURCE_FLOW
        );
        Response response = new Response();
        response.contractVersion = result.contractVersion;
        response.status = result.status;
        response.passedCount = result.passedCount;
        response.failedCount = result.failedCount;
        response.skippedCount = result.skippedCount;
        response.unableCount = result.unableCount;
        response.systemErrorCount = result.systemErrorCount;
        response.resultJson = JSON.serialize(result);
        responses.add(response);
      }
    } finally {
      // Boundary flush for the platform-event ERROR destination. RecordHealthCheck.runSet also
      // flushes per call; this keeps the invariant explicit at the Flow entry.
      RecordHealthCheckLogger.flush();
    }
    return responses;
  }
}
