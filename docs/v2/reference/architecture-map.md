# Architecture Map

The fastest way to navigate the codebase and find the right file to change. This file is an index, not a spec: for contracts and behavior see the [design spec](record-health-check-design-spec.md), [Programmatic API and Flow](../apex/programmatic-api.md), and [Lifecycle events](lifecycle-events.md).

> [!IMPORTANT]
> Facts here must match the code. If responsibility moves between classes, update this file in the same change.

## 1. What this is

Record Health Check runs **metadata-driven data-quality checks** against a Salesforce record and renders results on the record page. Checks are Custom Metadata (no code required for most Rules). The Apex engine evaluates them; an LWC displays them. The same engine is available from Apex and Flow through a public façade, with opt-in lifecycle events after deliberate runs.

Evaluation types: **FORMULA**, **QUERY**, **COMPARE_TWO_QUERIES**, **APEX**.

## 2. Layer diagram

```text
Record page LWC  recordHealthCheck
  └─ RecordHealthCheckController (@AuraEnabled; no lifecycle publish)
        ├─ getCheckDefinitions ─► ConfigService
        └─ evaluateCheck ───────► Engine ─► evaluators ─► RecordHealthCheckResult

Apex / Flow façade
  └─ RecordHealthCheck.run / runSet
  └─ RecordHealthCheckFlowAction (invocable)
        ├─ Engine (same path)
        └─ RecordHealthCheckLifecyclePublisher (opt-in, Publish After Commit)
              ├─ Record_Health_Check_Rule_Result__e
              └─ Record_Health_Check_Set_Run__e
```

The evaluation path is **read-only** (`with sharing`, `WITH USER_MODE`).

## 3. File → responsibility (production Apex)

### Entry / orchestration

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheck` | Public façade: `run` / `runSet` (single + bulk), caps, façade lifecycle publish. |
| `RecordHealthCheckFlowAction` | Packaged Flow invocable **Run Record Health Check**. |
| `RecordHealthCheckController` | `@AuraEnabled` LWC seam: definitions + evaluate one check (**no** event publish). |
| `RecordHealthCheckEngine` | Orchestrates one check: applicability, dependencies, evaluator routing, result normalization, diagnostics gating. |
| `RecordHealthCheckLifecyclePublisher` | Best-effort opt-in platform event publication. |

### Config & validation

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheckConfigService` | Loads Check Set + Rules; runtime validation; definition response. |
| `RecordHealthCheckMetadataValidator` | Deploy/CI metadata audit. |
| `RecordHealthCheckConfigValidator` | Shared validation primitives. |
| `RecordHealthCheckConstants` | Valid-value sets, numeric caps, LWC DTO mapping helpers. |
| `RecordHealthCheckReasonCodes` | Restricted reason-code remapping helpers. |

### Evaluators

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheckFormulaEvaluator` | Formula checks (FormulaEval). |
| `RecordHealthCheckSoqlEvaluator` | Single-query checks. |
| `RecordHealthCheckCompareQueriesEvaluator` | Dual-query checks. |
| `RecordHealthCheckApexEvaluator` | Custom `RecordHealthCheckRule` plugins. |
| `RecordHealthCheckComparisonEngine` | Shared operators + Found/Expected formatting. |
| `RecordHealthCheckSoqlTemplate` | SOQL template safety/normalization. |
| `RecordHealthCheckValueResolver` | Value coercion and typed comparison. |
| `RecordHealthCheckDescribeCache` | Per-transaction describe cache. |
| `RecordHealthCheckTemplateService` / token classes | Namespaced merge tokens. |

### Observability & ops

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheckLogger` | Structured `[RHC]` logging. |
| `RecordHealthCheckAccess` | `Record_Health_Check_View_Details` gating. |
| `RecordHealthCheckValueSource` | Comparison diagnostic detail rendering. |
| `RecordHealthCheckSetPicklist` | App Builder Check Set picker. |

### DTOs & contracts

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheckResult` | Sync Rule response (`contractVersion` `0.1`). |
| `RecordHealthCheckSetResult` | Sync Check Set response with rollup counts. |
| `RecordHealthCheckAdminDetail` | Structured diagnostics payload. |
| `RecordHealthCheckDefinition` / `…DefinitionResponse` | LWC definition payload. |
| `RecordHealthCheckContext` / `RecordHealthCheckRule` | Apex plugin input / interface. |
| `RecordHealthCheckEvaluatorException` | Evaluator failure with reason code. |

## 4. LWC bundle

`recordHealthCheck` (orchestration) + `healthCheckRunner` / `healthCheckModel` / `healthCheckPresentation`. One component, four JS modules — do not split into separate LWCs.

## 5. Documentation map (V2)

| Need | Doc |
| ---- | --- |
| Field reference | [Check Set](../metadata/check-set.md), [Rule](../metadata/rule-fields.md) |
| Apex / Flow callers | [Programmatic API and Flow](../apex/programmatic-api.md) |
| Events | [Lifecycle events](lifecycle-events.md) |
| Reason codes | [Reason codes](reason-codes.md) |
| Formal runtime contract | [Design Specification](record-health-check-design-spec.md) |
| Upgrade | [Upgrading to V2](../installation/upgrading-to-v2.md) |
