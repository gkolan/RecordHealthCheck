# Run Record Health Check from Queueable Apex

> [!NOTE]
> On this page, create a Queueable Apex wrapper that evaluates one bounded record scope in a separate transaction and preserves a correlation ID.

Queueable Apex is the preferred asynchronous pattern for new work that fits in one Record Health
Check request. It provides an `AsyncApexJob` ID, supports non-primitive constructor state, and can
chain follow-on work when the design requires another transaction.

## Packaged Queueable

For a bounded scope, enqueue the packaged adapter directly:

```apex
Id jobId = RecordHealthCheckQueueable.enqueue(
  'rhc__Account_Data_Quality',
  accountIds,
  RecordHealthCheckEventPublication.ACTIONABLE
);
```

## Custom Queueable example

Create a class that accepts the qualified Check Set identity and a bounded list of record IDs:

```apex
public with sharing class AccountHealthQueueable
  implements Queueable, Finalizer {
  private final String checkSetQualifiedApiName;
  private final List<Id> recordIds;

  public AccountHealthQueueable(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = new List<Id>(recordIds);
  }

  public void execute(QueueableContext context) {
    System.attachFinalizer(this);
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
      checkSetQualifiedApiName,
      recordIds
    )
      .withExecutionOrigin(RecordHealthCheckExecutionOrigin.QUEUEABLE)
      .withRunId('queueable-' + context.getJobId())
      .withEventPublication(RecordHealthCheckEventPublication.ACTIONABLE);

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    if (response.summary.systemError > 0 || response.summary.unable > 0) {
      // Persist a restricted operational record or notify approved monitoring.
    }
  }

  public void execute(FinalizerContext context) {
    if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
      // Send sanitized job context to approved operational monitoring.
      // Do not copy record data or an unfiltered stack trace into user-visible fields.
    }
  }
}
```

Enqueue the class from Apex with a scope that already satisfies the public limits:

```apex
Id jobId = System.enqueueJob(
  new AccountHealthQueueable(
    'rhc__Account_Data_Quality',
    accountIds
  )
);
```

## Failure handling

An `ERROR` result is data returned by the Framework. An uncaught exception fails the Queueable job.
The Finalizer observes that second channel even when the Queueable transaction rolls back. Store
the Queueable job ID with the Framework `runId` when operational staff must correlate an
`AsyncApexJob` with captured health results.

Queueable Apex does not increase the per-request Record Health Check limits. Split work before
enqueueing or use Batch Apex when the population requires multiple scopes.

The Queueable runs with the effective access of the user who enqueued it. Review object, record,
field, Apex class, and Custom Metadata access for that user.

## Test the Queueable

Use `Test.startTest()` and `Test.stopTest()` to execute the queued job. Assert the response-driven
side effect, the source or correlation value, and the Finalizer's sanitized handling of an uncaught
failure.

## Related

- [Batch Apex](batch.md)
- [Scheduled Apex](scheduled.md)
- [Apex API](apex-api.md)
- [Platform Event subscriptions](../platform-events/README.md)
