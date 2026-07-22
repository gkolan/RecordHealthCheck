# Apex reference

> [!NOTE]
> **On this page**
>
> Write a plugin class: read the record, parse JSON parameters, and return a result.
>
> **Reference**
>
> - This page is the source of truth for Apex plugin behavior; guides and examples link here
>   rather than restating it.
> - For an end-to-end example, use [Recent Account activity](01-recent-activity.md). To call the engine without
>   writing a plugin, use the [Apex API](../../integration/apex-api/public-api.md) or [Flow actions](../../integration/flow-actions.md).

## Interface

```apex
public interface RecordHealthCheckRule {
  RecordHealthCheckResult evaluate(RecordHealthCheckContext context);
}
```

Source: [`RecordHealthCheckRule.cls`](../../../force-app/main/default/classes/RecordHealthCheckRule.cls)

## How the engine calls your class

```text
Rule (Apex) → RecordHealthCheckApexEvaluator
  → Type.forName(ApexClass__c)
  → parse ApexParametersJson__c
  → build RecordHealthCheckContext
  → plugin.evaluate(context)
  → finalize (severity, message, validate status)
```

Each evaluation receives **one** `RecordHealthCheckContext`. The Rule metadata record itself is
**not** passed to `evaluate`: values an administrator should be able to change belong in **Apex
Parameters (JSON)**, not in the class.

The evaluator loads **Apex Class** with `Type.forName(ApexClass__c)`. An unpackaged class needs only
its class name. A class installed from a managed package may need the namespace-qualified name
instead; confirm the exact name in the target org before activating the Rule.

## 1. Getting `recordId`

The Id of the record on the Lightning page is always available on `context`:

```apex
Id recordId = context.recordId;
String objectApiName = context.objectApiName; // e.g. "Account"
```

Use `context.recordId` in SOQL bind variables:

```apex
Integer contactCount = [
  SELECT COUNT()
  FROM Contact
  WHERE AccountId = :context.recordId
  WITH USER_MODE
];
```

`context.recordId` is the same Id the caller supplies. It is **never null** when the evaluator calls
the plugin; a missing ID is rejected earlier with public reason `NO_RECORD_CONTEXT`.

`context.record.Id` is also available, but **`context.recordId`** is preferred for queries: it is explicit and works even when `context.record` is minimal.

## 2. Reading fields on the current record

### `context.record` is partial: Do not assume all fields are loaded

The engine loads only fields it knows the Rule needs:

| Source on the Rule | Fields added to `context.record` |
| ------------------ | -------------------------------- |
| `{!record.Field}` merge tokens in **Message When Failed** / **Message When Unable To Evaluate** | Those token paths (e.g. `Name`, `Customer_Tier__c`) |
| **Applies When (Formula)** | Fields referenced in that formula |
| SOQL templates on Query rules | Merge tokens in those queries |

For a typical **Apex** Rule with applicability **Always** and message `{!record.Name} has no recent activity`, `context.record` may contain only **`Id`** and **`Name`**.

`BillingCity`, custom fields, or `Parent.BillingCity` are **not** guaranteed on `context.record` unless they appear in merge tokens or applicability formulas on that Rule.

### When `context.record` is enough

When the required field is already loaded:

```apex
Account acct = (Account) context.record;
String name = acct.Name;
```

For dynamic access:

```apex
Object tier = context.record.get('Customer_Tier__c');
```

### When to query in the plugin (recommended for most Apex checks)

When fields are not guaranteed on `context.record`, query by `context.recordId`:

```apex
Account acct = [
  SELECT
    Id,
    Name,
    Type,
    BillingCity,
    AnnualRevenue,
    Customer_Tier__c
  FROM Account
  WHERE Id = :context.recordId
  WITH USER_MODE
];
```

All plugin SOQL must use **`WITH USER_MODE`** so the running context's CRUD/FLS apply.

## 3. Parent fields and relationships

### Option A: Relationship in SOQL SELECT (preferred)

