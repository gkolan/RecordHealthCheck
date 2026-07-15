# Apex API

Use the public `RecordHealthCheck` class to run a Check Set or one Rule from Apex. Start with a Check
Set: it is the parent configuration and contains the ordered Rules. Use the single-Rule API only when
a process intentionally needs one specific check.

## What this API is

- A synchronous, typed Apex entry point for metadata-configured evaluation.
- One façade with separate Set and Rule response classes.
- A way to supply a run ID for correlation.
- An optional publisher of after-commit lifecycle events.

## What this API is not

- It does not save result history.
- It does not update the evaluated record or block DML.
- It does not guarantee lifecycle-event delivery or subscriber completion.
- It does not bypass the running user's Salesforce access.
- It is not an unlimited bulk-processing API; request caps apply.

New to the model? Read [Integrate Record Health Check](../integrate/overview.md) first.

## Prerequisites and access

- Install and configure at least one active Check Set and Rule. The examples use metadata from the
  separate examples package; replace those API names with names available in your org.
- Grant the calling user Apex class access through the appropriate Record Health Check permission
  set or an equivalent profile/permission set.
- Calls run `with sharing` and evaluation uses the calling user's record and field access. The API
  does not elevate access.
- Restricted diagnostic values are returned only when the user has the
  `Record_Health_Check_View_Details` custom permission. Do not make business logic depend on those
  optional values.

## Quick examples

Run a complete Check Set:

```apex
RecordHealthCheckSetResult result = RecordHealthCheck.runSet(
  'Example_Account_360_Health_Check',
  accountId
);

switch on result.status {
  when 'PASS' {
    // The Set has no error, unable, or failed result and at least one Rule passed.
  }
  when 'FAIL' {
    // At least one Rule found an unhealthy business condition.
    System.debug(result.failedCount);
  }
  when 'SKIPPED' {
    // Applicability or dependency rules intentionally prevented evaluation.
  }
  when 'UNABLE_TO_EVALUATE' {
    // Configuration, access, or available data prevented a conclusion.
  }
  when 'ERROR' {
    // An unexpected system/evaluator problem occurred.
  }
}
```

Run one specific Rule only when the process does not need the rest of its Set:

```apex
RecordHealthCheckResult result = RecordHealthCheck.runRule(
  'Example_Recent_Activity',
  accountId
);
```

The successful status is **`PASS`**, not `SUCCESS`. `PASS` is used consistently in Apex responses,
Flow outputs, Lightning rows, and platform events.

## Set and Rule use different response classes

The methods share one public façade so callers have one discoverable API, but their outputs are
strongly typed separately:

| Operation | Apex response class | Represents |
| --- | --- | --- |
| `runSet` | `RecordHealthCheckSetResult` | One Check Set aggregate plus its ordered Rule results |
| `runRule` | `RecordHealthCheckResult` | One Rule evaluated for one record |

Separate service classes such as `RecordHealthCheckRuleService` and `RecordHealthCheckSetService`
would add entry points without changing the underlying engine, permissions, limits, or publication
contract. The single façade plus separate return types keeps invocation simple while preventing Rule
and Set responses from being confused.

## Available methods

| Method | Returns | Use |
| --- | --- | --- |
| `runSet(checkSetDeveloperName, recordId)` | `RecordHealthCheckSetResult` | One Check Set for one record |
| `runSet(checkSetDeveloperName, recordId, runId)` | `RecordHealthCheckSetResult` | One Check Set with caller correlation |
| `runSet(checkSetDeveloperName, recordIds)` | `List<RecordHealthCheckSetResult>` | One Check Set for multiple records |
| `runSet(checkSetDeveloperName, recordId, runId, source)` | `RecordHealthCheckSetResult` | One Check Set with caller correlation and an explicit lifecycle source |
| `runRule(ruleDeveloperName, recordId)` | `RecordHealthCheckResult` | One Rule for one record |
| `runRule(ruleDeveloperName, recordId, runId)` | `RecordHealthCheckResult` | One Rule with caller correlation |
| `runRule(ruleDeveloperName, recordId, runId, source)` | `RecordHealthCheckResult` | One Rule with caller correlation and an explicit lifecycle source |
| `runRule(ruleDeveloperName, recordIds)` | `List<RecordHealthCheckResult>` | One Rule for multiple records |

