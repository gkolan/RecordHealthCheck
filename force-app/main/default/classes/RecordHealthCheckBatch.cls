/** Splits a large qualified Check Set request into governor-safe transactions. */
global with sharing class RecordHealthCheckBatch implements Database.Batchable<Id> {
  /** Packaged execute-scope size, below the engine's 200-record ceiling. */
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
    RecordHealthCheckAccess.requireCanRunChecks();
    RecordHealthCheckAsyncSupport.RequestState state = RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Batch population'
    );
    this.checkSetQualifiedApiName = state.checkSetQualifiedApiName;
    this.recordIds = state.recordIds;
    this.publication = publication ?? RecordHealthCheckEventPublication.NONE;
  }

  /** Returns the explicit record identities supplied by the caller. */
  global Iterable<Id> start(Database.BatchableContext context) {
    RecordHealthCheckAccess.requireCanRunChecks();
    return recordIds;
  }

  /** Evaluates one batch scope through the public engine. */
  global void execute(Database.BatchableContext context, List<Id> scope) {
    RecordHealthCheckAccess.requireCanRunChecks();
    if (scope.isEmpty()) {
      return;
    }
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(checkSetQualifiedApiName, scope)
          .withExecutionOrigin(RecordHealthCheckExecutionOrigin.BATCH)
          .withEventPublication(publication)
          .withRunId('batch-' + context.getJobId())
      );
    } catch (Exception error) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        'batch-' + context.getJobId(),
        checkSetQualifiedApiName,
        null,
        null,
        'BATCH_SCOPE_FAILED',
        null,
        error
      );
      RecordHealthCheckLogger.flush();
      throw error;
    }
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
    RecordHealthCheckAccess.requireCanRunChecks();
    validatePopulation(checkSetQualifiedApiName, recordIds);
    return Database.executeBatch(
      new RecordHealthCheckBatch(
        checkSetQualifiedApiName,
        recordIds,
        publication
      ),
      DEFAULT_SCOPE_SIZE
    );
  }

  @TestVisible
  private static void validatePopulation(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Batch population'
    );
  }
}