```apex
Account acct = [
  SELECT
    Id,
    Name,
    ParentId,
    Parent.Name,
    Parent.BillingCity,
    Parent.Industry
  FROM Account
  WHERE Id = :context.recordId
  WITH USER_MODE
];

String parentCity = acct.Parent?.BillingCity;
Id parentId = acct.ParentId;
```

Use the relationship name from Schema (`Parent` on Account, `Account` on Contact, etc.).

### Option B: `getSObject` on a dynamic SObject

```apex
SObject parent = context.record.getSObject('Parent');
if (parent != null) {
  String parentCity = (String) parent.get('BillingCity');
}
```

This only works when the engine **pre-loaded** `Parent.BillingCity` on `context.record` (uncommon for Apex Rules unless `{!record.Parent.BillingCity}` appears in a message token).

### Custom lookup to another record

```apex
Account acct = [
  SELECT Primary_Contact__c, Primary_Contact__r.Email
  FROM Account
  WHERE Id = :context.recordId
  WITH USER_MODE
];
String primaryEmail = acct.Primary_Contact__r?.Email;
```

Replace `Primary_Contact__c` with the lookup API name for the object in use.

### Child records

Query children separately: `context.record` does not include child lists:

```apex
List<Opportunity> openOpps = [
  SELECT Id, Name, Amount, CloseDate
  FROM Opportunity
  WHERE AccountId = :context.recordId AND IsClosed = false
  WITH USER_MODE
];
```

## 4. Apex Parameters (JSON) (`ApexParametersJson__c`)

### Setup

On the Rule record in Custom Metadata:

