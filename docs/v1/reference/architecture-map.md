# Architecture Map

The fastest way to navigate the codebase and find the right file to change. This file is an index, not a spec: for contracts and behavior see the [design spec](record-health-check-design-spec.md).

> [!IMPORTANT]
> Facts here must match the code. If responsibility moves between classes, update this file in the same change.

## 1. What this is

Record Health Check runs **metadata-driven data-quality checks** against a single
Salesforce record and renders the results on the record page. Checks are defined
as Custom Metadata (no code); the Apex engine evaluates them; an LWC displays them.
A check can be a **Formula**, a **SOQL query**, a **dual-SOQL comparison**, or a
custom **Apex plugin**.

## 2. Layer diagram (request flow)

```text
Record page
  └─ LWC  recordHealthCheck            (orchestration, concurrency, display)
        │  @salesforce/apex
        ▼
     RecordHealthCheckController       (thin @AuraEnabled seam: no logic)
        ├─ getCheckDefinitions ─► ConfigService   (assemble + validate config)
        └─ evaluateCheck ───────► Engine          (orchestrate one check)
                                      │
                                      ├─ applicability gate (formula / SOQL)
                                      ├─ field planning (which fields to query)
                                      └─ route to ONE evaluator:
                                           ├─ FormulaEvaluator
                                           ├─ SoqlEvaluator
                                           ├─ DualSoqlEvaluator
                                           └─ ApexEvaluatorDispatcher ─► RecordHealthCheckRule plugin
                                      (all SOQL paths share:
                                           SoqlTemplate · ValueResolver · ComparatorEngine)
                                      ▼
                                 RecordHealthCheckResult  ──► back to LWC
```

The evaluation path is **read-only** (`with sharing`, `WITH USER_MODE`).

## 3. File → responsibility (production Apex)

One line each. Lines counts flag the four refactor hotspots (see 6).

### Entry / orchestration
| Class | Lines | Responsibility |
|-------|------:|----------------|
| `RecordHealthCheck` | 125 | One-line programmatic entry point to run a single check from anywhere. |
| `RecordHealthCheckController` | 145 | `@AuraEnabled` entry for the LWC: load Check Set definitions, evaluate one check, and report whether Check Sets exist for the record's object. |
| `RecordHealthCheckEngine` | **975** | Orchestrates one check: applicability gate, field planning, evaluator routing, dependency cache, result normalization. |

### Config & validation
| Class | Lines | Responsibility |
|-------|------:|----------------|
| `RecordHealthCheckConfigService` | **893** | Loads Check Set + Rules, assembles the definition, validates rules at **runtime**. |
| `RecordHealthCheckSetAvailability` | 20 | Apex response for whether an object has active and/or inactive Check Sets. |
| `RecordHealthCheckMetadataValidator` | **1,138** | Validates the same rules at **deploy/CI time**, emits `ValidationIssue`s. ⚠️ duplicates ConfigService logic (see 6 D1). |
| `RecordHealthCheckConfigValidator` | 40 | Pure, side-effect-free validation primitives shared by runtime and CI. |
| `RecordHealthCheckConstants` | 193 | Single source of truth for valid-value sets and numeric caps. |

### Evaluators (one per Check Type)
| Class | Lines | Responsibility |
|-------|------:|----------------|
| `RecordHealthCheckFormulaEvaluator` | 317 | Evaluates Formula checks via `FormulaEval`; transaction-wide budget. |
| `RecordHealthCheckSoqlEvaluator` | 503 | Single-query checks: token binding, query exec, scalar/aggregate comparison. |
| `RecordHealthCheckDualSoqlEvaluator` | 391 | Compares two queries (scalar & list comparators). |
| `RecordHealthCheckApexEvaluatorDispatcher` | 226 | Instantiates & runs a `RecordHealthCheckRule` plugin; validates its returned status. |

