/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckController {
  @TestVisible
  private static RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
  @TestVisible
  private static RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

  /**
   * Reports whether the record's object has active and/or inactive Check Sets.
   * Used when the LWC has no Check Set selected, so the setup banner can say
   * choose one, activate one, or create one.
   * Not cacheable: after an admin activates or creates a Check Set, the next
   * component load must see the fresh availability without waiting on the
   * Lightning Data Service cache.
   */
  @AuraEnabled
  public static RecordHealthCheckSetAvailability getCheckSetAvailabilityForRecord(
    Id recordId
  ) {
    if (recordId == null) {
      return new RecordHealthCheckSetAvailability();
    }
    try {
      return configService.getCheckSetAvailabilityForObject(
        RecordHealthCheckDescribeCache.objectApiName(recordId)
      );
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Returns Check Set display settings and ordered check definitions.
   * Not cacheable: metadata edits to Check Sets/Rules appear on the next
   * component load without requiring a page refresh.
   * Throws AuraHandledException for all component-level failures:
   * CONFIG_NOT_FOUND, CONFIG_INACTIVE, OBJECT_MISMATCH,
   * NO_RECORD_CONTEXT, NO_ACTIVE_CHECKS, and LOAD_FAILED for any
   * unexpected (non-ConfigException) error.
   */
  @AuraEnabled
  public static RecordHealthCheckDefinitionResponse getCheckDefinitions(
    String checkSetDeveloperName,
    Id recordId,
    String runId
  ) {
    // Normalize at the controller boundary (the engine also normalizes in evaluate).
    checkSetDeveloperName = RecordHealthCheckLogger.normalizeIdentifier(
      checkSetDeveloperName,
      80
    );
    runId = RecordHealthCheckLogger.normalizeIdentifier(runId, 120);
    if (String.isBlank(checkSetDeveloperName)) {
      throw buildAuraException(
        'CONFIG_NOT_FOUND',
        'No Check Set is selected for this Record Health Check component.'
      );
    }
    try {
      return configService.getDefinitionResponse(
        checkSetDeveloperName,
        recordId
      );
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      // Expected, admin-facing condition (e.g. CONFIG_NOT_FOUND) — log at DEBUG.
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.DEBUG,
        runId,
        checkSetDeveloperName,
        recordId,
        null,
        'CONFIG_EXCEPTION',
        new Map<String, Object>{ 'reasonCode' => ex.reasonCode },
        null
      );
      throw buildAuraException(ex.reasonCode, ex.getMessage());
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetDeveloperName,
        recordId,
        null,
        'CONFIG_UNEXPECTED',
        null,
        ex
      );
      // an unexpected failure here (governor limit, NPE, SOQL error) is
      // NOT a missing-config condition. Reporting CONFIG_NOT_FOUND would tell the
      // admin their Check Set does not exist when it does. Use LOAD_FAILED so the
      // LWC surfaces a generic load error (parseAuraError already treats unknown
      // codes as LOAD_FAILED); CONFIG_NOT_FOUND stays reserved for the explicit
      // not-found path raised as a ConfigException above.
      throw buildAuraException(
        'LOAD_FAILED',
        'An unexpected error occurred loading the health check configuration.'
      );
    } finally {
      // Publish the buffered CONFIG_UNEXPECTED error before LOAD_FAILED unwinds —
      // PublishImmediately survives the rollback the thrown exception triggers.
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Evaluates a single check and returns exactly one RecordHealthCheckResult.
   * Catchable failures are normalized by RecordHealthCheckEngine
   * and surfaced as status = ERROR with a safe message.
   * checkSetDeveloperName is validated server-side to confirm the rule belongs to the
   * named Check Set, preventing direct invocation of arbitrary rules.
   */
  @AuraEnabled
  public static RecordHealthCheckResult evaluateCheck(
    String checkSetDeveloperName,
    String ruleDeveloperName,
    Id recordId,
    String runId,
    String source
  ) {
    checkSetDeveloperName = RecordHealthCheckLogger.normalizeIdentifier(
      checkSetDeveloperName,
      80
    );
    ruleDeveloperName = RecordHealthCheckLogger.normalizeIdentifier(
      ruleDeveloperName,
      80
    );
    runId = RecordHealthCheckLogger.normalizeIdentifier(runId, 120);
    String effectiveSource = normalizeLwcSource(source);
    try {
      RecordHealthCheckResult result = engine.evaluate(
        checkSetDeveloperName,
        ruleDeveloperName,
        recordId,
        runId,
        effectiveSource
      );
      result.runId = runId;
      result.recordId = recordId;
      RecordHealthCheckLifecyclePublisher.publishRuleResults(
        checkSetDeveloperName,
        runId,
        new List<RecordHealthCheckResult>{ result },
        effectiveSource
      );
      return result;
    } catch (Exception ex) {
      // Engine promises never to throw, but guard the boundary regardless
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetDeveloperName,
        recordId,
        ruleDeveloperName,
        'CONTROLLER_BOUNDARY_ERROR',
        null,
        ex
      );
      RecordHealthCheckResult errorResult = new RecordHealthCheckResult();
      errorResult.ruleDeveloperName = ruleDeveloperName;
      errorResult.recordId = recordId;
      errorResult.status = 'ERROR';
      errorResult.reasonCode = 'APEX_EVALUATOR_ERROR';
      errorResult.message = 'An unexpected error occurred. Contact your administrator.';
      return errorResult;
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  /** Publishes the one aggregate event after a user-initiated client run finishes. */
  @AuraEnabled
  public static void completeRun(
    String checkSetDeveloperName,
    String runId,
    String source,
    Id recordId
  ) {
    try {
      String effectiveSource = normalizeLwcSource(source);
      String effectiveCheckSetName = RecordHealthCheckLogger.normalizeIdentifier(
        checkSetDeveloperName,
        80
      );
      if (
        effectiveSource !=
        RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED ||
        recordId == null ||
        !RecordHealthCheckLifecyclePublisher.isRunPublicationEnabled(
          effectiveCheckSetName
        )
      ) {
        return;
      }
      String effectiveRunId = RecordHealthCheckLogger.normalizeIdentifier(
        runId,
        120
      );
      RecordHealthCheckDefinitionResponse definitions = configService.getDefinitionResponse(
        effectiveCheckSetName,
        recordId
      );
      RecordHealthCheckSetResult response = new RecordHealthCheckSetResult();
      response.checkSetDeveloperName = effectiveCheckSetName;
      response.recordId = recordId;
      response.runId = effectiveRunId;
      // Never trust browser-supplied result objects for a lifecycle event.
      // Authoritative counts come only from server-owned metadata and results.
      for (RecordHealthCheckDefinition definition : definitions.checks) {
        response.add(
          engine.evaluate(
            effectiveCheckSetName,
            definition.developerName,
            recordId,
            effectiveRunId,
            effectiveSource
          )
        );
      }
      response.finish();
      RecordHealthCheckLifecyclePublisher.publishCompletedSet(
        response,
        effectiveSource
      );
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }

  /** The browser may request only the two LWC modes; unknown values fail closed. */
  private static String normalizeLwcSource(String source) {
    return source == RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
      ? RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
      : RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD;
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  private static AuraHandledException buildAuraException(
    String reasonCode,
    String message
  ) {
    // Surface a safe message to the LWC; reasonCode is embedded for diagnostic use.
    // Raw internal details are never passed through this public boundary.
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(
      JSON.serialize(
        new Map<String, String>{
          'reasonCode' => reasonCode,
          'message' => message
        }
      )
    );
    return ex;
  }
}
