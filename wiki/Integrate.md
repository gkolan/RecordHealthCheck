# Integrate

Use Apex or Flow when a process must run a health check without opening the Lightning record page.
Use the optional platform events when another Salesforce process needs completed results.

## Run checks from Apex

The public `RecordHealthCheck` class evaluates one Rule or one Check Set. It uses the calling user's
record and field access and returns the result before the transaction continues.

- **One record or many.** Pass a single record Id or a list; you get one response per record, so you
  can evaluate across a list view without per-record calls.
- **Consistent result.** Each response includes status, failure severity, reason code, Check Title,
  resolved messages, and—when the user has access—Found and Expected values. A Check Set response
  also includes overall status and result counts.
- In Apex or Flow decisions, use status, reason code, severity, and API name. Do not compare
  user-facing message text.

```apex
RecordHealthCheckSetResult result =
    RecordHealthCheck.runSet('Example_Account_360_Health_Check', accountId);
```

## Call it from Flow

Add the **Run Record Health Check** action to a Flow. Leave **Rule API Name** blank to run the whole
Check Set, or provide it to run one Rule. The action returns status and counts for Flow decisions.

## React to results — lifecycle events

Core can publish two optional platform events after a transaction commits:

| Event                                | One per                | Use it for                                     |
| ------------------------------------ | ---------------------- | ---------------------------------------------- |
| `Record_Health_Check_Set_Run__e`     | Check Set run          | Usage and result-count reporting               |
| `Record_Health_Check_Rule_Result__e` | Finalized Rule outcome | History, notifications, work creation, exports |

Both are **off by default** and enabled per Check Set / per Rule with the `Publish Run Event` and
`Publish Result Event` fields. Publication is **after commit** and best-effort: a publish failure
never changes a health result. Payloads carry stable identifiers and outcomes — not queries,
messages, or business-record values.

**Opening a record page never publishes these events.** The settings apply only to Apex and Flow
runs. See **[[Extend]]** before building automation from the events.

## Custom checks in Apex

Implement `RecordHealthCheckRule` to add organization-specific logic that plugs into the same engine:

```apex
public interface RecordHealthCheckRule {
  RecordHealthCheckResult evaluate(RecordHealthCheckContext context);
}
```

Core supplies the record context, calls your class, and returns errors in the standard result
format. Your class must use sharing and check object and field access for every query it adds.

## Reference

- [Programmatic API and Flow](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/apex/programmatic-api.md)
- [Lifecycle events](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/lifecycle-events.md)
- [Apex plugin contract](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/apex/plugin-contract.md)

## Next

- Turn these contracts into installable products → **[[Extend]]**
