# Apex API and Flow

Run Record Health Check from Apex or Flow without opening the Lightning card. The public V2 Apex
class uses the same evaluation behavior as the record page. Optional lifecycle platform events can
publish after Apex and Flow runs.

> [!NOTE]
> Apex response version: **`0.1`** (`RecordHealthCheckResult.CONTRACT_VERSION`). Future versions may
> add fields without changing existing fields. Lifecycle events use version `1.0`; see
> [Lifecycle events](../reference/lifecycle-events.md).

## Caps

| Cap | Value | Behavior |
| --- | --- | --- |
| `RecordHealthCheck.MAX_RECORDS_PER_CALL` | **200** | Maximum Ids in one bulk `run` / `runSet` / Flow request list. |
| `RecordHealthCheck.MAX_EVALUATIONS_PER_CALL` | **15** | Maximum planned Rule evaluations in one call (records × Rules for a Check Set run). |

Exceeding either throws `RecordHealthCheck.RecordHealthCheckRequestException`. Catchable Rule evaluation failures become result statuses; Apex governor limit exceptions remain uncatchable.

All Apex API evaluation runs as the **current user** (`WITH USER_MODE`).

## Apex: one Rule

```apex
RecordHealthCheckResult result = RecordHealthCheck.run(
  'Example_Account_360_Health_Check', // Check Set DeveloperName
  'Example_Recent_Activity',           // Rule DeveloperName
  accountId
);

if (result.status == 'FAIL') {
  // react to result.message, result.severity, result.reasonCode
}
```

Optional shared run identifier:

```apex
RecordHealthCheck.run(configName, ruleName, recordId, 'ticket-12345');
```

Bulk (preserves input order; one batched lifecycle publish afterward):

```apex
List<RecordHealthCheckResult> results = RecordHealthCheck.run(
  configName,
  ruleName,
  recordIds
);
```

## Apex: whole Check Set

```apex
RecordHealthCheckSetResult setResult = RecordHealthCheck.runSet(
  'Example_Account_360_Health_Check',
  accountId
);

System.debug(setResult.status);          // rollup
System.debug(setResult.passedCount);
for (RecordHealthCheckResult r : setResult.results) {
  System.debug(r.checkDeveloperName + ' ' + r.status);
}
```

Optional `runId` overload and bulk `runSet(configName, List<Id>)` mirror the Rule APIs. Planned evaluations for a Check Set = active Rules × records and must stay within **15**.

### `RecordHealthCheckSetResult`

| Field | Meaning |
| --- | --- |
| `contractVersion` | Sync contract (`0.1`). |
| `checkSetDeveloperName` | Check Set API name. |
| `recordId` | Subject record. |
| `runId` | Correlation id for this set run. |
| `status` | Rollup after evaluation: `ERROR` → `UNABLE_TO_EVALUATE` → `FAIL` → `PASS` → `SKIPPED` (first matching priority). |
| `passedCount`, `failedCount`, `skippedCount`, `unableCount`, `systemErrorCount` | Outcome counts. |
| `results` | Ordered per-Rule `RecordHealthCheckResult` list. |

## Flow: packaged action

Invocable label: **Run Record Health Check** (category **Record Health Check**). Class: `RecordHealthCheckFlowAction`.

| Input | Required | Meaning |
| --- | --- | --- |
| Check Set API Name | Yes | Check Set `DeveloperName`. |
| Rule API Name | No | Leave blank to run the **whole Check Set**; set to run **one Rule**. |
| Record ID | Yes | Record to evaluate. |

| Output | Meaning |
| --- | --- |
| Contract Version | Sync contract on the nested result. |
| Status | Rule status, or Check Set rollup status. |
| Reason Code | Populated on the **single-Rule** path only. |
| Passed / Failed / Skipped / Unable / System Error Count | Populated on the **Check Set** path. |
| Result JSON | Serialized `RecordHealthCheckResult` or `RecordHealthCheckSetResult` for advanced Flow consumers. |

The Flow action calls the same public Apex class. When lifecycle publishing is enabled, its events
use the stored source value `FACADE`; see [Lifecycle events](../reference/lifecycle-events.md).

## What the record page does differently

| Path | Publishes lifecycle events? |
| --- | --- |
| LWC / `RecordHealthCheckController.evaluateCheck` | **Never** |
| `RecordHealthCheck.run` / `runSet` / Flow action | **Yes**, when the opt-in publication switches are on |

## Rule result shape (`RecordHealthCheckResult`)

Key fields for integrators:

| Field | Notes |
| --- | --- |
| `contractVersion` | `0.1` |
| `runId` | Correlation |
| `checkDeveloperName`, `label` | Rule identity / Check Title |
| `status` | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, `ERROR` |
| `severity` | On `FAIL` only (`CRITICAL` / `WARNING` / `INFO` from metadata → display mapping in the LWC) |
| `message` | Safe user-facing text |
| `actualValue` / `expectedValue` / `expectedValueLabel` | Found / Expected / Passes when |
| `actualValueDetail` / `expectedValueDetail` | Comparison diagnostic detail (requires `Record_Health_Check_View_Details`) |
| `adminDetailMessage` / `adminDetail` | Diagnostics path (requires **Show Diagnostics** and View Details) |
| `actionLabel` / `actionUrl` / `fixInstructions` | FAIL remediation |
| `reasonCode` | Machine reason for non-pass/fail outcomes — see [Reason codes](../reference/reason-codes.md) |
| `priority`, `durationMs`, `evaluatorType` | Ordering, timing, evaluation type |

Restricted access reason codes are remapped on the public `reasonCode` to `CANNOT_EVALUATE`; the specific code can appear in `adminDetail` when diagnostics are authorized.

## Related

- [Lifecycle events](../reference/lifecycle-events.md)
- [Reason codes](../reference/reason-codes.md)
- [Apex plugin reference](plugin-reference.md)
- [Upgrading to V2](../installation/upgrading-to-v2.md)
