# Check Set Run Platform Event (`Record_Health_Check_Set_Run__e`)

> [!NOTE]
> **On this page**
>
> Understand when the Check Set Run Platform Event publishes, look up every field, and design subscribers for history, monitoring, analytics, and downstream automation.

`Record_Health_Check_Set_Run__e` contains one completion summary for a deliberately initiated Check
Set run. It is a high-volume Salesforce Platform Event with **Publish After Commit** behavior.

Use the [lifecycle-events overview](../integration/lifecycle-events.md) for publication sources,
opt-in behavior, transaction timing, and subscriber failure guidance.

## When to use this event

Choose the Set Run event when a subscriber needs one summary per completed Check Set rather than
one event per Rule.

| Possibility | What the subscriber can do |
| --- | --- |
| Health history | Persist one row per `RunId__c` and record to show how overall readiness changes over time |
| Operational monitoring | Alert when `SystemErrorCount__c` or `UnableCount__c` is greater than zero |
| Adoption analytics | Measure deliberate reviews by Check Set, source, and time period |
| Process orchestration | Start downstream work only after a deliberate Check Set run commits |
| Completion reporting | Compare passed, failed, skipped, unable, and system-error counts without receiving Rule detail |

Do not use this event when the current Salesforce transaction needs an immediate decision. Use the
synchronous [Apex API](../integration/apex-api/public-api.md) or [Flow action](../integration/flow-actions.md)
response instead.

## Publication conditions

The Framework publishes this event only when all conditions are true:

1. The Check Set has **Publish Run Event** (`PublishRunEvent__c`) checked.
2. The run completes through an allowed deliberate source: `APEX_API`, `FLOW`, `USER_INITIATED`,
   `SCHEDULED`, or `BATCH`.
3. The Salesforce transaction commits.

Automatic Lightning record-page evaluation (`RUN_ON_LOAD`) never publishes. Subscriber context
(`SUBSCRIBER`), blank sources, and unknown sources are blocked to prevent feedback loops.

## Event definition

| Property | Value |
| --- | --- |
| Salesforce metadata type | Platform Event |
| API name | `Record_Health_Check_Set_Run__e` |
| Setup label | Record Health Check Set Run |
| Event type | High Volume |
| Publish behavior | Publish After Commit |
| Contract version | `1.0` |
| Phase | `COMPLETED` |

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Application-level deduplication key. Do not substitute the Salesforce replay ID. |
| Run ID | `RunId__c` | Text(120) | Required; supplied or generated | Correlates the Set event, Rule Result events, synchronous response, and Framework logs. |
| Phase | `Phase__c` | Text(30) | Required; `COMPLETED` | Lifecycle phase. `COMPLETED` is the only supported value. |
| Check Set API Name | `CheckSetDeveloperName__c` | Text(80) | Required | Check Set `DeveloperName`; stable across label changes. |
| Record ID | `RecordId__c` | Text(18) | Optional | Salesforce record evaluated by the Check Set when one record is available. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC time when the Framework constructed the event. |
| Source | `Source__c` | Text(30) | Required; caller-derived | `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, or `BATCH`. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of this Platform Event schema, independent of synchronous response versions. |
| Core Version | `CoreVersion__c` | Text(20) | Required; `2.0.0` | Framework release that produced the event. |
| Eligible Rule Count | `EligibleRuleCount__c` | Number(5,0) | Optional; generated | Rules included after the Framework selected definitions for the run. |
| Evaluated Rule Count | `EvaluatedRuleCount__c` | Number(5,0) | Optional; generated | Finalized Rule results. Equal to eligible count for completed events. |
| Passed Count | `PassedCount__c` | Number(5,0) | Optional; generated | Rule results with `PASS`. |
| Failed Count | `FailedCount__c` | Number(5,0) | Optional; generated | Rule results with `FAIL`. |
| Skipped Count | `SkippedCount__c` | Number(5,0) | Optional; generated | Rule results with `SKIPPED`. |
| Unable Count | `UnableCount__c` | Number(5,0) | Optional; generated | Rule results with `UNABLE_TO_EVALUATE`. |
| System Error Count | `SystemErrorCount__c` | Number(5,0) | Optional; generated | Rule results with `ERROR`. |

## Example payload

```json
{
  "ContractVersion__c": "1.0",
  "CoreVersion__c": "2.0.0",
  "EventId__c": "rhc-run-001-SET-184275",
  "RunId__c": "rhc-run-001",
  "Phase__c": "COMPLETED",
  "CheckSetDeveloperName__c": "Account_Readiness",
  "RecordId__c": "001000000000001AAA",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Source__c": "USER_INITIATED",
  "EligibleRuleCount__c": 5,
  "EvaluatedRuleCount__c": 5,
  "PassedCount__c": 3,
  "FailedCount__c": 1,
  "SkippedCount__c": 1,
  "UnableCount__c": 0,
  "SystemErrorCount__c": 0
}
```

Values are illustrative. Subscribers must tolerate additive fields within contract version `1.0`.

## Subscriber design

- Deduplicate side effects with `EventId__c`; use the Salesforce replay ID for replay position.
- Treat delivery as at least once. A subscriber retry can deliver the same logical event again.
- Persist the event if history beyond Salesforce Platform Event retention is required.
- Join to business data under the subscriber's own sharing and field-access model.
- Do not assume `RecordId__c` is populated for every future invocation shape.
- Do not infer Rule-level causes from counts. Subscribe to the Rule Result event when details are required.

## Limits and security

The event intentionally excludes user identity, messages, SOQL, Found, Expected, and diagnostic
details. It can contain a Salesforce Record ID, so restrict subscriber and persisted-history access
according to the sensitivity of the referenced objects.

Publication is best effort and chunked in groups of 100. Publish acceptance does not prove delivery
or successful subscriber processing, and subscriber failure never changes the completed Check Set result.

## Related

- [Lifecycle-events overview](../integration/lifecycle-events.md)
- [Rule Result Platform Event](event-rule-result.md)
- [Log Platform Event](event-log.md)
- [Check Set fields](fields-check-set.md) — **Publish Run Event**
- [Reason Codes](../reference/reason-codes.md)