| Setup label | API name | Example |
| ----------- | -------- | ------- |
| Apex Parameters (JSON) | [`ApexParametersJson__c`](../../metadata/fields-rule.md#apex-parameters-json-apexparametersjson__c) | `{"daysBack": 90, "minScore": 80}` |

The evaluator parses this **before** calling the plugin and passes it as `context.parameters` (`Map<String, Object>`). When the field is blank, `context.parameters` is an **empty map** (not null).

### Rules

| Rule | Detail |
| ---- | ------ |
| Must be a JSON **object** | `{"key": "value"}`: not `[]` or `"string"` |
| Keys are strings | Access with `parameters.get('daysBack')` |
| Types after `JSON.deserializeUntyped` | Strings stay strings; numbers may be `Integer` or `Decimal`; booleans are `Boolean` |
| Invalid JSON | Rule returns `UNABLE_TO_EVALUATE` / `INVALID_APEX_PARAMETERS`: the plugin class is **not** called |

### Recommended parsing pattern (defaults + bounds)

Shipped classes use **constants in Apex** for defaults and **JSON for per-Rule overrides**:

```apex
private static final Integer DEFAULT_DAYS_BACK = 30;
private static final Integer MIN_DAYS_BACK = 1;
private static final Integer MAX_DAYS_BACK = 3650;

public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
  Integer daysBack = resolveDaysBack(context.parameters);
  // ...
}

private Integer resolveDaysBack(Map<String, Object> parameters) {
  if (parameters == null) {
    return DEFAULT_DAYS_BACK;
  }
  Object raw = parameters.get('daysBack');
  if (raw == null) {
    return DEFAULT_DAYS_BACK;
  }
  try {
    Integer parsed = Integer.valueOf(String.valueOf(raw));
    if (parsed >= MIN_DAYS_BACK && parsed <= MAX_DAYS_BACK) {
      return parsed;
    }
  } catch (Exception ex) {
    // fall through to default
  }
  return DEFAULT_DAYS_BACK;
}
```

**Why `String.valueOf`:** JSON may deserialize `90` as `Integer` or `Decimal`. `String.valueOf` normalizes before `Integer.valueOf`.

### Example JSON documents

| Intent | `ApexParametersJson__c` | `parameters.get(...)` |
| ------ | ----------------------- | ------------------------ |
| Look-back window | `{"daysBack": 90}` | `daysBack` → 90 |
| Stale threshold | `{"staleDays": 30}` | `staleDays` → 30 |
| Score gate | `{"minScore": 80, "activityDaysBack": 60}` | two keys |
| Feature flag | `{"strictMode": true}` | cast to Boolean |
| Omit key | `{}` or leave blank | use Apex default |

### Boolean and Decimal helpers

```apex
private static Boolean resolveBoolean(
  Map<String, Object> parameters,
  String key,
  Boolean defaultValue
) {
  if (parameters == null || !parameters.containsKey(key)) {
    return defaultValue;
  }
  Object raw = parameters.get(key);
  if (raw instanceof Boolean) {
    return (Boolean) raw;
  }
  return Boolean.valueOf(String.valueOf(raw));
}

private static Decimal resolveDecimal(
  Map<String, Object> parameters,
  String key,
  Decimal defaultValue
) {
  if (parameters == null || !parameters.containsKey(key)) {
    return defaultValue;
  }
  Object raw = parameters.get(key);
  if (raw == null) {
    return defaultValue;
  }
  return Decimal.valueOf(String.valueOf(raw));
}
```

## 5. Recommended class structure

```apex
/**
 * One-line description. Configurable via ApexParametersJson__c: {"daysBack": 90}
 */
public with sharing class MyAccountCheck implements RecordHealthCheckRule {
  // ── Defaults (Apex): JSON overrides per Rule ─────────────────────────
  private static final Integer DEFAULT_DAYS_BACK = 30;

  // ── Entry point ───────────────────────────────────────────────────────
  public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
    Integer daysBack = resolveDaysBack(context.parameters);

    // 1. Load data (query WITH USER_MODE; bind context.recordId)
    // 2. Apply business logic
    // 3. Build and return result
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = /* 'PASS' or 'FAIL' */;
    return result;
  }

  // ── Private helpers ─────────────────────────────────────────────────────
  private Integer resolveDaysBack(Map<String, Object> parameters) {
    // safe parse with default; see 4
    return DEFAULT_DAYS_BACK;
  }
}
```

| Practice | Why |
| -------- | --- |
| `public with sharing class` | Matches framework; respects user sharing |
| `implements RecordHealthCheckRule` | Required: the evaluator confirms the class implements the interface before calling it |
| Defaults as `private static final` | JSON overrides without redeploying for every tweak |
| Private `resolve*` methods | One place for bounds checking and bad JSON values |
| No DML / callouts unless intentional | Health checks are read-time advisory |
| Catch exceptions the class can recover from | Uncaught exceptions → `ERROR` / `APEX_EVALUATOR_ERROR` |

## 6. Returning `RecordHealthCheckResult`

### Normal path: Set status, Found, and Expected

For a completed check, return `PASS` or `FAIL` plus both comparison values. Metadata supplies the
label, severity, and fallback failure message:

```apex
RecordHealthCheckResult result = new RecordHealthCheckResult();
result.status = (taskCount + eventCount > 0) ? 'PASS' : 'FAIL';
result.actualValue = (taskCount + eventCount) + ' recent activities';
result.expectedValue = 'At least 1 recent activity';
return result;
```

On **`FAIL`**, the evaluator sets:

- **`severity`** from Rule `FailureSeverity__c` (not set by the plugin)
- **`message`** from `result.message` when non-blank; otherwise **Message When Failed** with `{!record.Field}` merge tokens resolved

### Found / Expected (required for PASS / FAIL)

Apex checks must set both comparison chips for every determinate result (`PASS` or `FAIL`). If either `actualValue` or `expectedValue` is blank, the evaluator rejects the result with `ERROR` / `APEX_EVALUATOR_ERROR`. Failed checks show comparison values inline; passing-check visibility follows the Check Set **Found/Expected Display** setting.

```apex
result.status = 'FAIL';
result.actualValue = '2 unhealthy';
result.expectedValue = '0 unhealthy';
result.actualValueSource = new RecordHealthCheckValueSource.Detail(
  'Unhealthy open opportunities',
  '2',
  '3 open opportunities scanned'
);
result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
  'Allowed unhealthy count',
  '0',
  null
);
```

See [Design spec 9 comparison display](../../reference/record-health-check-design-spec.md#comparison-display-contract).

### Diagnostic detail (optional)

When the check can explain where a value came from, populate `actualValueSource` /
`expectedValueSource` with `RecordHealthCheckValueSource.Detail`. These never render on the card.
See [Show Diagnostics](../../guides/show-diagnostics.md#what-you-see-in-the-browser-console) for who
can see them and when.

```apex
result.actualValueSource = new RecordHealthCheckValueSource.Detail(
  'Open Opportunities',
  '2 unhealthy',
  'filtered by Amount and Close Date'
);
result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
  'Allowed unhealthy count',
  '0',
  null
);
```

### Custom failure message from Apex (rare)

Only when the metadata message is insufficient:

```apex
result.status = 'FAIL';
result.message = 'Custom detail for this run only.';
```

When `message` is blank, metadata **Message When Failed** wins.

### Status values

| Status | When the plugin returns it |
| ------ | -------------------------- |
| `PASS` | Check succeeded |
| `FAIL` | Check failed (normal) |
| `SKIPPED` | Rare in plugins: usually dependencies skip in LWC |
| `UNABLE_TO_EVALUATE` | Rare: config/data detected inside the plugin |
| `ERROR` | Avoid: uncaught exceptions map here automatically |

Any other string → evaluator converts to `ERROR` / `APEX_EVALUATOR_ERROR`.

### Fields the plugin does not set

| Field | Who sets it |
| ----- | ----------- |
| `label`, `ruleDeveloperName`, `priority` | Evaluator from Rule metadata |
| `severity` | Evaluator from Rule on `FAIL` |
| `evaluatorType` | Always `APEX` |
| `durationMs` | Evaluator |
| `reasonCode` | Framework (plugins rarely need this) |

## 7. Canonical basic example

Use the complete [Recent Account activity example](01-recent-activity.md).
It is intentionally the one complete example shared by these plugin pages: it shows a
`public with sharing` implementation, user-mode aggregate SOQL, two independently overridable JSON
parameters, safe defaults, `PASS`/`FAIL`, and required Found/Expected values. Keeping the complete
class in one place prevents the short contract and detailed reference from drifting.

## 8. Checklist before deploy

- [ ] Class implements `RecordHealthCheckRule` and is **`public`** (so `Type.newInstance()` works).
- [ ] All SOQL uses **`WITH USER_MODE`** and binds **`:context.recordId`** (or fields from a plugin query).
- [ ] JSON keys documented in the class header comment; defaults apply when JSON is blank or omits a key. Invalid JSON prevents plugin invocation.
- [ ] Returns only valid `status` values; normal checks use `PASS` / `FAIL` only.
- [ ] Sets both `result.actualValue` and `result.expectedValue` for every `PASS` / `FAIL`.
- [ ] Apex test class covers `evaluate` with at least pass and fail paths.
- [ ] Rule **Apex Class** API name matches deployed class exactly.

## Compatibility and deprecation

- **Response contract:** Stable synchronous contract `1.0`.
- **Core version:** The plugin interface ships with Core `2.0.0`.
- **Compatible changes:** New context or result fields do not require plugin changes.
- **Breaking changes:** Removing or renaming an interface member requires a documented breaking
  product release.
- **Deprecations:** None.

## Related

- [Recent Account activity](01-recent-activity.md): end-to-end starting point
- [Recent activity](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/01-recent-activity.md): multiple objects plus JSON parameters
- [Opportunity health](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/02-open-opportunity-health.md): a child-record loop with Found/Expected
- [Strategic readiness](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/03-strategic-readiness.md): a scoring pattern with JSON parameters
- [Examples pattern library index](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/README.md)
- [Configure with AI](../../guides/llm-configuration.md#45-class-sketch-apex-only): prompt template for a class sketch
- [Configuration guide: Apex Rules](../../guides/configuration-guide.md#9-apex-rules): Setup fields
