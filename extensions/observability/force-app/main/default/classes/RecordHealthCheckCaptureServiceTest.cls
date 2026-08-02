@IsTest
private class RecordHealthCheckCaptureServiceTest {
  private static final String CHECK_SET = 'rhc__Example_Account_Profile_Readiness';

  @IsTest
  static void directApexCapturesEveryActionableResult() {
    Account accountRecord = RHCObservabilityTestDataFactory.incompleteAccount(
      'Observability Apex'
    );

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckCaptureService.runCheckSet(
      CHECK_SET,
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckCaptureService.SOURCE_APEX,
      null
    );
    Test.stopTest();

    Record_Health_Check_Run__c runRecord = runById(response.runId);
    Assert.areEqual('APEX', runRecord.Source__c);
    Assert.areEqual(1, runRecord.Record_Count__c);
    Assert.isTrue(runRecord.Failed_Count__c > 0);
    Assert.areEqual(
      runRecord.Failed_Count__c +
        runRecord.Unable_Count__c +
        runRecord.System_Error_Count__c,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Observation__c
        WHERE Run__c = :runRecord.Id
      ]
    );
  }

  @IsTest
  static void flowActionCapturesSourceAndReturnsRun() {
    Account accountRecord = RHCObservabilityTestDataFactory.incompleteAccount(
      'Observability Flow'
    );
    RecordHealthCheckCaptureFlowAction.Request input = new RecordHealthCheckCaptureFlowAction.Request();
    input.checkSetQualifiedApiName = CHECK_SET;
    input.recordId = accountRecord.Id;

    Test.startTest();
    List<RecordHealthCheckCaptureFlowAction.Response> outputs = RecordHealthCheckCaptureFlowAction.runAndCapture(
      new List<RecordHealthCheckCaptureFlowAction.Request>{ input }
    );
    Test.stopTest();

    Assert.areEqual(1, outputs.size());
    Assert.isTrue(outputs[0].isSuccess);
    Assert.isNotNull(outputs[0].runRecordId);
    Assert.areEqual('FLOW', runById(outputs[0].runId).Source__c);
  }

  @IsTest
  static void queueableCapturesSourceAndJob() {
    Account accountRecord = RHCObservabilityTestDataFactory.incompleteAccount(
      'Observability Queueable'
    );
    Test.startTest();
    Id jobId = RecordHealthCheckCaptureQueueable.enqueue(
      CHECK_SET,
      new List<Id>{ accountRecord.Id }
    );
    Test.stopTest();

    Record_Health_Check_Run__c runRecord = [
      SELECT Source__c, Async_Job_Id__c
      FROM Record_Health_Check_Run__c
      WHERE Source__c = 'QUEUEABLE'
      LIMIT 1
    ];
    Assert.areEqual(jobId, Id.valueOf(runRecord.Async_Job_Id__c));
  }

  @IsTest
  static void queueableFinalizerPersistsDurableFailure() {
    Id jobId = UserInfo.getUserId();

    Test.startTest();
    RecordHealthCheckCaptureService.captureQueueableFailure(
      CHECK_SET,
      jobId,
      null
    );
    Test.stopTest();

    Record_Health_Check_Run__c runRecord = [
      SELECT Id, Status__c, System_Error_Count__c
      FROM Record_Health_Check_Run__c
      WHERE Run_Id__c = :('rhc-queueable-finalizer-' + jobId)
      LIMIT 1
    ];
    Assert.areEqual('ERROR', runRecord.Status__c);
    Assert.areEqual(1, runRecord.System_Error_Count__c);
    Record_Health_Check_Observation__c observation = [
      SELECT Error_Code__c, Message__c
      FROM Record_Health_Check_Observation__c
      WHERE Run__c = :runRecord.Id
      LIMIT 1
    ];
    Assert.areEqual('QUEUEABLE_UNHANDLED_EXCEPTION', observation.Error_Code__c);
    Assert.isTrue(
      observation.Message__c.contains('without a reported exception')
    );
  }

  @IsTest
  static void batchCapturesSourceAndJob() {
    Account accountRecord = RHCObservabilityTestDataFactory.incompleteAccount(
      'Observability Batch'
    );
    Test.startTest();
    Id jobId = RecordHealthCheckCaptureBatch.run(
      CHECK_SET,
      new List<Id>{ accountRecord.Id }
    );
    Test.stopTest();

    Record_Health_Check_Run__c runRecord = [
      SELECT Source__c, Async_Job_Id__c
      FROM Record_Health_Check_Run__c
      WHERE Source__c = 'BATCH'
      LIMIT 1
    ];
    Assert.areEqual(jobId, Id.valueOf(runRecord.Async_Job_Id__c));
  }

  @IsTest
  static void lifecycleRuleAndSetEventsAreIdempotent() {
    Account accountRecord = RHCObservabilityTestDataFactory.incompleteAccount(
      'Observability Events'
    );
    String runId = 'event-run-1';
    Record_Health_Check_Rule_Result__e ruleEvent = RHCObservabilityTestDataFactory.failedRuleEvent(
      'rule-event-1',
      runId,
      accountRecord.Id
    );
    Record_Health_Check_Set_Run__e setEvent = new Record_Health_Check_Set_Run__e(
      ContractVersion__c = '2.0',
      EventId__c = 'set-event-1',
      RunId__c = runId,
      CheckSetQualifiedApiName__c = CHECK_SET,
      Phase__c = 'COMPLETED',
      EligibleRuleCount__c = 4,
      EvaluatedRuleCount__c = 4,
      FailedCount__c = 1,
      PassedCount__c = 3,
      OccurredAt__c = System.now(),
      Source__c = 'USER_INITIATED',
      FrameworkVersion__c = '2.0.0'
    );

    Test.startTest();
    RecordHealthCheckCaptureService.captureRuleEvents(
      new List<Record_Health_Check_Rule_Result__e>{ ruleEvent, ruleEvent }
    );
    RecordHealthCheckCaptureService.captureSetEvents(
      new List<Record_Health_Check_Set_Run__e>{ setEvent, setEvent }
    );
    RecordHealthCheckCaptureService.captureRuleEvents(
      new List<Record_Health_Check_Rule_Result__e>{ ruleEvent }
    );
    RecordHealthCheckCaptureService.captureSetEvents(
      new List<Record_Health_Check_Set_Run__e>{ setEvent }
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Record_Health_Check_Run__c WHERE Run_Id__c = :runId]
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Observation__c
        WHERE Event_Id__c = 'rule-event-1'
      ]
    );
    Assert.areEqual('FAIL', runById(runId).Status__c);
  }

  @IsTest
  static void enabledCoreErrorEventCapturesRestrictedDetail() {
    String runId = 'rhc-queueable-log-test';
    Record_Health_Check_Log__e logEvent = new Record_Health_Check_Log__e(
      ContractVersion__c = '2.0',
      EventId__c = 'log-event-1',
      RunId__c = runId,
      Level__c = 'ERROR',
      Code__c = 'UNHANDLED_EXCEPTION',
      CheckSetDeveloperName__c = CHECK_SET,
      RuleDeveloperName__c = 'Example_Profile_Phone_Available',
      Message__c = 'Synthetic framework error for capture verification',
      ExceptionType__c = 'System.NullPointerException',
      StackTrace__c = 'Class.Example: line 1, column 1',
      UserId__c = UserInfo.getUserId(),
      OccurredAt__c = System.now(),
      FrameworkVersion__c = '2.0.0'
    );

    Test.startTest();
    EventBus.publish(logEvent);
    Test.getEventBus().deliver();
    Test.stopTest();

    Record_Health_Check_Observation__c observation = [
      SELECT
        Observation_Type__c,
        Source__c,
        Status__c,
        Error_Code__c,
        Message__c,
        Stack_Trace__c,
        Contains_Restricted_Detail__c
      FROM Record_Health_Check_Observation__c
      WHERE Event_Id__c = 'log-event-1'
    ];
    Assert.areEqual('FRAMEWORK_ERROR', observation.Observation_Type__c);
    Assert.areEqual('QUEUEABLE', observation.Source__c);
    Assert.areEqual('ERROR', observation.Status__c);
    Assert.isTrue(observation.Contains_Restricted_Detail__c);
    Assert.isTrue(observation.Stack_Trace__c.contains('line 1'));
  }

  @IsTest
  static void invalidRequestFailsBeforeCreatingRun() {
    Test.startTest();
    try {
      RecordHealthCheckCaptureService.runCheckSet(
        CHECK_SET,
        new List<Id>(),
        RecordHealthCheckCaptureService.SOURCE_APEX,
        null
      );
      Assert.fail('Empty requests must fail.');
    } catch (RecordHealthCheckCaptureService.CaptureException ex) {
      Assert.isTrue(ex.getMessage().contains('record ID'));
    }
    Test.stopTest();
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Run__c]);
  }

  private static Record_Health_Check_Run__c runById(String runId) {
    return [
      SELECT
        Id,
        Run_Id__c,
        Source__c,
        Status__c,
        Record_Count__c,
        Failed_Count__c,
        Unable_Count__c,
        System_Error_Count__c
      FROM Record_Health_Check_Run__c
      WHERE Run_Id__c = :runId
      LIMIT 1
    ];
  }
}
