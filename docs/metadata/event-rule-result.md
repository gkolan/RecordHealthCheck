# Rule Result Platform Event (`Record_Health_Check_Rule_Result__e`)

> [!NOTE]
> On this page, design a secure Rule Result subscriber that receives one finalized Rule outcome after commit and uses its fields responsibly for history, routing, alerts, or analytics.

`Record_Health_Check_Rule_Result__e` contains the finalized public outcome of one Rule in a
deliberately initiated run. It is a high-volume Salesforce Platform Event with **Publish After
Commit** behavior.

Use the [lifecycle-events overview](../integration/lifecycle-events.md) for publication sources,
transaction timing, event selection, and subscriber failure guidance.

## When to use this event

Choose the Rule Result event only when the subscriber needs per-Rule information.

| Possibility | What the subscriber can do |
| --- | --- |
| Rule history | Persist status and Reason Code trends for each Rule and Salesforce record |
| Targeted alerts | Notify an owning team when a selected Rule returns `FAIL` or `ERROR` |
| Automation routing | Route by `Status__c`, `ReasonCode__c`, `Severity__c`, and stable Rule Developer Name |
| Configuration analytics | Identify Rules that often skip or cannot evaluate |
| Cross-system readiness | Send minimal finalized outcomes without sending Found, Expected, or administrator-authored messages |

Use the Set Run event instead when one completion summary is sufficient. Use a synchronous response
when the current transaction must branch immediately.

## Publication conditions

The Framework publishes one event for a Rule only when all conditions are true:

1. The Rule has **Publish Result Event** (`PublishResultEvent__c`) checked.
2. The Rule has a finalized result in a deliberate Check Set or Rule run.
3. The source is `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, or `BATCH`.
4. The Salesforce transaction commits.

Automatic Lightning record-page evaluation, subscriber context, blank sources, and unknown sources
do not publish.

## Event definition

| Property | Value |
| --- | --- |
| Salesforce metadata type | Platform Event |
| API name | `Record_Health_Check_Rule_Result__e` |
| Setup label | Record Health Check Rule Result |
| Event type | High Volume |
| Publish behavior | Publish After Commit |
| Contract version | `1.0` |

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Application-level deduplication key. |
| Run ID | `RunId__c` | Text(120) | Required; supplied or generated | Correlates this result with its Check Set run, response, and Framework logs. |
| Check Set API Name | `CheckSetDeveloperName__c` | Text(80) | Required | Parent Check Set `DeveloperName`. |
| Rule API Name | `RuleDeveloperName__c` | Text(80) | Required | Finalized Rule `DeveloperName`. |
| Record ID | `RecordId__c` | Text(18) | Optional | Salesforce record evaluated when one record is available. |
| Status | `Status__c` | Text(30) | Required | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`. |
| Reason Code | `ReasonCode__c` | Text(80) | Optional | Stable public Reason Code. Diagnostics-only codes are not published here. |
| Severity | `Severity__c` | Text(20) | Optional | `CRITICAL`, `WARNING`, or `INFO` when applicable. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC time when the Framework constructed the event. |
| Source | `Source__c` | Text(30) | Required; caller-derived | `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, or `BATCH`. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of this event schema. |
| Core Version | `CoreVersion__c` | Text(20) | Required; `2.0.0` | Framework release that produced the event. |
| Contains Restricted Detail | `ContainsRestrictedDetail__c` | Checkbox | Defaults to false | Indicates that restricted detail existed on the in-memory result. It does not publish that detail. |

## Example payload

```json
{
  "ContractVersion__c": "1.0",
  "CoreVersion__c": "2.0.0",
  "EventId__c": "rhc-run-001-Account_Has_Contact-27462",
  "RunId__c": "rhc-run-001",
  "CheckSetDeveloperName__c": "Account_Readiness",
  "RuleDeveloperName__c": "Account_Has_Contact",
  "RecordId__c": "001000000000001AAA",
  "Status__c": "FAIL",
  "ReasonCode__c": null,
  "Severity__c": "WARNING",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Source__c": "USER_INITIATED",
  "ContainsRestrictedDetail__c": false
}
```

Values are illustrative. Consumers must ignore additive fields they do not recognize.

## Interpret the outcome

| Status | Subscriber interpretation |
| --- | --- |
| `PASS` | The Rule's business condition was satisfied. |
| `FAIL` | The Rule evaluated normally and found a business condition that needs attention. |
| `SKIPPED` | The Rule did not apply, a prerequisite was not met, or configured empty-result behavior selected skip. |
| `UNABLE_TO_EVALUATE` | Access, configuration, dependency, or available data prevented a reliable decision. Use `ReasonCode__c`. |
| `ERROR` | An unexpected Framework, evaluator, or platform problem occurred. Investigate logs and the Log event. |

Never treat every status other than `FAIL` as success. Never branch on display messages; they are
intentionally absent from this contract.

## Subscriber design

- Deduplicate with `EventId__c` and make side effects safe to repeat.
- Route using API values, not translated labels or administrator-authored text.
- Allow unknown additive Reason Codes and statuses to enter a safe review path.
- Use `RunId__c` to group Rule Result events with their Set Run summary.
- Persist events when history beyond Platform Event retention is required.
- Query additional Salesforce data only under the subscriber's own security context.
- Do not treat `ContainsRestrictedDetail__c = true` as permission to expose diagnostics.

## Limits and security

The event excludes messages, SOQL, Found, Expected, stack traces, user identity, and
`adminDetail`. `ContainsRestrictedDetail__c` is a presence flag only. `RecordId__c` can identify a
Salesforce record, so access to subscribers and persisted results must match the referenced data's
sensitivity.

Publication is best effort and chunked in groups of 100. A publishing or subscriber failure does
not change the finalized Rule status.

## Related

- [Lifecycle-events overview](../integration/lifecycle-events.md)
- [Check Set Run Platform Event](event-set-run.md)
- [Log Platform Event](event-log.md)
- [Rule fields](fields-rule.md): **Publish Result Event**
- [Reason Codes](../reference/reference-reason-codes.md)
