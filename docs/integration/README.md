# Salesforce integrations

> [!NOTE]
> On this page, place each readiness decision on the right Salesforce surface by comparing how Lightning, Apex, Flow, and platform events start work, return outcomes, and handle failure.

Use this page to decide where a readiness decision belongs: a Lightning record page, Flow,
Apex, or an independent subscriber receiving an after-commit lifecycle event.

Record Health Check uses the same metadata-defined Check Sets and Rules across those surfaces. The
integration choice changes how the evaluation starts and how the caller receives the result; it
does not create a second configuration model.

## Choose an integration

| Goal | Start here | What you will learn |
| --- | --- | --- |
| Show health to a user on a record page | [Lightning component](lightning-component.md) | Automatic versus explicit runs, visible rows, and optional user-initiated events |
| Make an immediate decision in code | [Apex API](../reference/reference-apex-api.md) | Run a Check Set or Rule and branch on a typed response |
| Branch in automation without custom Apex | [Flow actions](flow-actions.md) | Configure an Action and Decision element with explicit status paths |
| Notify independent automation after commit | [Lifecycle events](lifecycle-events.md) | Opt in, subscribe, and handle replay or duplicate delivery |
| Implement a decision the other Evaluation Types cannot express | [Recent Account activity](../examples/apex/01-recent-activity.md) | Write the class used by a Verify with Apex Rule |

## What Record Health Check is

Record Health Check is a synchronous evaluation framework for Salesforce records.

- A **Check Set** is the parent configuration and normal unit of execution.
- A **Rule** is one ordered check inside a Check Set.
- A run returns structured status data immediately.
- Optional lifecycle events announce completed runs after the transaction commits.
- Evaluation respects the running user's Salesforce access.

Start with a Check Set. Use a single Rule only when your process intentionally needs one specific
check rather than the complete configured health assessment.

## What it is not

Record Health Check is not:

- A database of historical results. Responses are transient unless a subscriber stores them.
- A validation rule. It reports health; it does not block record save.
- A remediation engine. It does not automatically update unhealthy records.
- A guaranteed-message queue. Platform-event publication and delivery are asynchronous and best effort.
- A record-change listener. A run happens only when Lightning, Apex, Flow, or scheduled code invokes it.
- A replacement for Salesforce security. It evaluates with the caller's effective access.
- An all-record bulk scanner. Public requests are deliberately bounded.

## Compare integration outputs

| Goal | Start here | Immediate output | Optional event source |
| --- | --- | --- | --- |
| Show health on a record page | [Lightning component](lightning-component.md) | Rows and Set summary | `USER_INITIATED`; automatic load is blocked |
| Make a code-level decision | [Apex API](../reference/reference-apex-api.md) | Typed Rule or Set response | `APEX_API`, `SCHEDULED`, or `BATCH` |
| Branch in automation without code | [Flow actions](flow-actions.md) | Flow output variables and JSON | `FLOW` |
| React asynchronously or export results | [Platform events](lifecycle-events.md) | Event payload | Depends on the publisher |
| Add a custom evaluation algorithm | [Recent Account activity](../examples/apex/01-recent-activity.md) | Normal Rule result | Inherits the calling run |

## Core model

```text
Check Set
├── Rule A
├── Rule B
└── Rule C

runSet(...) ──> RecordHealthCheckSetResult
                 ├── aggregate status and counts
                 └── results[]: RecordHealthCheckResult
```

The successful status is `PASS`, not `SUCCESS`.

| Status | Meaning |
| --- | --- |
| `PASS` | The configured health condition was satisfied |
| `FAIL` | Evaluation completed and found an unhealthy business condition |
| `SKIPPED` | Evaluation was intentionally prevented by applicability, dependency, or stop behavior |
| `UNABLE_TO_EVALUATE` | Configuration, access, or data conditions prevented a reliable conclusion |
| `ERROR` | Unexpected system or evaluator failure |

A Check Set uses the strongest contained result in this order:
`ERROR → UNABLE_TO_EVALUATE → FAIL → PASS → SKIPPED`.

## Contract versions

The synchronous Apex and Flow response contract is stable at `1.0`. Lifecycle events use a
separate stable `1.0` schema and report Core product version `2.0.0`. Matching version numbers do not
make the schemas interchangeable; each can version independently.

## Quick start with Apex

```apex
RecordHealthCheckSetResult health = RecordHealthCheck.runSet(
  'Example_Account_360_Health_Check',
  accountId
);

switch on health.status {
  when 'PASS' {
    // Continue the healthy path.
  }
  when 'FAIL' {
    // Use health.failedCount and health.results for business handling.
  }
  when else {
    // Handle skipped, unable, and system-error outcomes explicitly.
  }
}
```

For method overloads, fields, limits, and exceptions, use the [Apex API reference](../reference/reference-apex-api.md).

## Quick start with Flow

1. Add **Run Record Health Check Set** from the **Record Health Check** action category.
2. Provide **Check Set API Name** and **Record ID**.
3. Add a Decision element with explicit branches for the returned **Status**.
4. Connect the fault path.
5. Use the count outputs or Result JSON when the decision needs Rule-level detail.

For every input and output, use the [Flow actions reference](flow-actions.md).

## Synchronous results versus events

| Output | Timing | Use |
| --- | --- | --- |
| Apex/Flow/LWC result | During the invocation | Make the current decision or render the card |
| Lifecycle event | After commit | Notify subscribers, persist history, export, or trigger independent automation |

Enabling events does not change the synchronous result. A successful synchronous run does not prove
that an event subscriber completed.

Publication is off by default:

- Check Set **Publish Run Event** enables one completed Set event.
- Rule **Publish Result Event** enables one event for that server-finalized Rule.
- Automatic Lightning page-load runs never publish.

## Limits

| Limit | Value |
| --- | --- |
| Records in one public Apex or Flow invocation | 200 |
| Planned Rule evaluations in one invocation | 15 |
| Concurrent Lightning Rule evaluations | 5 |
| Platform-event publish chunk | 100 |

For a Set request, planned evaluations equal records × active Rules.

## Design for failures

Handle these cases separately:

- A valid unhealthy result: `FAIL`.
- An intentional non-run: `SKIPPED`.
- No reliable conclusion: `UNABLE_TO_EVALUATE`.
- An unexpected execution problem: `ERROR`.
- An exception before a response is available, such as an invalid request or governor limit.
- A successful response followed by a transaction rollback, which suppresses Publish After Commit events.
- Duplicate or replayed subscriber processing.

Use stable Statuses, Reason Codes, Failure Severities, and Developer Names for automation. Do not branch on
administrator-authored message text.

## Test before enabling events

1. Configure and run the Check Set in a sandbox.
2. Verify every status branch your integration handles.
3. Test with users who have different record and field access.
4. Confirm request volume stays within evaluation and event allocations.
5. Enable publication for one Set or Rule at a time.
6. Verify commit, rollback, duplicate-processing, and subscriber-failure behavior.

## Next steps

- [Apex API](../reference/reference-apex-api.md)
- [Flow actions](flow-actions.md)
- [Lightning component](lightning-component.md)
- [Platform events](lifecycle-events.md)
- [Reason Codes](../reference/reference-reason-codes.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
