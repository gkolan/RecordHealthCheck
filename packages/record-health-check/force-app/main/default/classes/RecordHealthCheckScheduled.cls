/** Schedules a qualified Check Set batch without duplicating evaluation logic. */
global with sharing class RecordHealthCheckScheduled implements Schedulable {
  /** Daily 2:00 AM CRON expression used by the packaged scheduler. */
  global static final String CRON_DAILY_2AM = '0 0 2 * * ?';
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;

  /** Creates a scheduled batch request. */
  global RecordHealthCheckScheduled(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validateJobName('Direct scheduled request');
    RecordHealthCheckAsyncSupport.RequestState state = RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Scheduled population'
    );
    this.checkSetQualifiedApiName = state.checkSetQualifiedApiName;
    this.recordIds = state.recordIds;
    this.publication = publication ?? RecordHealthCheckEventPublication.NONE;
  }

  /** Delegates scheduled execution to the batch adapter. */
  global void execute(SchedulableContext context) {
    RecordHealthCheckAccess.requireCanRunChecks();
    RecordHealthCheckBatch.run(
      checkSetQualifiedApiName,
      recordIds,
      publication
    );
  }

  /** Registers the request for daily execution at 2:00 AM. */
  global static String scheduleDaily(
    String jobName,
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validateSubmission(jobName, checkSetQualifiedApiName, recordIds);
    return System.schedule(
      jobName,
      CRON_DAILY_2AM,
      new RecordHealthCheckScheduled(
        checkSetQualifiedApiName,
        recordIds,
        publication
      )
    );
  }

  @TestVisible
  private static void validateSubmission(
    String jobName,
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    validateJobName(jobName);
    RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Scheduled population'
    );
  }

  private static void validateJobName(String jobName) {
    if (
      String.isBlank(jobName) ||
      jobName.length() > RecordHealthCheckConstants.MAX_SCHEDULE_NAME_LENGTH
    ) {
      throw new IllegalArgumentException(
        'A schedule name of 1–' +
          RecordHealthCheckConstants.MAX_SCHEDULE_NAME_LENGTH +
          ' characters is required.'
      );
    }
  }
}
