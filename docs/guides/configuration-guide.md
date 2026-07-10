# Record Health Check Configuration Guide

This guide explains how Check Sets and Rules wire to the Lightning record page card, how to choose a Check Type, and how to troubleshoot common misconfigurations. The card is advisory: it shows pass, fail, skipped, unable, or error for each Rule without blocking saves or persisting results. Prerequisites: Custom Metadata edit access in Setup and a deployed `recordHealthCheck` component.

> [!NOTE]
> **Setup labels vs API names:** Each table lists the **Setup label** you see in the metadata editor, the **API name** (`__c` or `DeveloperName`), and what to enter. Use the Setup label in conversation and checklists: for example **Check Type**, not informal terms like “check type.”

## Contents

| Section | What it covers |
| ------- | -------------- |
| [1. Mental model](#1-mental-model) | Check Set, Rule, and component wiring |
| [2. What it can check](#2-what-it-can-check) | Choosing the right Check Type |
| [3. Check Set fields](#3-check-set-fields) | Link to [Check Set field reference](../metadata/check-set.md) |
| [4. Rule fields](#4-rule-fields) | Link to [Rule field reference](../metadata/rule-fields.md) and action links |
| [5. Result meanings](#5-result-meanings) | Status and severity |
| [6. Formula rules](#6-formula-rules) | Record-formula patterns |
| [7. Query rules](#7-query-rules) | Single-query patterns |
| [8. Compare two queries rules](#8-comparetwoqueries-rules) | Dual-query patterns |
| [9. Apex rules](#9-apex-rules) | Use custom Apex patterns |
| [10. Applicability and dependencies](#10-applicability-and-dependencies) | Gating and prerequisites |
| [11. Merge tokens](#11-merge-tokens) | `{!Field}` in messages and SOQL |
| [12. Security and guardrails](#12-security-and-guardrails) | SOQL safety and permissions |
| [13. Troubleshooting](#13-troubleshooting) | Symptoms, causes, and fixes |
| [14. Review checklist](#14-review-checklist) | Pre-activation validation |
| [15. Runtime and integration](#15-runtime-and-integration) | Stack, programmatic API, edge cases |

For copy-paste examples of every pattern, see [Examples](../examples/index.md). For the formal contract, see [Design Specification](../reference/record-health-check-design-spec.md). For setup walkthrough, see [Getting Started](../installation/getting-started.md). For action link examples, see [Action Links and Fix Instructions](action-links.md). For Show Troubleshooting Details, see [Show Troubleshooting Details](debug-mode.md).

## 1. Mental Model

| Piece | What it means |
| ----- | ------------- |
| Component instance | The Lightning record page component. It points to one Check Set through the **Check Set** picker in App Builder (`checkSetName` in the LWC, sent to Apex as `configName`). |
| Check Set | A group of Rules for one base object (for example, Account). Stored in `Record_Health_Check_Set__mdt`. |
| Rule | One individual check inside a Check Set. Stored in `Record_Health_Check_Rule__mdt`. |
| Evaluator | The engine path for a Rule: Formula, Query, CompareTwoQueries, or Apex. |
| Result | The outcome shown after a Rule runs. |

Wiring example:

```text
Lightning component Check Set: Account_Data_Quality
Check Set DeveloperName: Account_Data_Quality
Rule DeveloperName: Account_DQ_BillingCity
```

**Where to place the component:** Lightning **record pages** only. The component needs a record context (`recordId`). It is not exposed on App or Home pages.

**App Builder property:** Select a **Check Set** from the dropdown. It lists the active Check Sets whose object matches this record page, by `DeveloperName`. When the object has exactly one active Check Set, it is selected for you. This is the only property; comparison expanders start collapsed and follow the Check Set's **Found/Expected Display** setting.

## 2. What It Can Check

| Check Type (Setup label) | API value | Use when |
| -------------------------- | --------- | -------- |
| **Check fields on this record** | `Formula` | The answer is on the current record (or a parent field reachable by formula). |
| **Check records with a query** | `Query` | One SOQL result must be compared to a static value, formula, second query, or list. |
| **Compare two queries** | `CompareTwoQueries` | Two independent SOQL results must be compared (scalar or list). |
| **Use custom Apex** | `Apex` | Logic needs code (multi-object date math, scoring, external callouts in a custom plugin). |

Representative Account patterns (full walkthrough in the [Examples index](../examples/index.md)):

- Formula: Billing City is required.
- Formula + applicability: Partner Accounts must have Billing Country; others are skipped.
- Query + OneResult: Account has at least one Contact.
- Query + AnyRowPasses: At least one open Opportunity exceeds 10% of Annual Revenue.
- CompareTwoQueries: Contact count equals open Opportunity count.
- Dependency: Contact Email checked only after "has Contacts" passes.
- Apex: Recent activity via shipped class `AccountHasRecentActivityCheck`.

## 3. Check Set Fields

Every field on `Record_Health_Check_Set__mdt`: including picklist values for **Start Checks**, **Found/Expected Display**, display modes, and **Show Troubleshooting Details**: is documented in **[Check Set fields](../metadata/check-set.md)**.

## 4. Rule Fields

Every field on `Record_Health_Check_Rule__mdt` is documented in **[Rule fields](../metadata/rule-fields.md)**. Optional **Category** is metadata-only for now (UI grouping planned). Optional **Fix Instructions** and primary action fields render as read-only guidance on failed checks. Examples: [Action Links and Fix Instructions](action-links.md).

## 5. Result Meanings

| Status | Meaning | Typical response |
| ------ | ------- | ---------------- |
| `PASS` | Rule ran and passed. | No action. |
| `FAIL` | Rule ran and found a data issue. | Record or process owner. |
| `SKIPPED` | Rule did not apply or dependency did not pass. | Review applicability or dependencies if unexpected. |
| `UNABLE_TO_EVALUATE` | Metadata, permissions, SOQL, or data blocked safe evaluation. | Review configuration, FLS, and reason code. |
| `ERROR` | Unexpected framework or Apex exception. | Review the Apex plugin, Salesforce logs, and reason code. |

| Severity | Use when |
| -------- | -------- |
| `Error` | Important problem to fix. |
| `Warning` | Should be reviewed. |
| `Info` | Contextual information. |

Severity applies **only** to `FAIL` results.

## 6. Formula Rules

Use Formula when the result is expressible with Salesforce formula syntax on the current or parent record.

- `null` formula result (for example, `Parent.Field` with no parent) → **Unable To Evaluate**, not Fail.
- Only explicit `false` fails the check.

Billing City required:

```text
PassFailFormula__c: NOT(ISBLANK(BillingCity))
MessageWhenFailed__c: {!Name} is missing Billing City.
```

Phone or Website required:

```text
PassFailFormula__c: OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))
MessageWhenFailed__c: {!Name} needs either a Phone or Website.
```

### Formula operands can be formula or roll-up fields

`PassFailFormula__c` (and the optional formulas below) may reference **calculated fields** — formula fields, roll-up summaries, and even formulas of formulas — at any depth, for any type (number, text, date, boolean, picklist) and any standard function. The engine loads the whole dependency chain, so you reference the field API names you use in Setup; you do **not** rewrite checks to point at the underlying source fields.

### Showing Found vs Expected (optional)

By default a Formula check shows only a **Passes when** line — the pass/fail formula text, unquoted — and no **Found** value. That **Passes when** line is **Advanced-tier**: users without `Record_Health_Check_View_Details` see the failure message only (plus any display-formula Found/Expected chips). For balance and comparison checks you can declare two optional scalar formulas so the row shows readable numbers (or text/dates) on each side, like a Query check:

| Field | Purpose |
| ----- | ------- |
| `FoundValueFormula__c` | Scalar formula → **Found** (left side — what the record has). |
| `ExpectedValueFormula__c` | Scalar formula → **Expected** (right side — required or target value). |

`PassFailFormula__c` still decides pass/fail (it must return Boolean); these two are display-only and additive.

> **Found and Expected are not compared to each other.** The engine evaluates each independently and displays them. `PassFailFormula__c` performs the actual comparison (`FieldA = FieldB`, `Total >= 50000`, …) and is the only thing that determines pass/fail. If you put a formula in Found/Expected, it does **not** affect the result — it only changes what the row displays. There is no separate "formula comparison operator" setting: the comparison lives inside `PassFailFormula__c`.

```text
PassFailFormula__c:      BLANKVALUE(Debit_Total__c, 0) = BLANKVALUE(Credit_Total__c, 0)
FoundValueFormula__c:    BLANKVALUE(Debit_Total__c, 0)
ExpectedValueFormula__c: BLANKVALUE(Credit_Total__c, 0)
```

On a failing row this renders **Found "100"** / **Expected "75"** instead of echoing the formula.

> [!CAUTION]
> **Keep Found/Expected consistent with Pass Condition (Formula).** Because the engine does not compare the two sides itself, nothing stops you from showing values that disagree with the actual result. If `PassFailFormula__c` compares A to B, use A for `FoundValueFormula__c` and B for `ExpectedValueFormula__c`. Otherwise a row can **pass while Found ≠ Expected** or fail while the values look equal. A safe habit: copy each side of the comparison in `PassFailFormula__c` verbatim into the matching display formula.

- **When to use boolean-only:** the formula is a simple presence/condition check (`NOT(ISBLANK(...))`, `ISPICKVAL(...)`) where echoing the condition as Expected is enough.
- **When to add Found/Expected:** the formula compares two values (balance, threshold, equality, date) and seeing both sides is more actionable than the formula text.
- Leave both blank to keep the original behavior (Expected = quoted `PassFailFormula__c`, no Found).
- If a Found/Expected formula can't be resolved, the row silently falls back to the default display — it never changes pass/fail.
- Set **Scalar Formula Return Type** to the formulas' type (e.g. Number) to save FormulaEval calls in bulk/Flow runs; leave Auto if unsure.

### Which check type compares what?

If you want the *framework* to compare two sides with an operator (rather than encoding the comparison inside a formula), use a **Query** check — `CompareAgainst__c` already supports three right-hand sources:

| You want to compare… | Check Type | How |
| -------------------- | ------------ | --- |
| A SOQL result vs a **fixed value** | Check records with a query | `CompareAgainst__c = FixedValue`, set `FixedValue__c` |
| A SOQL result vs a **record formula** | Check records with a query | `CompareAgainst__c = RecordFormula`, set `RecordFormulaValue__c` |
| A SOQL result vs **another SOQL result** | Check records with a query / Compare two queries | `CompareAgainst__c = AnotherQuery` (or the Compare-two-queries method) |
| Two values **on the record** (formula vs formula, or formula vs fixed value) | Check fields on this record | Encode the comparison in `PassFailFormula__c`; optionally add Found/Expected to display each side |

So "compare SOQL to a formula" and "compare SOQL to a fixed value" are existing Query-check features — no new setting is needed. Formula checks compare inside `PassFailFormula__c`; Found/Expected only make that comparison *readable*.

## 7. Query Rules

Use Query when one SOQL result is the primary value.

At least one Contact:

```text
DataQuery__c: SELECT COUNT() FROM Contact WHERE AccountId = {!Id}
WhenMultipleRows__c: OneResult
Operator__c: GreaterThan
CompareAgainst__c: FixedValue
FixedValue__c: 0
```

Supported aggregates (alias required except bare `COUNT()`):

```text
COUNT(), COUNT(field), COUNT_DISTINCT(field), SUM(field), AVG(field), MIN(field), MAX(field)
```

SUM equals 10% of Annual Revenue:

```text
DataQuery__c: SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!Id} AND IsClosed = false
FieldToRead__c: totalAmount
WhenMultipleRows__c: OneResult
Operator__c: Equals
CompareAgainst__c: RecordFormula
RecordFormulaValue__c: AnnualRevenue * 0.1
```

## 8. CompareTwoQueries Rules

Use when both sides come from SOQL.

- `OneResult` + scalar comparators for single values.
- `CompareAsLists` + `ListsOverlap`, `ListContainsAll`, or `ExactListMatch` for lists (**case-insensitive** list matching; `Contains` / `DoesNotContain` on scalar text are **case-sensitive**).

Contact count equals open Opportunity count:

```text
DataQuery__c: SELECT COUNT() FROM Contact WHERE AccountId = {!Id}
CompareToQuery__c: SELECT COUNT() FROM Opportunity WHERE AccountId = {!Id} AND IsClosed = false
WhenMultipleRows__c: OneResult
Operator__c: Equals
```

## 9. Apex Rules

Use Apex when metadata cannot express the rule safely. **Implementing a class:** [Apex plugin reference](../apex/plugin-reference.md). **Walkthroughs:** [examples catalog](../examples/index.md#example-catalog). **Contract:** [Apex plugin contract](../apex/plugin-contract.md).

**Shipped example classes:** `AccountHasRecentActivityCheck`, `AccountOpenOpportunityHealthCheck`. Deploy custom classes (for example the strategic readiness reference in [example 3](../examples/apex/03-strategic-readiness.md)) before referencing them in **Apex Class Name**.

| Setup label | API name | Role |
| ----------- | -------- | ---- |
| Apex Class Name | `ApexClass__c` | Class implementing `RecordHealthCheckRule` |
| Apex Settings (JSON) | `ApexSettingsJson__c` | Optional tuning map passed as `context.parameters` |

For AI-assisted drafting, see [LLM Configuration Guide: Apex](llm-configuration.md#54-apex-checkmethod__c-apex) and [recent-activity Apex pattern](llm-configuration.md#106-recent-taskevent-activity-apex-multi-object).

## 10. Applicability and Dependencies

**Applicability**: does this Rule run for this record?

| Mode | When to use |
| ---- | ----------- |
| All records | Universal data quality rules. |
| `Formula` | Condition is on the record (for example, `ISPICKVAL(Type, "Partner")`). |
| `SOQL` | Condition needs a related COUNT (for example, at least one open Opportunity exists). |

**Dependencies**: does this Rule wait for another Rule to pass?

Set **Prerequisite Check (Developer Name)** to the prerequisite `DeveloperName`. Use sparingly for checks that are misleading unless a foundation check passed first.

## 11. Merge Tokens

Messages and SOQL may use any readable field on the base record: **standard or custom**: by API name:

```text
{!Id}
{!Name}
{!BillingCity}
{!Parent.Name}
{!Customer_Tier__c}
{!Primary_Contact__c}
{!Contract_Renewal_Date__c}
```

- Use field API names exactly as shown in Setup (custom fields include the `__c` suffix).
- Missing message tokens become blank text.
- SOQL tokens are escaped and typed by the framework (strings quoted, numbers/dates/booleans unquoted).
- The engine loads every token field from the record before evaluation; if the running user lacks FLS, the check may return `RECORD_NOT_ACCESSIBLE` or `MISSING_BIND_VALUE`.

SOQL examples live in the [SOQL examples catalog](../examples/index.md#soql-single-query).

## 11a. Multi-line messages

**Message When Check Fails** and **Message When Check Cannot Run** support multiple lines. Press **Enter** in Setup to start a new line; each line renders as a separate line on the card. Use a blank line (press Enter twice) to add spacing between paragraphs.

```text
{!Name} is out of balance.

Debit total: {!Debit_Total__c}
Expected credit net: {!Credit_Net__c}

Contact Finance to reconcile.
```

- Merge tokens work on any line.
- Single-line messages are unchanged: no extra spacing is added.
- Messages are always plain text (HTML and links are not rendered), and screen readers announce the lines as one sentence with a pause between them.

## 12. Security and Guardrails

- Sharing, CRUD, and field access apply (`WITH USER_MODE` on dynamic SOQL).
- Keep queries narrow: clear `WHERE` clauses, merge tokens instead of hard-coded Ids.
- Editing `Record_Health_Check_Rule__mdt` is a privileged operation: anyone with Rule edit access can run SOQL as the viewing user.
- Do not put secrets or stack traces in user-facing messages.
- Unsafe SOQL (DML keywords, `FOR UPDATE`, `ALL ROWS`) is rejected.

## 13. Troubleshooting

| Symptom | Likely cause | What to check |
| ------- | ------------ | ------------- |
| Health Check Needs Setup / not ready yet | LWC has no Check Set selected | In App Builder, choose a Check Set and save the page. |
| Ask admin to activate a Check Set | Check Sets exist for the object but all are inactive | Activate a Check Set, then choose it in App Builder. |
| Ask admin to set up a Check Set | No Check Set matches the page object | Create and activate a Check Set whose Record Object API Name matches the page object. |
| Check Set was not found | Selected Check Set was renamed or deleted | Re-open App Builder and choose an active Check Set. |
| Check Set is inactive | Selected Check Set has `IsActive__c = false` | Activate it, or choose another active Check Set. |
| Invalid configuration | Blank/invalid Record Object API Name, or a bad display setting | Record Object API Name plus Passed/Skipped Checks Display, Run Checks When, How Checks Appear, Comparison Display. |
| Object mismatch | Check Set `ObjectApiName__c` does not match the page object | Check Set object vs record page object. |
| No active checks | Check Set has no active Rules (inactive Rules may still exist) | Activate an existing Rule, or add a new active Rule. |
| No checks run | Inactive Check Set or Rules | `IsActive__c` on Set and Rules. |
| Rule skipped | Applicability false or required check did not pass | Applicability fields and `RequiresCheck__c`. |
| Unable to Check | SOQL, formula, permissions, or limits | Rule fields, FLS, Show Troubleshooting Details, reason code. |
| System Error | Apex or framework exception | Apex class, Salesforce logs, and Show Troubleshooting Details. |
| Stale results after metadata edit | Component not reloaded | Refresh the record page. |
| Stale results after inline edit | No auto-rerun on record save | Click **Rerun** or refresh the page. |
| Prerequisite skipped | 25-check cap | Lower the prerequisite's Run Order (lower runs first) so it runs within the first 25, or reduce active Rules. |
| Custom automation runs slowly or hits limits | Each `RecordHealthCheck.run` call is one full evaluation | Reduce batch size; evaluate fewer Rules per transaction; monitor Salesforce logs. There is no packaged Flow invocable: only custom Apex. |
| Check passes in UI but fails from custom automation | Different running user (FLS) | Automation runs as the integration or invoking user: verify field access. |

For reason codes and open limitations, see [Design Specification: reason codes and open limitations](../reference/record-health-check-design-spec.md#10-reason-codes).

Pre-deployment metadata audit:

```apex
for (RecordHealthCheckMetadataValidator.ValidationIssue i :
        new RecordHealthCheckMetadataValidator().validate()) {
    System.debug(i.severity + ' ' + i.componentName + '.' + i.fieldName + ': ' + i.message);
}
```

## 14. Review Checklist

Before activating a Check Set:

- [ ] Permission Set `Record_Health_Check_User` assigned to users who run the card (assign `Record_Health_Check_Admin` when Show Troubleshooting Details is needed).
- [ ] Component **Check Set** selection points to the intended active Check Set.
- [ ] `ObjectApiName__c` matches the record page object.
- [ ] Component is on a **record page** (not App/Home).
- [ ] Every active Rule has Check Name, Run Order (lower runs first), Check Type, Failure Severity, and Message When Check Fails.
- [ ] Longer panels use Category consistently for authoring (UI grouping not implemented yet), or leave it blank to group checks as Uncategorized.
- [ ] Any Fix Instructions or Action Button URL are advisory/read-only. They can guide users on failed checks, but Record Health Check does not update records.
- [ ] **Found/Expected Display** matches the amount of Found/Expected detail users need (`On demand` for audit-friendly panels, `Failed checks only` for compact pass checks).
- [ ] Check records with a query and Compare two queries Rules have required query fields and **How To Interpret Query Results** set appropriately.
- [ ] `WhenZeroRows__c` is set for Any/All/CompareAsLists Rules.
- [ ] Apex Rules reference deployed `RecordHealthCheckRule` implementations.
- [ ] Dependencies reference active Rules with lower Run Order (lower runs first) in the same Check Set.
- [ ] **Show Troubleshooting Details** is off for production unless actively troubleshooting (requires `Record_Health_Check_View_Details` via `Record_Health_Check_Admin`: see [Troubleshooting Details](debug-mode.md)).
- [ ] Tested on records that pass, fail, skip, and unable-to-evaluate.

## 15. Runtime and Integration

**Stack:** Custom Metadata → Apex (Constants, Config Service, Engine, Evaluators, SoqlTemplate, ValueResolver, Logger) → LWC. Programmatic entry is the `RecordHealthCheck` façade; there is no packaged Flow invocable.

**Runtime flow (record page):**

1. LWC calls `getCheckDefinitions(configName, recordId, runId)` (not cacheable).
2. Apex loads active Check Set, validates object, returns ordered Rule definitions.
3. LWC orchestrates runs (dependencies, concurrency, display modes, run token).
4. Apex evaluates each Rule (applicability, dependencies, evaluator routing).
5. LWC renders results and summaries.

**Programmatic flow (Apex):**

1. Caller invokes `RecordHealthCheck.run` with Check Set name, Rule name, and record Id.
2. Façade logs `RUN_INVOKED`, delegates to the engine (same path as LWC `evaluateCheck`).
3. Result returned: catchable failures normalize to result statuses; uncatchable governor limits behave like any Apex API.

**Boundaries:**

- Record-page results live in component state for the session; nothing is persisted.
- Read-only: no record mutations from evaluation.
- Formula checks require API v63.0+ (FormulaEval). Package source API version is 66.0.
- Up to **5** concurrent Apex evaluations per LWC run (queued beyond that) when Stop After System Error is off; fully sequential when it is on.
- Each programmatic call (`RecordHealthCheck.run` or one Flow input row) is its own evaluation: bulk flows multiply governor cost.
- `recordId` changes after connect reload definitions; record-save does not auto-rerun checks.
- Server-side dependency gate re-evaluates prerequisites (safe for direct Apex calls; may duplicate work from the LWC path).
- Unsupported Apex plugin status strings are rejected with `APEX_EVALUATOR_ERROR`.
- All framework logs use `[RHC]` prefix with `runId` and running-user attribution via `RecordHealthCheckLogger`.

**Edge cases to plan for:**

| Scenario | Behavior |
| -------- | -------- |
| Child subquery with inner `ORDER BY`/`LIMIT` on any query-based check | Handled by depth-0-aware `RecordHealthCheckSoqlTemplate` on all paths |
| Multi-select picklist tokens | Unquoted `{!Field}` on a resolved multi-select expands to `('A', 'B')`; quoted `'{!Field}'` keeps `'A;B;C'`. Relationship paths follow the same rules when the related record is loaded. |
| Same `{!Field}` token used quoted and unquoted in one SOQL template | Each form substituted independently (2026-06-22). `Name LIKE '{!Name}%'` works when the exact `'{!Name}'` substring appears in the template. |
| Null field on existing row (multi-row Query) | Rows returned but value null + `SkipRecordsWithMissingValue` → **SKIPPED** / `VALUE_IS_EMPTY` (not `WhenZeroRows__c`) |
| CompareTwoQueries empty query side (OneResult) | Governed by **`WhenZeroRows__c`** before null-field logic: distinct from null on a returned row |
| Semicolon-only multi-select bind | Value `;` alone can produce invalid `INCLUDES ()` SOQL: avoid blank multi-select values in bind tokens |
| Apex plugin `context.record` | Engine loads merge/formula fields referenced in messages and applicability; plugins needing other fields must query by `context.recordId` |
| Managed-package Apex class names | `Type.forName` without namespace may not resolve classes in a managed namespace: use fully qualified API names when required |
| Prerequisite Rule outside the 25-check cap | Dependents skip with `DEPENDENCY_NOT_IN_RUN` (LWC only) |
| Stop After System Error | Stops only on `ERROR`, not `FAIL` or `UNABLE_TO_EVALUATE` |
| Empty multi-row query result | Defaults to `Skip` when `WhenZeroRows__c` is blank |
| Static comparison values with locale formatting | Untyped text: may fall through to string comparison |

## Related

- [Getting Started](../installation/getting-started.md): first install and first Rule
- [Examples index](../examples/index.md): copy-paste patterns
- [Design Specification](../reference/record-health-check-design-spec.md): formal contract
