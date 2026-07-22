# Reference: Architecture map

> [!NOTE]
> On this page, trace a Record Health Check behavior from the user experience to the Apex, Lightning Web Component, Custom Metadata, or contract that owns it before making a change.

Use this map to navigate the codebase and find the right file to change. This page is an index,
not a specification: use the [Apex API](../reference/reference-apex-api.md),
[Flow actions](../integration/flow-actions.md), [Platform events](../integration/lifecycle-events.md),
and Evaluation Type references for published behavior.

## Use this map during a code change

Consult this map before changing Framework Apex or Lightning Web Components. Begin with the
user-visible behavior, identify the owning layer below, and confirm the formal behavior in the
linked specification.

| If you are changing… | Trace first |
| --- | --- |
| How a Check Set or Rule is loaded and validated | Config service and metadata validation |
| How a Rule reaches `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` | Engine, selected evaluator, and comparison engine |
| What users see on a Lightning record page | LWC bundle, controller, and result payload classes |
| The public Apex or packaged Flow surface | Entry/orchestration classes and response contracts |
| Lifecycle event publication | Public entry point, Flow action, or LWC run path, then lifecycle publisher |

> [!IMPORTANT]
> Facts here must match the code. If responsibility moves between classes, update this file in the same change.

## 1. What this is

Record Health Check runs **metadata-driven data-quality checks** against a Salesforce record and renders results on the record page. Checks are Custom Metadata (no code required for most Rules). The Apex engine evaluates them; an LWC displays them. The same engine is available from Apex and Flow through a public entry point, with opt-in lifecycle events after deliberate runs.

Evaluation Types: **FORMULA**, **QUERY**, **COMPARE_TWO_QUERIES**, **APEX**.

## 2. Layer diagram

```text
Record page LWC  recordHealthCheck
  └─ RecordHealthCheckController (@AuraEnabled; no lifecycle publish)
        ├─ getCheckDefinitions ─► ConfigService
        └─ evaluateCheck ───────► Engine ─► evaluators ─► RecordHealthCheckResult

Apex / Flow entry point
  └─ RecordHealthCheck.runRule / runSet
  ├─ RecordHealthCheckRunRuleFlowAction (invocable)
  └─ RecordHealthCheckRunSetFlowAction (invocable)
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
| `RecordHealthCheck` | Public Apex entry point: `runRule` / `runSet` (single + bulk), caps, lifecycle publish. |
| `RecordHealthCheckRunRuleFlowAction` | Packaged Flow invocable **Run Record Health Check Rule**. |
| `RecordHealthCheckRunSetFlowAction` | Packaged Flow invocable **Run Record Health Check Set**. |
| `RecordHealthCheckController` | `@AuraEnabled` entry point for the LWC: definitions + evaluate one check (**no** event publish). |
| `RecordHealthCheckEngine` | Orchestrates one check: applicability, dependencies, evaluator routing, result normalization, diagnostics gating. |
| `RecordHealthCheckLifecyclePublisher` | Best-effort opt-in platform event publication. |

### Config & validation

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheckConfigService` | Loads Check Set + Rules; runtime validation; definition response. |
| `RecordHealthCheckMetadataValidator` | Deploy/CI metadata audit. |
| `RecordHealthCheckConfigValidator` | Shared validation helpers. |
| `RecordHealthCheckConstants` | Valid-value sets, numeric caps, response-mapping helpers for the LWC. |
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
| `RecordHealthCheckAccess` | `Record_Health_Check_View_Diagnostics` gating. |
| `RecordHealthCheckValueSource` | Comparison diagnostic detail rendering. |
| `RecordHealthCheckSetPicklist` | App Builder Check Set picker. |

### Result and payload classes

| Class | Responsibility |
| ----- | -------------- |
| `RecordHealthCheckResult` | Stable sync Rule response (`contractVersion` `1.0`). |
| `RecordHealthCheckSetResult` | Sync Check Set response with rollup counts. |
| `RecordHealthCheckAdminDetail` | Structured diagnostics payload. |
| `RecordHealthCheckDefinition` / `…DefinitionResponse` | LWC definition payload. |
| `RecordHealthCheckContext` / `RecordHealthCheckRule` | Apex plugin input / interface. |
| `RecordHealthCheckEvaluatorException` | Evaluator failure with a Reason Code. |

## 4. LWC bundle

`recordHealthCheck` (orchestration) + `healthCheckRunner` / `healthCheckModel` / `healthCheckPresentation`. One component, four JS modules: do not split into separate LWCs.

## 5. Documentation map

| Need | Doc |
| ---- | --- |
| Field reference | [Check Set fields](../metadata/fields-check-set.md), [Rule fields](../metadata/fields-rule.md) |
| Apex callers | [Apex API](../reference/reference-apex-api.md) |
| Flow callers | [Flow actions](../integration/flow-actions.md) |
| Lightning component | [Lightning component](../integration/lightning-component.md) |
| Events | [Lifecycle events](../integration/lifecycle-events.md) |
| Reason Codes | [Reason Codes](reference-reason-codes.md) |
| Upgrade | [Upgrading Record Health Check](../installation/04-upgrading.md) |

## Related

- [Documentation index](../README.md)
- [Integration overview](../integration/README.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
