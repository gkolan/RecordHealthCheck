@IsTest
private with sharing class RecordHealthCheckAsyncTest {
  private class EnabledLogSettingsProvider extends RecordHealthCheckSettingsProvider {
    public override Boolean isErrorEventPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return true;
    }
  }

  @IsTest
  static void shouldExecuteQueueableWithNullScopeSafely() {
    Test.startTest();
    Id queueJobId = RecordHealthCheckQueueable.enqueue('Any_Set', null, null);
    Test.stopTest();

    AsyncApexJob queuedJob = [
      SELECT Status
      FROM AsyncApexJob
      WHERE Id = :queueJobId
    ];
    Assert.areEqual(
      'Completed',
      queuedJob.Status,
      'The Queueable adapter must safely accept a null record scope.'
    );
  }

  @IsTest
  static void shouldHandleEmptyBatchLifecycleSafely() {
    RecordHealthCheckBatch batch = new RecordHealthCheckBatch(
      'Any_Set',
      null,
      null
    );

    Test.startTest();
    Iterator<Id> recordIterator = batch.start(null).iterator();
    batch.execute(null, new List<Id>());
    batch.finish(null);
    Test.stopTest();

    Assert.isFalse(
      recordIterator.hasNext(),
      'A null Batch record scope must become an empty iterable.'
    );
  }

  @IsTest
  static void shouldLogUnhandledQueueableFinalizerFailure() {
    RecordHealthCheckQueueable queueable = new RecordHealthCheckQueueable(
      'Any_Set',
      new List<Id>(),
      RecordHealthCheckEventPublication.NONE
    );
    Id jobId = RecordHealthCheckTestDataFactory.syntheticId(
      AsyncApexJob.SObjectType,
      1
    );
    RecordHealthCheckLogger.settingsProvider = new EnabledLogSettingsProvider();
    Test.startTest();
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'pre-finalizer',
      'Any_Set',
      null,
      null,
      'PRE_FINALIZER_ERROR',
      null,
      new IllegalArgumentException('Synthetic buffered failure')
    );
    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'The test precondition must include one buffered event.'
    );
    queueable.handleFinalizerResult(
      ParentJobResult.UNHANDLED_EXCEPTION,
      jobId,
      new IllegalArgumentException('Synthetic queueable failure')
    );
    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'An unhandled Queueable failure must flush all buffered log events.'
    );
    Test.stopTest();
  }

  @IsTest
  static void shouldRegisterDailySchedule() {
    Test.startTest();
    String jobId = RecordHealthCheckScheduled.scheduleDaily(
      'RHC Async Test',
      'Any_Set',
      null,
      null
    );
    CronTrigger scheduled = [
      SELECT CronExpression, State
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.abortJob(jobId);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckScheduled.CRON_DAILY_2AM,
      scheduled.CronExpression,
      'Daily scheduling must use the documented CRON expression.'
    );
  }
}
