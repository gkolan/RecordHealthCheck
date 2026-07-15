# Lifecycle events

Optional, versioned platform events describe completed Check Set runs and their Rule results. Start
with the Set event for the parent run; use Rule events for per-check detail.

Both are **high-volume platform events** configured as **Publish After Commit**. They carry the
evaluated record's ID in `RecordId__c` when one is available, but exclude queries, messages, user
identity, and field values. Automatic record-page checks never publish;
explicit Run and Rerun actions can publish when enabled.

## What these events are

- Minimal completion facts for one Check Set run and its server-finalized Rule results.
- Optional, high-volume, Publish After Commit platform events.
- A decoupling mechanism for history, notifications, exports, analytics, and independent automation.

## What these events are not

- They are not the synchronous health-check response.
- They are not a guaranteed or permanent audit log; Salesforce retains high-volume platform events
  for 72 hours, not indefinitely.
- They are not exactly-once commands. Subscribers must handle duplicates and replay safely.
- They carry the evaluated `RecordId__c` when available, but do not contain user ID, messages,
  queries, or field values.
- Publish acceptance does not prove delivery or successful subscriber processing.

For the end-to-end model, start with [Integrate Record Health Check](../integrate/overview.md).

## Prerequisites and sandbox quick start

1. Assign subscriber access to the selected platform event and choose Flow, Apex, or Pub/Sub API as
   the subscriber technology.
2. In a sandbox, enable **Publish Run Event** on one Check Set. Leave Rule publication off for the
   first test.
3. Subscribe before clicking Run or Rerun; automatic page load cannot publish.
4. Verify one `COMPLETED` Set event after commit, then test rollback, replay, and duplicate handling.
5. Enable individual Rule events only after the Set subscriber is operating within event
   allocations.

## When events publish

Publishing runs from deliberate public Apex, packaged Flow, and user-initiated Lightning component
runs. Automatic Lightning record-page runs never publish.

| Source constant | Meaning in V2 shipping callers |
| --- | --- |
| `APEX_API` | Public `RecordHealthCheck` Apex methods |
| `FLOW` | Packaged Flow actions |
| `USER_INITIATED` | An explicit Run or Rerun action in the Lightning component |
| `SCHEDULED` | A source-aware scheduled Apex caller |
| `BATCH` | A source-aware batch or other asynchronous Apex caller |
| `RUN_ON_LOAD` | Hard-blocked — never publishes |
| `SUBSCRIBER` | Hard-blocked — never publishes |

Unknown, blank, and misspelled source values are also blocked. Source-aware Apex callers must pass
one of the allowed constants; subscribers must use `SUBSCRIBER` to prevent event feedback loops.

Publish failures are logged and **do not** change Rule or Check Set results.

Events are chunked in batches of **100** (`PUBLISH_CHUNK_SIZE`).

## Opt-in switches (default off)

| Metadata | Field | What it enables |
| --- | --- | --- |
| Check Set | **Publish Run Event** (`PublishRunEvent__c`) | One `Record_Health_Check_Set_Run__e` after a completed deliberate LWC, Apex, or Flow run |
| Rule | **Publish Result Event** (`PublishResultEvent__c`) | One `Record_Health_Check_Rule_Result__e` per server-finalized Rule result in a deliberate LWC, Apex, or Flow run |

Page-load card evaluations never publish even if these checkboxes are on.

## Contract versions on events

| Field | Value | Meaning |
| --- | --- | --- |
| `ContractVersion__c` | `1.0` | Lifecycle event contract (`RecordHealthCheckLifecyclePublisher.CONTRACT_VERSION`) |
| `CoreVersion__c` | `2.0.0` | Core product version string |

This is separate from the stable sync response contract (`1.0` on `RecordHealthCheckResult` /
`RecordHealthCheckSetResult`). Both currently use version `1.0`, but they are independent schemas
and can version separately in the future.

## What is never included on an event

Events intentionally omit:

- Record Id and object API name
- User Id
- User-facing messages
- Found / Expected values
- `adminDetail` text

Subscribers join to Salesforce data with `CheckSetDeveloperName__c`, `RuleDeveloperName__c`, and `RunId__c` when they need more context under their own security model.

---

## Check Set Run event (`Record_Health_Check_Set_Run__e`)

High-volume platform event. Publish After Commit.

