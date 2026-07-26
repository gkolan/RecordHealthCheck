# Reference: Apex classes

> [!NOTE]
> On this page, look up what each Record Health Check Apex class owns, when to use it, and how it
> fits the runtime layers. Use this as a class-by-class reference while reading source or extending
> the Framework.
>
> **Reference**
>
> - For the full architecture story (layers, runtime path, security, limits), use
> [Reference: Architecture](reference-architecture.md).
> - For calling health checks from your code, use [Reference: Apex API](reference-apex-api.md).
> - For writing a custom evaluator plugin, use [Reference: Apex](reference-apex.md).

This guide covers every **production** class under `force-app/main/default/classes/` (excluding
`*Test` classes and coverage helpers). Shipped and integration-test example plugins are listed at
the end.

Unless noted otherwise, Framework service classes are `public with sharing`. Result and definition
data holders, the plugin interface, merge-token helpers, and a few other types are plain `public`
classes (no sharing keyword) because they hold data or interfaces rather than query Salesforce
records. Exceptions and interfaces are called out in their entries when that distinction matters.

## How to use this guide

| You want to… | Start here |
| --- | --- |
| Scan classes by layer | [Class index by level](#class-index-by-level) |
| Understand who calls whom | [Layers at a glance](#layers-at-a-glance) |
| Read a detailed description | The layer sections below |
| Call the Framework from Apex or Flow | Entry points, then [Apex API](reference-apex-api.md) / [Flow actions](../integration/flow-actions.md) |
| Implement `RecordHealthCheckRule` | Plugin interface classes, then [Apex reference](reference-apex.md) |

Every class entry below follows the same order, so you can find any given fact in the same place
every time: **Role** (what it is, read in under three seconds) → **Type** (declared sharing mode or
data holder / interface / exception) → what it does → **Key members** (the constants/methods/fields
worth knowing) → **Notable behavior** (gotchas, rationale, or a concrete example grounded in the
code) → **See also**. A class skips a slot only when there's genuinely nothing to put there - the
order never changes.

## Layers at a glance

Higher levels call lower levels. Lower levels never call back up. This matches
[Reference: Architecture § 5. Layers](reference-architecture.md#5-layers); the sections below use
the same L5→L1 numbering so you can move between the two pages without re-deriving the mapping.

| Level | Layer | Classes (summary) |
| --- | --- | --- |
| L5 | Entry points | `RecordHealthCheck`, Flow actions, `RecordHealthCheckController`, plus lifecycle publication and run context |
| L4 | Engine | `RecordHealthCheckEngine` |
| L3 | Evaluators | Formula, Query, Compare two queries, Apex evaluators + query support |
| L2 | Shared services | Config, validation, SOQL templates, comparison, values, merge tokens, describe cache, logger, access, constants |
| L1 | Results and definitions | Result data holders, definition responses, plugin interface and context |

Configuration, shared evaluation services, and merge tokens each get their own H2 section below for
readability, but all three live at **L2** in the architecture layer diagram.

## Class index by level

### L5 - Entry points

| Level | Class | One-line purpose |
| --- | --- | --- |
| L5 | [`RecordHealthCheck`](#recordhealthcheck) | Public Apex `runRule` / `runSet` API |
| L5 | [`RecordHealthCheckController`](#recordhealthcheckcontroller) | Aura-enabled API for the Lightning card |
| L5 | [`RecordHealthCheckRunRuleFlowAction`](#recordhealthcheckrunruleflowaction) | Packaged Flow action "Run Record Health Check Rule" |
| L5 | [`RecordHealthCheckRunSetFlowAction`](#recordhealthcheckrunsetflowaction) | Packaged Flow action "Run Record Health Check Set" |
| L5 | [`RecordHealthCheckLifecyclePublisher`](#recordhealthchecklifecyclepublisher) | Optional Set Run and Rule Result platform events |
| L5 | [`RecordHealthCheckRunContext`](#recordhealthcheckruncontext) | Run id, source, and timing for one evaluation |
| L5 | [`RecordHealthCheckSetPicklist`](#recordhealthchecksetpicklist) | App Builder dynamic picklist for Check Set Developer Name |

### L4 - Engine

| Level | Class | One-line purpose |
| --- | --- | --- |
| L4 | [`RecordHealthCheckEngine`](#recordhealthcheckengine) | One-Rule evaluation path (never throws for catchable failures) |

### L3 - Evaluators

| Level | Class | One-line purpose |
| --- | --- | --- |
| L3 | [`RecordHealthCheckFormulaEvaluator`](#recordhealthcheckformulaevaluator) | Formula Evaluation Type and shared formula resolution |
| L3 | [`RecordHealthCheckSoqlEvaluator`](#recordhealthchecksoqlevaluator) | Single-query Evaluation Type |
| L3 | [`RecordHealthCheckCompareQueriesEvaluator`](#recordhealthcheckcomparequeriesevaluator) | Compare-two-queries Evaluation Type |
| L3 | [`RecordHealthCheckApexEvaluator`](#recordhealthcheckapexevaluator) | Loads and runs a `RecordHealthCheckRule` plugin |
| L3 | [`RecordHealthCheckQueryEvaluatorSupport`](#recordhealthcheckqueryevaluatorsupport) | Shared query execution and empty-result handling |

### L2 - Shared services

| Level | Class | One-line purpose |
| --- | --- | --- |
| L2 | [`RecordHealthCheckConfigService`](#recordhealthcheckconfigservice) | Load Check Sets/Rules; definitions; runtime validation adapter |
| L2 | [`RecordHealthCheckRuleValidator`](#recordhealthcheckrulevalidator) | Shared per-Evaluation-Type Rule field validation |
| L2 | [`RecordHealthCheckMetadataValidator`](#recordhealthcheckmetadatavalidator) | Deploy-time / CI audit of Custom Metadata |
| L2 | [`RecordHealthCheckConfigValidator`](#recordhealthcheckconfigvalidator) | Shared validation helpers (object names, plugins, JSON, tokens) |
| L2 | [`RecordHealthCheckConstants`](#recordhealthcheckconstants) | Allowed values and numeric limits (single source of truth) |
| L2 | [`RecordHealthCheckReasonCodes`](#recordhealthcheckreasoncodes) | Selected stable reason-code helpers |
| L2 | [`RecordHealthCheckSetAvailability`](#recordhealthchecksetavailability) | Whether an object has active/inactive Check Sets |
| L2 | [`RecordHealthCheckComparisonEngine`](#recordhealthcheckcomparisonengine) | Operators, equality, empty/null behavior |
| L2 | [`RecordHealthCheckDisplayFormat`](#recordhealthcheckdisplayformat) | Renders Found and Expected values for the card chips |
| L2 | [`RecordHealthCheckSoqlTemplate`](#recordhealthchecksoqltemplate) | Safe SOQL preparation (`WITH USER_MODE`, row limit, keyword rejection) |
| L2 | [`RecordHealthCheckValueResolver`](#recordhealthcheckvalueresolver) | Extract, convert, and compare query values |
| L2 | [`RecordHealthCheckDescribeCache`](#recordhealthcheckdescribecache) | Schema describe cache for the current transaction |
| L2 | [`RecordHealthCheckEvaluatorException`](#recordhealthcheckevaluatorexception) | Evaluator failure carrying a reason code |
| L2 | [`RecordHealthCheckAccess`](#recordhealthcheckaccess) | Diagnostics Custom Permission check |
| L2 | [`RecordHealthCheckLogger`](#recordhealthchecklogger) | `[RHC]` debug lines and ERROR log platform events |
| L2 | [`RecordHealthCheckTemplateService`](#recordhealthchecktemplateservice) | Parse, validate, and resolve namespaced merge tokens and their optional fallback text |
| L2 | [`RecordHealthCheckTokenRegistry`](#recordhealthchecktokenregistry) | Allowed token namespaces and properties |
| L2 | [`RecordHealthCheckToken`](#recordhealthchecktoken) | One parsed merge token |
| L2 | [`RecordHealthCheckTokenIssue`](#recordhealthchecktokenissue) | One token validation failure |
| L2 | [`RecordHealthCheckMergeContext`](#recordhealthcheckmergecontext) | Values available while resolving merge tokens |

### L1 - Results and definitions

| Level | Class | One-line purpose |
| --- | --- | --- |
| L1 | [`RecordHealthCheckResult`](#recordhealthcheckresult) | One Rule response (contract `1.0`) |
| L1 | [`RecordHealthCheckSetResult`](#recordhealthchecksetresult) | One Check Set aggregate response (contract `1.0`) |
| L1 | [`RecordHealthCheckDefinition`](#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | One Rule row in the Lightning definition response |
| L1 | [`RecordHealthCheckDefinitionResponse`](#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | Check Set display settings + ordered Rule definitions |
| L1 | [`RecordHealthCheckAdminDetail`](#recordhealthcheckadmindetail) | Structured diagnostics detail on a Rule result |
| L1 | [`RecordHealthCheckValueSource`](#recordhealthcheckvaluesource) | Structured Found/Expected diagnostic detail |
| L1 | [`RecordHealthCheckRule`](#recordhealthcheckrule-interface) | Interface every Apex evaluator plugin implements |
| L1 | [`RecordHealthCheckContext`](#recordhealthcheckcontext) | Input passed to an Apex plugin `evaluate` |

### Example plugins

| Level | Class | One-line purpose |
| --- | --- | --- |
| Example | [`AccountHasRecentActivityCheck`](#accounthasrecentactivitycheck) | Shipped Apex Rule: recent Task/Event activity on an Account |

---

## Entry points (L5)

### `RecordHealthCheck`

**Role:** Public Apex `runRule` / `runSet` API.
**Type:** Service class · `public with sharing`

Runs the same metadata-defined Rules the Lightning card uses, without requiring a record page.
Callers choose `runRule` (one Rule) or `runSet` (every active Rule in a Check Set). The class owns
request limits, run-id generation, lifecycle source defaults (`APEX_API`), delayed publication across
nested calls, and a final `RecordHealthCheckLogger.flush()`.

**Key members:**

| Member | Purpose |
| --- | --- |
| `MAX_EVALUATIONS_PER_CALL` (`15`) | Planned Rule evaluations per call |
| `MAX_FLOW_RECORDS_PER_CALL` (`200`) | Flow Invocable request limit (also referenced by Flow actions) |
| `runRule(...)` | Evaluate one Rule for one or many records |
| `runSet(...)` | Evaluate one Check Set for one or many records; source-aware overloads for `SCHEDULED` / `BATCH` |
| `RecordHealthCheckRequestException` | Thrown when the request itself is invalid (null Id list, over the limit) |

**Notable behavior:**
- **When to use it:** any Apex process that needs a typed health decision. Prefer `runSet` when the
 business question is "is this Check Set healthy?" Prefer `runRule` only when the process needs one
 specific Rule.
- **Gotcha:** multi-record `runRule`/`runSet` overloads increment a private `publicationDeferralDepth`
 counter around the per-record loop so lifecycle events publish once after the whole batch, not once
 per record; the single-record overloads publish immediately because that counter stays at `0`.

**See also:** [Reference: Apex API](reference-apex-api.md)

### `RecordHealthCheckController`

**Role:** Aura-enabled API for the Lightning card.
**Type:** Service class · `public with sharing`

Exposes four card operations and nothing else. It does not contain evaluation logic; it cleans up
inputs, supplies Lightning lifecycle sources, and delegates to `RecordHealthCheckConfigService` and
`RecordHealthCheckEngine`.

**Key members:**

| Member | Purpose |
| --- | --- |
| `getCheckSetAvailabilityForRecord(recordId)` | Active/inactive Check Sets for the record's object (setup banner) |
| `getCheckDefinitions(checkSetDeveloperName, recordId)` | Display settings and ordered Rule definitions for the card |
| `evaluateCheck(checkSetDeveloperName, ruleDeveloperName, recordId, runId, source)` | One Rule evaluation (one Apex transaction per Rule from the card) |
| `completeRun(checkSetDeveloperName, recordId, runId, source)` | After a user-initiated run: re-evaluates server-side and publishes the Set completed event |

**Notable behavior:**
- **Source behavior:** the browser may request only Lightning-allowed source values. Unknown values
 fall back to non-publishable `RUN_ON_LOAD` behavior (as documented in architecture).
- **Gotcha:** `getCheckDefinitions` distinguishes a caught `ConfigException` (logged at `DEBUG`,
 reason code passed through as-is) from any other exception (logged at `ERROR`, always rethrown as
 `LOAD_FAILED`) so a real governor-limit or NPE failure is never mistaken by the card for a genuine
 missing-Check-Set condition. `completeRun` also ignores any Rule results the browser tried to pass
 in - it always re-evaluates server-side before publishing, since a lifecycle event must reflect
 server-side counts.

**See also:** [Lightning component](../integration/lightning-component.md)

### `RecordHealthCheckRunRuleFlowAction`

**Role:** Packaged Flow action "Run Record Health Check Rule".
**Type:** Invocable Flow action · `public with sharing`

Invocable wrapper around `RecordHealthCheck.runRule` with `SOURCE_FLOW`. Accepts a list of
`Request` rows (`ruleDeveloperName`, `recordId`) and returns status, reason code, contract version,
and full `resultJson` for advanced consumers. Enforces the Flow record and evaluation limits.

**Notable behavior:**
- **Gotcha:** `validateRequestCount` checks the request-list size against both
 `RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL` (200) and `MAX_EVALUATIONS_PER_CALL` (15) up front, so
 an oversized bulk Flow call fails before any record is evaluated rather than partway through the
 loop.

### `RecordHealthCheckRunSetFlowAction`

**Role:** Packaged Flow action "Run Record Health Check Set".
**Type:** Invocable Flow action · `public with sharing`

Invocable wrapper around `RecordHealthCheck.runSet` with `SOURCE_FLOW`. Returns aggregate status,
outcome counts, and `resultJson`. Plans evaluation count from definitions before dispatch so
oversized requests fail before partial work.

**Notable behavior:**
- **Gotcha:** before evaluating anything, it calls `getDefinitionResponse` for every request and
 accumulates `plannedEvaluations`, throwing `RecordHealthCheckRequestException` the moment the
 running total would exceed `MAX_EVALUATIONS_PER_CALL` - this planning pass means an oversized
 multi-record batch fails without evaluating any of it, not just the records past the limit.

**See also:** [Flow actions](../integration/flow-actions.md)

### `RecordHealthCheckLifecyclePublisher`

**Role:** Optional Set Run and Rule Result platform events.
**Type:** Service class · `public with sharing`

Publishes only for deliberate, publishable sources (`APEX_API`, `FLOW`, `USER_INITIATED`,
`SCHEDULED`, `BATCH`). Honors Check Set `PublishRunEvent__c` and Rule `PublishResultEvent__c`.
Publishes in batches of 100, never fails the health-check run when publish fails, and blocks
publication in subscriber context to prevent loops.

**Key members:**

| Member | Purpose |
| --- | --- |
| `CONTRACT_VERSION`, `CORE_VERSION`, `SOURCE_*`, `PUBLISH_CHUNK_SIZE` | Event contract, product version, publishable-source values, and the 100-row publish batch size |
| `publishCompletedSet(...)` | Publish the Set Run event after a deliberate run |
| `publishRuleResults(...)` | Publish per-Rule Result events for Rules that enable publication |
| `isRunPublicationEnabled(...)` | Whether the Check Set's `PublishRunEvent__c` allows publication |
| `canPublish(...)` | Whether the source is publishable and the call isn't inside subscriber context |

**Notable behavior:**
- **Gotcha:** `newEventId` builds a unique key from the run id, a suffix (`SET` or the Rule
 Developer Name), and 8 hex characters from a freshly generated AES key - truncating the run id to
 50 characters and the suffix to 20 so a caller-supplied run id can never exceed the platform
 event's `EventId__c` field. `canPublish` checks both `PUBLISHABLE_SOURCES` and a
 `subscriberContextOverride` flag so a subscriber reacting to one of these events cannot trigger
 republication and loop.

**See also:** [Lifecycle events](../integration/lifecycle-events.md)

### `RecordHealthCheckRunContext`

**Role:** Run id, source, and timing for one evaluation.
**Type:** Data holder · `public` (no sharing keyword)

Holds `runId`, `source`, `startedAt`, `completedAt`, and `durationMs`. Created at the start of an
evaluation path; `complete()` stamps end time. Exposed to merge tokens (`rhcRun.*`) and used when
building lifecycle events.

**Notable behavior:**
- **Gotcha:** `complete()` is safe to call more than once - it only stamps `completedAt`/`durationMs`
 when `completedAt` is still `null`, so calling it again along a call chain cannot overwrite the
 original duration with a later, longer one.

### `RecordHealthCheckSetPicklist`

**Role:** App Builder dynamic picklist for Check Set Developer Name.
**Type:** Service class · `public with sharing`, extends `VisualEditor.DynamicPickList`

Lists active Check Set Developer Names for the page's object
(`DesignTimePageContext.entityName`). Both label and stored value are the Developer Name. When
exactly one active Check Set matches, it becomes the default so a first drop onto the page needs no
extra click.

**Notable behavior:**
- **Why it exists:** DeveloperName, not MasterLabel, is used for both the picklist label and value
 because MasterLabels are not guaranteed unique across Check Sets while the DeveloperName is - using
 it avoids the free-text entry that was previously the most common cause of a blank card. When
 `entityName` is blank (for example, a template being edited outside a record page), `getValues()`
 falls back to listing every active Check Set rather than none.

---

## Engine (L4)

### `RecordHealthCheckEngine`

**Role:** One-Rule evaluation path for every entry point.
**Type:** Service class · `public with sharing`

Takes a Check Set name, Rule name, record Id, and run context, then returns exactly one
`RecordHealthCheckResult`. Designed never to throw for catchable failures - those become a status and
reason code. Governor-limit exceptions remain uncatchable, as with any Apex API.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(checkSetDeveloperName, ruleDeveloperName, recordId, runId, source)` | Public entry point (and related overloads used by entry points) |
| Owns (in order) | Request cleanup → Rule/Check Set load → prerequisite evaluation → runtime Rule validation → record load (`WITH USER_MODE`, only needed fields) → applicability check → evaluator routing → merge-token resolution → safe fix-link handling → logging → deciding whether to include diagnostics |
| Caches | Describe results via `RecordHealthCheckDescribeCache` for the transaction; prerequisite Rule results cached only for the current top-level evaluation chain, then cleared |

**Notable behavior:**
- **Gotcha:** the per-transaction FormulaEval call counter is deliberately never reset inside
 `evaluate` - a code comment explains that the platform's 100-call `FormulaEval` limit applies to
 the whole transaction, so resetting the framework's own counter per check would let a caller looping
 `evaluate()` many times (Flow, batch, anonymous Apex) drive the framework's count back to zero
 while the real platform count keeps climbing toward the uncatchable governor limit. Calculated-field
 dependency expansion is separately limited to `FORMULA_DEPENDENCY_DEPTH_CAP` (`10`) so a
 misconfigured or cyclic formula-field graph cannot walk forever even though a visited-set already
 breaks true cycles. Remediation deep links only resolve on `FAIL` and only when the URL is a
 same-org relative path or absolute `https://` - `javascript:`, `data:`, and protocol-relative (`//`)
 URLs are rejected.

**See also:** [Architecture § How one Rule is evaluated](reference-architecture.md#6-how-one-rule-is-evaluated)

---

## Evaluators (L3)

Each evaluator implements the same shape: build an empty result, run Evaluation Type logic, catch
failures into `UNABLE_TO_EVALUATE` / `ERROR` with a reason code, and set `durationMs` /
`evaluatorType`.

### `RecordHealthCheckFormulaEvaluator`

**Role:** Formula Evaluation Type (`FORMULA`).
**Type:** Evaluator · `public with sharing`

Evaluates `PassConditionFormula__c` against the loaded record via Salesforce `FormulaEval`. Also
used by other paths for applicability formulas, expected-record formulas, and list-membership
primary values (`FindInListFormula__c`).

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(rule, recordId, record)` | Main entry point for a Formula Rule |
| `resolveFormulaSingleValue(...)` | Shared formula resolution used by other paths |
| Governor safety | Tracks FormulaEval calls for the whole transaction (platform limit 100) with a safety margin; caches resolved return types so bulk callers do not retry every record |

**Notable behavior:**
- **Gotcha:** a formula that resolves to `null` (e.g. a null relationship traversal) is treated as
 `UNABLE_TO_EVALUATE`/`INVALID_FORMULA`, not `FAIL` - the class comments explain that letting null
 count as false would produce false failures. `evaluateFormulaAnyType` tries the admin-declared
 `FormulaResultType__c` or a cached previously-resolved return type first, and only falls back to
 trying all eight `formulaeval.FormulaReturnType` values (in a fixed cheapest-first order:
 `BOOLEAN`, `DECIMAL`, `DATE`, `DATETIME`, `STRING`, `DOUBLE`, `INTEGER`, `LONG`) when that preferred
 type fails, since every failed attempt still uses one of the 100 FormulaEval calls for the
 transaction. `FORMULA_EVAL_SAFETY_MARGIN` is `5`, so calls stop being attempted once
 `formulaEvalCallCount` reaches 95, leaving spare room for later checks' applicability checks in
 the same transaction.

**See also:** [Reference: Formula](reference-formula.md)

### `RecordHealthCheckSoqlEvaluator`

**Role:** Query Evaluation Type (`QUERY`).
**Type:** Evaluator · `public with sharing`

Binds merge tokens in `SourceQuery__c`, runs the query through
`RecordHealthCheckQueryEvaluatorSupport` / `RecordHealthCheckSoqlTemplate`, extracts Found values,
resolves Expected from fixed value / record formula / comparison query, and applies operators via
`RecordHealthCheckComparisonEngine`. Supports one-result, multi-row, list-membership, and unary
operators according to Rule configuration.

**Notable behavior:**
- **Gotcha:** an indeterminate operator result is split into two distinct causes that must not be
 handled the same way: a genuine zero-row query is governed by `NoRowsResult__c`, while a present
 row whose field value is null is governed by `EmptyValueHandling__c` and resolves to `SKIPPED` - 
 collapsing the two would let "null value + no rows" wrongly resolve to `FAIL`. `bindTokens` also
  resolves each `{!record.FieldApiName}` token (with optional `|Fallback value`) in both a quoted and unquoted form, since a multi-select
 picklist token expands differently depending on whether it appears inside quotes (raw `'A;B;C'`
 value) or unquoted (an `INCLUDES (...)` list).

**See also:** [Reference: Query](reference-query.md)

### `RecordHealthCheckCompareQueriesEvaluator`

**Role:** Compare two queries Evaluation Type (`COMPARE_TWO_QUERIES`).
**Type:** Evaluator · `public with sharing`

Runs `SourceQuery__c` and `ComparisonQuery__c`, then compares either one value per side
(`ONE_RESULT`) or two lists (`COMPARE_AS_LISTS`) with list set operators. Empty-query handling
follows `NoRowsResult__c`, consistent with the single-query evaluator.

**Key members:**

| Member | Purpose |
| --- | --- |
| `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY` | Supported list operators (the last compares how often each cleaned-up value appears, so duplicate counts must match, not just shared values) |

**Notable behavior:**
- **Gotcha:** under `AS_NO_MATCH` empty-value handling, a missing list value is not converted to an
 empty string (which would let two nulls wrongly "match" as blanks) - it is replaced with a unique
 placeholder, `' __rhc_missing__:' + side + ':' + index`, so a null on one side matches nothing, not
 even another null.

**See also:** [Reference: Compare two queries](reference-compare-two-queries.md)

### `RecordHealthCheckApexEvaluator`

**Role:** Apex Evaluation Type (`APEX`).
**Type:** Evaluator · `public with sharing`

Resolves `ApexClass__c` with `Type.forName`, confirms the instance implements
`RecordHealthCheckRule`, parses `ApexParametersJson__c` into `context.parameters`, calls
`evaluate(context)`, then finalizes severity, messages, and validation of returned statuses /
Found-Expected completeness for `PASS` / `FAIL`.

**Key members:**

| Member | Purpose |
| --- | --- |
| `APEX_CLASS_NOT_FOUND`, `INVALID_APEX_PARAMETERS`, `APEX_EVALUATOR_ERROR` | Typical failure reason codes |

**Notable behavior:**
- **Gotcha:** `finalizeApexResult` rejects any `apexResult.status` outside
 `{PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR}` and, for determinate `PASS`/`FAIL`, requires both
 `actualValue` and `expectedValue` to be non-blank - a plugin returning an unrecognized status or a
 determinate result without those values is changed to `ERROR`/`APEX_EVALUATOR_ERROR` rather than
 letting a malformed plugin response reach the UI. A `null` `recordId` is also rejected explicitly
 before the plugin runs (`APEX_EVALUATOR_ERROR`), since the interface's null-safe `objectApiName`
 lookup would otherwise let a plugin run with no real record context.

**See also:** [Reference: Apex](reference-apex.md)

### `RecordHealthCheckQueryEvaluatorSupport`

**Role:** Shared query execution for both SOQL evaluators.
**Type:** Shared helper · `public with sharing`

`runQuery` prepares SOQL (row limit +1 so it can detect too many rows), executes `Database.query`,
maps template and query exceptions to evaluator exceptions, and rejects results over the row limit
with `GOVERNOR_LIMIT_RISK`. Also provides shared `buildEmptyResult` / `buildNullIndeterminateResult`
and the safe "cannot evaluate" message helper.

**Key members:**

| Member | Purpose |
| --- | --- |
| `runQuery(...)` | Shared, limited query execution for both SOQL evaluators |
| `buildEmptyResult(...)` | Shared zero-row result shape, based on `NoRowsResult__c` |
| `buildNullIndeterminateResult(...)` | Shared null-value result shape |

**Notable behavior:**
- **Gotcha:** `runQuery` asks `RecordHealthCheckSoqlTemplate.prepareForExecution` for `maxRows + 1`
 rows rather than `maxRows` - fetching one extra row is how it distinguishes "exactly at the limit"
 from "over the limit" and raises `GOVERNOR_LIMIT_RISK` only in the latter case, without needing a
 separate `COUNT()` query. `buildEmptyResult`'s four-way branch on `NoRowsResult__c` (`PASS`, `FAIL`,
 `UNABLE_TO_EVALUATE`, or the default `SKIPPED`/`APPLICABILITY_NOT_MET`) is shared exactly by both
 SOQL evaluators so a zero-row query behaves identically regardless of Evaluation Type.

---

## Configuration and validation (L2)

### `RecordHealthCheckConfigService`

**Role:** Load Check Sets/Rules and runtime validation adapter.
**Type:** Service class · `public with sharing`

Queries Check Set and Rule Custom Metadata, builds Lightning definition responses (including
truncation at `FRAMEWORK_MAX_CHECKS`), reports Check Set availability for an object, resolves a
Rule's parent Check Set, loads Rules for evaluation, and maps the first
`RecordHealthCheckRuleValidator` finding into an `UNABLE_TO_EVALUATE` / `INVALID_CONFIG` result.

**Key members:**

| Member | Purpose |
| --- | --- |
| `ConfigException` (nested) | Exception carrying `reasonCode` |
| `RC_*` | Reason-code string aliases used across load paths - the single source of truth callers compare against, rather than a literal (e.g. `RC_CONFIG_INACTIVE`, `RC_OBJECT_MISMATCH`, `RC_NO_ACTIVE_CHECKS`) |
| `findCheckSetDeveloperName(...)` | Resolve a Rule's parent Check Set |
| `getCheckSetAvailabilityForObject(...)` | Active/inactive Check Sets for an object |
| `getDefinitionResponse(...)` | Build the Lightning definition response |
| `validateRuleForEvaluation(...)` | Map the first validator finding to a result |
| `loadRule(...)` | Load a Rule for evaluation |
| `cachedRulePublicationSettings(...)` | Transaction-cached publication flags |

**Notable behavior:**
- **Gotcha:** `getDefinitionResponse` prefers `CardTitle__c`, then falls back to MasterLabel, then
 DeveloperName, so the card never renders with a blank title when an admin left Card Title blank.
 When active Rules for a Check Set exceed `FRAMEWORK_MAX_CHECKS` (25), it logs a `WARN` server-side
 in addition to the truncation metadata the LWC shows as its "First 25 of N shown" badge, so the
 excess is visible in logs too, not only in the UI.

### `RecordHealthCheckRuleValidator`

**Role:** Shared Rule-field validation for every Evaluation Type.
**Type:** Shared validator · `public with sharing`

Returns ordered `Finding` values (`FindingCode` enum) once. Runtime (`ConfigService`) takes the first
finding; deploy-time (`MetadataValidator`) collects all findings. Keeps the decision logic in one
place so the two validators cannot disagree on *what* is invalid - only on how findings are mapped to
messages and field names.

**Notable behavior:**
- **Gotcha:** `MaxQueryRows__c` and `EmptyValueHandling__c` / `NoRowsResult__c` are deliberately
 *excluded* from `queryFindings`/`compareQueriesFindings` - callers run `maxRowsFindings` and
 `nullEmptyFindings` separately, since `ConfigService` applies them only to Query/CompareTwoQueries
 checks while `MetadataValidator` runs them once at the top level for every Evaluation Type; folding
 them into the per-type producers would double-count findings for the collect-all caller. Mutually
 exclusive conditions (operator, `QueryResultHandling__c`, comparison-value source) use `if`/`else
 if` chains for the same reason - so at most one `Finding` is returned per field even by the
 collect-everything path.

### `RecordHealthCheckMetadataValidator`

**Role:** Deploy-time / CI Custom Metadata audit.
**Type:** Service class · `public with sharing`

Validates all active Check Sets and Rules in the org and returns `ValidationIssue` rows (`ERROR` /
`WARNING`) with component name, field, message, and reason code. An empty list means the audit
passed. Use before promoting configuration between orgs.

**Key members:**

| Member | Purpose |
| --- | --- |
| `validate()` | Validate every active Check Set and Rule in the org |
| `validateRecords(...)` | Validate a supplied set of records |

**Notable behavior:**
- **Gotcha:** `validateRecords` treats a Check Set with more active Rules than
 `RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS` (25) as `WARNING`/`CHECK_LIMIT_EXCEEDED`, not
 `ERROR` - the excess Rules still deploy and are still valid, they simply will not run. It then
 checks whether any *included* Rule's `PrerequisiteRule__c` points outside that first-25 execution
 window and adds a second `WARNING`/`DEPENDENCY_NOT_IN_RUN` per such Rule, since the dependency
 would silently never resolve.

### `RecordHealthCheckConfigValidator`

**Role:** Shared validation helpers.
**Type:** Shared helper · `public with sharing`

First template token issue, object API name checks, Apex plugin class validation / creation helpers
(`isValidApexPlugin`, `takeValidatedPlugin`), and JSON-object shape checks. Used by both runtime and
deploy-time paths.

**Notable behavior:**
- **Gotcha:** `isValidApexPlugin` creates an instance of the class while validating it, then caches
 that instance in `validatedPluginInstances` by class name; `takeValidatedPlugin` retrieves and
 removes it so `RecordHealthCheckApexEvaluator` can reuse the already-built plugin instead of
 calling `newInstance()` a second time. `isJsonObject` treats a blank string as valid (returns
 `true`) since `ApexParametersJson__c` is optional - only a non-blank value that fails to parse as a
 JSON object is rejected.

### `RecordHealthCheckConstants`

**Role:** Allowed values and numeric limits (single source of truth).
**Type:** Constants holder · `public with sharing`

Owns `FRAMEWORK_MAX_CHECKS` (25), `FRAMEWORK_MAX_ROWS` (2000), and Set accessors that return a copy
for display modes, trigger/reveal modes, Evaluation Types, operators, null/empty behaviors,
severities, applicability modes, and related allowed-value lists. Runtime and deploy-time validators
both read from here so they cannot get out of sync.

**Notable behavior:**
- **Why it exists:** a class comment notes these values used to be duplicated exactly in both
 `RecordHealthCheckConfigService` and `RecordHealthCheckMetadataValidator`; adding a new operator or
 mode meant editing several files together, and missing one let the two validators silently
 disagree. Every `public static Set<String>` accessor here returns a `new Set<String>(...)` copy,
 not the internal set itself, so a caller changing the returned set can never overwrite the
 framework's official values. The class also owns the Apex-to-LWC value translation
 (`toLwcTriggerMode`, `toLwcSeverity`, `toLwcEvaluatorType`, etc.) that maps current metadata
 picklist values (for example `CRITICAL`) onto the older string values the LWC still expects (for
 example `Error`).

### `RecordHealthCheckReasonCodes`

**Role:** Selected stable reason-code helpers.
**Type:** Constants holder · `public` (no sharing keyword - data-only)

Declares commonly referenced codes (for example applicability and access) and marks which codes are
diagnostics-only (`isDiagnosticsOnly`). Full outcome list lives in
[Reference: Reason Codes](reference-reason-codes.md).

**Key members:**

| Member | Purpose |
| --- | --- |
| `isDiagnosticsOnly(reasonCode)` | Whether a reason code should be treated as diagnostics-only |

**Notable behavior:**
- **Example:** `DIAGNOSTICS_ONLY` contains exactly `FIELD_NOT_ACCESSIBLE` and
 `RECORD_NOT_ACCESSIBLE` - the two reason codes that reveal FLS/sharing details an unauthorized
 viewer should not see; `isDiagnosticsOnly(reasonCode)` simply checks whether the code is in that
 pair.

### `RecordHealthCheckSetAvailability`

**Role:** Check Set availability data for setup messaging.
**Type:** Data holder · `public` (no sharing keyword)

Used when the Lightning card has no Check Set selected.

**Key members:**

| Member | Purpose |
| --- | --- |
| `hasActive` | Whether the object has any active Check Sets |
| `hasInactive` | Whether the object has any inactive Check Sets |

**Notable behavior:**
- **Gotcha:** the no-arg constructor sets both `@AuraEnabled` booleans to `false`, so a caller that
 returns early before filling them in (for example `RecordHealthCheckController` on a `null`
 `recordId`) still returns a valid, non-null shape to the LWC.

---

## Shared evaluation services (L2)

### `RecordHealthCheckComparisonEngine`

**Role:** Shared comparison operators for Query evaluators.
**Type:** Shared service · `public with sharing`

Implements Equals / NotEquals / Contains / ordered operators, unary blank checks, list operators,
and `EmptyValueHandling__c` / `NoRowsResult__c` resolution. Throws
`RecordHealthCheckEvaluatorException` so both SOQL evaluators map the same reason codes.

**Key members:**

| Member | Purpose |
| --- | --- |
| `applySingleValueComparison(...)` | One-value operator comparison |
| `applySingleComparison(...)` | Single-row operator comparison |
| `applyUnaryComparison(...)` | Blank-check style operators |
| `valuesEqual(...)` | Typed equality |
| `resolveEmptyBehavior(...)` | `EmptyValueHandling__c` / `NoRowsResult__c` resolution |
| `formatValue(...)` / `formatList(...)` | Human-readable display formatting |
| `describeExpected(...)` / `describeExpectedForActual(...)` | Operator phrase plus the formatted operand |

**Notable behavior:**
- Each display method has an overload that takes the Rule's `DisplayValueFormat__c`. The no-format
 overloads render on `Auto`. The rendering itself lives in
 [`RecordHealthCheckDisplayFormat`](#recordhealthcheckdisplayformat); this class owns the operator
 phrasing and the list preview cap.
- **Example:** `formatList` limits the rendered preview to `LIST_PREVIEW_CAP` (`10`) entries and
 appends `… (N total)` beyond that, so a large query result stays readable in the UI. Full
 contract: [Reference: Display value format](reference-display-value-format.md).

### `RecordHealthCheckDisplayFormat`

**Role:** Renders Found and Expected values as the text shown on the card chips.
**Type:** Shared service · `public with sharing`

Applies the Rule's **Display: Value Format** (`DisplayValueFormat__c`). On `Auto` a value is
humanized from its Apex type; a named format such as `Currency` or `Raw` overrides that. Formatting
is display only - `RecordHealthCheckComparisonEngine` decides pass and fail from the raw typed
values, so no format can move a check between pass and fail.

**Key members:**

| Member | Purpose |
| --- | --- |
| `render(value, format, isoCode)` | One value rendered for the chosen format and currency |
| `renderCurrency(amount, isoCode)` | Money in a named currency |
| `formatForField(...)` / `formatForRow(...)` | The format a field's Setup definition suggests, used when the Rule is on Auto |
| `currencyIsoCodeFrom(row)` | The currency a row's amounts belong to, in an org with more than one |
| `alignExpectedToFound(...)` | Keeps a fixed text operand in the same units as a numeric Found value |
| `FORMAT_*` constants | The `DisplayValueFormat__c` API values |

**Notable behavior:**
- Numbers are grouped through `Decimal.format()`, so separators follow the running user's locale:
 `70000.0` reads `70,000` for an English (US) user and `70.000` for a German (Germany) one.
- A named format that cannot apply to a value returns the value with its original spelling rather
 than raising an error - `Currency` on a Salesforce Id stays the Id.
- A `Date` is tested before a `Datetime` everywhere, because Apex reports a `Date` as an instance of
 `Datetime`; checking the other way round would shift a date by the user's time-zone offset.
- An org with more than one currency renders ISO-first (`USD 70,000.00`); a single-currency org uses
 the symbol. `RecordHealthCheckEngine` loads `CurrencyIsoCode` on the record in a multi-currency org
 so an amount can be shown in the currency its own record uses.
- Full contract: [Reference: Display value format](reference-display-value-format.md).

### `RecordHealthCheckSoqlTemplate`

**Role:** Safe preparation of administrator-authored SOQL.
**Type:** Shared service · `public with sharing`

Cleans up admin-authored SOQL with awareness of parenthesis depth: rejects DML keywords and
`WITH SYSTEM_MODE`, requires a single outer SELECT, rewrites bare `COUNT()`, enforces the outer row
limit, and injects `WITH USER_MODE` in a legal clause position. Ignores keywords inside string
literals and nested subqueries so false positives and misplaced injection are avoided.

**Key members:**

| Member | Purpose |
| --- | --- |
| `prepareForExecution(soql, maxRows)` | Main entry point; cleans up and limits admin-authored SOQL |
| `TemplateException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**
- **Gotcha:** `maskStringLiterals` replaces every character inside a single-quoted literal with a
 space (preserving length and position) rather than stripping it, so later regex match indices
 computed against the masked copy still map back onto the original SOQL string unchanged.
 `injectUserMode` only inserts `WITH USER_MODE` when no outer `WITH` clause already exists, and
 walks `TAIL_CLAUSE_PATTERNS` to find the earliest legal tail-clause position (`GROUP BY`/`ORDER
 BY`/`LIMIT`/etc.) to insert before - an admin query already ending in a tail clause never gets
 `WITH USER_MODE` appended after it, which would be invalid SOQL. `WITH SYSTEM_MODE` is rejected
 outright rather than merely ignored, since it would let an admin-authored query bypass the
 sharing/FLS enforcement the framework guarantees.

### `RecordHealthCheckValueResolver`

**Role:** Value extraction, conversion, and comparison.
**Type:** Shared service · `public with sharing`

Reads fields from rows and `AggregateResult`s (including relationship paths), classifies
`QueryException` messages into access vs template reason codes, and compares numeric / datetime /
string values consistently for both Query evaluators.

**Key members:**

| Member | Purpose |
| --- | --- |
| `traverse(...)` | Read a (possibly relationship-dotted) field path off a row |
| `classifyQueryException(...)` | Map a `QueryException` message to a reason code |
| `ResolverException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**
- **Gotcha:** `traverse` returns `null` (not an exception) when an intermediate relationship in a
 dotted field path (e.g. `Account.Name`) is itself null, so a broken relationship chain becomes a
 null value rather than an error. `classifyQueryException` inspects the exception message text
 for `access`, `permission`, or `insufficient privileges` to decide `FIELD_NOT_ACCESSIBLE` vs.
 `INVALID_SOQL_TEMPLATE` - it accepts the base `Exception` type specifically because
 `System.QueryException` cannot be constructed with a custom message in a test, so only the message
 is ever inspected, not the exception's runtime type.

### `RecordHealthCheckDescribeCache`

**Role:** Schema describe cache for the current transaction.
**Type:** Shared service · `public with sharing`

Caches global describe, SObject describes, field maps, and field describes so a busy card or bulk
run does not rebuild metadata repeatedly. Production describe lookups should go through this class
rather than calling Schema APIs directly elsewhere in the Framework.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsObject(...)` | Whether an object exists in the global describe |
| `resolveSObjectType(...)` | Resolve an object API name to its `SObjectType` |
| `getGlobalDescribe(...)` | Cached global describe map |
| `objectApiName(...)` | Cached object API name lookup |
| `describeSObject(...)` | Cached `DescribeSObjectResult` |
| `fieldMap(...)` | Cached field map for an object |
| `describeField(...)` | Cached `DescribeFieldResult` for one field |

**Notable behavior:**
- **Gotcha:** `describeField` keys its cache on the `Schema.SObjectField` token itself, not on
 `String.valueOf(field)` - a comment notes that `String.valueOf` returns only the unqualified field
 name, so two same-named fields reached from different objects (for example `Account.Name` vs.
 `Contact.Name` via a relationship traversal) would otherwise collide in the cache and return the
 wrong describe, including a wrong `isAccessible()` result.

### `RecordHealthCheckEvaluatorException`

**Role:** Evaluator exception with a reason code.
**Type:** Custom exception · `public`, extends `Exception`

Thrown by comparison, SOQL template, and value-resolution paths. Evaluators catch it and map
`reasonCode` onto `UNABLE_TO_EVALUATE` results instead of leaking stack traces to users.

**Notable behavior:**
- **Why it exists:** a class comment explains this type was promoted from duplicate inner
 `EvaluatorException` classes that previously lived separately inside
 `RecordHealthCheckSoqlEvaluator` and `RecordHealthCheckCompareQueriesEvaluator`; a single top-level
 exception lets the shared `RecordHealthCheckComparisonEngine` throw one type that both evaluators'
 catch blocks recognize, instead of each evaluator needing its own.

### `RecordHealthCheckAccess`

**Role:** Diagnostics Custom Permission check.
**Type:** Shared service · `public with sharing`

`canViewDetails()` returns whether the running user holds `Record_Health_Check_View_Diagnostics`.
Check Set `ShowDiagnostics__c` still controls *when* troubleshooting fields are attached; this class
only answers *who* may see them.

**Key members:**

| Member | Purpose |
| --- | --- |
| `canViewDetails()` | Whether the running user holds the diagnostics Custom Permission |

**Notable behavior:**
- **Gotcha:** `canViewDetails()` only honors the `@TestVisible` `viewDetailsPermissionOverride` when
 `Test.isRunningTest()` is true - a test override left set can never leak into a non-test
 `FeatureManagement.checkPermission` call, so production behavior always reflects the real Custom
 Permission assignment.

### `RecordHealthCheckLogger`

**Role:** Single logging destination for the Framework.
**Type:** Shared service · `public with sharing`

Every Framework log line goes through this class as structured `[RHC]` output with run id and
running user. Levels: `ERROR`, `WARN`, `INFO`, `DEBUG`. ERROR lines are also held as
`Record_Health_Check_Log__e` and published by `flush()` at the transaction boundary (default on;
subscriber-context guarded). Entry points call `flush()` so ERROR platform events are not lost when
`System.debug` is off.

**Key members:**

| Member | Purpose |
| --- | --- |
| `normalizeIdentifier(...)` | Length-limited API names used in logs and lookups |
| `flush()` | Publish held `ERROR` events at the transaction boundary |
| `enterSubscriberContext()` | Loop guard for subscriber-context log handling |

**Notable behavior:**
- **Gotcha:** `captureErrorEvent` deliberately never carries field values (actual/expected) into the
 `Record_Health_Check_Log__e` event - only identifying context (run id, Check Set/Rule
 names, record id, exception type/message/stack) - because those raw values belong to Debug Mode's
 admin detail channel, not a platform event any subscriber with object access could read.
 `enterSubscriberContext()` is a one-way loop guard a subscriber processing this same event must
 call first, so an error raised while handling a log event cannot republish onto the same event bus.

**See also:** [Log event metadata](../metadata/event-log.md)

---

## Merge tokens (L2)

### `RecordHealthCheckTemplateService`

**Role:** Parse, validate, and resolve merge tokens.
**Type:** Shared service · `public` (no sharing keyword)

Handles namespaced tokens such as `{!record.Name}`, with optional fallback text such as
`{!record.Name|Fallback}`, for display messages, URLs, and SOQL text.
Enforces max 100 tokens and 20,000 characters of resolved text. Unknown namespaces, unknown
properties, legacy flat tokens, and stray braces become structured `RecordHealthCheckTokenIssue`s.

**Key members:**

| Member | Purpose |
| --- | --- |
| `SURFACE_DISPLAY`, `SURFACE_URL`, `SURFACE_SOQL` | The three contexts tokens can resolve for |
| `resolveFieldPath(...)` | Resolve a dotted `record.*` token to a field value |

**Notable behavior:**
- **Gotcha:** `resolveFieldPath` rejects a dotted record token whose relationship depth exceeds 5
 hops (`parts.size() > 6`) with `TOKEN_NOT_AVAILABLE_IN_PHASE`, so a runaway relationship chain in an
 admin-authored template fails immediately rather than describing arbitrarily deep schema. On
 `SURFACE_URL`, a token that resolves blank and has no `|Fallback` throws `MISSING_TOKEN_VALUE`
 instead of silently substituting an empty string - a blank display value is harmless, but a blank
 URL segment could produce a broken or unintended link. `rhcResult` tokens can only be resolved once
 `context.resultFinalized` is true, since a result's Found/Expected values are not meaningful until
 the evaluator has finished.

**See also:** [Reference: Merge tokens](reference-merge-tokens.md)

### `RecordHealthCheckTokenRegistry`

**Role:** Allowed list of merge-token namespaces and properties.
**Type:** Constants holder · `public` (no sharing keyword)

Record properties are any non-blank field path; other namespaces use fixed property sets (Developer
Name, status, run id, and so on).

**Key members:**

| Member | Purpose |
| --- | --- |
| `record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun` | The five allowed token namespaces |
| `RESULT_PROPERTIES` | Fixed property set for the `rhcResult` namespace |

**Notable behavior:**
- **Example:** `RESULT_PROPERTIES` is exactly `{status, foundValue, foundValuePluralSuffix,
 expectedValue, failedRecordCount, totalRecordCount, reasonCode}` - `foundValuePluralSuffix` in
 particular exists so a multi-row summary message can render "1 Contact" vs "2 Contacts" without the
 admin hand-authoring a conditional.

### `RecordHealthCheckToken`

**Role:** One parsed merge token.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `expression` | The full raw token text |
| `namespaceName` | The token's namespace (e.g. `record`, `rhcRule`) |
| `propertyPath` | The property or field path within that namespace |
| `fallbackValue` | Optional fallback text written after the pipe character; `null` when omitted |
| `startIndex` / `endIndex` | Start and end position of the token within the template string |

**Notable behavior:**
- **Note:** a convenience constructor omits `fallbackValue` (defaults to `null`) for callers that
 only need the namespace/property/span.

### `RecordHealthCheckTokenIssue`

**Role:** One merge-token validation failure.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckTokenIssue(String reasonCode, String token, String message)` | Constructor - for example `('UNSUPPORTED_TOKEN_NAMESPACE', '{!foo.bar}', 'Unsupported token namespace "foo".')` <!-- legacy-token-ok --> |

### `RecordHealthCheckMergeContext`

**Role:** Values available while resolving merge tokens.
**Type:** Chainable builder · `public` (no sharing keyword)

Chainable `withRecord` / `withRule` / `withResult` / `withRun` builders supply the record, Rule (and
parent Check Set), result, and run context used by token resolution. Also carries optional
failed/total record counts for plural-aware result tokens.

**Key members:**

| Member | Purpose |
| --- | --- |
| `withRecord(...)` | Supply the record for `record.*` tokens |
| `withRule(...)` | Supply the Rule (and derive its parent Check Set) for `rhcRule.*` / `rhcSet.*` tokens |
| `withResult(value, finalized)` | Supply the result for `rhcResult.*` tokens; only usable when `finalized` is true |
| `withRun(...)` | Supply the run context for `rhcRun.*` tokens |

**Notable behavior:**
- **Gotcha:** `withRule` also derives `checkSet` by calling
 `value.getSObject('Record_Health_Check_Set__r')` on the passed-in Rule record - callers never set
 `checkSet` directly, so a Rule query that omits the `Record_Health_Check_Set__r` relationship will
 silently leave `rhcSet.*` tokens unresolved. `resultFinalized` defaults to `false` and is only
 ever set `true` through `withResult(value, finalized)`, which controls when `rhcResult.*` tokens
 become available.

---

## Results, definitions, and plugin interface (L1)

### `RecordHealthCheckResult`

**Role:** One Rule response (contract `1.0`).
**Type:** Data holder (`@AuraEnabled`) · `public` (no sharing keyword)

Public `@AuraEnabled` fields are the stable public API: status, severity, reason code,
messages, Found/Expected strings, action link fields, timing, and evaluator type. Internal-only
fields (`detailMessage`, `actualValueSource`, `expectedValueSource`, `recordId`) are not
Aura-enabled; the engine may copy cleaned-up diagnostics into `adminDetailMessage` / `adminDetail`
when authorized.

**Key members:**

| Member | Purpose |
| --- | --- |
| `PASSES_WHEN_LABEL` (`"Passes when"`) | Override for `expectedValueLabel` on Formula Rules |

**Notable behavior:**
- **Gotcha:** `expectedValueLabel` exists purely to override the UI's default "Expected" caption - it
 is set to the class constant `PASSES_WHEN_LABEL` only for the Formula-evaluator case where
 `expectedValue` echoes the raw pass/fail condition rather than a real comparison operand, so the
 row reads "Passes when …" instead of the misleading "Expected …".

**See also:** [Apex API - Rule response](reference-apex-api.md#rule-response)

### `RecordHealthCheckSetResult`

**Role:** One Check Set aggregate response (contract `1.0`).
**Type:** Data holder (`@AuraEnabled`) · `public` (no sharing keyword)

Combines ordered Rule results and counts (`passedCount`, `failedCount`, `skippedCount`,
`unableCount`, `systemErrorCount`). `add` updates counts; `finish` sets aggregate `status` with
precedence ERROR → UNABLE_TO_EVALUATE → FAIL → PASS → SKIPPED.

**Key members:**

| Member | Purpose |
| --- | --- |
| `add(...)` | Add one Rule result and update its counter |
| `finish()` | Compute the aggregate status by precedence |

**Notable behavior:**
- **Gotcha:** `add`'s status-to-counter mapping treats any status other than `PASS`, `FAIL`,
 `SKIPPED`, or `ERROR` as `unableCount` (the `else` branch) - so `UNABLE_TO_EVALUATE` is only ever
 reached implicitly, not matched by name. `finish()` defaults the aggregate `status` to `SKIPPED`
 when every counter is still zero (an empty `results` list), rather than leaving `status` null.

**See also:** [Apex API - Check Set response](reference-apex-api.md#check-set-response)

### `RecordHealthCheckDefinition` / `RecordHealthCheckDefinitionResponse`

**Role:** Lightning definition response (not evaluation results).
**Type:** Data holders (`@AuraEnabled`) · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckDefinition.developerName` / `label` / `description` / `priority` | One Rule's identity and display fields |
| `RecordHealthCheckDefinition.dependsOnRuleDeveloperName` | `null` when the Rule has no `PrerequisiteRule__c` dependency |
| `RecordHealthCheckDefinitionResponse` title/trigger/reveal/display fields | Check Set card settings (title, trigger/reveal modes, passed/skipped/comparison display, stop-on-first-error) |
| `RecordHealthCheckDefinitionResponse.checksOmittedByLimit` | Truncation metadata for the "First 25 of N shown" badge |
| `RecordHealthCheckDefinitionResponse.inactiveRuleLabels` | Diagnostics-only detail behind `inactiveRuleCount` |
| `RecordHealthCheckDefinitionResponse.showDiagnostics` / `checks` | Diagnostics visibility flag and the ordered Rule definitions |

**Notable behavior:**
- **Note:** `inactiveRuleLabels` - the list of names, not just the count - is only meaningful to an
 admin auditing why a Rule did not run.

### `RecordHealthCheckAdminDetail`

**Role:** Structured diagnostics for authorized Show Diagnostics viewers.
**Type:** Data holder (`@AuraEnabled`) · `public` (no sharing keyword)

Left blank on a normal business response.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsRestrictedDetail` | Whether restricted detail is present; read by `RecordHealthCheckLifecyclePublisher` to set `ContainsRestrictedDetail__c` on the outgoing event |
| `reasonCode` | Diagnostics reason code |
| `message` | Diagnostics message text |

**Notable behavior:**
- **Note:** all three fields are `@AuraEnabled` with no constructor - callers set them field by
 field.

### `RecordHealthCheckValueSource`

**Role:** Structured Found/Expected diagnostic detail.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `Detail` (nested: `sourceLabel`, `rawValueLabel`, `coercionLabel`) | Structured pieces of one diagnostic note |
| `render(Detail)` | Turns a `Detail` into the single human-readable note shown as `actualValueDetail` / `expectedValueDetail` |
| `rowCount(...)` | Formats pluralized row counts |

**Notable behavior:**
- **Gotcha:** `render` returns `null` - not an empty string - when every part of the `Detail` is
 blank, so the engine can leave the public `*Detail` string `null` rather than showing an empty
 parenthetical note. `rowCount` exists solely so a value-source note never reads "1 row(s)": it
 special-cases `n == 1` to `"1 row"` and treats a `null` count as `0`.

### `RecordHealthCheckRule` (interface)

**Role:** Plugin interface for Apex Evaluation Type.
**Type:** Interface · `public`

```apex
public interface RecordHealthCheckRule {
 RecordHealthCheckResult evaluate(RecordHealthCheckContext context);
}
```

Implementations must be `public`, preferably `with sharing`, and return valid statuses with both
Found and Expected set on determinate `PASS` / `FAIL`.

**Notable behavior:**
- **Gotcha:** the interface itself has no return-value validation - it is a one-method contract with
 a single `evaluate(RecordHealthCheckContext context)` signature. All the enforcement described
 above (valid status set, required Found/Expected on `PASS`/`FAIL`) lives in the caller,
 `RecordHealthCheckApexEvaluator.finalizeApexResult`, not in this interface, since Apex interfaces
 cannot express those constraints at compile time.

### `RecordHealthCheckContext`

**Role:** Input to `RecordHealthCheckRule.evaluate`.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `recordId` | Id of the record under evaluation (preferred bind variable) |
| `objectApiName` | Object API name (for example `Account`) |
| `record` | Partially loaded SObject - only fields the engine already needed |
| `parameters` | Parsed `ApexParametersJson__c` object; empty map when blank (never null from the evaluator) |
| `ruleDeveloperName` | Rule Developer Name for logging/correlation |

**Notable behavior:**
- **Gotcha:** `parameters` is guaranteed to be a non-null (possibly empty) `Map<String, Object>` - 
 `RecordHealthCheckApexEvaluator` parses `ApexParametersJson__c` before building the context and
 always supplies at least an empty map, so a plugin never needs a null check before reading
 `context.parameters`.

**See also:** [Reference: Apex](reference-apex.md)

---

## Example Apex plugins

These classes implement `RecordHealthCheckRule`. They are examples and fixtures, not required for
the engine to run Formula or Query Rules.

### `AccountHasRecentActivityCheck`

**Role:** Shipped Apex Rule for recent Account Task/Event activity.
**Type:** Example plugin (implements `RecordHealthCheckRule`) · `public with sharing`

Ships with Core in `force-app`. Passes when the Account has at least one completed Task or Event in
a look-back window. Tunable with `ApexParametersJson__c`: `{"daysBack": 90}` (default 30, bounds
1–3650). Sets Found/Expected and value-source detail; label, severity, and failure message come from
metadata.

**Key members:**

| Member | Purpose |
| --- | --- |
| `DEFAULT_DAYS_BACK` (`30`) | Fallback look-back window when `daysBack` is missing/invalid |
| `MIN_DAYS_BACK` / `MAX_DAYS_BACK` (`1` / `3650`) | Valid bounds for `daysBack` |
| `resolveDaysBack(...)` | Parses and bounds-checks the `daysBack` parameter |

**Notable behavior:**
- **Gotcha:** `resolveDaysBack` falls back to `DEFAULT_DAYS_BACK` whenever the supplied `daysBack` is
 missing, non-numeric, or outside `MIN_DAYS_BACK`/`MAX_DAYS_BACK` - a malformed parameter never
 throws or fails the check, it just uses the default window. Both queries run
 `WITH USER_MODE` and use `SELECT COUNT()`, so Task/Event visibility follows the running user's
 sharing and FLS like every other Framework query.

**See also:** [Recent Account activity example](../examples/apex/01-recent-activity.md)

### Integration-test plugins

These live under `integration-tests/main/default/classes/` and accompany the examples library. They
are not part of the Core package unless you deploy that folder.

| Class | What it checks | Typical JSON parameters |
| --- | --- | --- |
| `AccountOpenOpportunityHealthCheck` | Open Opportunities that are stale, missing Next Step, and not closing this quarter | `{"staleDays": 30}` |
| `AccountStrategicReadinessCheck` | Weighted readiness score (contacts, pipeline, activity, billing) | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApprovalInactiveApproverCheck` | Pending approval steps assigned to inactive users (dynamic object/field names for Advanced Approvals) | Object/field/status overrides; returns `UNABLE_TO_EVALUATE` when the approval object is absent |

**See also:** [Apex examples](../examples/apex/README.md)

---

## Test helpers (not runtime)

| Class | Note |
| --- | --- |
| `RecordHealthCheckTestDataFactory` | `@isTest` factory for Accounts/Contacts and related coverage data; not used at runtime |
| `*Test.cls` / coverage classes | Unit and coverage tests; not part of the product API |

---

## Related

- [Reference: Architecture](reference-architecture.md) - layers, runtime path, ownership map
- [Reference: Apex API](reference-apex-api.md) - public `runRule` / `runSet` contract
- [Reference: Apex](reference-apex.md) - writing a `RecordHealthCheckRule` plugin
- [Reference: Reason Codes](reference-reason-codes.md) - status and reason codes
- [Reference: Merge tokens](reference-merge-tokens.md) - token namespaces and limits
- [Technical references index](README.md)
