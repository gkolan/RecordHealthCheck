# Result Contract and Reason Codes

> [!NOTE]
> **Canonical source:** Section numbers and anchors in the [full design specification](../reference/record-health-check-design-spec.md) are stable for cross-links.

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
| `message` | Safe user-facing message (from `MessageWhenFailed__c` on `FAIL`, or unable/skip text otherwise). |
| `actualValue` | What the record or query produced: the **Found** side in the UI. Populated on a determinate `PASS` or `FAIL` when the evaluator can name a primary value (Query, CompareTwoQueries, and required for Apex). Left null for Formula checks unless `FoundValueFormula__c` is configured (then it carries that scalar). |
| `expectedValue` | The comparator and operand as readable text: the **Expected** side in the UI. Populated on a determinate `PASS` or `FAIL` for Query and CompareTwoQueries; for Formula checks, set to the resolved `ExpectedValueFormula__c` scalar when configured, otherwise the quoted `PassFailFormula__c` condition text. Apex plugins must set this for `PASS` / `FAIL`. |
| `actualValueDetail` | Human-readable provenance note for the **Found** side. Populated when the evaluator sets `actualProvenance` **and** the running user has **`Record_Health_Check_View_Details`**. |
| `expectedValueDetail` | Provenance note for the **Expected** side. Same gating as `actualValueDetail`. |
| `actionLabel` | Read-only remediation link label from `PrimaryActionLabel__c`; defaults to `Fix this` when a safe URL exists without a label. Populated only on `FAIL`. |
| `actionUrl` | Resolved and sanitized remediation URL from `PrimaryActionUrl__c`. Supports merge tokens. Only same-org relative paths and `https://` URLs are allowed; unsafe or over-2000-character resolved URLs are dropped. Populated only on `FAIL`. |
| `fixInstructions` | Optional guidance from `FixInstructions__c`, with merge tokens resolved. Populated only on `FAIL`; may render even when `actionUrl` is dropped. |
| `detailMessage` | Diagnostic detail (server-side; not `@AuraEnabled`). |
| `adminDetailMessage` | Populated only when `DebugMode__c` is on **and** the user has **`Record_Health_Check_Debug`** (permission set `Record_Health_Check_Admin`). |
| `durationMs` | Evaluator execution time; excludes configuration, dependencies, base-record loading, applicability, and event delivery. |

Evaluators populate internal `RecordHealthCheckProvenance.Detail` on `actualProvenance` / `expectedProvenance` (not `@AuraEnabled`). The engine renders and permission-gates the public `*Detail` strings.

### Comparison display contract

| Topic | Contract |
| ----- | -------- |
| Value metadata | Found/Expected values are computed at evaluation time from comparator, operand, formulas, and query results. Formula Rules may provide display-only scalar formulas (`FoundValueFormula__c`, `ExpectedValueFormula__c`). Multi-row `Every record must pass` Query Rules may override the summary wording with `FoundSummaryOverride__c` and `ExpectedSummaryOverride__c`. |
| Display policy metadata | Check Set **Found/Expected Display** (`ComparisonDisplay__c`): **On demand** (`OnDemand`, default), **Failed checks only** (`FailuresOnly`), or **Show on every check** (`AllRows`). |
| UI visibility (values) | **Failures:** Found/Expected inline in every mode when captured. **Passes:** inline only with **Show on every check** (`AllRows`); otherwise behind the expander with **On demand** (`OnDemand`) or hidden with **Failed checks only** (`FailuresOnly`). |
| UI visibility (provenance) | Provenance lines appear only when the caret region is expanded **and** `*Detail` strings are non-null (permission-gated). Always behind the caret. |
| UI layout | Values as stacked labelled chips; provenance as de-emphasized lines beneath when expanded. |
| Formula checks | By default no separable scalar "found" value: `expectedValue` carries the unquoted pass/fail formula and `expectedValueLabel` is `Passes when`, `actualValue` stays null, only that side renders. Optional `FoundValueFormula__c` / `ExpectedValueFormula__c` populate display-only scalars (shown under the standard `Expected` key). |
| Skipped / unable / error | Neither value nor provenance is shown. |
| Programmatic API | `RecordHealthCheck.run` returns the same fields on `RecordHealthCheckResult`. |

### Remediation display contract

| Topic | Contract |
| ----- | -------- |
| Source metadata | `FixInstructions__c`, `PrimaryActionLabel__c`, and `PrimaryActionUrl__c` on the Rule. |
| Status gating | Remediation fields render only on `FAIL` rows. `PASS`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` suppress them. |
| URL safety | `PrimaryActionUrl__c` is merge-token resolved, URL-encoded, and sanitized. Same-org relative paths and `https://` URLs are allowed; unsafe schemes, protocol-relative forms, and resolved URLs over 2000 characters are dropped. |
| Partial rendering | If the URL is dropped, `FixInstructions__c` may still render so the row keeps useful guidance. |
| Behavior | Links are advisory/read-only. Record Health Check does not update records. |

### Comparison provenance

| Topic | Contract |
| ----- | -------- |
| Purpose | One note per side: where a value came from and its raw form (for example `Rating → "Cold"`). |
| Permission | **`Record_Health_Check_View_Details`** — included in `Record_Health_Check_Admin`. Independent of `DebugMode__c`. |
| Render format | `RecordHealthCheckProvenance.render`: `source → raw` with optional `(coercion)` suffix. |

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
| `displayTitle`, `displayDescription` | Header presentation from Check Set. |
| `triggerMode`, `revealMode` | Run and reveal behavior. |
| `successDisplayMode`, `skippedDisplayMode` | Row visibility rules. |
| `comparisonDisplay` | API value from Check Set **Found/Expected Display** (`ComparisonDisplay__c`): `OnDemand`, `FailuresOnly`, or `AllRows`. |
| `stopOnFirstError`, `debugMode` | Run control and diagnostics. |
| `totalAvailableCheckCount` | Active Rules before the 25-check cap. |
| `checksOmittedByLimit` | True when Rules were truncated. |
| `checks` | Ordered `RecordHealthCheckDefinition` list (`developerName`, `label`, `description`, `priority`, `dependsOnCheckDeveloperName`). |

## 10. Reason Codes

| Reason Code | Meaning |
| ----------- | ------- |
| `CONFIG_NOT_FOUND` | Check Set or Rule could not be found. |
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
| `MULTIPLE_ROWS_RETURNED` | A scalar check received multiple rows. |
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
| `CIRCULAR_DEPENDENCY` | Circular `RequiresCheck__c` graph; all surfaces return `UNABLE_TO_EVALUATE`. |
| `CLIENT_CALL_FAILED` | LWC `evaluateCheck` Aura call threw before a result was returned. |
| `SETUP_REQUIRED` | Component `configName` is blank. |
| `MISSING_REQUIRED_FIELD` | `RecordHealthCheckMetadataValidator` deployment-time validation. |
| `INVALID_DEPENDENCY` | Validator dependency graph validation. |
| `CHECK_LIMIT_EXCEEDED` | Metadata Validator only: Check Set has more than 25 active Rules; only the first 25 run. |
