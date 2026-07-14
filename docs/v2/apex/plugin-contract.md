# Apex check contract

Short reference for the plugin interface. Step-by-step behavior (recordId, fields, parent paths, JSON defaults, class layout, responses): [Apex plugin reference](plugin-reference.md).

> [!NOTE]
> This reference is the source of truth for the `RecordHealthCheckRule` interface. The plugin reference covers implementation patterns.

## The interface

```apex
public interface RecordHealthCheckRule {
  RecordHealthCheckResult evaluate(RecordHealthCheckContext context);
}
```

Source: [`RecordHealthCheckRule.cls`](../../../force-app/main/default/classes/RecordHealthCheckRule.cls)

## Context (`RecordHealthCheckContext`)

| Field | Type | What it holds |
| ----- | ---- | ------------- |
| `recordId` | `Id` | Record on the Lightning page: **use this in SOQL** |
| `objectApiName` | `String` | API name (for example `Account`) |
| `record` | `SObject` | **Partial** record; see [Apex plugin reference 2](plugin-reference.md#2-reading-fields-on-the-current-record) |
| `parameters` | `Map<String, Object>` | Parsed **Apex Parameters (JSON)**; empty map when blank |
| `checkDeveloperName` | `String` | Rule `DeveloperName` being evaluated |

**Managed packages:** `ApexClass__c` resolves with `Type.forName` without a namespace prefix. Classes in a managed package may need a fully qualified name (for example `myns__MyCheck`).

## Result (`RecordHealthCheckResult`)

| Field | Plugin sets | Notes |
| ----- | ------- | ----- |
| `status` | **Yes** | `PASS` or `FAIL` for normal checks |
| `actualValue` | **Required for `PASS` / `FAIL`** | **Found** comparison value. Blank determinate Apex results are rejected with `APEX_EVALUATOR_ERROR`. |
| `expectedValue` | **Required for `PASS` / `FAIL`** | **Expected** comparison value. Blank determinate Apex results are rejected with `APEX_EVALUATOR_ERROR`. |
| `actualValueSource` | Optional | Internal detail for the Found side; surfaced as `actualValueDetail` in the nested `[RHC] Source detail` **browser console** group, never on the card. See [Show Diagnostics](../guides/show-diagnostics.md#what-you-see-in-the-browser-console) for the conditions that reveal it. |
| `expectedValueSource` | Optional | Internal detail for the Expected side; surfaced as `expectedValueDetail` in the same console group, under the same conditions. |
| `message` | Optional | Used on `FAIL` when non-blank; else metadata message |

Evaluator sets `label`, `severity`, `durationMs`, etc. Details: [Apex plugin reference 6](plugin-reference.md#6-returning-recordhealthcheckresult).

## Apex Settings JSON

Optional JSON **object** on the Rule → `context.parameters`. Defaults live in **Apex**; JSON overrides per Rule. Parsing pattern: [Apex plugin reference 4](plugin-reference.md#4-apex-settings-json-apexsettingsjson__c).

## Security

- Query with **`WITH USER_MODE`**
- `public with sharing class` on the plugin
- Read-time advisory: avoid DML/callouts unless intentional

## Evaluator flow

```text
Rule (Apex) → RecordHealthCheckApexEvaluator
  → Type.forName(ApexClass__c)
  → parse ApexParametersJson__c
  → build RecordHealthCheckContext
  → plugin.evaluate(context)
  → finalize (severity, message, validate status)
```

[← Examples index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md) · [Apex plugin reference](plugin-reference.md)
