# Reference: Apex API

> [!NOTE]
> On this page, run metadata-defined health checks from Apex and handle typed Check Set or Rule responses without duplicating Framework evaluation logic in the caller.
>
> **Reference**
>
> - This page is the source of truth for the public `RecordHealthCheck` Apex API: methods,
>   parameters, limits, errors, and response contracts.
> - To write the plugin class a Rule calls, use the [Apex reference](reference-apex.md) or
>   [Recent Account activity](../examples/apex/01-recent-activity.md).

The public `RecordHealthCheck` class runs the same metadata-defined Check Sets and Rules used by the
Lightning card. This reference documents its methods, typed results, limits, security context, and
lifecycle-event behavior.

Start with `runSet`: a Check Set is the parent configuration and contains the ordered Rules. Use
`runRule` only when the Apex process intentionally needs one specific health decision.

## What you will learn

| Goal | Where this page helps |
| --- | --- |
| Run the same Check Set users see on a record page | [Quick examples](#quick-examples) |
| Choose between `runSet` and `runRule` | [Set and Rule use different response classes](#set-and-rule-use-different-response-classes) |
| Handle every returned status and reason correctly | [Check Set response](#check-set-response) and [Rule response](#rule-response) |
| Evaluate several records safely | [Limits and transaction behavior](#limits-and-transaction-behavior) |
| Understand running-user access | [Prerequisites and access](#prerequisites-and-access) |
| Enable optional after-commit events | [Lifecycle publication criteria](#lifecycle-publication-criteria) |

## What this API is

- A synchronous, typed Apex entry point for metadata-configured evaluation.
- One entry-point class with separate Set and Rule response classes.
- A way to supply a run ID for correlation.
- An optional publisher of after-commit lifecycle events.

## What this API is not

- It does not save result history.
- It does not update the evaluated record or block DML.
- It does not guarantee lifecycle-event delivery or subscriber completion.
- It does not bypass the running user's Salesforce access.
- It is not an unlimited bulk-processing API; request limits apply.

New to the model? Read [Integrate Record Health Check](../integration/README.md) first.

## Prerequisites and access

- Configure at least one active Check Set and Rule. Replace the sample Developer Names with names
  available in your org.
- Grant the calling user Apex class access through the appropriate Record Health Check permission
  set or an equivalent Profile or Permission Set.
- Calls run `with sharing` and evaluation uses the calling user's record and field access. The API
  does not elevate access.
- Restricted diagnostic values are returned only when the user has the
  `Record_Health_Check_View_Diagnostics` Custom Permission. Keep business logic on public Status and
  Reason Code fields.

## Quick examples

For a runnable scratch-org demonstration using the integration fixtures, run
`integration-tests/scripts/demo_apex_api.apex`. It exercises both public entry points, validates the
typed responses, and prints one compact JSON summary suitable for a live demo.

Run a complete Check Set:

```apex
RecordHealthCheckSetResult result = RecordHealthCheck.runSet(
  'Example_Account_Relationship_Risk',
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
  'Example_Customer_Engagement_Current',
  accountId
);
```

The successful status is **`PASS`**, not `SUCCESS`. `PASS` is used consistently in Apex responses,
Flow outputs, Lightning rows, and platform events.

## Set and Rule use different response classes

`runSet` and `runRule` share one public class so callers have one discoverable API, but each method
returns its own typed result:

| Operation | Apex response class | Represents |
| --- | --- | --- |
| `runSet` | `RecordHealthCheckSetResult` | One Check Set aggregate plus its ordered Rule results |
| `runRule` | `RecordHealthCheckResult` | One Rule evaluated for one record |

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
| `recordIds` | `List<Id>` | Yes | Results preserve input order; the planned-evaluation cap below determines the usable batch size |
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

| Apex call | Event `Source__c` |
| --- | --- |
| Ordinary public API call | `APEX_API` |
| Source-aware scheduled caller | `SCHEDULED` |
| Source-aware batch/async caller | `BATCH` |
| Platform-event subscriber | `SUBSCRIBER`: publication blocked |

Unknown and blank source values fall back to the safer default: evaluation can run, but lifecycle publication is
blocked.

## Limits and transaction behavior

| Limit | Value |
| --- | --- |
| Planned Rule evaluations per call | 15 |

Planned Set evaluations equal active Rules × records. Exceeding a cap throws
`RecordHealthCheck.RecordHealthCheckRequestException`.

The evaluation cap limits health-check work after the Framework expands a Check Set into Rules.
One record evaluated against 10 active Rules therefore plans 10 evaluations; two records plan 20
and are rejected before the Framework starts partial work. The public Apex collection overloads do
not impose a separate 200-record cap; the Flow invocable transport does.

The Framework stops at a predictable boundary because each evaluation can read fields, execute a
formula or SOQL, call custom Apex, and create a result. Allowing a caller to consume the remaining
transaction limits unpredictably could fail after only some requested work had run. Split larger
jobs across transactions or use a smaller Check Set so every accepted call has a realistic chance
to complete.

Evaluation is synchronous and uses the current user's record and field access. Catchable evaluator
problems return a result status; uncatchable governor-limit exceptions behave like any other Apex
limit exception.

Lifecycle events are optional, best effort, and Publish After Commit. A later rollback prevents
delivery even if `EventBus.publish` was already called.

## Errors and investigation

Returned statuses and thrown exceptions are different contracts. `FAIL`, `SKIPPED`,
`UNABLE_TO_EVALUATE`, and `ERROR` are valid response statuses; inspect `reasonCode` and the
[reason-code reference](reference-reason-codes.md) before retrying. A thrown exception means no
usable response was returned for that call.

| Symptom | Likely cause | What to investigate |
| --- | --- | --- |
| `RecordHealthCheckRequestException: Record IDs are required.` | A collection overload received `null` | Pass a non-null `List<Id>`; use an empty list only when no work is intended |
| `RecordHealthCheckRequestException: This request would run too many checks...` | Planned evaluations exceed 15 | Reduce records, use a smaller Check Set, or distribute work across transactions |
| Configuration lookup exception | The API name is blank, misspelled, inactive, or unavailable to the caller | Verify the exact metadata `DeveloperName`, activation, and caller access |
| Salesforce access exception or an `UNABLE_TO_EVALUATE` response | The running user cannot read the record, object, or required field | Grant only the required record/object/field access, then rerun as that user |
| Uncatchable governor-limit exception | The calling transaction lacks remaining Salesforce limits | Reduce work per transaction or move the call to a transaction with adequate limits |

Catch `RecordHealthCheck.RecordHealthCheckRequestException` only when the caller can correct or
report the request. Treat a missing response as a fault or unable outcome and report the request.

```apex
try {
  RecordHealthCheckSetResult health = RecordHealthCheck.runSet(
    'Account_Data_Quality',
    accountId
  );
  // Branch on health.status and stable Reason Codes.
} catch (RecordHealthCheck.RecordHealthCheckRequestException ex) {
  // Report an invalid request; there is no health result to interpret.
}
```

## Versioning and deprecation

The contract version tells long-lived Apex, Flow, and serialized-response consumers which response
shape they received. It is not the installed package version. This distinction lets the Framework
release fixes and features without forcing integrations to change when the response shape is still
compatible.

The synchronous result contract is stable at `1.0`. Additive response fields may appear within that version,
so JSON consumers must ignore unknown fields. Removing or renaming a public field, method, status,
or reason value requires a new contract version. Lifecycle events use their own `1.0` contract and
the product version is reported separately as `2.0.0`.

No Apex API is currently deprecated. A future deprecation notice will identify the replacement
and earliest removal release in this page, the [documentation index](../README.md), the upgrade guide, and the
changelog.

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

For decisions, use Status, Reason Code, Failure Severity, and Developer Name, not message text.

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
| `message` | User-facing text; branch automation on Status, Reason Code, and Developer Name |
| `actualValue`, `expectedValue` | Security-filtered comparison values when available |
| `expectedValueLabel` | Overrides the Expected caption, including authorized **Passes when** formula detail |
| `actualValueDetail`, `expectedValueDetail` | Authorized source-detail strings; included only through enabled browser diagnostics |
| `adminDetailMessage` | Authorized troubleshooting text when Show Diagnostics is enabled |
| `adminDetail` | Authorized structured diagnostics: restricted-detail flag, field names, Reason Code, and message |
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

Error Log publication follows a separate rule: `PublishErrorLogEvent__c` defaults to `true` on the
Check Set and applies to Framework `ERROR` logs from any run source. Uncheck it to opt out. Missing
or unresolved Check Set configuration defaults to publication so configuration failures remain
observable.

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
The [Platform events reference](../integration/lifecycle-events.md) remains the primary behavioral overview,
retention, replay, and subscriber contract.

## Related

- [Integration overview](../integration/README.md)
- [Flow actions](../integration/flow-actions.md)
- [Lightning component](../integration/lightning-component.md)
- [Reason Codes](reference-reason-codes.md)
- [Recent Account activity](../examples/apex/01-recent-activity.md)
