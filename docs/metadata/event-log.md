# Log Platform Event (`Record_Health_Check_Log__e`)

> [!NOTE]
> **On this page**
>
> Understand the restricted Framework diagnostics event, look up every field, and design secure subscribers for error persistence, investigation, and alerting.

`Record_Health_Check_Log__e` carries structured Framework `ERROR` information. Unlike the two
lifecycle events, it uses **Publish Immediately**, contains restricted diagnostic detail, and is not
controlled by Check Set or Rule publication fields.

This event is for technical operations and support—not business readiness workflows.

## When to use this event

| Possibility | What the subscriber can do |
| --- | --- |
| Durable error history | Persist Framework errors beyond debug-log and Platform Event retention |
| Technical alerting | Notify a restricted support channel when a new error Code or exception appears |
| Incident correlation | Group errors by Run ID, Salesforce record, Check Set, Rule, user, and Core version |
| Release monitoring | Compare error rates before and after a Framework or configuration deployment |
| Reproduction support | Use record and metadata identifiers to reproduce a failure under controlled access |

Do not use the Log event as a Rule result, audit history, or business-process command. Use Rule
Result and Set Run events for finalized outcomes.

## How publication works

`RecordHealthCheckLogger` buffers each Framework log entry whose level is `ERROR`. The public Apex,
Flow, and Lightning boundaries call `flush()`, which publishes buffered events in chunks of 100 and
clears the transaction buffer.

| Behavior | Log event |
| --- | --- |
| Event type | High Volume |
| Publish behavior | Publish Immediately |
| Default | Error-event publication enabled in Framework code |
| Published levels | `ERROR` only |
| Opt-in Custom Metadata field | None |
| Contract version | `1.0` |
| Failure behavior | Best effort; publishing failure is logged and does not change the health-check result |

`Publish Immediately` allows an accepted event to survive a later transaction rollback. However, an
uncatchable governor-limit abort can prevent `flush()` from running, so this event is not a complete
replacement for Salesforce debug logs and platform exception monitoring.

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Application-level deduplication key. |
| Run ID | `RunId__c` | Text(120) | Required; generated or inherited | Correlates errors from one Framework run. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC event-construction time. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of the diagnostics-event schema. |
| Core Version | `CoreVersion__c` | Text(20) | Optional; Framework supplied | Framework release that produced the error. |
| Level | `Level__c` | Text(10) | Required; `ERROR` | Log level. Core publishes only `ERROR` events. |
| Code | `Code__c` | Text(120) | Optional | Stable or internal event code such as `APEX_EVALUATOR_ERROR` or `UNHANDLED_EXCEPTION`. |
| Message | `Message__c` | Long Text Area(32,768) | Optional | Sanitized exception message or compact sorted field summary. |
| Exception Type | `ExceptionType__c` | Text(120) | Optional | Apex exception type when an exception is available. |
| Stack Trace | `StackTrace__c` | Long Text Area(32,768) | Optional | Sanitized Apex stack trace. |
| Record ID | `RecordId__c` | Text(18) | Optional | Salesforce record being evaluated, when known. |
| Check Set Developer Name | `CheckSetDeveloperName__c` | Text(120) | Optional | Check Set `DeveloperName` associated with the error. |
| Rule Developer Name | `RuleDeveloperName__c` | Text(120) | Optional | Rule `DeveloperName` associated with the error. |
| User ID | `UserId__c` | Text(18) | Optional | Running Salesforce user from `UserInfo.getUserId()`. |

## Example payload

```json
{
  "ContractVersion__c": "1.0",
  "CoreVersion__c": "2.0.0",
  "EventId__c": "rhc-run-001-APEX_EVALUATOR_ERRO-18273",
  "RunId__c": "rhc-run-001",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Level__c": "ERROR",
  "Code__c": "APEX_EVALUATOR_ERROR",
  "CheckSetDeveloperName__c": "Account_Readiness",
  "RuleDeveloperName__c": "Account_Strategic_Readiness",
  "RecordId__c": "001000000000001AAA",
  "UserId__c": "005000000000001AAA",
  "ExceptionType__c": "System.QueryException",
  "Message__c": "Illustrative sanitized exception message",
  "StackTrace__c": "Illustrative sanitized stack trace"
}
```

Never copy real stack traces, IDs, or production error messages into public documentation or an
unrestricted support channel.

## Security requirements

This event can contain a record ID, user ID, exception message, exception type, and stack trace.
Treat the event and every persisted copy as restricted operational data.

- Grant event subscription and persisted-log access only to approved administrators or support staff.
- Apply least privilege to the subscriber's Apex class, Flow, integration user, and destination object.
- Define retention and deletion requirements for persisted diagnostics.
- Do not forward raw payloads to email, chat, tickets, or external systems without security review.
- Do not assume sanitization removes every organization-specific identifier from an exception message.
- Keep Found, Expected, and source field values out of custom logging additions.

## Subscriber loop protection

A subscriber that processes `Record_Health_Check_Log__e` must call
`RecordHealthCheckLogger.enterSubscriberContext()` before its work. This prevents an error raised by
the subscriber from publishing another Log event onto the same channel.

```apex
trigger RecordHealthCheckLogSubscriber on Record_Health_Check_Log__e (after insert) {
    RecordHealthCheckLogger.enterSubscriberContext();
    // Hand off only to restricted, idempotent processing.
}
```

The subscriber must also deduplicate by `EventId__c`, handle replay, and make side effects safe to
repeat.

## Known limitations

- An uncatchable governor-limit abort can prevent `flush()` and produce no Log event.
- Publish acceptance does not prove delivery, persistence, alerting, or successful investigation.
- Platform Event retention is temporary; long-term history requires a subscriber-owned store.
- A missing Record ID or metadata name can be legitimate when the error occurred before that context was known.
- `Code__c` can contain Framework-internal codes; use the public [Reason Code registry](../reference/reason-codes.md) only for public Rule outcomes.

## Related

- [Lifecycle-events overview](../integration/lifecycle-events.md)
- [Check Set Run Platform Event](event-set-run.md)
- [Rule Result Platform Event](event-rule-result.md)
- [Show Diagnostics](../guides/show-diagnostics.md)
- [Reason Codes](../reference/reason-codes.md)
