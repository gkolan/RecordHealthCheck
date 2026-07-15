# Lightning component runs and lifecycle events

The Record Health Check Lightning component supports two materially different run contexts:
automatic page-load evaluation and an explicit user Run or Rerun. This page explains their event
behavior.

## What the component is

- A record-page presentation and orchestration surface for one configured Check Set.
- A transient view of Set and Rule results under the current user's access.
- An optional event publisher only when the user explicitly clicks Run or Rerun.

## What the component is not

- It is not a result-history store.
- It does not block record save or automatically remediate failures.
- Automatic page load is not consent to publish lifecycle events.
- A completed card does not prove that an event subscriber processed anything.

New to the model? Read [Integrate Record Health Check](../integrate/overview.md) first.

## Prerequisites and quick start

1. Assign **Record Health Check User** to the viewer and grant access to the record and fields used
   by the selected Rules.
2. In Lightning App Builder, add **Record Health Check** to a record page and select an active Check
   Set for that object.
3. On the Check Set Custom Metadata record, set **When Checks Run** to **When the page opens** or
   **When the user clicks Run**.
4. Save and activate the Lightning page, then open a matching record.
5. Confirm the card returns rows and summary counts. Click Run or Rerun only when an explicit run is
   intended.

For installation details, use [Getting started](../installation/getting-started.md). Advanced
diagnostic values additionally require **Show Diagnostics** and the
`Record_Health_Check_View_Details` custom permission.

## Behavior matrix

| Component action | Source | Set event | Rule events |
| --- | --- | --- | --- |
| Automatic page-load run | `RUN_ON_LOAD` | Never | Never |
| User clicks Run | `USER_INITIATED` | Enabled Check Set | Enabled Rules |
| User clicks Rerun | `USER_INITIATED` | Enabled Check Set | Enabled Rules |

Custom Metadata switches remain off by default:

- `PublishRunEvent__c` enables one Set Run completion event for the Check Set.
- `PublishResultEvent__c` enables a Rule Result event for that Rule.

An automatic run never publishes even when both switches are enabled.

## Component inputs and visible outputs

| Input/context | Meaning |
| --- | --- |
| Check Set selected in App Builder | Configuration loaded and evaluated by the card |
| Current record ID | Record evaluated |
| Check Set **When Checks Run** = **When the page opens** (`RUN_ON_LOAD`) | Run after definitions load; publication blocked |
| Check Set **When Checks Run** = **When the user clicks Run** (`RUN_ON_REQUEST`) | Wait for an explicit Run; publication can be enabled |
| Run or Rerun button | Explicit user-initiated run; publication can be enabled |

The visible output is the completed row list and summary counts. Results remain in component state;
the component does not create a history record.

## Event outputs for Run and Rerun

### Check Set Run event

After every row resolves, an opted-in Set can produce `Record_Health_Check_Set_Run__e`:

| Field | Component event value |
| --- | --- |
| `EventId__c`, `RunId__c` | Event identity and shared component-run correlation |
| `Phase__c` | `COMPLETED` |
| `CheckSetDeveloperName__c` | Completed Check Set |
| `Source__c` | `USER_INITIATED` |
| Count fields | Eligible/evaluated, passed, failed, skipped, unable, and system errors |
| `OccurredAt__c` | Completion request's event construction time |
| `ContractVersion__c`, `CoreVersion__c` | `1.0` and `2.0.0` |

### Rule Result event

Each server-finalized, opted-in Rule can produce `Record_Health_Check_Rule_Result__e`:

| Field | Component event value |
| --- | --- |
| `EventId__c`, `RunId__c` | Event identity and shared component-run correlation |
| `CheckSetDeveloperName__c`, `RuleDeveloperName__c` | Metadata identities |
| `Status__c`, `ReasonCode__c`, `Severity__c` | Final Rule outcome |
| `Source__c` | `USER_INITIATED` |
| `OccurredAt__c` | Rule request's event construction time |
| `ContractVersion__c`, `CoreVersion__c` | `1.0` and `2.0.0` |
| `ContainsRestrictedDetail__c` | Presence flag only; no restricted text |

Events intentionally omit record ID, user ID, messages, queries, and field values.

## Why publication happens in two stages

The component evaluates Rules through separate Apex requests so it can enforce dependencies,
control concurrency, stop after system errors, and progressively reveal results.

For an explicit run:

1. Each server-finalized Rule result can publish its own Rule Result event after that Apex request commits.
2. When every row has resolved, the component makes one completion call.
3. That call can publish one aggregate Set Run event after its transaction commits.

Client-synthesized results—such as a dependency skip that never called Apex—are included in the Set
counts but do not create a separate Rule Result event because no server Rule evaluation finalized.

## Best-effort behavior

Event publication never changes the card result. If the completion call or event publication fails,
the user still sees the completed health-check results. Consumers should monitor their own event and
subscriber processing rather than treating the card as delivery confirmation.

The [Platform events reference](../reference/lifecycle-events.md) is needed only for exact field
types, replay behavior, retention, and subscriber implementation.

## Versioning and compatibility

The component consumes the stable synchronous response contract `1.0`. Events created by explicit
Run or Rerun use the independent lifecycle-event contract `1.0` and report Core `2.0.0`. No V2
component run behavior is currently deprecated.

## Related

- [Platform events](../reference/lifecycle-events.md)
- [Apex API](../apex/public-api.md)
- [Flow actions](../flow/actions.md)
- [Configuration Guide](../guides/configuration-guide.md)
- [Show Diagnostics](../guides/show-diagnostics.md)
- [V2 documentation standard](../api-documentation-standard.md)
