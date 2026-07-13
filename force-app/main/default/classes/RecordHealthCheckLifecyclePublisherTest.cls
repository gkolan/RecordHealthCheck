@isTest
private class RecordHealthCheckLifecyclePublisherTest {
  private static RecordHealthCheckResult result(String name, String status) {
    RecordHealthCheckResult response = new RecordHealthCheckResult();
    response.checkDeveloperName = name;
    response.status = status;
    response.runId = 'run-test';
    return response;
  }

  private static RecordHealthCheckSetResult setResponse() {
    RecordHealthCheckSetResult response = new RecordHealthCheckSetResult();
    response.checkSetDeveloperName = 'Account_Data_Quality';
    response.runId = 'run-test';
    response.add(result('Account_DQ_BillingCity', 'PASS'));
    response.finish();
    return response;
  }

  @isTest
  static void onLoadPublishesNeitherStreamEvenWhenSwitchesAreOn() {
    RecordHealthCheckLifecyclePublisher.publishRunSettingOverride = true;
    RecordHealthCheckLifecyclePublisher.publishRuleNamesOverride = new Set<String>{
      'Account_DQ_BillingCity'
    };
    Integer beforeDml = Limits.getDmlStatements();

    RecordHealthCheckLifecyclePublisher.publishCompletedSet(
      setResponse(),
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    RecordHealthCheckLifecyclePublisher.publishRuleResults(
      'Account_Data_Quality',
      'run-test',
      setResponse().results,
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );

    System.assertEquals(
      beforeDml,
      Limits.getDmlStatements(),
      'Page-load evaluation must publish zero events.'
    );
  }

  @isTest
  static void facadePublishesBothEnabledStreamsWithoutChangingResult() {
    RecordHealthCheckLifecyclePublisher.publishRunSettingOverride = true;
    RecordHealthCheckLifecyclePublisher.publishRuleNamesOverride = new Set<String>{
      'Account_DQ_BillingCity'
    };
    RecordHealthCheckSetResult response = setResponse();
    Test.startTest();
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishRuleResults(
      response.checkSetDeveloperName,
      response.runId,
      response.results,
      RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
    );
    RecordHealthCheckLifecyclePublisher.publishCompletedSet(
      response,
      RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
    );
    System.assertEquals(
      'PASS',
      response.status,
      'Publishing cannot alter health.'
    );
    System.assertEquals(
      beforeDml + 2,
      Limits.getDmlStatements(),
      'Each lifecycle point uses one bulk publish.'
    );
    Test.stopTest();
  }

  @isTest
  static void defaultOffAndSubscriberGuardPublishNothing() {
    RecordHealthCheckLifecyclePublisher.publishRunSettingOverride = false;
    RecordHealthCheckLifecyclePublisher.publishRuleNamesOverride = new Set<String>();
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishCompletedSet(
      setResponse(),
      RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
    );
    RecordHealthCheckLifecyclePublisher.publishRuleResults(
      'Account_Data_Quality',
      'run-test',
      setResponse().results,
      RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
    );
    RecordHealthCheckLifecyclePublisher.subscriberContextOverride = true;
    RecordHealthCheckLifecyclePublisher.publishRunSettingOverride = true;
    RecordHealthCheckLifecyclePublisher.publishCompletedSet(
      setResponse(),
      RecordHealthCheckLifecyclePublisher.SOURCE_FACADE
    );
    System.assertEquals(beforeDml, Limits.getDmlStatements());
  }

  @isTest
  static void ruleEventsPublishInBoundedChunks() {
    List<Record_Health_Check_Rule_Result__e> events = new List<Record_Health_Check_Rule_Result__e>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckLifecyclePublisher.PUBLISH_CHUNK_SIZE;
      index++
    ) {
      events.add(
        new Record_Health_Check_Rule_Result__e(
          ContractVersion__c = '1.0',
          EventId__c = 'chunk-' + index,
          RunId__c = 'chunk-run',
          CheckSetDeveloperName__c = 'Chunk_Set',
          RuleDeveloperName__c = 'Chunk_Rule',
          Status__c = 'PASS',
          OccurredAt__c = System.now(),
          Source__c = 'FACADE',
          CoreVersion__c = '2.0.0'
        )
      );
    }

    Test.startTest();
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishRuleEvents(events);
    System.assertEquals(
      beforeDml + 2,
      Limits.getDmlStatements(),
      'One event beyond the chunk size must use exactly two bulk publishes.'
    );
    Test.stopTest();
  }

  @isTest
  static void partialPublishFailureIsInspectedWithoutThrowing() {
    List<Record_Health_Check_Rule_Result__e> events = new List<Record_Health_Check_Rule_Result__e>{
      new Record_Health_Check_Rule_Result__e(
        ContractVersion__c = '1.0',
        EventId__c = 'valid-event',
        RunId__c = 'partial-run',
        CheckSetDeveloperName__c = 'Partial_Set',
        RuleDeveloperName__c = 'Partial_Rule',
        Status__c = 'PASS',
        OccurredAt__c = System.now(),
        Source__c = 'FACADE',
        CoreVersion__c = '2.0.0'
      ),
      new Record_Health_Check_Rule_Result__e(
        ContractVersion__c = '1.0',
        RunId__c = 'partial-run',
        CheckSetDeveloperName__c = 'Partial_Set',
        RuleDeveloperName__c = 'Partial_Rule',
        Status__c = 'PASS',
        OccurredAt__c = System.now(),
        Source__c = 'FACADE',
        CoreVersion__c = '2.0.0'
      )
    };

    Test.startTest();
    RecordHealthCheckLifecyclePublisher.inspectedPublishFailures = 0;
    RecordHealthCheckLifecyclePublisher.publishRuleEvents(events);
    System.assertEquals(
      1,
      RecordHealthCheckLifecyclePublisher.inspectedPublishFailures,
      'A missing required event id must be inspected without changing evaluation.'
    );
    Test.stopTest();
  }
}
