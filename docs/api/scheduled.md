# Run Record Health Check from Scheduled Apex

> [!NOTE]
> On this page, schedule recurring health-check work by handing the record population to Batch Apex instead of evaluating an unbounded population in the scheduler transaction.

Scheduled Apex should start bounded Queueable work or a Batch Apex job. The scheduler transaction
should not query an unrestricted population and attempt to evaluate it in one request.

## Scheduled example

Create a scheduler that starts the reviewed Batch Apex implementation:

```apex
public with sharing class NightlyAccountHealthSchedule
  implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(
      new AccountHealthBatch('rhc__Account_Data_Quality'),
      25
    );
  }
}
```

Schedule the class from Setup or Apex:

```apex
String jobId = System.schedule(
  'Nightly Account Health',
  '0 0 2 * * ?',
  new NightlyAccountHealthSchedule()
);
```

## Operational design

Record the scheduled job ID, downstream Batch or Queueable job ID, and Framework run IDs when the
process needs traceable history. Monitor failed scheduler starts separately from health-check
`ERROR` results and downstream asynchronous job failures.

The scheduled user supplies the effective Apex, object, record, and field access. Verify that
access in a sandbox before enabling the schedule.

## Test the schedule

Schedule the class between `Test.startTest()` and `Test.stopTest()`. Assert the downstream job or
its persisted outcome. Keep the scheduler test separate from detailed evaluator tests.

## Related

- [Batch Apex](batch.md)
- [Queueable Apex](queueable.md)
- [Apex API](apex-api.md)
- [Check Set Run event](../platform-events/check-set-run.md)
