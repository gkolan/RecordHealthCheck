# Flow actions

Use the two packaged actions to run Record Health Check from Flow without writing Apex. Start with
the Set action: a Check Set is the parent configuration and contains its ordered Rules. Choose the
Rule action only when the Flow intentionally needs one specific check.

## What these actions are

- Synchronous Flow wrappers over the same engine used by Apex and Lightning.
- Typed inputs and common outputs for Flow decisions.
- Optional publishers of after-commit lifecycle events with source `FLOW`.

## What these actions are not

- They do not persist a history record.
- They do not automatically fix or update the evaluated record.
- They do not turn `FAIL` into a Flow fault; `FAIL` is a valid returned business result.
- They do not guarantee event delivery or subscriber completion.
- They do not remove Flow transaction, security, or governor-limit constraints.

New to the model? Read [Integrate Record Health Check](../integrate/overview.md) first.

## Prerequisites and access

- Configure at least one active Check Set and Rule before building the Flow.
- Grant the Flow's running user the **Record Health Check User** permission set, or equivalent Apex
  class access to the selected action and `RecordHealthCheck`.
- Evaluation uses the Flow running user's sharing, record, object, and field access. The action does
  not elevate access.
- Test the action in the Flow's actual run context; a user-run screen flow and a system-context
  automation can have different effective access.

## Available actions

Both actions appear in the **Record Health Check** category.

### Run Record Health Check Set

Apex implementation: `RecordHealthCheckRunSetFlowAction`.

| Input | Required | Meaning |
| --- | --- | --- |
| Check Set API Name | Yes | Check Set `DeveloperName` |
| Record ID | Yes | Record evaluated by the Check Set |

| Output | Meaning |
| --- | --- |
| Contract Version | Stable synchronous response contract; currently `1.0` |
| Status | Aggregate Check Set status |
| Passed / Failed / Skipped Count | Business outcome counts |
| Unable / System Error Count | Non-business outcome counts |
| Result JSON | Complete serialized `RecordHealthCheckSetResult` |

The Set status uses this precedence: `ERROR` → `UNABLE_TO_EVALUATE` → `FAIL` → `PASS` → `SKIPPED`.
For example, one unable Rule makes the Set `UNABLE_TO_EVALUATE` even when other Rules passed.

### Run Record Health Check Rule

Apex implementation: `RecordHealthCheckRunRuleFlowAction`.

| Input | Required | Meaning |
| --- | --- | --- |
| Rule API Name | Yes | Rule `DeveloperName` |
| Record ID | Yes | Record evaluated by the Rule |

