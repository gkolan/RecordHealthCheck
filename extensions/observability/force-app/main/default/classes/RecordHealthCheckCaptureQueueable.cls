/** Evaluates and captures one Check Set request in Queueable Apex. */
public with sharing class RecordHealthCheckCaptureQueueable implements Queueable {
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;

  /** @param checkSetQualifiedApiName Qualified Check Set identity. @param recordIds Records to evaluate. */
  public RecordHealthCheckCaptureQueueable(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = recordIds == null ? null : new List<Id>(recordIds);
  }

  /** @param context Current Queueable context. */
  public void execute(QueueableContext context) {
    System.attachFinalizer(
      new CaptureFinalizer(checkSetQualifiedApiName, context.getJobId())
    );
    RecordHealthCheckCaptureService.runCheckSet(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckCaptureService.SOURCE_QUEUEABLE,
      context.getJobId()
    );
  }

  /**
   * @param checkSetQualifiedApiName Qualified Check Set identity.
   * @param recordIds Records to evaluate.
   * @return The queued AsyncApexJob ID.
   */
  public static Id enqueue(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    return System.enqueueJob(
      new RecordHealthCheckCaptureQueueable(checkSetQualifiedApiName, recordIds)
    );
  }

  /** Persists an unhandled Queueable failure in a fresh transaction. */
  private class CaptureFinalizer implements Finalizer {
    private String checkSetQualifiedApiName;
    private Id jobId;

    private CaptureFinalizer(String checkSetQualifiedApiName, Id jobId) {
      this.checkSetQualifiedApiName = checkSetQualifiedApiName;
      this.jobId = jobId;
    }

    /** @param context Terminal context for the parent Queueable job. */
    public void execute(FinalizerContext context) {
      if (context.getResult() == ParentJobResult.SUCCESS) {
        return;
      }
      RecordHealthCheckCaptureService.captureQueueableFailure(
        checkSetQualifiedApiName,
        jobId,
        context.getException()
      );
    }
  }
}
