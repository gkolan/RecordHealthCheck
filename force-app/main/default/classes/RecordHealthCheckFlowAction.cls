/** Flow action over the same versioned façade used by Apex callers. */
public with sharing class RecordHealthCheckFlowAction {
  public class Request {
    @InvocableVariable(
      required=true
      label='Check Set API Name'
      description='API name of the Check Set to run.'
    )
    public String checkSetDeveloperName;

    @InvocableVariable(
      label='Rule API Name'
      description='Optional Rule API name. Leave blank to run the whole Check Set.'
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
      description='Versioned structured response for advanced Flow consumers.'
    )
    public String resultJson;
  }

  @InvocableMethod(
    label='Run Record Health Check'
    description='Runs one Rule or a complete Check Set for each input record.'
    category='Record Health Check'
  )
  public static List<Response> run(List<Request> requests) {
    if (requests == null)
      return new List<Response>();
    if (requests.size() > RecordHealthCheck.MAX_RECORDS_PER_CALL) {
      throw new RecordHealthCheck.RecordHealthCheckRequestException(
        'A request can include at most ' +
          RecordHealthCheck.MAX_RECORDS_PER_CALL +
          ' records.'
      );
    }
    Integer plannedEvaluations = 0;
    RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
    for (Request request : requests) {
      plannedEvaluations += String.isBlank(request.ruleDeveloperName)
        ? configService
            .getDefinitionResponse(
              request.checkSetDeveloperName,
              request.recordId
            )
            .checks.size()
        : 1;
      if (plannedEvaluations > RecordHealthCheck.MAX_EVALUATIONS_PER_CALL) {
        throw new RecordHealthCheck.RecordHealthCheckRequestException(
          'This Flow request would run too many checks. Reduce the records or Rules and try again.'
        );
      }
    }
    List<Response> responses = new List<Response>();
    for (Request request : requests) {
      Response response = new Response();
      if (String.isBlank(request.ruleDeveloperName)) {
        RecordHealthCheckSetResult result = RecordHealthCheck.runSet(
          request.checkSetDeveloperName,
          request.recordId
        );
        response.contractVersion = result.contractVersion;
        response.status = result.status;
        response.passedCount = result.passedCount;
        response.failedCount = result.failedCount;
        response.skippedCount = result.skippedCount;
        response.unableCount = result.unableCount;
        response.systemErrorCount = result.systemErrorCount;
        response.resultJson = JSON.serialize(result);
      } else {
        RecordHealthCheckResult result = RecordHealthCheck.run(
          request.checkSetDeveloperName,
          request.ruleDeveloperName,
          request.recordId
        );
        response.contractVersion = result.contractVersion;
        response.status = result.status;
        response.reasonCode = result.reasonCode;
        response.resultJson = JSON.serialize(result);
      }
      responses.add(response);
    }
    return responses;
  }
}
