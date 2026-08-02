/** Splits a large qualified Check Set request into governor-safe transactions. */
global with sharing class RecordHealthCheckBatch implements Database.Batchable<Id> {
  global static final Integer DEFAULT_SCOPE_SIZE = 100;
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;

  /** Creates a batch over an explicit, defensively copied record scope. */
  global RecordHealthCheckBatch(
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

  /** Returns the explicit record identities supplied by the caller. */
  global Iterable<Id> start(Database.BatchableContext context) {
    return recordIds;
  }

  /** Evaluates one batch scope through the public engine. */
  global void execute(Database.BatchableContext context, List<Id> scope) {
    if (scope.isEmpty()) {
      return;
    }
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(checkSetQualifiedApiName, scope)
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.BATCH)
        .withEventPublication(publication)
        .withRunId('batch-' + context.getJobId())
    );
  }

  /** Completes without a second evaluation or chained transaction. */
  global void finish(Database.BatchableContext context) {
    return;
  }

  /** Starts the batch with the framework default scope size. */
  global static Id run(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    return Database.executeBatch(
      new RecordHealthCheckBatch(
        checkSetQualifiedApiName,
        recordIds,
        publication
      ),
      DEFAULT_SCOPE_SIZE
    );
  }
}