### Shared evaluator utilities (the DRY core: change comparison logic here)
| Class | Lines | Responsibility |
|-------|------:|----------------|
| `RecordHealthCheckComparatorEngine` | 365 | Shared comparator + null/empty-behavior engine for both SOQL evaluators; formats `actualValue` / `expectedValue` for display. |
| `RecordHealthCheckDescribeCache` | 80 | Caches Schema describe results for the Apex transaction so busy record pages do less repeated metadata work. |
| `RecordHealthCheckSoqlTemplate` | 327 | Parenthesis-depth-aware SOQL normalizer + string-literal masking. |
| `RecordHealthCheckValueResolver` | 239 | Value extraction, coercion, and comparison for SOQL results. |

### Observability & ops
| Class | Lines | Responsibility |
|-------|------:|----------------|
| `RecordHealthCheckLogger` | 190 | Single logging facade for the framework. |
| `RecordHealthCheckAccess` | 34 | Gates Advanced-tier details through `Record_Health_Check_View_Details`: troubleshooting when `DebugMode__c` is on, and comparison provenance in console diagnostics. |
| `RecordHealthCheckProvenance` | 73 | Renders structured provenance `Detail` into `actualValueDetail` / `expectedValueDetail` strings. |
| `RecordHealthCheckSetPicklist` | 73 | Design-time App Builder picklist for the LWC `checkSetName` property, scoped to the page object. |

### DTOs & contracts (data carriers: no behavior)
| Class | Responsibility |
|-------|----------------|
| `RecordHealthCheckResult` | `@AuraEnabled` result returned to the LWC (`status`, `message`, `actualValue`, `expectedValue`, `actualValueDetail`, `expectedValueDetail`, …). |
| `RecordHealthCheckDefinition` / `…DefinitionResponse` | Check + Check-Set metadata sent to the LWC. |
| `RecordHealthCheckContext` | Input passed to an Apex plugin (record, params). |
| `RecordHealthCheckRule` | Interface every Apex-plugin check implements. |
| `RecordHealthCheckEvaluatorException` | Shared evaluator exception carrying a machine-readable reason code. |
| `AccountHasRecentActivityCheck` | Example `RecordHealthCheckRule` plugin. |

## 4. File → responsibility (LWC bundle `recordHealthCheck`)

The bundle is intentionally **one component, four JS modules** (cohesive UI, split
by concern: do **not** split into separate LWCs):

| File | Lines | Responsibility |
|------|------:|----------------|
| `recordHealthCheck.js` | 942 | Component shell: @api props, lifecycle, definition load, tooltip dwell, template getters, diagnostics. Delegates the run to the runner. |
| `healthCheckRunner.js` | 362 | Run lifecycle: dependency gating, 5-way concurrency cap, run/reveal tokens, progressive-reveal draining, stop-on-first-error. Sets `runComplete` and `hasCompletedRunOnce` on completion; clears `runComplete` (not `hasCompletedRunOnce`) when a new run starts. |
| `healthCheckModel.js` | 112 | Pure domain logic: result shaping, response normalization, dependency-cycle detection, error parsing. No component state. |
| `healthCheckPresentation.js` | 336 | Pure view formatting: maps results into template-ready flags, CSS classes, summary rows, tooltip anchors, **Found** / **Expected** chip visibility, and comparison caret behavior. |
| `recordHealthCheck.html` / `.css` | 319 / 1032 | Markup and styling (CSS status icons, tooltips, comparison chips, action-button spinner, summary-pill nubbin host). |

## 5. Data model (metadata & objects)

| API name | Type | Role |
|----------|------|------|
| `Record_Health_Check_Set__mdt` | Custom Metadata | A named group of checks bound to one object + display settings. |
| `Record_Health_Check_Rule__mdt` | Custom Metadata | One check: type, query/formula, comparator, severity, applicability, dependencies. |
| Permission Sets / Custom Permissions | | `Record_Health_Check_User`; `Record_Health_Check_Admin` (includes `Record_Health_Check_View_Details`, `Record_Health_Check_Configure`). |