### Parameters

| Parameter | Type | Required | Contract |
| --- | --- | --- | --- |
| `checkSetDeveloperName` | `String` | Yes for `runSet` | Exact Check Set `DeveloperName` visible to the caller |
| `ruleDeveloperName` | `String` | Yes for `runRule` | Exact Rule `DeveloperName`; resolves its parent Check Set |
| `recordId` | `Id` | Yes | Record evaluated in the running user's access context |
| `recordIds` | `List<Id>` | Yes | Up to 200 IDs; results preserve input order |
| `runId` | `String` | No | Caller correlation value; blank values are replaced with a generated ID |
| `source` | `String` | Source-aware overloads only | One documented lifecycle source constant; blank or unknown values prevent publication |

The `runSet` and `runRule` single-record overloads return one response even when evaluation cannot
reach a business conclusion. The collection overloads return one response per input ID in the same
order. An empty ID list returns an empty Set response list; request and evaluation caps still apply
as described below.

The source-aware four-argument overloads accept one of the lifecycle source constants. Use these
only when the caller has a more specific execution context:

```apex
RecordHealthCheckSetResult result = RecordHealthCheck.runSet(
  'Account_Data_Quality',
  accountId,
  'nightly-' + Date.today(),
  RecordHealthCheckLifecyclePublisher.SOURCE_SCHEDULED
);
```

| Apex invocation | Event `Source__c` |
| --- | --- |
| Ordinary public API call | `APEX_API` |
| Source-aware scheduled caller | `SCHEDULED` |
| Source-aware batch/async caller | `BATCH` |
| Platform-event subscriber | `SUBSCRIBER` — publication blocked |

Unknown and blank source values fail closed: evaluation can run, but lifecycle publication is
blocked.

## Limits and transaction behavior

| Limit | Value |
| --- | --- |
| Records per public call | 200 |
| Planned Rule evaluations per call | 15 |

Planned Set evaluations equal active Rules × records. Exceeding a cap throws
`RecordHealthCheck.RecordHealthCheckRequestException`.

Evaluation is synchronous and uses the current user's record and field access. Catchable evaluator
problems return a result status; uncatchable governor-limit exceptions behave like any other Apex
limit exception.

Lifecycle events are optional, best effort, and Publish After Commit. A later rollback prevents
delivery even if `EventBus.publish` was already called.

## Errors and investigation

Returned statuses and thrown exceptions are different contracts. `FAIL`, `SKIPPED`,
`UNABLE_TO_EVALUATE`, and `ERROR` are valid response statuses; inspect `reasonCode` and the
[reason-code reference](../reference/reason-codes.md) before retrying. A thrown exception means no
usable response was returned for that invocation.

| Symptom | Likely cause | What to investigate |
| --- | --- | --- |
| `RecordHealthCheckRequestException: Record IDs are required.` | A collection overload received `null` | Pass a non-null `List<Id>`; use an empty list only when no work is intended |
| `RecordHealthCheckRequestException: A request can include at most 200 records.` | The collection exceeds the public record cap | Split the records into smaller transactions while also observing the evaluation cap |
| `RecordHealthCheckRequestException: This request would run too many checks...` | Planned evaluations exceed 15 | Reduce records, use a smaller Check Set, or distribute work across transactions |
| Configuration lookup exception | The API name is blank, misspelled, inactive, or unavailable to the caller | Verify the exact metadata `DeveloperName`, activation, and caller access |
| Salesforce access exception or an `UNABLE_TO_EVALUATE` response | The running user cannot read the record, object, or required field | Grant only the required record/object/field access, then rerun as that user |
| Uncatchable governor-limit exception | The calling transaction lacks remaining Salesforce limits | Reduce work per transaction or move the call to a transaction with adequate limits |

