# Run Record Health Check from Batch Apex

> [!NOTE]
> On this page, process a large record population in Batch Apex scopes sized for the selected Check Set and capture each scope with a distinct correlation ID.

Use the packaged `RecordHealthCheckBatch` when the record IDs are already known:

```apex
Id jobId = RecordHealthCheckBatch.run(
  'rhc__Account_Data_Quality',
  accountIds,
  RecordHealthCheckEventPublication.ACTIONABLE
);
```

Create a custom query-backed Batch only when record discovery must also happen asynchronously.
Each
`execute` scope is a separate transaction, so each scope must independently satisfy Record Health
Check limits.

## Batch example

Create a batch that queries record IDs and evaluates each scope once:

```apex
public with sharing class AccountHealthBatch
  implements Database.Batchable<Account> {
  private final String checkSetQualifiedApiName;

  public AccountHealthBatch(String checkSetQualifiedApiName) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      'SELECT Id FROM Account WHERE IsDeleted = false'
    );
  }

  public void execute(
    Database.BatchableContext context,
    List<Account> scope
  ) {
    List<Id> recordIds = new List<Id>();
    for (Account accountRecord : scope) {
      recordIds.add(accountRecord.Id);
    }

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          checkSetQualifiedApiName,
          recordIds
        )
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.BATCH)
        .withRunId(
          'batch-' + context.getJobId() + '-' + recordIds[0]
        )
        .withEventPublication(
          RecordHealthCheckEventPublication.ACTIONABLE
        )
    );

    // Persist or aggregate only the outcomes required by the use case.
  }

  public void finish(Database.BatchableContext context) {
  }
}
```

Choose the scope size from the number and shape of active Rules. For a Check Set with several
Formula Rules, the planned-evaluation ceiling may require a much smaller scope than the public
record ceiling.

Run the batch with an explicitly reviewed scope size:

```apex
Id jobId = Database.executeBatch(
  new AccountHealthBatch('rhc__Account_Data_Quality'),
  25
);
```

## Failure and retry behavior

One failed scope does not erase successful earlier scopes. Retried work can produce the same
business outcomes again, so use a stable uniqueness key when persisting results or handling
events. Correlate each scope with the Batch job ID and a scope-specific value.

Do not create a per-record fallback when a Rule cannot evaluate in bulk. Resolve unsupported
shapes in memory or return the documented unable status.

## Test the batch

Execute one batch in a test method between `Test.startTest()` and `Test.stopTest()`. Assert the
captured outcome and query `AsyncApexJob` for completion. Add a focused test for a scope that
returns `FAIL`, `UNABLE_TO_EVALUATE`, or `ERROR`.

## Related

- [Queueable Apex](queueable.md)
- [Scheduled Apex](scheduled.md)
- [Apex API limits](apex-api.md#limits-and-access)
- [Check Set Run event](../platform-events/check-set-run.md)
