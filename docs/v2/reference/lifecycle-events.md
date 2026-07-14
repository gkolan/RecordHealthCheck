# Lifecycle events

Optional, versioned platform events for completed Check Set and Rule runs. Both are **high-volume
platform events** configured as **Publish After Commit**. Their fields exclude record IDs, queries,
messages, and field values. Record-page checks never publish.

## When events publish

Publishing runs only from the public `RecordHealthCheck.run` and `runSet` Apex methods, including
the packaged Flow action. The Lightning record-page controller does **not** publish.

| Source constant | Meaning in V2 shipping callers |
| --- | --- |
| `FACADE` | Public Apex methods and packaged Flow action (current production source) |
| `RUN_ON_LOAD` | Hard-blocked — never publishes |
| `SUBSCRIBER` | Hard-blocked — never publishes |

The source values `FLOW`, `USER_INITIATED`, `SCHEDULED`, and `BATCH` are reserved for future callers
and are not used by the shipping LWC or Flow action. Flow events currently use `FACADE` because the
action calls the public Apex methods.

Publish failures are logged and **do not** change Rule or Check Set results.

Events are chunked in batches of **100** (`PUBLISH_CHUNK_SIZE`).

## Opt-in switches (default off)

| Metadata | Field | What it enables |
| --- | --- | --- |
| Check Set | **Publish Run Event** (`PublishRunEvent__c`) | One `Record_Health_Check_Set_Run__e` after a completed Check Set Apex or Flow run |
| Rule | **Publish Result Event** (`PublishResultEvent__c`) | One `Record_Health_Check_Rule_Result__e` per completed Rule result in an Apex or Flow run |

Page-load card evaluations never publish even if these checkboxes are on.

## Contract versions on events

| Field | Value | Meaning |
| --- | --- | --- |
| `ContractVersion__c` | `1.0` | Lifecycle event contract (`RecordHealthCheckLifecyclePublisher.CONTRACT_VERSION`) |
| `CoreVersion__c` | `2.0.0` | Core product version string |

This is separate from the sync response contract (`0.1` on `RecordHealthCheckResult` / `RecordHealthCheckSetResult`).

## What is never included on an event

Events intentionally omit:

- Record Id and object API name
- User Id
- User-facing messages
- Found / Expected values
- `adminDetail` text

Subscribers join to Salesforce data with `CheckSetDeveloperName__c`, `RuleDeveloperName__c`, and `RunId__c` when they need more context under their own security model.

---

## Rule Result event (`Record_Health_Check_Rule_Result__e`)

High-volume platform event. Publish After Commit.

| Field (API) | Setup label | Type | Notes |
| --- | --- | --- | --- |
| `EventId__c` | Event ID | Text(80) | Unique per event |
| `RunId__c` | Run ID | Text(120) | Shared identifier for the Apex or Flow run |
| `CheckSetDeveloperName__c` | Check Set API Name | Text(80) | Parent Check Set |
| `RuleDeveloperName__c` | Rule API Name | Text(80) | Rule that finished |
| `Status__c` | Status | Text(30) | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, `ERROR` |
| `ReasonCode__c` | Reason Code | Text(80) | Public reason when present |
| `Severity__c` | Severity | Text(20) | Failure severity when applicable |
| `OccurredAt__c` | Occurred At | DateTime | Publish time |
| `Source__c` | Source | Text(30) | e.g. `FACADE` |
| `ContractVersion__c` | Contract Version | Text(10) | `1.0` |
| `CoreVersion__c` | Core Version | Text(20) | `2.0.0` |
| `ContainsRestrictedDetail__c` | Contains Restricted Detail | Checkbox | True when diagnostics-authorized restricted detail was present on the result (flag only; detail text is not on the event) |

Published only for Rules with **Publish Result Event** selected after an Apex or Flow run.

---

## Check Set Run event (`Record_Health_Check_Set_Run__e`)

High-volume platform event. Publish After Commit.

| Field (API) | Setup label | Type | Notes |
| --- | --- | --- | --- |
| `EventId__c` | Event ID | Text(80) | Unique per event |
| `RunId__c` | Run ID | Text(120) | Shared set-run correlation id |
| `Phase__c` | Phase | Text(30) | Shipping value: **`COMPLETED`** only |
| `CheckSetDeveloperName__c` | Check Set API Name | Text(80) | Check Set that finished |
| `OccurredAt__c` | Occurred At | DateTime | Publish time |
| `Source__c` | Source | Text(30) | e.g. `FACADE` |
| `ContractVersion__c` | Contract Version | Text(10) | `1.0` |
| `CoreVersion__c` | Core Version | Text(20) | `2.0.0` |
| `EligibleRuleCount__c` | Eligible Rule Count | Number | Rules in the completed response |
| `EvaluatedRuleCount__c` | Evaluated Rule Count | Number | Same as eligible for the shipping `COMPLETED` phase |
| `PassedCount__c` | Passed Count | Number | |
| `FailedCount__c` | Failed Count | Number | |
| `SkippedCount__c` | Skipped Count | Number | |
| `UnableCount__c` | Unable Count | Number | |
| `SystemErrorCount__c` | System Error Count | Number | |

Emitted only when the Check Set has **Publish Run Event** checked, after `runSet` (or Flow with blank Rule API Name).

---

## Admin checklist before enabling

1. Review org platform-event allocations and existing subscribers.
2. Enable publication only on deliberate Apex / Flow / batch callers — not for card traffic.
3. Start with a sandbox subscriber (Flow, Apex trigger, or export).
4. Use the platform event replay ID and subscriber error handling required by your business process;
   a publishing or subscriber error does not change the completed health result.
5. Do not expect record identity on the event; correlate with `RunId__c` and metadata API names.

## Related

- [Programmatic API and Flow](../apex/programmatic-api.md)
- [Check Set fields](../metadata/check-set.md) — Publish Run Event
- [Rule fields](../metadata/rule-fields.md) — Publish Result Event
- [Upgrading to V2](../installation/upgrading-to-v2.md)
- [Reason codes](reason-codes.md)
