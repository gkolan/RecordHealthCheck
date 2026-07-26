/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Best-effort, optional lifecycle publication for deliberately initiated runs. */
public with sharing class RecordHealthCheckLifecyclePublisher {
  public static final String CONTRACT_VERSION = '1.0';
  public static final String CORE_VERSION = '2.0.0';
  public static final String SOURCE_APEX_API = 'APEX_API';
  public static final String SOURCE_FLOW = 'FLOW';
  public static final String SOURCE_USER_INITIATED = 'USER_INITIATED';
  public static final String SOURCE_SCHEDULED = 'SCHEDULED';
  public static final String SOURCE_BATCH = 'BATCH';
  public static final String SOURCE_RUN_ON_LOAD = 'RUN_ON_LOAD';
  public static final Integer PUBLISH_CHUNK_SIZE = 100;
  private static final Set<String> PUBLISHABLE_SOURCES = new Set<String>{
    SOURCE_APEX_API,
    SOURCE_FLOW,
    SOURCE_USER_INITIATED,
    SOURCE_SCHEDULED,
    SOURCE_BATCH
  };

  @TestVisible
  private static Boolean subscriberContextOverride = false;
  @TestVisible
  private static Boolean publishRunSettingOverride;
  @TestVisible
  private static Set<String> publishRuleNamesOverride;

  public static void publishCompletedSet(
    RecordHealthCheckSetResult response,
    String source
  ) {
    if (!canPublish(source) || response == null)
      return;
    if (!isRunPublicationEnabled(response.checkSetDeveloperName))
      return;

    Record_Health_Check_Set_Run__e eventRecord = new Record_Health_Check_Set_Run__e(
      ContractVersion__c = CONTRACT_VERSION,
      EventId__c = newEventId(response.runId, 'SET'),
      RunId__c = response.runId,
      Phase__c = 'COMPLETED',
      CheckSetDeveloperName__c = response.checkSetDeveloperName,
      OccurredAt__c = System.now(),
      Source__c = source,
      CoreVersion__c = CORE_VERSION,
      EligibleRuleCount__c = response.results.size(),
      EvaluatedRuleCount__c = response.results.size(),
      PassedCount__c = response.passedCount,
      FailedCount__c = response.failedCount,
      SkippedCount__c = response.skippedCount,
      UnableCount__c = response.unableCount,
      SystemErrorCount__c = response.systemErrorCount,
      RecordId__c = response.recordId == null
        ? null
        : String.valueOf(response.recordId)
    );
    publishSetEvents(new List<Record_Health_Check_Set_Run__e>{ eventRecord });
  }

  public static Boolean isRunPublicationEnabled(String checkSetDeveloperName) {
    if (publishRunSettingOverride != null)
      return publishRunSettingOverride;
    // code-analyzer-suppress-next-line ApexCRUDViolation: This reads the core-owned Custom Metadata publication switch; no business record data is queried.
    List<Record_Health_Check_Set__mdt> settings = [
      SELECT PublishRunEvent__c
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = :checkSetDeveloperName
      LIMIT 1
    ];
    return !settings.isEmpty() && settings[0].PublishRunEvent__c == true;
  }

  public static void publishRuleResults(
    String checkSetDeveloperName,
    String runId,
    List<RecordHealthCheckResult> results,
    String source
  ) {
    if (!canPublish(source) || results == null || results.isEmpty())
      return;
    Set<String> names = new Set<String>();
    for (RecordHealthCheckResult result : results) {
      names.add(result.ruleDeveloperName);
    }
    Set<String> enabled = publishRuleNamesOverride;
    if (enabled == null) {
      enabled = new Set<String>();
      Map<String, Boolean> cached = RecordHealthCheckConfigService.cachedRulePublicationSettings(
        checkSetDeveloperName,
        names
      );
      Set<String> unresolved = names.clone();
      unresolved.removeAll(cached.keySet());
      for (String name : cached.keySet()) {
        if (cached.get(name) == true)
          enabled.add(name);
      }
      if (!unresolved.isEmpty()) {
        // code-analyzer-suppress-next-line ApexCRUDViolation: This reads core-owned Custom Metadata publication switches; no business record data is queried.
        for (Record_Health_Check_Rule__mdt rule : [
          SELECT DeveloperName
          FROM Record_Health_Check_Rule__mdt
          WHERE
            Record_Health_Check_Set__r.DeveloperName = :checkSetDeveloperName
            AND DeveloperName IN :unresolved
            AND PublishResultEvent__c = TRUE
        ]) {
          enabled.add(rule.DeveloperName);
        }
      }
    }

    List<Record_Health_Check_Rule_Result__e> events = new List<Record_Health_Check_Rule_Result__e>();
    for (RecordHealthCheckResult result : results) {
      if (!enabled.contains(result.ruleDeveloperName))
        continue;
      events.add(
        new Record_Health_Check_Rule_Result__e(
          ContractVersion__c = CONTRACT_VERSION,
          EventId__c = newEventId(
            String.isBlank(result.runId) ? runId : result.runId,
            result.ruleDeveloperName
          ),
          RunId__c = String.isBlank(result.runId) ? runId : result.runId,
          CheckSetDeveloperName__c = checkSetDeveloperName,
          RuleDeveloperName__c = result.ruleDeveloperName,
          Status__c = result.status,
          ReasonCode__c = result.reasonCode,
          Severity__c = result.severity,
          OccurredAt__c = System.now(),
          Source__c = source,
          CoreVersion__c = CORE_VERSION,
          ContainsRestrictedDetail__c = result.adminDetail != null &&
            result.adminDetail.containsRestrictedDetail == true,
          RecordId__c = result.recordId == null
            ? null
            : String.valueOf(result.recordId)
        )
      );
    }
    publishRuleEvents(events);
  }

  @TestVisible
  private static Boolean canPublish(String source) {
    return PUBLISHABLE_SOURCES.contains(source) &&
      subscriberContextOverride != true;
  }

  private static String newEventId(String runId, String suffix) {
    return String.valueOf(runId).left(50) +
      '-' +
      String.valueOf(suffix).left(20) +
      '-' +
      EncodingUtil.convertToHex(Crypto.generateAesKey(128)).left(8);
  }

  private static void publishSetEvents(
    List<Record_Health_Check_Set_Run__e> events
  ) {
    for (
      Integer start = 0; start < events.size(); start += PUBLISH_CHUNK_SIZE
    ) {
      Integer finish = Math.min(start + PUBLISH_CHUNK_SIZE, events.size());
      List<Record_Health_Check_Set_Run__e> chunk = new List<Record_Health_Check_Set_Run__e>();
      for (Integer index = start; index < finish; index++) {
        chunk.add(events[index]);
      }
      inspect(EventBus.publish(chunk), 'SET_RUN_PUBLISH_FAILED');
    }
  }

  @TestVisible
  private static void publishRuleEvents(
    List<Record_Health_Check_Rule_Result__e> events
  ) {
    for (
      Integer start = 0; start < events.size(); start += PUBLISH_CHUNK_SIZE
    ) {
      Integer finish = Math.min(start + PUBLISH_CHUNK_SIZE, events.size());
      List<Record_Health_Check_Rule_Result__e> chunk = new List<Record_Health_Check_Rule_Result__e>();
      for (Integer index = start; index < finish; index++) {
        chunk.add(events[index]);
      }
      inspect(EventBus.publish(chunk), 'RULE_RESULT_PUBLISH_FAILED');
    }
  }

  private static void inspect(
    List<Database.SaveResult> saveResults,
    String logCode
  ) {
    for (Database.SaveResult saveResult : saveResults) {
      if (saveResult.isSuccess())
        continue;
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.WARN,
        null,
        null,
        null,
        null,
        logCode,
        new Map<String, Object>{
          'errorCount' => saveResult.getErrors().size()
        },
        null
      );
    }
  }
}