| Field (API) | Setup label | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| `EventId__c` | Event ID | Text(80) | Required; generated | Unique application event identifier used for deduplication |
| `RunId__c` | Run ID | Text(120) | Required; supplied or generated | Correlates the Set event, Rule events, response, and logs for one run |
| `Phase__c` | Phase | Text(30) | Required; `COMPLETED` | Event phase; `COMPLETED` is the only V2 value |
| `CheckSetDeveloperName__c` | Check Set API Name | Text(80) | Required; no metadata default | Stable `DeveloperName` of the completed Check Set |
| `RecordId__c` | Record ID | Text(18) | Optional; populated when available | The record the Check Set was evaluated against; null on runs with no single record |
| `OccurredAt__c` | Occurred At | DateTime | Required; generated | UTC event-construction timestamp |
| `Source__c` | Source | Text(30) | Required; caller-derived | Documented execution source such as `APEX_API`, `FLOW`, or `USER_INITIATED` |
| `ContractVersion__c` | Contract Version | Text(10) | Required; `1.0` | Independent lifecycle-event schema version |
| `CoreVersion__c` | Core Version | Text(20) | Required; `2.0.0` | Product release version that produced the event |
| `EligibleRuleCount__c` | Eligible Rule Count | Number(5,0) | Optional; generated count | Rules included in the completed response after definition selection |
| `EvaluatedRuleCount__c` | Evaluated Rule Count | Number(5,0) | Optional; generated count | Finalized Rule results; equal to eligible count for V2 `COMPLETED` events |
| `PassedCount__c` | Passed Count | Number(5,0) | Optional; generated count | Rule results with status `PASS` |
| `FailedCount__c` | Failed Count | Number(5,0) | Optional; generated count | Rule results with status `FAIL` |
| `SkippedCount__c` | Skipped Count | Number(5,0) | Optional; generated count | Rule results with status `SKIPPED` |
| `UnableCount__c` | Unable Count | Number(5,0) | Optional; generated count | Rule results with status `UNABLE_TO_EVALUATE` |
| `SystemErrorCount__c` | System Error Count | Number(5,0) | Optional; generated count | Rule results with status `ERROR` |

Emitted only when the Check Set has **Publish Run Event** checked, after a deliberate LWC run,
`runSet`, or the packaged Flow Set action.

---

## Rule Result event (`Record_Health_Check_Rule_Result__e`)

High-volume platform event. Publish After Commit.

