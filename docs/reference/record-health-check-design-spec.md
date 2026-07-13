# Record Health Check Design Specification

**Version:** 1.2.0 (2026-07-09) — aligned with `force-app/` at this commit

Record Health Check is a metadata-driven framework for evaluating Salesforce records from a Lightning record page. Check Sets and Rules live in Custom Metadata Types (CMTs). Apex validates and evaluates those Rules. A Lightning Web Component (LWC) orchestrates the run and displays results.

The framework is **read-only**. It does not block saves or mutate record data. Runtime outcomes live in LWC state and `[RHC]` debug logs only; nothing is persisted (see [14](#14-logging-and-observability)).

For Setup walkthroughs and field tables, see [Getting Started](../installation/getting-started.md) and the [Configuration Guide](../guides/configuration-guide.md). This document is the formal contract: runtime layout, evaluators, reason codes, and integration boundaries.

> [!NOTE]
> **June 2026 UI refresh:** Formal LWC contracts are in [15](#15-lwc-behavior) below.

## Related guides

| Goal | Start here |
| ---- | ---------- |
| Configure checks in Setup | [Getting Started](../installation/getting-started.md) → [Configuration Guide](../guides/configuration-guide.md) |
| Review runtime layout and contracts | Sections 1-3, 9-15, and the field reference in Sections 4-5 |
| Navigate source code | [Architecture Map](architecture-map.md) |
| Copying working patterns | [Examples index](../examples/index.md) |

Terminology is consistent across all documents:

- **Check Set**: one `Record_Health_Check_Set__mdt` record; controls a component instance.
- **Rule**: one `Record_Health_Check_Rule__mdt` record; one evaluable check.
- **Evaluator**: the Apex code path for a Rule (`Formula`, `Query`, `CompareTwoQueries`, or `Apex`).
- **Status**: the outcome of one Rule (`PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`).

## 1. Goals

- Define record health checks in metadata without changing component code.
- Support formula, SOQL, two-query comparison, and custom Apex evaluation patterns.
- Return clear statuses for pass, fail, skipped, unable-to-evaluate, and unexpected errors.
- Enforce sharing, CRUD, field access, SOQL safety, and row limits.
- Keep the user experience predictable on record pages.
- Support programmatic single-check evaluation from Apex (including custom automation invoked from Flow, batch, or triggers).
- Keep configuration explicit in metadata and contracts reviewable in one place.

## 2. Non-Goals

- Blocking record saves.
- Replacing validation rules, duplicate rules, or flow automation.
- Translating labels and messages automatically.

**Out of scope today (with nuance):**

- **Full result history on the record page.** The LWC does not show past runs; nothing is persisted (see [14](#14-logging-and-observability)).
- **Background health monitoring as a product feature.** There is no built-in scheduler and no packaged Flow invocable. Individual checks **can** be invoked via `RecordHealthCheck.run` from Apex: including a **custom** invocable action built for Flow, scheduled flows, batch/queueable jobs, or triggers. Each call is one Rule on one record, with governor limits per invocation.

## 3. Runtime Architecture

| Layer | Responsibility |
| ----- | -------------- |
| Custom Metadata | Stores Check Sets and Rules. |
| `RecordHealthCheckConstants` | Single source of truth for valid-value sets and framework caps (25 checks, 2000 rows). |
| Apex Controller | Exposes definition loading and single-check evaluation to LWC. |
| `RecordHealthCheck` façade | One-line Apex entry point for single-check runs outside the record page; no packaged Flow invocable. |
| Config Service | Loads metadata and validates Check Set and Rule configuration. |
| Engine | Loads the current record, checks applicability and dependencies, routes to evaluators, and normalizes results. |
| Evaluators | Execute Formula, Query, CompareTwoQueries, or Apex checks. |
| `RecordHealthCheckSoqlTemplate` | Depth-0-aware SOQL normalizer (`WITH USER_MODE`, row cap, keyword rejection). Used by single-query evaluator, dual-query evaluator, and engine applicability SOQL. |
| `RecordHealthCheckComparisonEngine` | Shared single value, multi-row, list, and empty-value operators for the SOQL evaluators; also formats `actualValue` / `expectedValue` for the UI. |
| `RecordHealthCheckValueResolver` | Shared single value/list extraction, query-exception classification, typed equality and ordered comparison. |
| Logger | Central logging sink (`RecordHealthCheckLogger`): all framework log lines flow here with `runId` correlation and running-user attribution. |
| LWC | Loads definitions, orchestrates check runs, respects dependencies, and renders results. |

Primary flow:

1. LWC calls `RecordHealthCheckController.getCheckDefinitions(configName, recordId)` using its selected `checkSetName` as the Apex `configName` parameter.
2. Apex loads one active Check Set by `DeveloperName`.
3. Apex confirms the current record object matches `ObjectApiName__c`.
4. Apex returns ordered active Rule definitions.
5. LWC starts the run according to the Check Set trigger mode.
6. LWC calls `evaluateCheck` for each Rule through a five-request worker pool.
7. Apex validates, evaluates dependencies, and evaluates each Rule.
8. LWC reveals results in Check Set order.

**Deployment surfaces:**

| Surface | Entry point | Notes |
| ------- | ----------- | ----- |
| Lightning record page | LWC `recordHealthCheck` | Primary UX: requires `recordId` and `checkSetName`. Exposed on `lightning__RecordPage` only. |
| Apex (any context) | `RecordHealthCheck.run(configName, checkDeveloperName, recordId)` | One Rule per call; catchable failures return result statuses. An optional overload adds a `runId` for log correlation. |

## 4. Check Set Model (`Record_Health_Check_Set__mdt`)

A Check Set defines one group of Rules for one component instance on one object.

> [!NOTE]
> Field reference (Setup labels, API names, picklist values): [Check Set fields](../metadata/check-set.md).

### 4.1 Framework limits (not configurable)

| Limit | Value | Behavior |
| ----- | ----- | -------- |
| Maximum active Rules per Check Set in one run | 25 | First 25 by `EvaluationOrder__c` ascending, then `DeveloperName` ascending. `checksOmittedByLimit` is true when more active Rules exist. The LWC badge shows **First 25 of N** using `totalAvailableCheckCount`. |
| Definition reload | Per component load or `recordId` change | `getCheckDefinitions` and `getCheckSetAvailabilityForRecord` are **not** cacheable. Metadata edits and Check Set activation appear on the next component load. After `connectedCallback`, a change to `recordId` also reloads definitions. A full page refresh reloads record field data as well. |
| Concurrent evaluations | Up to **5 in flight** when `StopOnSystemError__c` is false | The LWC queues all eligible checks (up to 25) but caps concurrent `evaluateCheck` Apex calls at `MAX_CONCURRENT_EVALUATIONS` (5); additional checks wait in a client-side queue. Display order remains priority-ordered via a drain buffer. When `StopOnSystemError__c` is true, checks run **sequentially** (one Apex call at a time). |
| Run isolation | Per run | LWC increments `_runToken` on each run so stale in-flight results from a prior run are discarded. |

## 5. Rule Model (`Record_Health_Check_Rule__mdt`)

A Rule defines one check inside a Check Set.

> [!NOTE]
> Field reference (Setup labels, API names, per-method fields): [Rule fields](../metadata/rule-fields.md).

### 5.1 Dependencies

Dependency contract:

- Prerequisite must be active and in the same Check Set.
- Prerequisite must have a strictly lower `EvaluationOrder__c` (validated by `RecordHealthCheckMetadataValidator`).
- Dependent Rule runs only when prerequisite returns `PASS`.
- If prerequisite is missing, inactive, fails, errors, is skipped, or cannot be evaluated, dependent is `SKIPPED` with `DEPENDENCY_NOT_PASSED`.
- Cycles return `CIRCULAR_DEPENDENCY` with status `UNABLE_TO_EVALUATE` on both the LWC (client pre-seed, no Apex call) and direct Apex evaluation.
- Enforced **both** client-side (LWC, before each Apex call) and server-side (`RecordHealthCheckEngine`, for direct Apex/API callers). Server-side evaluation re-runs the prerequisite, which can duplicate work when the LWC already evaluated it.
- If prerequisite is omitted from the run because of the 25-check cap, dependent is `SKIPPED` with `DEPENDENCY_NOT_IN_RUN`.

### 5.2 Applicability (pre-evaluation gate)

Applicability is evaluated before the Rule evaluator. If false, the Rule returns `SKIPPED` with `APPLICABILITY_NOT_MET`. If it cannot be evaluated safely, the Rule returns `UNABLE_TO_EVALUATE`.

## 6. Check Types

Setup field: **Check Type** (`EvaluationType__c`). Subsections below use API values; Setup picklist labels are in parentheses.

### Check fields on this record (`Formula`)

Evaluates `PassConditionFormula__c` against the loaded record. Formula must return Boolean.

| Formula result | Status |
| -------------- | ------ |
| `true` | `PASS` |
| `false` | `FAIL` |
| `null` (for example, null relationship traversal) | `UNABLE_TO_EVALUATE` |
| Non-boolean result | `UNABLE_TO_EVALUATE` |
| Formula error or inaccessible field | `UNABLE_TO_EVALUATE` |

Operands in `PassConditionFormula__c` may be **calculated fields** (formula, roll-up) at any depth — field planning expands the full dependency chain so FormulaEval can regenerate each value from the loaded record.

**Optional Found / Expected display** (`DisplayFoundFormula__c`, `DisplayExpectedFormula__c`): when set, each is evaluated as a single value (via `resolveFormulaSingleValue`, honoring `FormulaResultType__c`) and populates `actualValue` / `expectedValue` for the row, formatted like Query checks. They are **display-only** — pass/fail stays decided by the Boolean `PassConditionFormula__c`, the two sides are not compared to each other, and an unresolvable display formula falls back to the default (a `Passes when` line echoing the unquoted pass/fail formula) without changing status. They get the same calculated-field dependency expansion as `PassConditionFormula__c`.

Uses Salesforce FormulaEval API (`Formula.builder()`). Requires API v63.0+ (Spring '25). Salesforce platform limit: **100 FormulaEval calls per Apex transaction**. The framework tracks calls for the whole transaction and throws `FORMULA_EVAL_LIMIT` when the count reaches **95** (a 5-call safety margin). A single Rule can consume multiple FormulaEval calls (formula body, applicability, merge-field resolution). Flow or batch jobs that evaluate many checks in one transaction share one budget.

### Check records with a query (`Query`)

Runs `SourceQuery__c` and compares the extracted result to a static value, formula value, query value, empty-value blank check, or list.

single value aggregate SOQL is supported for `OneResult`. Supported functions: `COUNT`, `COUNT_DISTINCT`, `SUM`, `AVG`, `MIN`, `MAX`. Alias aggregate expressions and reference the alias from `SourceQueryField__c` or `ComparisonQueryField__c`.

| `QueryResultHandling__c` | Behavior |
| ---------------------------- | -------- |
| `OneResult` | Expects one row or one aggregate result. |
| `AnyRowPasses` | Passes when any primary row matches. |
| `AllRowsPass` | Passes when every primary row matches. |
| `CompareAsLists` | Full result treated as a list for list operators. |

**List membership exception (`ListContainsAny` / `ListDoesNotContainAny`):** the primary single value comes from `FindInListFormula__c` (a formula on the record resolving to the value to test), and the comparison list comes from `ComparisonQuery__c` / `ComparisonQueryField__c`. `SourceQuery__c` is not used, and `PassConditionFormula__c` is never read for Query checks. A blank `FindInListFormula__c` yields `INVALID_FORMULA`.

### Compare two queries (`CompareTwoQueries`)

Runs `SourceQuery__c` and `ComparisonQuery__c`.

| Mode | operators |
| ---- | ----------- |
| `OneResult` | single-value operators (`Equals`, `GreaterThan`, `Contains`, and so on). |
| `CompareAsLists` | `ListsOverlap`, `ListContainsAll`, `ExactListMatch`. |

### Use custom Apex (`Apex`)

Instantiates `ApexClass__c`, requires `RecordHealthCheckRule`, passes `RecordHealthCheckContext`. Use custom Apex may return `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`. Any other status string is rejected with `APEX_EVALUATOR_ERROR`. Determinate Apex results (`PASS` / `FAIL`) must set both `actualValue` and `expectedValue`; missing Found/Expected values are rejected with `APEX_EVALUATOR_ERROR`. Only `FAIL` is post-processed for metadata severity and failure message.

**Plugin contract:** Implementations must use `with sharing`, enforce CRUD/FLS on
their own queries, avoid unbounded DML/callouts, and return only a documented
status. `context.record` contains Id plus fields the engine discovered for the
configured formula/query/message; it is not a fully populated record. Parameter
JSON must be an object and should be treated as a versioned, bounded input. The
current public interface supports same-namespace/source deployments; a managed
package intended for subscriber implementations would require a deliberately
versioned `global` contract.

**Shipped example:** `AccountHasRecentActivityCheck` checks closed Tasks and
Events in a look-back window. `daysBack` is bounded to 1-3650 and defaults to 30
when missing, malformed, or outside the range.

## 7. Operators (`ComparisonOperator__c`)

Setup label: **Operator**. API values below; Setup picklist labels differ (for example `Equals` → **Equals**, `Contains` → **Contains text**, `IsBlank` → **Is empty**).

| Operator (API) | Meaning |
| ---------- | ------- |
| `Equals` | Primary equals comparison value. |
| `NotEquals` | Primary does not equal comparison value. |
| `GreaterThan` | Primary is greater than comparison value. |
| `GreaterThanOrEqual` | Primary is greater than or equal to comparison value. |
| `LessThan` | Primary is less than comparison value. |
| `LessThanOrEqual` | Primary is less than or equal to comparison value. |
| `Contains` | Primary text contains comparison text (**case-sensitive**). |
| `DoesNotContain` | Primary text does not contain comparison text (**case-sensitive**). |
| `IsBlank` | Primary value is blank. |
| `IsNotBlank` | Primary value is not blank. |
| `ListContainsAny` | Comparison list contains the primary single value. |
| `ListDoesNotContainAny` | Comparison list does not contain the primary single value. |
| `ListsOverlap` | Two lists share at least one value (case-insensitive). |
| `ListContainsAll` | Comparison list contains every value from the primary list (case-insensitive). |
| `ExactListMatch` | Two lists contain the same values and duplicate counts (case-insensitive). |

Ordered comparisons try `Decimal`, then `DateTime`, then `Date`. Incompatible types return `INCOMPATIBLE_COMPARISON_TYPES` rather than silent string sorting.

**Case sensitivity:** `Contains` and `DoesNotContain` are case-sensitive. `Equals` / `NotEquals` use typed comparison when possible; otherwise they compare string forms case-sensitively. List membership and list-mode overlap operators (`ListContainsAny`, `ListDoesNotContainAny`, `ListsOverlap`, `ListContainsAll`, `ExactListMatch`) compare case-insensitively.

**Display formatting:** On a determinate `PASS` or `FAIL`, Query and CompareTwoQueries evaluators populate `actualValue` and `expectedValue` on the result using `RecordHealthCheckComparisonEngine` helpers (`operatorLabel`, `formatValue`, `formatList`, `describeExpected`). `formatValue` wraps **every** non-blank single value in double quotes (text, number, Boolean, date/time) so mixed-type comparisons read uniformly (`"1"` beside `at least "2"` instead of bare `1` beside `"2"`), and humanizes the value first: numbers gain thousands separators (`"50,000"`; a trailing `.0` is dropped), Booleans read `"Yes"` / `"No"`, dates/datetimes render in the running user's locale and time zone, and semicolon-delimited multi-select values render comma-separated (`"Hot, Warm, Cold"`). Pure `Date` values are formatted through the `Date` branch before `Datetime` so orgs where Apex type checks overlap do not mis-render dates as datetimes. Typed values are converted directly; the same shapes arriving as metadata operand strings (the Expected side) are matched textually so both sides humanize identically. `operatorLabel` returns verb phrases for the expected side: e.g. `to equal "Technology"`, `at least "50,000"`, `to be one of ["North", "South"]`. Null/blank values render as `(blank)`; empty lists as `(none)`. List previews cap at 10 values with a `(N total)` suffix when truncated. `IsBlank` / `IsNotBlank` show the comparison operator phrase only (no operand). Formula evaluators route `PassConditionFormula__c` through `formatValue` for `expectedValue` (e.g. `"NOT(ISBLANK(BillingCity))"`). The LWC renders these as labelled **Found** / **Expected** chips per Check Set **Found/Expected Display** (`FoundExpectedDisplay__c`; see [9](#comparison-display-contract) and [15](#15-lwc-behavior)).

## 8. Applicability

| Mode | Contract |
| ---- | -------- |
| `All records` | Rule proceeds to evaluation. |
| `Formula` | `ApplicabilityFormula__c` must return Boolean `true` to proceed. |
| `SOQL` | `ApplicabilityCountQuery__c` returns a COUNT; `ApplicabilityCountOperator__c` compares it to `ApplicabilityCountThreshold__c`. |

## 9. Result Contract (`RecordHealthCheckResult`)

| Field | Purpose |
| ----- | ------- |
| `checkDeveloperName` | Rule key. |
| `label` | User-facing Rule label. |
| `priority` | Display ordering value. |
| `evaluatorType` | `Formula`, `Query`, `CompareTwoQueries`, or `Apex`. |
| `status` | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`. |
| `severity` | Populated for failed checks. |
| `reasonCode` | Machine-readable reason for skipped, unable, or error results. |
| `message` | Safe user-facing message (from `FailureMessage__c` on `FAIL`, or unable/skip text otherwise). |
| `actualValue` | What the record or query produced: the **Found** side in the UI. Populated on a determinate `PASS` or `FAIL` when the evaluator can name a primary value (Query, CompareTwoQueries, and required for Apex). Left null for Formula checks unless `DisplayFoundFormula__c` is configured (then it carries that single value). |
| `expectedValue` | The comparison operator and operand as readable text: the **Expected** side in the UI. Populated on a determinate `PASS` or `FAIL` for Query and CompareTwoQueries; for Formula checks, set to the resolved `DisplayExpectedFormula__c` single value when configured, otherwise the quoted `PassConditionFormula__c` condition text. Apex plugins must set this for `PASS` / `FAIL`. |
| `actualValueDetail` | Human-readable diagnostic details note for the **Found** side (for example `Rating → "Cold"`). Populated when the evaluator sets `actualValueSource` **and** the running user has **`Record_Health_Check_View_Details`**. Not tied to `ShowDiagnostics__c`. |
| `expectedValueDetail` | diagnostic details note for the **Expected** side. Same gating as `actualValueDetail`. |
| `actionLabel` | Read-only remediation link label from `ActionLabel__c`; defaults to `Fix this` when a safe URL exists without a label. Populated only on `FAIL`. |
| `actionUrl` | Resolved and sanitized remediation URL from `ActionUrl__c`. Supports merge tokens. Only same-org relative paths and `https://` URLs are allowed; unsafe or over-2000-character resolved URLs are dropped. Populated only on `FAIL`. |
| `fixInstructions` | Optional guidance from `FixMessage__c`, with merge tokens resolved. Populated only on `FAIL`; may render even when `actionUrl` is dropped. |
| `detailMessage` | Diagnostic detail (server-side; not `@AuraEnabled`). |
| `adminDetailMessage` | Populated only when `ShowDiagnostics__c` is on **and** the user has **`Record_Health_Check_View_Details`** (permission set `Record_Health_Check_Admin`). See [Comparison visibility model and permission tiers](#comparison-visibility-model-and-permission-tiers). |
| `durationMs` | Evaluator execution time; excludes configuration, dependencies, base-record loading, applicability, and event delivery. |

Evaluators populate internal `RecordHealthCheckValueSource.Detail` on `actualValueSource` / `expectedValueSource` (not `@AuraEnabled`). `RecordHealthCheckEngine.applyValueSourceDetail` renders them into the two `*Detail` strings and gates on `RecordHealthCheckAccess.canViewDetails()`.

### Comparison display contract

| Topic | Contract |
| ----- | -------- |
| Value metadata | Found/Expected values are computed at evaluation time from comparison operator, operand, formulas, and query results. Formula Rules may provide display-only single-value formulas (`DisplayFoundFormula__c`, `DisplayExpectedFormula__c`). Multi-row `Every record must pass` Query Rules may override the summary wording with `DisplayFoundText__c` and `DisplayExpectedText__c`. |
| Display policy metadata | Check Set **Found/Expected Display** (`FoundExpectedDisplay__c`): **On demand** (`OnDemand`, default), **Failed checks only** (`FailuresOnly`), or **Show on every check** (`AllRows`). Returned to the LWC as `comparisonDisplay` on the definition response. |
| UI visibility (values) | Governed by **Found/Expected Display** and check outcome. **Failures:** Found/Expected inline in every mode when captured. **Passes:** inline only with **Show on every check** (`AllRows`); otherwise behind the expander with **On demand** (`OnDemand`) or hidden with **Failed checks only** (`FailuresOnly`). |
| UI visibility (diagnostic details) | diagnostic details does **not** render on the card. Permission-gated `actualValueDetail` / `expectedValueDetail` strings appear only in the F12 browser console diagnostics, which the LWC emits only when `ShowDiagnostics__c` is on. |
| UI layout | Each value side renders as a **labelled chip**: uppercase caption (`Found` / `Expected`) beside the value in a monospace chip. Values **stack vertically**. |
| Long value clamp | Each value chip clamps to **two lines**; a long formula or list therefore cannot dominate the card. A quiet **`...`** / **`less`** toggle beneath the chip reveals or re-clamps the full text (screen readers still hear “Show more” / “Show less” via `aria-label`). The toggle appears only on chips that actually overflow — the LWC measures each chip in `renderedCallback` and re-measures as checks resolve — so short values show no control. `aria-expanded` reflects the toggle state. |
| Disclosure caret | Shown when values would be revealed on expand. Hidden on passing checks when mode is `FailuresOnly`. `aria-expanded` on the caret; label toggles **Show comparison detail** / **Hide comparison detail**. |
| Screen readers | Values enter `aria-label` when visible (inline or expanded). diagnostic details is excluded from the card's accessible name because it is console-only. |
| Formula checks | By default no separable single-value "found" value: `expectedValue` carries the unquoted pass/fail formula and `expectedValueLabel` is `Passes when`. This `Passes when` line is **Advanced-tier** — the engine clears it for users without `Record_Health_Check_View_Details`, so a business user sees the failure message only (see [Comparison visibility model and permission tiers](#comparison-visibility-model-and-permission-tiers)). Optional display-only `DisplayFoundFormula__c` / `DisplayExpectedFormula__c` scalars populate the two sides (under the standard `Found` / `Expected` keys, ungated) for balance/comparison checks; pass/fail stays decided solely by the Boolean `PassConditionFormula__c`, and an unresolvable display formula falls back to the default. |
| Skipped / unable / error | Neither value nor diagnostic details is shown: these outcomes have no determinate comparison. |
| Programmatic API | `RecordHealthCheck.run` returns the same fields on `RecordHealthCheckResult`. |

### Remediation display contract

| Topic | Contract |
| ----- | -------- |
| Source metadata | `FixMessage__c`, `ActionLabel__c`, and `ActionUrl__c` on the Rule. |
| Status gating | Remediation fields render only on `FAIL` rows. `PASS`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` suppress them. |
| URL safety | `ActionUrl__c` is merge-token resolved, URL-encoded, and sanitized. Same-org relative paths and `https://` URLs are allowed; unsafe schemes, protocol-relative forms, and resolved URLs over 2000 characters are dropped. |
| Partial rendering | If the URL is dropped, `FixMessage__c` may still render so the row keeps useful guidance. |
| Behavior | Links are advisory/read-only. Record Health Check does not update records. |

### comparison diagnostic details

| Topic | Contract |
| ----- | -------- |
| Purpose | One note per side explaining *where* a value came from and its raw form before display coercion — for example `NumberOfEmployees → null (blank treated as 0)` or `COUNT() of Contacts = 0 rows`. |
| Internal shape | `RecordHealthCheckValueSource.Detail { sourceLabel, rawValueLabel, coercionLabel }` on `actualValueSource` / `expectedValueSource`. |
| Render format | `RecordHealthCheckValueSource.render`: `source → raw` with optional `(coercion)` suffix. Returns null when empty so the public string stays null. |
| Permission | **`Record_Health_Check_View_Details`** — the single Advanced-tier grant. Included in `Record_Health_Check_Admin`. Apex *populates* the `*ValueDetail` strings independent of `ShowDiagnostics__c`; the LWC only *emits* them to the console when `ShowDiagnostics__c` is on. |
| Evaluator duty | Query, CompareTwoQueries, Formula (display formulas), and Apex plugins populate diagnostic details when they can name a source. Omission is valid when there is nothing useful to say. |

### Comparison visibility model and permission tiers

**Status:** Implemented. This subsection is the canonical description of the
model; the individual as-built statements elsewhere in the spec have been
reconciled to match.

**Principle — separate _what_ from _how_.** Each row can surface up to five
kinds of evidence, split into two intents:

| Element | Meaning | Intent |
| ------- | ------- | ------ |
| **Found** (`actualValue`) | The value the record actually produced. | Business evidence |
| **Expected** (`expectedValue`) | The requirement in **business-legible** terms — a humanized comparison operator phrase (`to equal "Technology"`) or a display-formula single value. | Business evidence |
| **Passes when** | The **raw** pass/fail condition (formula / SOQL logic, field API names). | Technical explanation |
| **diagnostic details** (`*ValueDetail`) | Which source field/row produced a value (`source → raw (coercion)`). | Technical explanation |
| **Troubleshooting** (`adminDetailMessage`, diagnostics-meta) | Engine internals: reason codes, timings, evaluator type, raw exceptions. | Diagnostic |

A **raw formula is never relabeled "Expected."** It is always **Passes when**, and
Passes when is always the Advanced tier. Query / CompareTwoQueries already
produce a business-legible Expected, so their Expected side is business evidence;
a bare Formula check has no business Expected unless the admin authors one.

**Two visibility tiers** (collapsed from three — "power user" and "debug" are one
audience):

| Element | Business (no permission) | Advanced (`Record_Health_Check_View_Details`) |
| ------- | ------------------------ | --------------------------------------------- |
| Found (if present) | shown | shown |
| Expected — business (if present) | shown | shown |
| Message / fix / action | shown | shown |
| **Passes when** (raw condition) | hidden | shown |
| **diagnostic details** | hidden | console diagnostics only, **and only when `ShowDiagnostics__c` is on** for the Check Set — never on the card |
| **Troubleshooting** internals | hidden | shown **only when `ShowDiagnostics__c` is on** for the Check Set |

**Permission collapse.** `Record_Health_Check_Debug` is retired; its capability
folds into a single power-user permission, `Record_Health_Check_View_Details`.

- `RecordHealthCheckAccess.canViewDebugDetails()` and `canViewDetails()` both
  resolve to `View_Details` — a strict ladder (_none → advanced_), never a combo.
- `ShowDiagnostics__c` on the Check Set is **retained** as the per-set switch that
  decides **when** the troubleshooting subset (raw exceptions / codes / timings)
  is computed and shown. Permission = **who**; `ShowDiagnostics__c` = **where/when**.
  It is not a second permission.
- Migration: fold whatever the retired `Debug` permission granted into the
  `Record_Health_Check_Admin` permission set so no one loses access.
  `Record_Health_Check_Configure` is untouched.

**Formula-check authoring contract.** A Formula check shows business Found/Expected
chips only when `DisplayFoundFormula__c` / `DisplayExpectedFormula__c` are authored.
Otherwise a business user sees the **failure message only**
(`FailureMessage__c` — the business explanation for that check), and the raw
`PassConditionFormula__c` appears as **Passes when** for Advanced users. This is
intentional, not a regression: display formulas are how an admin gives business
users chips on a Formula check.

**Behavior as of v1.2.0:** The **Passes when** line is Advanced-tier only. Business users see the failure message and any display-formula Found/Expected chips; diagnostic details renders in browser console diagnostics only (and only with `ShowDiagnostics__c` on), not on the card.

**Implementation (shipped in v1.2.0).**

- Apex `RecordHealthCheckAccess`: both getters resolve to `Record_Health_Check_View_Details`.
- Apex `RecordHealthCheckEngine.applyPassesWhenEntitlement` and `applyValueSourceDetail` gate Advanced-tier strings.
- LWC renders Found/Expected chips per `FoundExpectedDisplay__c`; diagnostic details is console-only.
- Metadata: `Record_Health_Check_Debug` retired; `Record_Health_Check_View_Details` and `Record_Health_Check_Configure` ship in `Record_Health_Check_Admin`.

**Reconciled elsewhere:** §9 result-contract gating notes for `adminDetailMessage`
(now `Record_Health_Check_View_Details`); the Comparison display contract
**Formula checks** row; the comparison diagnostic details **Permission** row; §14
Client-side diagnostics; §15 LWC **Rows** and **Component design property**;
behavior IDs **B14**, **B18**; and the §17 custom-permission list.

### Result statuses

| Status | Contract |
| ------ | -------- |
| `PASS` | Rule evaluated successfully and condition passed. |
| `FAIL` | Rule evaluated successfully and condition failed. |
| `SKIPPED` | Rule did not apply, dependency did not pass, or empty-result behavior chose skip. |
| `UNABLE_TO_EVALUATE` | Rule could not safely evaluate (metadata, data, SOQL, formula, access, or limits). |
| `ERROR` | Unexpected exception after normal validation paths. |

### Definition response (`RecordHealthCheckDefinitionResponse`)

| Field | Purpose |
| ----- | ------- |
| `displayTitle`, `displayDescription` | Header presentation from Check Set. `displayTitle` prefers `CardTitle__c`, then `MasterLabel`, then `DeveloperName`. |
| `triggerMode`, `revealMode` | Run and reveal behavior. |
| `successDisplayMode`, `skippedDisplayMode` | Row visibility rules. |
| `comparisonDisplay` | `OnDemand`, `FailuresOnly`, or `AllRows` from `FoundExpectedDisplay__c`. |
| `stopOnFirstError`, `showDiagnostics` | Run control and diagnostics. |
| `totalAvailableCheckCount` | Active Rules before the 25-check cap. |
| `checksOmittedByLimit` | True when Rules were truncated. |
| `inactiveRuleCount` | Inactive Rules on the Check Set (not run). The LWC shows `N inactive rule(s) omitted.` when this is greater than zero, pluralizing `rule` / `rules` on N. |
| `checks` | Ordered `RecordHealthCheckDefinition` list (`developerName`, `label`, `description`, `priority`, `dependsOnCheckDeveloperName`). |

## 10. Reason Codes

| Reason Code | Meaning |
| ----------- | ------- |
| `CONFIG_NOT_FOUND` | Selected Check Set DeveloperName is missing at definition load. |
| `RULE_NOT_FOUND` | Evaluate-time: Rule DeveloperName is missing on the named Check Set (or belongs to a different set). |
| `RULE_INACTIVE` | Evaluate-time: Rule exists on the Check Set but `IsActive__c` is false. |
| `CONFIG_INACTIVE` | Check Set is inactive. |
| `OBJECT_MISMATCH` | Record object does not match Check Set base object. |
| `NO_RECORD_CONTEXT` | No record Id was provided. |
| `NO_ACTIVE_CHECKS` | Check Set has no active Rules. |
| `INVALID_CONFIG` | Check Set or Rule configuration is invalid. |
| `INVALID_CHECK_TYPE` | Check Type is not recognized. |
| `INVALID_COMPARATOR` | Operator is missing, invalid, or invalid for the Rule shape. |
| `INVALID_FORMULA` | Formula is missing, malformed, or returns the wrong type. |
| `INVALID_SOQL_TEMPLATE` | SOQL is missing, malformed, or unsafe. |
| `MISSING_BIND_VALUE` | SOQL token could not be resolved from the current record. |
| `FIELD_NOT_ACCESSIBLE` | Running user cannot access a required object or field. |
| `RECORD_NOT_ACCESSIBLE` | Current record could not be loaded. |
| `MULTIPLE_ROWS_RETURNED` | A single-value check received multiple rows. |
| `NO_ROWS_RETURNED` | Empty result with `UnableToEvaluate` behavior. |
| `GOVERNOR_LIMIT_RISK` | Query result exceeded configured row safety. |
| `INCOMPATIBLE_COMPARISON_TYPES` | Ordered comparison across incompatible types. |
| `FORMULA_EVAL_LIMIT` | FormulaEval call budget exceeded in the transaction. |
| `APEX_CLASS_NOT_FOUND` | Apex class is missing or does not implement the required interface. |
| `INVALID_APEX_PARAMETERS` | Apex parameter JSON is invalid. |
| `APEX_EVALUATOR_ERROR` | Custom Apex threw unexpectedly or returned an invalid result (unsupported status or missing required Found/Expected values). |
| `APPLICABILITY_NOT_MET` | Applicability returned false or empty-result skip. |
| `DEPENDENCY_NOT_PASSED` | Prerequisite Rule did not pass. |
| `STOPPED_AFTER_ERROR` | Run stopped after a framework error. |
| `DEPENDENCY_NOT_IN_RUN` | LWC only: prerequisite Rule excluded by the 25-check cap. |
| `CIRCULAR_DEPENDENCY` | Circular `PrerequisiteRule__c` graph; all surfaces return `UNABLE_TO_EVALUATE`. |
| `CLIENT_CALL_FAILED` | LWC `evaluateCheck` Aura call threw before a result was returned. |
| `SETUP_REQUIRED` | LWC `checkSetName` is blank, but at least one active Check Set exists for this object. |
| `INACTIVE_CHECK_SETS_ONLY` | LWC `checkSetName` is blank, and only inactive Check Sets exist for this object. |
| `NO_ACTIVE_CHECK_SETS` | LWC `checkSetName` is blank, and no Check Set exists for this object yet. |
| `MISSING_REQUIRED_FIELD` | `RecordHealthCheckMetadataValidator` deployment-time validation. |
| `INVALID_DEPENDENCY` | Validator dependency graph validation. |
| `CHECK_LIMIT_EXCEEDED` | Metadata Validator only: Check Set has more than 25 active Rules; only the first 25 run. |

## 11. SOQL Safety

SOQL templates may use merge tokens on **any readable field** on the base record: standard or custom (API name, including `__c`):

```text
{!record.Id}
{!record.Name}
{!record.Parent.Name}
{!record.Customer_Tier__c}
{!record.Primary_Contact__c}
```

Safety contract:

- Token values are escaped or formatted before query execution.
- Date, DateTime, Time, Boolean, and numeric tokens are substituted without quotes; strings and Ids are quoted with `String.escapeSingleQuotes`.
- Multi-select picklist tokens in **unquoted** context on a field the engine can resolve expand semicolon-delimited values to `('A', 'B')` for INCLUDES-style queries (direct fields and relationship paths when the related record is loaded). **Quoted** tokens (`'{!record.Field}'`) substitute the raw `'A;B;C'` string. When the exact substring `'{!record.Field}'` appears inside a larger string literal (for example `Name LIKE '{!record.Name}%'`), that quoted form is replaced first: yielding `Name LIKE 'Acme%'`. A token may also appear both quoted and unquoted in one template; each form is substituted independently (multi-select picklists differ between the two forms).
- Queries run with `WITH USER_MODE` when not already present.
- Unsafe DML keywords and `FOR UPDATE` / `ALL ROWS` are rejected.
- Bare `SELECT COUNT()` is rewritten to `SELECT COUNT(Id)`.
- Non-aggregate queries receive `LIMIT maxRows + 1` when no explicit limit is present (default 2000, overridable via `MaxQueryRows__c`).
- Results exceeding the row cap are rejected with `GOVERNOR_LIMIT_RISK`.

## 12. Message Tokens

Failure and unable-to-evaluate messages may use `{!record.FieldApiName}` merge tokens. Unresolved tokens are replaced with blank text. A bad message token does not change Rule status.

**Found / Expected is separate from merge tokens.** The engine builds `actualValue` and `expectedValue` automatically for Query and CompareTwoQueries checks; Apex checks must set both fields for `PASS` / `FAIL`. These lines are not authored in metadata and do not need `{!record.Field}` tokens in `FailureMessage__c` to show what the record produced versus what the rule required, though merge tokens remain useful for narrative context (record name, owner, and so on).

## 13. Programmatic API (`RecordHealthCheck`)

For adoption beyond the record page, `RecordHealthCheck` is the supported Apex entry point. It delegates to the same engine as the LWC. Catchable evaluation failures surface as result statuses (`ERROR`, `UNABLE_TO_EVALUATE`, etc.); uncatchable Apex governor limit exceptions behave like any other Apex API.

### Apex

```apex
RecordHealthCheckResult r = RecordHealthCheck.run(
    'Account_Data_Quality',      // Check Set DeveloperName
    'Account_DQ_BillingCity',    // Rule DeveloperName
    accountId);                  // record under test
```

Optional overload:

```apex
RecordHealthCheck.run(configName, checkName, recordId, 'ticket-12345'); // custom runId
```

| Parameter | Contract |
| --------- | -------- |
| `configName` | Check Set `DeveloperName`: required; scopes the Rule server-side. |
| `checkDeveloperName` | Rule `DeveloperName`: one Rule per call. |
| `recordId` | Record under test. |
| `runId` | Optional correlation id (for example, a ticket or batch-job id) so this run's `[RHC]` log lines group with related work. When blank, the façade generates `api-<timestamp>-<random>`. |

Checks always evaluate with the **running** user's access (`WITH USER_MODE`); to evaluate as another user, run while that user is current or wrap in `System.runAs(thatUser)` in a test.

Each call logs `RUN_INVOKED` and `RUN_COMPLETE` events through `RecordHealthCheckLogger`.

### Flow (not packaged)

There is **no packaged Flow invocable**; it was descoped for governor safety. To call the engine from Flow, build a bulk-designed Apex invocable that groups records and evaluates them within transaction limits, or drive it from scheduled/batch Apex with an intentionally small scope. Do not wrap `run(...)` in a per-record loop.

### Anonymous Apex runner

`scripts/apex/runHealthCheck.apex` loads a Check Set definition and evaluates every Rule in priority order, printing a structured report to the debug log. Set `CONFIG_NAME`, `RECORD_ID`, and optionally `RUN_ID`, then run via `sf apex run --file scripts/apex/runHealthCheck.apex`.

## 14. Logging and Observability

All framework log lines flow through `RecordHealthCheckLogger`: the engine, controller, and evaluators never call `System.debug` directly. The sink can be swapped in one place (for example, Nebula Logger) without touching other classes.

### Structured debug log format

```text
[RHC] <LEVEL> <EVENT> | runId=… user=… config=… check=… record=… <sorted key=value fields>
```

| Concept | Behavior |
| ------- | -------- |
| `runId` | Correlation id: one id is reused for an Automatic definition request and its automatic run; manual reruns receive a fresh id. Callers may supply one to `RecordHealthCheck.run`. Control characters and excessive lengths are removed by the logger. |
| `user` | `UserInfo.getUserId()`: authoritative, not client-supplied. |
| Levels | `ERROR`, `WARN`, `INFO`, `DEBUG` (maps to `FINE` in `System.debug`). |

### Client-side diagnostics (Show Troubleshooting Details)

Requires **both** `ShowDiagnostics__c` on the Check Set **and** `Record_Health_Check_View_Details` on the running user (included in permission set `Record_Health_Check_Admin`). See [Show Troubleshooting Details guide](../guides/show-diagnostics.md).

When enabled, after a run completes the LWC:

- Renders a compact per-row diagnostics-meta line under each result.
- Shows inline **Troubleshooting detail** (`adminDetailMessage`) on errors.
- Shows footnote: **Check console (F12) for diagnostics.**
- Logs to the browser console: `[RHC] Health Check run …` with a one-line outcome summary, copy-friendly run metadata, a `console.table` of per-check results, and a nested **Source detail** group when any `actualValueDetail` / `expectedValueDetail` strings are present.

## 15. LWC Behavior

The `recordHealthCheck` bundle (`recordHealthCheck.js`, `healthCheckRunner.js`,
`healthCheckModel.js`, `healthCheckPresentation.js`) orchestrates definition load,
run lifecycle, and display. Presentation logic that LWC templates cannot express
lives in `healthCheckPresentation.js`.

### Lifecycle and run control

- Loads definitions once when inserted (deferred one macrotask so Automatic does not fire during initial mount).
- Reloads definitions when `recordId` or `checkSetName` changes after the initial connect. On reload, invalidates any in-flight run (`_runToken` bump, run-state reset) so stale results cannot bleed across records (H1).
- Runs automatically for `Automatic` Check Sets; shows **Run** for `Manual`.
- Shows **Rerun** after any run completes (including Automatic). While a run is in flight the action button stays visible, is **disabled**, keeps **Run** on the first run or **Rerun** on later runs (see `hasCompletedRunOnce` below), and shows a **spinner** in place of the play glyph (it does not disappear or relabel to "Running…").
- Runs at most **5** `evaluateCheck` calls concurrently when `StopOnSystemError__c` is false; runs **sequentially** when `StopOnSystemError__c` is true.
- Reveals rows in priority order via a drain buffer.
- Enforces `PrerequisiteRule__c` client-side before calling Apex.
- Pre-seeds circular dependencies as `UNABLE_TO_EVALUATE` / `CIRCULAR_DEPENDENCY` without calling Apex.
- Discards stale results from prior runs via `_runToken`.
- Stores runtime state only in the component instance.

**Run-state flags (regression guard)**

| Flag | Set `true` when | Cleared when | Drives |
| ---- | --------------- | ------------ | ------ |
| `runComplete` | All checks in the current run have been revealed | A new run starts (`healthCheckRunner.run`) or definitions reload | Summary bar visibility, pre-run hint, debug diagnostics, `showRerunButton` |
| `hasCompletedRunOnce` | A run finishes (including zero-check sets) | Definitions reload (`recordId` / `checkSetName` change) | Action button **visible label** (`Run` vs `Rerun`) and busy `title` / `aria-label` while a run is in flight |

`runComplete` clears at the start of every run so the summary bar hides during evaluation. **`hasCompletedRunOnce` must not clear when a re-run starts**: otherwise the button relabels to **Run** + spinner instead of **Rerun** + spinner.

**Not supported today:** automatic re-run on record save.

### Card chrome and header

- Renders as a custom card (`rhc-card`) with a visible border and elevation: not `slds-card`: so it reads as a contained card on white Lightning tabs.
- **Rounded corners** match standard Lightning cards: `border-radius: var(--lwc-borderRadiusMedium, 0.25rem)`. The card uses **`overflow: visible`** so row and summary tooltips are **not clipped** at the card boundary (especially the last row's below-row bubble). Bottom corner rounding is applied to **`.rhc-body > :last-child`** so the outline still matches standard Lightning related lists and record panels without trapping popovers.
- **No header icon**: the card does not render a header icon. There is no icon field on the Check Set; titles are text-only.
- Header layout: **title** and **action button** share one row (vertically centered); **Card Subtitle** spans the full width on the row beneath (eliminates a tall empty column beside a short button).
- Shows a **First 25 of N shown** badge when `checksOmittedByLimit` is true, where N is `totalAvailableCheckCount`.
- When `inactiveRuleCount` is greater than zero, shows a quiet notice: `N inactive rules omitted.`
- Blank-setup banners use title **Health Check Needs Setup** and primary text **Record Health Check is not ready on this page yet.**, plus a short admin hint by reason code (`SETUP_REQUIRED`, `INACTIVE_CHECK_SETS_ONLY`, `NO_ACTIVE_CHECK_SETS`, and other setup/load codes).
- Unexpected framework failures render as red **System Error**, separate from gray **Unable to Check**.
- When Passed/Skipped display is Hide and every row is filtered out, shows a short notice such as `All checks passed. Details are hidden.` so the card does not look empty.

### Row status accent

- Each resolved row carries a **3px-wide status accent** on the left edge, coloured by outcome (pass / fail / warning / info / skipped / unable).
- The accent is a dedicated **`.rhc-row__accent` element** (`position: absolute; left: 0; top: 0; bottom: 0; width: 3px`) so it spans the full row height flush to the card's left inner edge and renders reliably in LWC shadow DOM. Do **not** use `border-left`, inset `box-shadow`, or row `::before` for the accent: tooltip nubbins on described rows use `::before`.

### Action button

Native SLDS neutral button (`.rhc-action-button`, `slds-button_neutral`): **not** `lightning-button` (SVG play icon was unreliable in the target context).

**Visible label (regression guard)**

- The visible label is **only** `Run` (before the first completed run) or `Rerun` (after any run has completed). **Do not** relabel to `Running…`, `Running`, or any other in-flight text: that widened the button and left empty padding on `Run` / `Rerun`.
- The label **does not change when a run starts**: first run stays **Run** + spinner; subsequent runs stay **Rerun** + spinner (`hasCompletedRunOnce`: not `runComplete`, which clears during the run).
- Check count lives in `title` and in `aria-label` while busy (e.g. `Run 18 Checks`, `Running 18 Checks`, `Re-running 18 Checks`): not in the visible label.

**In-flight / busy state**

- Button **stays visible** and **disabled** for the whole run (Manual and Automatic).
- **CSS spinner** (`.rhc-action-button__spinner`) replaces the play glyph (`.rhc-action-button__play`) inside a fixed **`.rhc-action-button__glyph`** slot (`0.75rem`); do not show both at once.
- Set **`aria-busy="true"`** while a run is in flight; `aria-label` carries the busy phrase for screen readers.
- **Do not** hide the button during a run: that was the pre-June-2026 behavior this iteration replaced.

**Width and layout (regression guard)**

- **`min-width: 5rem`** with tighter horizontal padding: sized for **Rerun** + a fixed **0.75rem** glyph slot (`.rhc-action-button__glyph`) so `Run` and `Rerun` share the same compact footprint and the label **does not shift** when the play icon swaps to the spinner.
- **Do not** size `min-width` for a longer label such as `Running…` (the old `7rem` value).
- Fixed width prevents the card title from reflowing between one and two lines as the button state changes.

**Play glyph**

- CSS-drawn triangle (▶) after the label when idle: always renders and greys with disabled text when the button is disabled for other reasons.

### Pre-run hint

Before the first Manual run (both `OneAtATime` and `AllAtOnce`), shows one line:

> Click Run to evaluate {count phrase}.

`{count phrase}` is pluralized (`1 check` / `18 checks`) or, when `checksOmittedByLimit` is true, **the first 25 of N checks** (N = `totalAvailableCheckCount`).

### Rows

- Renders each row's `CheckDescription__c` as a hover/focus tooltip (`data-tooltip` on the `<li>`) when a description exists: **never inline**. Tooltip anchor classes are omitted when description is blank. Description is folded into `accessibleLabel` for screen readers.
- Row tooltip layout and nubbin behavior are defined in [Tooltips](#tooltips) below.
- Row status icons are **CSS-drawn** circles (`rhc-status-icon--*`): not `lightning-icon`.
- Always renders `FAIL` (Error), `Warning`, `Info`, and `UNABLE_TO_EVALUATE` outcomes as full rows: these are actionable and are never collapsed into the summary bar. Only `PASS` and `SKIPPED` outcomes can be collapsed (via `PassedChecksDisplay__c` / `SkippedChecksDisplay__c`).
- Applies `PassedChecksDisplay__c` and `SkippedChecksDisplay__c`: rows in `Hide` mode are filtered from the list even when `CardRevealMode__c` is `AllAtOnce`.
- Shows **Found** / **Expected** comparison chips per Check Set **Found/Expected Display** (`FoundExpectedDisplay__c`; see [9](#comparison-display-contract)): failed checks show values inline in every mode; passing checks show inline only with **Show on every check** (`AllRows`), otherwise behind an expander with **On demand** (`OnDemand`) or hidden with **Failed checks only** (`FailuresOnly`). Formula checks may show Expected only unless display formulas populate both sides; the raw `Passes when` line is Advanced-tier (`Record_Health_Check_View_Details`).
- diagnostic details (`actualValueDetail` / `expectedValueDetail`) does not render on the card. For viewers with **`Record_Health_Check_View_Details`**, source details appear only in the F12 browser console diagnostics.
- Shows a read-only remediation block on `FAIL` rows when Apex returns `actionUrl` and/or `fixInstructions`: the link uses `actionLabel` (defaulting to `Fix this` server-side when needed), and instructions render as quiet helper text. If URL sanitization drops the link, instructions can still render.
- Renders `FailureMessage__c` / `UnableToEvaluateMessage__c` across multiple lines: newlines authored in Setup become separate visual lines (interior blank lines preserved as spacing), folded into one sentence for the row `aria-label`.
- Shows `adminDetailMessage` **inline** (no click-to-expand), per-row diagnostics-meta, and console footnote when `ShowDiagnostics__c` is on **and** the user has `Record_Health_Check_View_Details` (see [Show Troubleshooting Details guide](../guides/show-diagnostics.md)).

### Summary bar

- After run completion, renders a single **summary bar** of per-outcome pills (`Passed`, `Failed`, `Warning`, `Info`, `Skipped`, `Unable`) when at least one bucket is non-zero.
- Each pill uses the **same CSS status icon** as rows (`rhc-status-icon--*`) for visual consistency (e.g. Unable = `?`, Skipped = `-`).
- Each pill is a hover/focus tooltip target; tooltip text is `{label}: {comma-separated rule labels}` (e.g. `2 Warnings: Website Uses HTTPS, Has at Least Two Contacts`). **Warning** pluralizes (`1 Warning` vs `2 Warnings`).
- Summary-pill tooltip layout and nubbin behavior are defined in [Tooltips](#tooltips) below.
- Replaces the removed standalone "N rules passed" / "N rules were skipped" footer notes. Rows hidden by `Hide` still contribute to their pill counts.

### Tooltips

CSS-drawn hover/focus popovers (`rhc-tooltip-anchor` + `::before` / `::after`). **Do not** switch to `lightning-helptext` or inline description text: the compact-row contract depends on this mechanism.

**Shared surface and interaction**

- Light-gray popover (`neutral-base-95`) with `border-base-3` edge, drop shadow, and `z-index: 100` (nubbin `101`) so bubbles layer above the card and adjacent page chrome.
- Trigger after a **600ms pointer dwell** (enforced in `recordHealthCheck.js`; the `rhc-tooltip-anchor--dwell` class fades the bubble in) and on **`:focus-visible`** for keyboard users. Keyboard focus keeps a **150ms** CSS dwell. Hide immediately when hover/focus leaves. `prefers-reduced-motion: reduce` skips the pointer dwell.

**Non-clipping (regression guard)**

- **Do not** set `overflow: hidden` on `.rhc-card` to "tidy" corners. That clips the last row's below-row tooltip and summary tooltips at the card edge.
- Card bottom rounding comes from **`.rhc-body > :last-child`**, not from trapping overflow on the card shell.

**Row tooltips** (`rhc-tooltip-anchor--row` on the `<li>`)

- Bubble appears **below** the row (`top: calc(100% + 0.5rem)`), pinned `left: 1rem; right: 1rem` so it spans the card width and wraps at any column width.
- **Upward nubbin** (`::before`): bordered square rotated 45°, pointing at the row. Row accent must remain a **`.rhc-row__accent` element**: not `::before` on the row.

**Summary-pill tooltips** (`.rhc-summary-pill` grid wrapper + `.rhc-tooltip-anchor--footer` on the pill `<span>`)

- Bubble appears **above** the stats bar (`bottom: 100%` on `.rhc-stats-bar`), pinned **`left: 1rem; right: 1rem`**: **same width and wrap behavior as row tooltips**.
- Pill anchor and `.rhc-summary-pill` wrapper must stay **`position: static`** so the bubble's containing block is `.rhc-stats-bar`, not the small pill. **Do not** wrap pills in `position: relative`: that squeezes `left/right` insets to pill width and produces a tall, narrow tooltip.
- **Downward nubbin** is **`.rhc-stat__nubbin`** inside **`.rhc-stat__nubbin-host`**: a **grid sibling** of the footer anchor (not an ancestor). Host is `position: relative` and pill-sized; footer anchor stays `position: static`. Nubbin sits at `bottom: calc(100% + 0.25rem)` on the host so it **meets the bubble bottom** (same 0.25rem / 0.5rem spacing as row tooltips). **Do not** place the nubbin on the pill top or detach it from the bubble.
- **Do not** center a `max-content` bubble on the pill with a very large `max-width`: that produces an unreadably wide one-line tooltip.

### Troubleshooting Details

Requires `Record_Health_Check_View_Details` plus **Show Troubleshooting Details** on the Check Set. Per-row troubleshooting lines, **Troubleshooting detail** on errors, console footnote, and `[RHC]` browser console summary after run completion. See [Troubleshooting Details](../guides/show-diagnostics.md).
- Error banner (setup/load failures) still uses `lightning-icon`.

### Component design property

| Property | Type | Purpose |
| -------- | ---- | ------- |
| `checkSetName` | String | `DeveloperName` of the `Record_Health_Check_Set__mdt` record to run. Selected in Lightning App Builder from a picklist (`apex://RecordHealthCheckSetPicklist`) scoped to the record page's object and sorted by DeveloperName; both the displayed label and the stored value are the DeveloperName (unique and stable). The picklist auto-selects the object's sole active Check Set when exactly one exists (`getDefaultValue`); with zero or several, the admin picks. Sent to Apex under the `configName` parameter. This is the **only** design-time property — the former `comparisonDisclosure` was removed. |

## 16. Validation Rules

`RecordHealthCheckMetadataValidator` (deploy-time) and `RecordHealthCheckConfigService` (runtime) validate overlapping rules. Both alias valid-value sets from `RecordHealthCheckConstants`. The validator is a CI and Anonymous Apex utility; there is no Setup UI wired to it yet.

Both validate Check Set modes, objects/icons, Rule shape and required fields,
severity/source/handling values, single COUNT applicability COUNT shape and threshold,
query output fields, plugin class/interface/JSON, row caps, and dependencies. The
deploy-time validator warns when the first-25 cap omits rules or prerequisites and
exposes structured JSON through `validateAsJson()` for CI.

Validation must catch: missing required fields, unknown modes and Check Types, invalid **`FoundExpectedDisplay__c`**, invalid Operator / **How To Interpret Query Results** combinations, invalid **If Query Finds No Records** values, invalid Apex JSON, missing or cyclic dependencies, and row safety values outside framework caps.

## 17. Deployment Contents

- Apex classes and interfaces (including `RecordHealthCheck` façade, `RecordHealthCheckLogger`, `RecordHealthCheckConstants`, `RecordHealthCheckSoqlTemplate`, `RecordHealthCheckValueResolver`, `RecordHealthCheckValueSource`)
- Lightning Web Component
- Custom Metadata Type definitions and fields
- Sample Custom Metadata records (15 Account Check Sets, 132 Rules: 10 reusable sample sets, 4 teaching example sets, and 1 Account 360 demo set)
- Layout metadata for Custom Metadata editing
- Custom permissions: `Record_Health_Check_View_Details`, `Record_Health_Check_Configure`
- Permission Sets: `Record_Health_Check_User`, `Record_Health_Check_Admin`
- Documentation and anonymous Apex runner script

Deploy via `force-app` or `manifest/package.xml`.

## 18. Default Behavior Summary

| Field | CMT default | Runtime when blank on Rule |
| ----- | ----------- | -------------------------- |
| `EmptyValueHandling__c` | `SkipRecordsWithMissingValue` | Same: blank aligns with skip-on-null for row comparisons. |
| `NoRowsResult__c` | `Skip` | Same: blank resolves to `Skip`. |
| `FoundExpectedDisplay__c` | `OnDemand` | Same: unrecognized values fall back to `OnDemand` at runtime. |

For `AnyRowPasses`, `AllRowsPass`, and `CompareAsLists`, set `NoRowsResult__c` explicitly so intent is visible in metadata.

## 19. Resolved Issues (formerly 18)

These items were previously tracked as known bugs and are **fixed** in the current codebase:

| ID | Resolution |
| -- | ---------- |
| B1 | Blank `EmptyValueHandling__c` aligns with CMT default (`SkipRecordsWithMissingValue`). |
| B2 | Server-side `PrerequisiteRule__c` gate in `RecordHealthCheckEngine` (prerequisite re-evaluation can duplicate work; see [20](#20-open-limitations-and-edge-cases)). |
| B3 | `getCheckDefinitions` is no longer cacheable. |
| B4 | `CardRunMode__c` and `CardRevealMode__c` validated at definition load in Config Service and Metadata Validator. |
| B5 | LWC `_runToken` discards stale in-flight results on rerun; `_loadDefinitions` resets run state on `recordId` change (H1). |
| B6 | `RecordHealthCheckConstants` centralizes valid-value sets and caps. |
| B7 | Applicability sub-fields validated at runtime and deploy-time. |
| B8 | `RecordHealthCheckSoqlTemplate` + `RecordHealthCheckValueResolver` extracted; all query paths (single-query, dual-query, applicability) wired. |
| B9 | Ordered comparisons use typed coercion; no string-sort fallback. |
| B10 | List membership and list-mode overlap operators are case-insensitive (`Contains` / `DoesNotContain` remain case-sensitive). |
| B11 | Named aggregate aliases supported via `getPopulatedFieldsAsMap`. |
| B12 | Documentation uses `AccountHasRecentActivityCheck`. |
| B13 | LWC Automatic concurrency capped at 5 simultaneous `evaluateCheck` calls; queue for the rest. |
| B14 | Troubleshooting details gated by `Record_Health_Check_View_Details` Custom Permission in Apex (`RecordHealthCheckAccess`); `canViewDebugDetails()` delegates to `canViewDetails()`. |
| B15 | Null `recordId` on evaluate path returns `NO_RECORD_CONTEXT`. |
| B17 | Manual mode shows pre-run guidance before the first run in **both** reveal modes (`showPreRunHint`). |
| B18 | Non-passing checks show **Found** / **Expected** labelled chips from `actualValue` / `expectedValue`; Formula checks show a **Passes when** line (unquoted pass/fail formula) only, unless `DisplayFoundFormula__c` / `DisplayExpectedFormula__c` supply display-only scalars. The `Passes when` line is Advanced-tier — cleared for users without `Record_Health_Check_View_Details`. |
| B19 | Row and summary-pill status icons are CSS-drawn (`rhc-status-icon--*`): not `lightning-icon`: for reliable rendering. |
| B20 | Summary pills list rule labels in hover/focus tooltips; standalone per-status footer notes removed. |
| B21 | Rule descriptions are tooltip-only (never inline); tooltips use `:focus-visible` to avoid double-tooltip on mouse click. |
| B22 | Action button stays visible during runs (disabled, spinner, label unchanged); label driven by **`hasCompletedRunOnce`**; busy text in `title` / `aria-label`. |
| B23 | `formatValue` quotes all non-blank single values uniformly (numbers, Booleans, dates included). |
| B24 | LWC header icon removed; the icon field was dropped from the schema and the Apex definition response (no `IconName__c` / `iconName` exists today). |
| B25 | `PassedChecksDisplay__c` / `SkippedChecksDisplay__c`: `Hide` collapses rows from the list but still populates summary pills after run completion. |
| B26 | Card uses `--lwc-borderRadiusMedium` rounded corners; **`overflow: visible`** on the card shell with bottom radius on `.rhc-body > :last-child` so tooltips are not clipped. |
| B27 | Row status accent is a full-height `.rhc-row__accent` element flush to the left edge: not `border-left`, `box-shadow`, or row `::before`. |
| B28 | Row/summary tooltips wait **600ms** of continuous pointer hover (JS dwell) before showing; **150ms** on `:focus-visible`; hide immediately on leave. |
| B29 | Summary-pill tooltips span the stats bar (`left/right: 1rem`, same as rows); nubbin is `.rhc-stat__nubbin` in `.rhc-stat__nubbin-host` (grid sibling of footer anchor). |
| B30 | Tooltips use `z-index: 100+` and must remain fully visible outside the card boundary (no `overflow: hidden` on `.rhc-card`). |
| B31 | Action button visible label is **only** `Run` or `Rerun`: never `Running…`; in-flight busy state is **spinner + `aria-busy`**, with busy text in `title` / `aria-label`. Label tracks **`hasCompletedRunOnce`** so a re-run stays **Rerun** while in flight. |
| B32 | Action button `min-width` is **5rem** with a fixed **0.75rem** glyph slot: label must not shift when play swaps to spinner. |
| B33 | Summary-pill tooltip bubble must **wrap** at card width: never a narrow pill-width column (`position: relative` wrapper between anchor and stats bar). |
| B34 | Summary-pill nubbin must **attach to the tooltip bubble bottom** (`.rhc-stat__nubbin-host` sibling pattern): never float above the pill detached from the bubble. |
| B35 | Check Set **Found/Expected Display** (`FoundExpectedDisplay__c`) controls Found/Expected visibility: **On demand** (`OnDemand`, default), **Failed checks only** (`FailuresOnly`), or **Show on every check** (`AllRows`); the expander appears on checks that have values hidden behind it. |
| B36 | `actualValueDetail` / `expectedValueDetail` diagnostic detail notes gated by `Record_Health_Check_View_Details`; rendered from `RecordHealthCheckValueSource` by the engine. |
| B37a | Category Rule fields ship in metadata; LWC grouping is not implemented yet. |
| B37b | Remediation Rule fields (`FixMessage__c`, `ActionLabel__c`, `ActionUrl__c`) render as read-only guidance on `FAIL` rows. Unsafe or over-2000-character resolved URLs are dropped, but fix instructions may still render. |
| B38 | `Record_Health_Check_Configure` custom permission ships in Admin set for future admin tooling; no runtime branch today. |

## 20. Open Limitations and Edge Cases

| Area | Behavior | Mitigation |
| ---- | -------- | ---------- |
| FormulaEval budget | Platform limit 100 calls/transaction; framework throws at 95 when the transaction-wide counter is reached. A single Rule can use multiple calls. | Prefer SOQL checks; keep formula-heavy Rules sparse per Check Set; avoid many formula checks in one Flow/batch transaction. |
| Declared single-value formula return type | `FormulaResultType__c` (Auto default): when set, declares a comparison/value-to-test formula's return type so it resolves in **one** FormulaEval call instead of probing up to eight. The declared type is **trusted**: if it is wrong but the platform still coerces the formula to that type (e.g. declaring `Text` for a numeric formula yields the string `"1000"` rather than the number `1000`), the resolved value's type changes and ordered comparisons (`GreaterThan`, etc.) may switch to lexical semantics. A declared type that the platform **rejects** degrades safely back to the full probe. | Leave as `Auto` unless the formula's return type is known; set it only to the formula's actual type. Auto always resolves correctly: it only costs more FormulaEval calls. |
| Server dependency cost | Within one Apex transaction the engine memoizes prerequisite results in a static cache keyed by config + record + check. The LWC still evaluates each Rule in its own transaction, so a prerequisite may run twice (once as its own row, once when a dependent calls the server). | Accept cost for safety on the record-page path; direct Apex chains benefit from memoization. |
| Same-transaction re-evaluation | Dependency memoization cache is **cleared after each top-level** `evaluate()` / `run()`. A second call in the same Apex transaction reloads the record and re-evaluates. Memoization applies only **within** one evaluation when resolving `PrerequisiteRule__c` chains. | Safe for Flow/batch loops that call `run()` after DML; do not rely on cross-call memoization. |
| SOQL tokens inside partial literals | The exact substring `'{!record.Field}'` inside a larger literal is substituted (for example `Name LIKE '{!record.Name}%'` → `Name LIKE 'Acme%'`). Exotic nesting (multiple tokens in one literal, escaped quotes) is untested. | Prefer standalone `'{!record.Field}'` or unquoted `{!record.Field}` tokens; test wildcard patterns on representative data. |
| `WITH SYSTEM_MODE` in Rule SOQL templates | Rejected at **any** parenthesis depth before execution; framework queries run `WITH USER_MODE`. | Do not embed elevated access in Check Set templates. |
| Dual-query list null semantics | Under `MissingMeansNoMatch`, null list values use distinct internal sentinels (nulls do not match each other). All-null rows with `SkipRecordsWithMissingValue` → **SKIPPED**. CompareAsLists still applies `NoRowsResult__c` when either side has **zero rows**, without distinguishing which side was empty. | Use applicability SOQL when only one side being empty should change the outcome. |
| Aggregate alias validation | Deploy-time validation allows a blank query field when any aggregate exists; runtime may require an explicit alias. | Set `SourceQueryField__c` / `ComparisonQueryField__c` to the aggregate alias for every non-`COUNT()` expression. |
| Semicolon-only multi-select bind | A multi-select value of `;` only (or segments that trim to empty) can bind to invalid `INCLUDES ()` SOQL. | Ensure picklist values are non-blank; avoid binding empty multi-select fields in unquoted token context. |
| Query / formula access errors (i18n) | `FIELD_NOT_ACCESSIBLE` vs `INVALID_SOQL_TEMPLATE` / `INVALID_FORMULA` is inferred from **English** substrings in platform exception messages. | Non-English orgs may see generic reason codes; test in target locales. |
| single value vs list case sensitivity | single value `Contains` / `DoesNotContain` are **case-sensitive**; list operators (`ListContainsAny`, dual list modes) normalize to lowercase. | Match casing in static values or use list operators for case-insensitive membership. |
| DateTime token / comparison timezone | Ordered DateTime coercion treats values ending in `Z` as GMT; other strings use `Datetime.valueOf` (org/user context). Cross-type `Date` vs `DateTime` equality may not align. | Use consistent types; test with org timezone. |
| Apex recent-activity Events | `AccountHasRecentActivityCheck` filters Events on **`ActivityDate`**, not `StartDateTime`: timed events can appear active when start time is before the cutoff. | Tune `daysBack` or implement a custom check using `StartDateTime` if needed. |
| Schema describe churn | Field planning and validation call `getDescribe()` on hot paths. v1.2.0 caches global/object/field describe per Apex transaction in `RecordHealthCheckDescribeCache`. | No action for normal record-page use; avoid unbounded custom plugins that bypass the cache. |
| Flow/batch governor pressure | Each `RecordHealthCheck.run` or Flow input row is a full engine evaluation (record load + evaluator). Bulk flows multiply SOQL/FormulaEval cost. | Keep batch sizes small; prefer targeted Rules; monitor debug logs. |
| Multi-select picklist tokens | Unquoted `{!record.Field}` on a resolved multi-select expands to `('A', 'B')`; quoted `'{!record.Field}'` keeps `'A;B;C'`. Relationship paths behave the same when the related record is loaded. | Use direct field tokens when possible; ensure relationship fields are collected by the engine. |
| 25-check cap | Dependents skip with `DEPENDENCY_NOT_IN_RUN` if prerequisite is omitted. UI shows **First 25 of N shown** (N = `totalAvailableCheckCount`). Deploy-time validator emits `CHECK_LIMIT_EXCEEDED` WARNING when a Check Set has more than 25 active Rules and warns when a dependency target is outside the first-25 window. | Keep Check Sets ≤ 25 active Rules or raise priority of prerequisites. |
| Stop on first error | Only `ERROR` stops the run; `FAIL` and `UNABLE_TO_EVALUATE` do not. Enables sequential execution. | Document intent; use dependencies if sequencing matters. |
| Validator gaps | Metadata Validator rejects blank `CardTitle__c` at deploy/validate time (aligned with the CMT `required` flag). Runtime `getDefinitionResponse` still falls back if a blank value is present. Apex class validation uses `Type.forName` at deploy/validate time. | Run `validateAsJson()` in CI plus manual review; test on representative records. |
| Static comparison values | `ExpectedFixedValue__c` is untyped text. | Use simple literals; normalize in SOQL or Apex for locale-specific formats. |
| Blank `CardTitle__c` at runtime | Required in CMT field metadata and caught by the validator. If blank metadata still reaches `getDefinitionResponse`, the LWC falls back to Check Set `MasterLabel`, then `DeveloperName`, so the card title is never empty. | Prefer a real Card Title; the fallback is a safety net, not a substitute for good labeling. |
| Record save | No automatic re-run after inline edit. | User clicks **Rerun** or refreshes the page. |
| Component placement | Record-page only (`lightning__RecordPage`). | Use `RecordHealthCheck.run` or Flow for non-record-page automation. |
| `checksOmittedByLimit` logging | When Rules are truncated, Apex emits a WARN with `CHECK_LIMIT_EXCEEDED` and the LWC shows **First 25 of N shown**. | Review Check Set active Rule count during configuration. |
| Category UI | `Category__c` is editable in Setup but rows are not grouped by category on the card yet. | Use Category for authoring consistency and future grouping; do not expect visible row groups today. |
| Remediation links | `FixMessage__c`, `ActionLabel__c`, and `ActionUrl__c` render only on failed checks. URLs are resolved from merge tokens and sanitized; unsafe or over-2000-character URLs are dropped. | Use same-org relative links or `https://` URLs. Keep instructions helpful even when a URL cannot render. |
| `Record_Health_Check_Configure` | Custom permission is assigned via Admin set but no feature gates on it yet (reserved for Rule Tester). | Assign Admin for validator/debug/view-details access; Configure permission is forward-compatible only. |
