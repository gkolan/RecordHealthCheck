/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * One-line entry point to run a SINGLE Record Health Check from anywhere
 * Apex triggers, batch/queueable, scheduled jobs, anonymous Apex, other classes
 * or tests. This is the simplest adoption surface: no LWC, no record page.
 * RecordHealthCheckResult r = RecordHealthCheck.run(
 * 'Account_Data_Quality', 'Account_DQ_BillingCity', accountId);
 * if (r.status == 'FAIL') { ... }
 * Like the LWC path, the call is correlated by a generated `runId` and every
 * `[RHC]` log line is attributed to the actual running user.
 */
public with sharing class RecordHealthCheck {
  public static final Integer MAX_RECORDS_PER_CALL = 200;
  public static final Integer MAX_EVALUATIONS_PER_CALL = 15;
  @TestVisible
  private static RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
  private static Boolean deferPublication = false;

  /**
   * Run one check. The headline one-liner.
   * Normalizes catchable evaluation failures as result statuses. Apex governor
   * limit exceptions remain uncatchable, as they are for every Apex API.
   */
  public static RecordHealthCheckResult run(
    String configName,
    String checkDeveloperName,
    Id recordId
  ) {
    return run(configName, checkDeveloperName, recordId, null);
  }

  /** Evaluate one Rule for each record, preserving input order. */
  public static List<RecordHealthCheckResult> run(
    String configName,
    String checkDeveloperName,
    List<Id> recordIds
  ) {
    validateRecordCount(recordIds);
    validateEvaluationCount(recordIds.size());
    List<RecordHealthCheckResult> responses = new List<RecordHealthCheckResult>();
    deferPublication = true;
    try {
      for (Id recordId : recordIds) {
        responses.add(run(configName, checkDeveloperName, recordId));
      }
    } finally {
      deferPublication = false;
    }
    RecordHealthCheckLifecyclePublisher.publishRuleResults(
      configName,
      null,
      responses,
      RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
    );
    return responses;
  }

  /** Evaluate every active Rule in a Check Set for one record. */
  public static RecordHealthCheckSetResult runSet(
    String configName,
    Id recordId
  ) {
    return runSet(configName, recordId, null);
  }

  public static RecordHealthCheckSetResult runSet(
    String configName,
    Id recordId,
    String runId
  ) {
    String effectiveRunId = String.isBlank(runId) ? newRunId() : runId;
    RecordHealthCheckDefinitionResponse definitions = new RecordHealthCheckConfigService()
      .getDefinitionResponse(configName, recordId);
    validateEvaluationCount(definitions.checks.size());
    RecordHealthCheckSetResult response = new RecordHealthCheckSetResult();
    response.checkSetDeveloperName = configName;
    response.recordId = recordId;
    response.runId = effectiveRunId;
    for (RecordHealthCheckDefinition definition : definitions.checks) {
      RecordHealthCheckResult result = engine.evaluate(
        configName,
        definition.developerName,
        recordId,
        effectiveRunId
      );
      result.runId = effectiveRunId;
      response.add(result);
    }
    response.finish();
    if (!deferPublication) {
      RecordHealthCheckLifecyclePublisher.publishRuleResults(
        configName,
        effectiveRunId,
        response.results,
        RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
      );
      RecordHealthCheckLifecyclePublisher.publishCompletedSet(
        response,
        RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
      );
    }
    return response;
  }

  /** Evaluate a Check Set for each record, preserving input order. */
  public static List<RecordHealthCheckSetResult> runSet(
    String configName,
    List<Id> recordIds
  ) {
    validateRecordCount(recordIds);
    if (recordIds.isEmpty())
      return new List<RecordHealthCheckSetResult>();
    RecordHealthCheckDefinitionResponse definitions = new RecordHealthCheckConfigService()
      .getDefinitionResponse(configName, recordIds[0]);
    validateEvaluationCount(recordIds.size() * definitions.checks.size());
    List<RecordHealthCheckSetResult> responses = new List<RecordHealthCheckSetResult>();
    deferPublication = true;
    try {
      for (Id recordId : recordIds)
        responses.add(runSet(configName, recordId));
    } finally {
      deferPublication = false;
    }
    for (RecordHealthCheckSetResult response : responses) {
      RecordHealthCheckLifecyclePublisher.publishRuleResults(
        configName,
        response.runId,
        response.results,
        RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
      );
      RecordHealthCheckLifecyclePublisher.publishCompletedSet(
        response,
        RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
      );
    }
    return responses;
  }

  private static void validateRecordCount(List<Id> recordIds) {
    if (recordIds == null) {
      throw new RecordHealthCheckRequestException('Record IDs are required.');
    }
    if (recordIds.size() > MAX_RECORDS_PER_CALL) {
      throw new RecordHealthCheckRequestException(
        'A request can include at most ' + MAX_RECORDS_PER_CALL + ' records.'
      );
    }
  }

  private static void validateEvaluationCount(Integer count) {
    if (count > MAX_EVALUATIONS_PER_CALL) {
      throw new RecordHealthCheckRequestException(
        'This request would run too many checks. Reduce the records or Rules and try again.'
      );
    }
  }

  public class RecordHealthCheckRequestException extends Exception {
  }

  /**
   * Full control: supply your own correlation `runId` (e.g. a ticket number or a
   * batch job id) so this run's log lines group with related work.
   */
  public static RecordHealthCheckResult run(
    String configName,
    String checkDeveloperName,
    Id recordId,
    String runId
  ) {
    String effectiveRunId = String.isBlank(runId) ? newRunId() : runId;

    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.INFO,
      effectiveRunId,
      configName,
      recordId,
      checkDeveloperName,
      'RUN_INVOKED',
      new Map<String, Object>{ 'via' => 'RecordHealthCheck.run' },
      null
    );

    RecordHealthCheckResult result = engine.evaluate(
      configName,
      checkDeveloperName,
      recordId,
      effectiveRunId
    );
    result.runId = effectiveRunId;

    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.INFO,
      effectiveRunId,
      configName,
      recordId,
      checkDeveloperName,
      'RUN_COMPLETE',
      new Map<String, Object>{
        'status' => result.status,
        'reasonCode' => result.reasonCode,
        'durationMs' => result.durationMs
      },
      null
    );

    if (!deferPublication) {
      RecordHealthCheckLifecyclePublisher.publishRuleResults(
        configName,
        effectiveRunId,
        new List<RecordHealthCheckResult>{ result },
        RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
      );
    }
    return result;
  }

  // Correlation id for runs that don't supply one. Unique enough to group a
  // single run's log lines; not security-sensitive.
  private static String newRunId() {
    return 'api-' +
      String.valueOf(Datetime.now().getTime()) +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }
}
