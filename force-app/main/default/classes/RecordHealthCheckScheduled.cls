/** Schedules a qualified Check Set batch without duplicating evaluation logic. */
global with sharing class RecordHealthCheckScheduled implements Schedulable {
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
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = recordIds == null
      ? new List<Id>()
      : new List<Id>(recordIds);
    this.publication = publication ?? RecordHealthCheckEventPublication.NONE;
  }

  /** Delegates scheduled execution to the batch adapter. */
  global void execute(SchedulableContext context) {
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
}