| Output | Meaning |
| --- | --- |
| Contract Version | Stable synchronous response contract; currently `1.0` |
| Status | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` |
| Reason Code | Stable machine-readable reason |
| Result JSON | Complete serialized `RecordHealthCheckResult` |

The success value is **`PASS`**, not `SUCCESS`.

## Status meanings

| Status | Flow interpretation |
| --- | --- |
| `PASS` | The Rule passed, or the Set has no error/unable/failure and at least one pass |
| `FAIL` | A completed Rule found an unhealthy condition; for a Set, at least one Rule failed and no stronger status exists |
| `SKIPPED` | Evaluation was intentionally skipped; a Set uses this when no stronger outcome exists |
| `UNABLE_TO_EVALUATE` | No reliable conclusion because of configuration, access, dependency, or data conditions |
| `ERROR` | Unexpected system/evaluator failure |

Use a Decision element with explicit branches for the statuses relevant to the business process.
Avoid treating every value other than `FAIL` as success.

## Basic Flow pattern

1. Add the appropriate Record Health Check action.
2. Supply the Rule or Check Set API name and record ID.
3. Add a Decision element using **Status**, **Reason Code**, or count outputs.
4. Handle the action's fault connector.
5. Use Result JSON only when downstream automation needs fields not exposed individually.

Do not branch on user-facing message text; administrators can change messages without changing the
stable status or reason-code contract.

## Bulk and transaction behavior

Flow passes a request collection to the invocable action. The same Apex limits apply:

| Limit | Value |
| --- | --- |
| Flow requests in one invocation | 200 |
| Planned Rule evaluations | 15 |

For a Set action, planned evaluations equal Rules × Flow requests. Reduce the collection size or use
a smaller Check Set if the request would exceed 15 evaluations.

The action participates in the Flow transaction. Lifecycle events use Publish After Commit, so a
later Flow fault or rollback prevents delivery.

## Lifecycle publication criteria

Flow is a deliberate source and publishes events with:

```text
Source__c = FLOW
```

- A Set action can publish enabled Rule Result events and one Set Run event when **Publish Run Event** is enabled.
- A Rule action can publish one Rule Result event when that Rule has **Publish Result Event** enabled.
- Publication is optional, off by default, best effort, and does not change the Flow result.
- Every finalized status is eligible; publication is not restricted to failures.

## Event outputs

The Flow action's synchronous outputs and asynchronous event outputs are independent. A Flow can use
the action result immediately; subscribers receive enabled events after commit.

### Set action events

The Set action can produce both event types:

| Event | Quantity | Enabled by | Main output |
| --- | --- | --- | --- |
| `Record_Health_Check_Rule_Result__e` | One per enabled finalized Rule | Rule **Publish Result Event** | Rule identity, status, reason, severity, `Source__c = FLOW` |
| `Record_Health_Check_Set_Run__e` | One per completed Set request | Set **Publish Run Event** | Set identity, `COMPLETED`, outcome counts, `Source__c = FLOW` |

The Set event includes eligible/evaluated, passed, failed, skipped, unable, and system-error counts.
Events intentionally omit record ID, user ID, messages, queries, and field values.

### Rule action event

When **Publish Result Event** is enabled, `Record_Health_Check_Rule_Result__e` contains:

| Field | Flow event value |
| --- | --- |
| `EventId__c`, `RunId__c` | Event identity and action-run correlation |
| `CheckSetDeveloperName__c`, `RuleDeveloperName__c` | Metadata identities |
| `Status__c` | Final Rule status |
| `ReasonCode__c`, `Severity__c` | Outcome details when applicable |
| `Source__c` | `FLOW` |
| `OccurredAt__c` | Event construction time |
| `ContractVersion__c`, `CoreVersion__c` | `1.0` and `2.0.0` |
| `ContainsRestrictedDetail__c` | Presence flag only; no restricted text |

The [Platform events reference](../reference/lifecycle-events.md) remains the canonical field-type,
retention, replay, and subscriber contract.

## Security and fault handling

- Evaluation uses the running Flow user's effective Salesforce access.
- Connect the action's fault path for request errors and uncatchable transaction failures.
- A successful action result does not prove that an asynchronous event subscriber completed.
- Subscribers must be idempotent and must not use Flow message text as a key.

### Fault causes and remedies

| Fault | Likely cause | What to investigate |
| --- | --- | --- |
| Request includes more than 200 records | The invocable request collection exceeds the public cap | Split the collection across transactions |
| Request would run more than 15 Rules | Records × active Rules exceeds the evaluation cap | Reduce the collection or use a smaller Check Set |
| Configuration lookup fault | The supplied API name is wrong, inactive, or unavailable | Verify the exact `DeveloperName`, activation, and running-user access |
| Salesforce access fault | The running user lacks required record, object, field, or Apex access | Assign only the required access and retest in the same Flow context |
| Governor-limit fault | The transaction lacks remaining Salesforce limits | Reduce work in the transaction or invoke from a separate transaction |

`FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` are returned statuses, not Flow faults. Route
them with a Decision element; use the fault connector only when no action response is available.

## Versioning and deprecation

The synchronous Flow response contract and the independent lifecycle-event contract are both
stable at `1.0`; they remain separate schemas that version independently.
Additive JSON fields may appear within a contract version, so consumers must ignore unknown fields.
No V2 Flow action is currently deprecated. Future notices will identify a replacement and earliest
removal release according to the [V2 documentation standard](../api-documentation-standard.md).

## Related

- [Integration overview](../integrate/overview.md)
- [V2 documentation standard](../api-documentation-standard.md)
- [Apex API](../apex/public-api.md)
- [Lightning component runs](../lwc/runs-and-events.md)
- [Reason codes](../reference/reason-codes.md)
- [Platform events](../reference/lifecycle-events.md)