| Field (API) | Setup label | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| `EventId__c` | Event ID | Text(80) | Required; generated | Unique application event identifier used for deduplication |
| `RunId__c` | Run ID | Text(120) | Required; supplied or generated | Correlates this result with its parent run, response, and logs |
| `CheckSetDeveloperName__c` | Check Set API Name | Text(80) | Required; no metadata default | Stable `DeveloperName` of the parent Check Set |
| `RuleDeveloperName__c` | Rule API Name | Text(80) | Required; no metadata default | Stable `DeveloperName` of the finalized Rule |
| `RecordId__c` | Record ID | Text(18) | Optional; populated when available | The record the Rule was evaluated against; null when no single record is in context |
| `Status__c` | Status | Text(30) | Required; finalized result | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` |
| `ReasonCode__c` | Reason Code | Text(80) | Optional; blank when not applicable | Stable public reason code; diagnostics-only detail is never copied here |
| `Severity__c` | Severity | Text(20) | Optional; populated for applicable failures | `CRITICAL`, `WARNING`, or `INFO` |
| `OccurredAt__c` | Occurred At | DateTime | Required; generated | UTC event-construction timestamp |
| `Source__c` | Source | Text(30) | Required; caller-derived | Documented execution source such as `APEX_API`, `FLOW`, or `USER_INITIATED` |
| `ContractVersion__c` | Contract Version | Text(10) | Required; `1.0` | Independent lifecycle-event schema version |
| `CoreVersion__c` | Core Version | Text(20) | Required; `2.0.0` | Product release version that produced the event |
| `ContainsRestrictedDetail__c` | Contains Restricted Detail | Checkbox | Optional; defaults unchecked | Presence flag only; restricted diagnostic text is never published |

Published only for Rules with **Publish Result Event** selected after a deliberate LWC, Apex, or
Flow run.

---

## Admin checklist before enabling

1. Review org platform-event allocations and existing subscribers.
2. Enable publication only for deliberate LWC, Apex, Flow, scheduled, or batch runs.
3. Start with a sandbox subscriber (Flow, Apex trigger, or export).
4. Use the platform event replay ID and subscriber error handling required by your business process;
   a publishing or subscriber error does not change the completed health result.
5. Do not expect record identity on the event; correlate with `RunId__c` and metadata API names.

## Subscriber failure guidance

| Symptom | Likely cause | What to investigate |
| --- | --- | --- |
| No event after page open | Automatic runs are blocked from publishing | Click Run/Rerun or invoke Apex/Flow deliberately |
| No event after an explicit run | Metadata switch is off, source is blocked, or transaction rolled back | Check the opt-in field, source, logs, and commit outcome |
| Duplicate processing | Replay or subscriber retry delivered the event again | Deduplicate with `EventId__c`; make side effects idempotent |
| Missing record context | The run had no single record, or a record ID was not available at publish | Correlate with `RunId__c` and metadata names; `RecordId__c` is populated only when available |
| Subscriber failure | Subscriber limits, access, or business logic failed independently | Monitor and retry in the subscriber; do not reinterpret the completed health result |

## Diagnostics event — `Record_Health_Check_Log__e`

A **third, separate** platform event exists for a different purpose than the two lifecycle events
above. Where the Set and Rule events are opt-in, minimal completion **facts** that deliberately
exclude messages, user identity, and field values, the diagnostics event is the durable trace of a framework **error** —
a check that failed to run. It answers the question the lifecycle events cannot: *what broke, and
where.*

| Property | Lifecycle events (Set / Rule) | Diagnostics event (Log) |
| --- | --- | --- |
| Purpose | Completion facts | Errors that need reproducing |
| Default | Opt-in per Set/Rule (off) | **On by default** (opt-out) |
| Publish behavior | Publish After Commit | **Publish Immediately** — survives the rollback a failing check triggers |
| Carries error detail | No — record ID + counts/status only | Yes — record ID plus message, exception type, stack trace |
| Level | All completed runs | `ERROR` only |
| Access | Standard subscriber | **Restricted** — permission-gate the subscriber |

Core only **emits** this event. The **object, subscriber, retention, and reporting are owned by the
Record Health Check extension package**, exactly as the lifecycle events leave persistence to
subscribers. Every `[RHC] ERROR` log line is buffered and published once per transaction by
`RecordHealthCheckLogger.flush()` (called at each Apex/Flow/LWC boundary), chunked in batches of
100.

### Fields

| API name | Type | Notes |
| --- | --- | --- |
| `RunId__c` | Text(120), required | Correlation id tying one page's / run's checks together |
| `RecordId__c` | Text(18) | The record the failing check was evaluating; null for pre-record errors (e.g. config not found) |
| `CheckSetDeveloperName__c` | Text(120) | Check Set developer name (V2 contract vocabulary) |
| `RuleDeveloperName__c` | Text(120) | Rule developer name (V2 contract vocabulary) |
| `Level__c` | Text(10), required | `ERROR` |
| `Code__c` | Text(120) | Event code, e.g. `UNHANDLED_EXCEPTION`, `APEX_EVALUATOR_ERROR` |
| `Message__c` | Long Text Area | Sanitized exception message, or a compact field summary when no exception |
| `ExceptionType__c` | Text(120) | Apex exception type name |
| `StackTrace__c` | Long Text Area | Apex stack trace |
| `UserId__c` | Text(18) | Running user (authoritative, from `UserInfo`) |
| `OccurredAt__c` | DateTime, required | Event-construction timestamp |
| `EventId__c` | Text(80), required | Dedupe key |
| `ContractVersion__c` | Text(10), required; `1.0` | Diagnostics-event schema version |
| `CoreVersion__c` | Text(20) | Product release version that produced the event |

**Never carried:** field values (`actualValue` / `expectedValue`). Those stay in Debug Mode's admin
detail. The record ID is a pointer for reproduction, not record data.

### Subscriber contract

- The subscriber persisting these events **must** call
  `RecordHealthCheckLogger.enterSubscriberContext()` before doing work, so an error raised while
  handling a log event does not republish onto the same bus (feedback loop).
- Because the event carries a message, stack trace, and record ID, treat the persistence object as
  **restricted** and permission-gate read access.
- Admins can switch the channel off org-wide via `RecordHealthCheckLogger.publishErrorEvents`
  without disabling `System.debug` logging.

### Known limitation

An **uncatchable** governor-limit abort (e.g. `LimitException`) rolls back before `flush()` runs, so
no diagnostics event is published — the same gap that leaves no result. Only the platform's own
unhandled-exception log captures that case.

## Related

- [Apex API](../apex/public-api.md)
- [Flow actions](../flow/actions.md)
- [Lightning component runs](../lwc/runs-and-events.md)
- [Check Set fields](../metadata/check-set.md) — Publish Run Event
- [Rule fields](../metadata/rule-fields.md) — Publish Result Event
- [Upgrading to V2](../installation/upgrading-to-v2.md)
- [Reason codes](reason-codes.md)
- [V2 documentation standard](../api-documentation-standard.md)
