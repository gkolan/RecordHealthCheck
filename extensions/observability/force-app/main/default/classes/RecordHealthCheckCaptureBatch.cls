/** Evaluates and captures a Check Set over record IDs in Batch Apex chunks. */
public with sharing class RecordHealthCheckCaptureBatch implements Database.Batchable<Id> {
  private static final Integer DEFAULT_SCOPE_SIZE = 50;
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;

  /** @param checkSetQualifiedApiName Qualified Check Set identity. @param recordIds Records to evaluate. */
  public RecordHealthCheckCaptureBatch(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = recordIds == null
      ? new List<Id>()
      : new List<Id>(recordIds);
  }

  /** @return The detached IDs supplied to the batch. */
  public Iterable<Id> start(Database.BatchableContext context) {
    return recordIds;
  }

  /** Evaluates and captures one Batch Apex scope. */
  public void execute(Database.BatchableContext context, List<Id> scope) {
    RecordHealthCheckCaptureService.runCheckSet(
      checkSetQualifiedApiName,
      scope,
      RecordHealthCheckCaptureService.SOURCE_BATCH,
      context.getJobId()
    );
  }

  /** No additional work is required after captured scopes complete. */
  // code-analyzer-suppress-next-line EmptyStatementBlock: Database.Batchable requires finish; this implementation has no terminal work.
  public void finish(Database.BatchableContext context) {
  }

  /** @return The Batch Apex AsyncApexJob ID. */
  public static Id run(String checkSetQualifiedApiName, List<Id> recordIds) {
    return Database.executeBatch(
      new RecordHealthCheckCaptureBatch(checkSetQualifiedApiName, recordIds),
      DEFAULT_SCOPE_SIZE
    );
  }
}
