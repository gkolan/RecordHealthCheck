# Lifecycle events

> [!NOTE]
> **On this page**
>
> Configure, publish, subscribe to, and troubleshoot optional Check Set Run and Rule Result platform events.

Use lifecycle events when an independent subscriber needs completion information after an explicit
Record Health Check run. This reference documents publication behavior, event payloads,
permissions, retention, replay, and subscriber requirements.

Start with the **Check Set Run** event when the subscriber needs one summary per review. Add **Rule
Result** events only when the subscriber needs per-Rule status, reason, and severity.

## Choose the event detail

| Subscriber needs… | Event | Start with |
| --- | --- | --- |
| One summary for a completed Check Set | [`Record_Health_Check_Set_Run__e`](../metadata/event-set-run.md) | Check Set **Publish Run Event** |
| One result for each selected Rule | [`Record_Health_Check_Rule_Result__e`](../metadata/event-rule-result.md) | Rule **Publish Result Event** |
| Restricted Framework error diagnostics | [`Record_Health_Check_Log__e`](../metadata/event-log.md) | Framework `ERROR` logging; not a lifecycle-result opt-in |
| The immediate decision in the current transaction | Neither lifecycle event | Use the Lightning, Apex, or Flow response instead |

The Set Run and Rule Result events are **high-volume Platform Events** configured as **Publish
After Commit**. They carry the
evaluated record's ID in `RecordId__c` when one is available, but exclude queries, messages, user
identity, and field values. Automatic record-page checks never publish;
explicit Run and Rerun actions can publish when enabled.

**Publish After Commit** means Salesforce delivers the event only if the transaction that ran the
health check commits successfully. This prevents a subscriber from recording or acting on a result
from work that Salesforce later rolled back. The tradeoff is that the caller cannot wait for the
subscriber or use the event for an immediate decision; Apex and Flow must branch on the synchronous
result instead.

## What these events are

- Minimal completion facts for one Check Set run and its server-finalized Rule results.
- A way for subscribers to build history, notifications, exports, analytics, or other automation
  without coupling to the health-check call itself.

## What these events are not

- They are not the synchronous health-check response.
- They are not a guaranteed or permanent audit log; Salesforce retains high-volume platform events
  for 72 hours, not indefinitely.
- They are not exactly-once commands. Subscribers must handle duplicates and replay safely.
- Publish acceptance does not prove delivery or successful subscriber processing.

For the end-to-end model, start with [Integrate Record Health Check](../integration/overview.md).

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

| Source constant | Meaning in shipped callers |
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

The source restrictions prevent passive record-page loading from consuming event allocations and
prevent a subscriber from triggering another event indefinitely. They also make each published
event traceable to a deliberate Framework entry point.

Publish failures are logged and **do not** change Rule or Check Set results.

Events are chunked in batches of **100** (`PUBLISH_CHUNK_SIZE`).

## Opt-in switches (default off)

Publication starts off because events consume the org's Platform Event allocation and may trigger
subscriber automation, storage, notifications, or external processing. An administrator should
enable only the summary or per-Rule detail that a reviewed subscriber actually uses.

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

Subscribers should store or inspect `ContractVersion__c`, not infer the event shape from
`CoreVersion__c`. A Core release can change implementation behavior without changing the event
schema; an incompatible event-field change requires a new contract version.

## What is never included on an event

The Set Run and Rule Result events intentionally omit:

- User Id
- User-facing messages
- Found / Expected values
- SOQL and formula source
- `adminDetail` text

They include `RecordId__c` when one evaluated record is available. Subscribers join to additional
Salesforce data under their own security model using the Record ID, metadata Developer Names, and
`RunId__c`.

---

## Event metadata references

| Platform Event | Detailed reference | Purpose |
| --- | --- | --- |
| `Record_Health_Check_Set_Run__e` | [Check Set Run Platform Event](../metadata/event-set-run.md) | One completion summary and outcome counts for a Check Set run |
| `Record_Health_Check_Rule_Result__e` | [Rule Result Platform Event](../metadata/event-rule-result.md) | One finalized public Rule outcome |
| `Record_Health_Check_Log__e` | [Log Platform Event](../metadata/event-log.md) | Restricted Framework `ERROR` diagnostics |

## Admin checklist before enabling

1. Review org platform-event allocations and existing subscribers.
2. Enable publication only for deliberate LWC, Apex, Flow, scheduled, or batch runs.
3. Start with a sandbox subscriber (Flow, Apex trigger, or export).
4. Use the platform event replay ID and subscriber error handling required by your business process;
   a publishing or subscriber error does not change the completed health result.
5. Treat `RecordId__c` as optional and correlate with `RunId__c` and metadata Developer Names.

## Subscriber failure guidance

| Symptom | Likely cause | What to investigate |
| --- | --- | --- |
| No event after page open | Automatic runs are blocked from publishing | Click Run/Rerun or invoke Apex/Flow deliberately |
| No event after an explicit run | Metadata switch is off, source is blocked, or transaction rolled back | Check the opt-in field, source, logs, and commit outcome |
| Duplicate processing | Replay or subscriber retry delivered the event again | Deduplicate with `EventId__c`; make side effects safe to repeat |
| Missing record context | The run had no single record, or a record ID was not available at publish | Correlate with `RunId__c` and metadata names; `RecordId__c` is populated only when available |
| Subscriber failure | Subscriber limits, access, or business logic failed independently | Monitor and retry in the subscriber; do not reinterpret the completed health result |

## Diagnostics events are a separate channel

`Record_Health_Check_Log__e` serves a different purpose from the two lifecycle-result events. It
carries restricted Framework `ERROR` diagnostics and uses **Publish Immediately**.

| Property | Lifecycle events (Set / Rule) | Diagnostics event (Log) |
| --- | --- | --- |
| Purpose | Completion facts | Errors that need reproducing |
| Default | Opt-in per Set/Rule (off) | **On by default** (opt-out) |
| Publish behavior | Publish After Commit | **Publish Immediately** — survives the rollback a failing check triggers |
| Carries error detail | No — record ID + counts/status only | Yes — record ID plus message, exception type, stack trace |
| Level | All completed runs | `ERROR` only |
| Access | Standard subscriber | **Restricted** — permission-gate the subscriber |

The Log event is not controlled by **Publish Run Event** or **Publish Result Event**. Its complete
payload, security requirements, subscriber loop guard, possibilities, and known limitations are in
the [Log Platform Event reference](../metadata/event-log.md).

## Related

- [Apex API](../integration/apex-api/public-api.md)
- [Flow actions](flow-actions.md)
- [Lightning component](lightning-component.md)
- [Check Set fields](../metadata/fields-check-set.md) — Publish Run Event
- [Rule fields](../metadata/fields-rule.md) — Publish Result Event
- [Check Set Run Platform Event](../metadata/event-set-run.md)
- [Rule Result Platform Event](../metadata/event-rule-result.md)
- [Log Platform Event](../metadata/event-log.md)
- [Upgrading Record Health Check](../installation/04-upgrading.md)
- [Reason Codes](../reference/reason-codes.md)
- [Documentation standard](../development/documentation-standard.md)
