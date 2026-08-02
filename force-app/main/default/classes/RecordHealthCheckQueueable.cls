/** Runs one qualified Check Set scope asynchronously through the public engine. */
global with sharing class RecordHealthCheckQueueable implements Queueable, Finalizer {
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;

  /** Creates a bounded asynchronous Check Set request. */
  global RecordHealthCheckQueueable(
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

  /** Executes the immutable request in the queueable transaction. */
  global void execute(QueueableContext context) {
    System.attachFinalizer(this);
    if (recordIds.isEmpty()) {
      return;
    }
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(checkSetQualifiedApiName, recordIds)
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.QUEUEABLE)
        .withEventPublication(publication)
        .withRunId('queue-' + context.getJobId())
    );
  }

  /** Finalizer hook reserved for durable framework logging and recovery. */
  global void execute(FinalizerContext context) {
    handleFinalizerResult(
      context.getResult(),
      context.getAsyncApexJobId(),
      context.getException()
    );
  }

  @TestVisible
  private void handleFinalizerResult(
    ParentJobResult result,
    Id asyncApexJobId,
    Exception exceptionValue
  ) {
    if (result == ParentJobResult.UNHANDLED_EXCEPTION) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        'queue-' + asyncApexJobId,
        checkSetQualifiedApiName,
        null,
        null,
        'QUEUEABLE_FAILED',
        null,
        exceptionValue
      );
      RecordHealthCheckLogger.flush();
    }
  }

  /** Enqueues one bounded asynchronous Check Set request. */
  global static Id enqueue(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    return System.enqueueJob(
      new RecordHealthCheckQueueable(
        checkSetQualifiedApiName,
        recordIds,
        publication
      )
    );
  }
}