## 6. "Where do I change X?" index

| I want to… | Go to |
|------------|-------|
| Add/adjust a **comparator** (`equals`, `>`, list overlap…) | `RecordHealthCheckComparatorEngine`: **only here**; both SOQL evaluators delegate to it. |
| Change **null / empty behavior** semantics | `RecordHealthCheckComparatorEngine` + `RecordHealthCheckConstants`. |
| Add a new **valid enum value** (mode, severity, Check Type) | `RecordHealthCheckConstants`: both validators read from it. |
| Add a **new Check Type** | New evaluator class + routing in `RecordHealthCheckEngine.routeEvaluator` + a `validate*Rule` in *both* validators (until D1 lands). |
| Change **rule validation** rules | ⚠️ today edit **both** `ConfigService` and `MetadataValidator` (see D1). After D1: one `RecordHealthCheckRuleValidator`. |
| Change **SOQL token binding / normalization** | `RecordHealthCheckSoqlTemplate` (+ `SoqlEvaluator.bindTokens`). |
| Change **what fields get queried** for a record | field-planning methods in `RecordHealthCheckEngine` (`collectRecordFields`, `addFormulaFields`, `addMergeFields`); describe lookups go through `RecordHealthCheckDescribeCache`. |
| Write a custom **Apex check** | Implement `RecordHealthCheckRule`; see `AccountHasRecentActivityCheck`. |
| Change **display / summary / styling** logic | `healthCheckPresentation.js` (not the HTML: templates can't branch). |
| Change **comparison disclosure UI** | `healthCheckPresentation.js` + `recordHealthCheck.html` / `.css`. |
| Change **provenance rendering / permission gate** | `RecordHealthCheckProvenance`, `RecordHealthCheckEngine.applyDetailProvenance`, `RecordHealthCheckAccess`. |
| Change **run orchestration / concurrency** | `healthCheckRunner.js` (run queue, tokens, 5-cap). |
| Change **framework logging** | `RecordHealthCheckLogger` (`[RHC]` debug-log facade). |

### Known structural debt (do not add to it)
- **D1: duplicated validation:** `ConfigService` and `MetadataValidator` both implement
  `validateApplicability / validateFormulaRule / validateQueryRule / validateApexRule /
  validateDualSoqlRule`. The standing plan is to extract one
  `RecordHealthCheckRuleValidator`. **Never add a third copy.**
- **D2/D3: comparator duplication:** ✅ closed (2026-06-20): both evaluators use
  `RecordHealthCheckComparatorEngine`; do not reintroduce private comparator methods.
- **Refactor hotspots (size):** `MetadataValidator` (1,138), `Engine` (975),
  `ConfigService` (893), and the test `RecordHealthCheckCoverageTest` (3,340). See the
  backlog for the split plan.

## 7. Examples by Check Type
| Check Type (Setup label) | Example doc |
|------------|-------------|
| Check fields on this record | [`examples/index.md#example-catalog`](../examples/index.md#example-catalog) |
| Check records with a query | [`examples/index.md#example-catalog`](../examples/index.md#example-catalog) |
| Check records with a query (aggregates) | [`examples/index.md (aggregate reference)`](../examples/index.md#pattern-reference-aggregates) |
| Compare two queries | [`examples/index.md#example-catalog`](../examples/index.md#example-catalog) |
| Use custom Apex | [`examples/index.md#example-catalog`](../examples/index.md#example-catalog) · [`plugin-reference`](../apex/plugin-reference.md) |
| Applicability & dependencies | [`Configuration Guide 10`](../guides/configuration-guide.md#10-applicability-and-dependencies) |

## Related
| Doc | Role |
|-----|------|
| [`record-health-check-design-spec.md`](record-health-check-design-spec.md) | Authoritative contracts & behavior |
| [`Examples index`](../examples/index.md) | Pattern catalog and sample manifests |
