/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * One-line entry point to run a SINGLE Record Health Check from anywhere
 * Apex triggers, batch/queueable, scheduled jobs, anonymous Apex, other classes
 * or tests. This is the simplest adoption surface: no LWC, no record page.
 * RecordHealthCheckResult r = RecordHealthCheck.runRule(
 * 'Example_Owner_Is_Active', accountId);
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
  public static RecordHealthCheckResult runRule(
    String ruleDeveloperName,
    Id recordId
  ) {
    return runRule(ruleDeveloperName, recordId, null);
  }

  /** Evaluate one Rule for each record, preserving input order. */
  public static List<RecordHealthCheckResult> runRule(
    String ruleDeveloperName,
    List<Id> recordIds
  ) {
    validateRecordCount(recordIds);
    validateEvaluationCount(recordIds.size());
    List<RecordHealthCheckResult> responses = new List<RecordHealthCheckResult>();
    String checkSetDeveloperName = findCheckSetDeveloperName(ruleDeveloperName);
    deferPublication = true;
    try {
      for (Id recordId : recordIds) {
        responses.add(
          runResolved(
            checkSetDeveloperName,
            ruleDeveloperName,
            recordId,
            null,
            RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
          )
        );
      }
    } finally {
      deferPublication = false;
      RecordHealthCheckLogger.flush();
    }
    RecordHealthCheckLifecyclePublisher.publishRuleResults(
      checkSetDeveloperName,
      null,
      responses,
      RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
    );
    return responses;
  }

  /** Evaluate every active Rule in a Check Set for one record. */
  public static RecordHealthCheckSetResult runSet(
    String checkSetDeveloperName,
    Id recordId
  ) {
    return runSet(checkSetDeveloperName, recordId, null);
  }

  public static RecordHealthCheckSetResult runSet(
    String checkSetDeveloperName,
    Id recordId,
    String runId
  ) {
    return runSet(
      checkSetDeveloperName,
      recordId,
      runId,
      RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
    );
  }

  public static RecordHealthCheckSetResult runSet(
    String checkSetDeveloperName,
    Id recordId,
    String runId,
    String source
  ) {
    try {
      return runSetResolved(checkSetDeveloperName, recordId, runId, source);
    } finally {
      if (!deferPublication) {
        RecordHealthCheckLogger.flush();
      }
    }
  }

  private static RecordHealthCheckSetResult runSetResolved(
    String checkSetDeveloperName,
    Id recordId,
    String runId,
    String source
  ) {
    String effectiveRunId = String.isBlank(runId) ? newRunId() : runId;
    RecordHealthCheckDefinitionResponse definitions = new RecordHealthCheckConfigService()
      .getDefinitionResponse(checkSetDeveloperName, recordId);
    validateEvaluationCount(definitions.checks.size());
    RecordHealthCheckSetResult response = new RecordHealthCheckSetResult();
    response.checkSetDeveloperName = checkSetDeveloperName;
    response.recordId = recordId;
    response.runId = effectiveRunId;
    for (RecordHealthCheckDefinition definition : definitions.checks) {
      RecordHealthCheckResult result = engine.evaluate(
        checkSetDeveloperName,
        definition.developerName,
        recordId,
        effectiveRunId,
        source
      );
      result.runId = effectiveRunId;
      result.recordId = recordId;
      response.add(result);
    }
    response.finish();
    if (!deferPublication) {
      RecordHealthCheckLifecyclePublisher.publishRuleResults(
        checkSetDeveloperName,
        effectiveRunId,
        response.results,
        source
      );
      RecordHealthCheckLifecyclePublisher.publishCompletedSet(response, source);
    }
    return response;
  }

  /** Evaluate a Check Set for each record, preserving input order. */
  public static List<RecordHealthCheckSetResult> runSet(
    String checkSetDeveloperName,
    List<Id> recordIds
  ) {
    validateRecordCount(recordIds);
    if (recordIds.isEmpty())
      return new List<RecordHealthCheckSetResult>();
    RecordHealthCheckDefinitionResponse definitions = new RecordHealthCheckConfigService()
      .getDefinitionResponse(checkSetDeveloperName, recordIds[0]);
    validateEvaluationCount(recordIds.size() * definitions.checks.size());
    List<RecordHealthCheckSetResult> responses = new List<RecordHealthCheckSetResult>();
    deferPublication = true;
    try {
      for (Id recordId : recordIds)
        responses.add(runSet(checkSetDeveloperName, recordId));
    } finally {
      deferPublication = false;
      RecordHealthCheckLogger.flush();
    }
    for (RecordHealthCheckSetResult response : responses) {
      RecordHealthCheckLifecyclePublisher.publishRuleResults(
        checkSetDeveloperName,
        response.runId,
        response.results,
        RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
      );
      RecordHealthCheckLifecyclePublisher.publishCompletedSet(
        response,
        RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
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
  public static RecordHealthCheckResult runRule(
    String ruleDeveloperName,
    Id recordId,
    String runId
  ) {
    return runRule(
      ruleDeveloperName,
      recordId,
      runId,
      RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
    );
  }

  public static RecordHealthCheckResult runRule(
    String ruleDeveloperName,
    Id recordId,
    String runId,
    String source
  ) {
    return runResolved(
      findCheckSetDeveloperName(ruleDeveloperName),
      ruleDeveloperName,
      recordId,
      runId,
      source
    );
  }

  private static RecordHealthCheckResult runResolved(
    String checkSetDeveloperName,
    String ruleDeveloperName,
    Id recordId,
    String runId,
    String source
  ) {
    try {
      String effectiveRunId = String.isBlank(runId) ? newRunId() : runId;

      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.INFO,
        effectiveRunId,
        checkSetDeveloperName,
        recordId,
        ruleDeveloperName,
        'RUN_INVOKED',
        new Map<String, Object>{ 'via' => 'RecordHealthCheck.runRule' },
        null
      );

      RecordHealthCheckResult result = engine.evaluate(
        checkSetDeveloperName,
        ruleDeveloperName,
        recordId,
        effectiveRunId,
        source
      );
      result.runId = effectiveRunId;
      result.recordId = recordId;

      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.INFO,
        effectiveRunId,
        checkSetDeveloperName,
        recordId,
        ruleDeveloperName,
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
          checkSetDeveloperName,
          effectiveRunId,
          new List<RecordHealthCheckResult>{ result },
          source
        );
      }
      return result;
    } finally {
      if (!deferPublication) {
        RecordHealthCheckLogger.flush();
      }
    }
  }

  private static String findCheckSetDeveloperName(String ruleDeveloperName) {
    return new RecordHealthCheckConfigService()
      .findCheckSetDeveloperName(ruleDeveloperName);
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