Catch `RecordHealthCheck.RecordHealthCheckRequestException` only when the caller can correct or
report the request. Do not convert a missing response into `PASS`.

```apex
try {
  RecordHealthCheckSetResult health = RecordHealthCheck.runSet(
    'Account_Data_Quality',
    accountId
  );
  // Branch on health.status and stable reason codes.
} catch (RecordHealthCheck.RecordHealthCheckRequestException ex) {
  // Report an invalid request; there is no health result to interpret.
}
```

## Versioning and deprecation

The synchronous result contract is stable at `1.0`. Additive response fields may appear within that version,
so JSON consumers must ignore unknown fields. Removing or renaming a public field, method, status,
or reason value requires a new contract version. Lifecycle events use their own `1.0` contract and
the product version is reported separately as `2.0.0`.

No V2 Apex API is currently deprecated. A future deprecation notice will identify the replacement
and earliest removal release in this page, the [V2 index](../README.md), the upgrade guide, and the
changelog. See the shared [V2 documentation standard](../api-documentation-standard.md).

## Check Set response

`RecordHealthCheckSetResult` contains:

| Field | Meaning |
| --- | --- |
| `contractVersion` | Stable synchronous response contract; currently `1.0` |
| `checkSetDeveloperName` | Stable Check Set metadata identity |
| `recordId` | Evaluated record |
| `runId` | Supplied or generated correlation value shared by the contained Rule results |
| `status` | Aggregate result using the precedence below |
| `passedCount`, `failedCount`, `skippedCount` | Outcome counts |
| `unableCount`, `systemErrorCount` | Non-business outcome counts |
| `results` | Ordered Rule results |

For decisions, use status, reason code, severity, and developer name—not message text.

### Check Set aggregate status

The Set status is calculated from its Rule results in this precedence order:

1. `ERROR` when at least one Rule has a system error.
2. `UNABLE_TO_EVALUATE` when none errored and at least one Rule was unable to evaluate.
3. `FAIL` when none errored/were unable and at least one Rule failed.
4. `PASS` when none of the above occurred and at least one Rule passed.
5. `SKIPPED` when every result was skipped, or there was no stronger outcome.

Therefore `RecordHealthCheckSetResult.status == 'PASS'` means the Set completed without an error,
unable result, or failed Rule and at least one Rule passed.

## Rule response

Each entry in the Set's `results` list is a `RecordHealthCheckResult`. The same type is returned
directly by `runRule`.

| Field | Meaning |
| --- | --- |
| `contractVersion` | Stable synchronous response contract; currently `1.0` |
| `runId` | Correlates the call, logs, and lifecycle events |
| `ruleDeveloperName` | Stable Rule metadata identity |
| `label` | User-facing Check Title resolved from Rule metadata |
| `status` | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` |
| `severity` | `CRITICAL`, `WARNING`, or `INFO` when applicable |
| `reasonCode` | Stable machine-readable outcome reason |
| `message` | User-facing text; do not use as an automation key |
| `actualValue`, `expectedValue` | Security-filtered comparison values when available |
| `expectedValueLabel` | Overrides the Expected caption, including authorized **Passes when** formula detail |
| `actualValueDetail`, `expectedValueDetail` | Authorized source-detail strings; emitted only through enabled browser diagnostics |
| `adminDetailMessage` | Authorized troubleshooting text when Show Diagnostics is enabled |
| `adminDetail` | Authorized structured diagnostics: restricted-detail flag, field names, reason code, and message |
| `actionLabel`, `actionUrl` | Resolved read-only remediation link for `FAIL`; blank when unavailable or unsafe |
| `fixInstructions` | Resolved failed-check guidance from Fix Message |
| `priority` | Rule evaluation/display order value |
| `durationMs` | Evaluator duration in milliseconds |
| `evaluatorType` | `FORMULA`, `QUERY`, `COMPARE_TWO_QUERIES`, or `APEX` |

`adminDetail` is a `RecordHealthCheckAdminDetail` with `containsRestrictedDetail`, `fieldNames`,
`reasonCode`, and `message`. It is null unless Show Diagnostics and the View Details permission
authorize it. Internal `detailMessage`, `actualValueSource`, and `expectedValueSource` values are not
Aura-enabled public response fields.

### Rule status meanings

| Status | Meaning | Successful? |
| --- | --- | --- |
| `PASS` | Evaluation completed and the configured pass condition was satisfied | Yes |
| `FAIL` | Evaluation completed and found an unhealthy business condition | No |
| `SKIPPED` | Applicability, dependency, or stop behavior intentionally prevented evaluation | Neither pass nor failure |
| `UNABLE_TO_EVALUATE` | Configuration, access, or data conditions prevented a reliable conclusion | No conclusion |
| `ERROR` | Unexpected system or evaluator failure | System failure |

`FAIL` is a valid business evaluation result. `ERROR` is reserved for an unexpected execution
problem.

## Lifecycle publication criteria

- A Set event requires `PublishRunEvent__c = true` on that Check Set.
- A Rule event requires `PublishResultEvent__c = true` on that Rule.
- All finalized statuses are eligible, not only failures.
- The Apex transaction must commit.
- `SUBSCRIBER`, `RUN_ON_LOAD`, blank, and unknown sources cannot publish.

## Event outputs

The API can produce these asynchronous outputs in addition to its synchronous return value.

### Check Set Run event

`Record_Health_Check_Set_Run__e` contains:

| Field | Value from the Apex run |
| --- | --- |
| `EventId__c`, `RunId__c` | Event identity and run correlation |
| `Phase__c` | `COMPLETED` |
| `CheckSetDeveloperName__c` | Completed Check Set API name |
| `Source__c` | `APEX_API`, `SCHEDULED`, or `BATCH` |
| `EligibleRuleCount__c`, `EvaluatedRuleCount__c` | Completed response size |
| `PassedCount__c`, `FailedCount__c`, `SkippedCount__c` | Business outcome counts |
| `UnableCount__c`, `SystemErrorCount__c` | Non-business outcome counts |
| `OccurredAt__c` | Event construction time |
| `ContractVersion__c`, `CoreVersion__c` | `1.0` and `2.0.0` |

### Rule Result event

`Record_Health_Check_Rule_Result__e` contains:

| Field | Value from the Apex run |
| --- | --- |
| `EventId__c` | Unique application event ID |
| `RunId__c` | Supplied or generated run ID |
| `CheckSetDeveloperName__c` | Parent Check Set API name |
| `RuleDeveloperName__c` | Completed Rule API name |
| `Status__c` | Final Rule status |
| `ReasonCode__c`, `Severity__c` | Outcome details when applicable |
| `Source__c` | `APEX_API`, `SCHEDULED`, or `BATCH` |
| `OccurredAt__c` | Event construction time |
| `ContractVersion__c`, `CoreVersion__c` | `1.0` and `2.0.0` |
| `ContainsRestrictedDetail__c` | Restricted detail existed; the detail itself is never included |

Events intentionally omit record ID, object API name, user ID, messages, queries, and field values.
The [Platform events reference](../reference/lifecycle-events.md) remains the canonical field-type,
retention, replay, and subscriber contract.

## Related

- [Integration overview](../integrate/overview.md)
- [V2 documentation standard](../api-documentation-standard.md)
- [Flow actions](../flow/actions.md)
- [Lightning component runs](../lwc/runs-and-events.md)
- [Reason codes](../reference/reason-codes.md)
- [Apex example](apex-example.md)
