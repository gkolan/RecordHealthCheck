# Record Health Check configuration guide

This guide explains how Check Sets and Rules wire to the Lightning record page card, how to choose an Evaluation Type, and how to troubleshoot common misconfigurations. The card is advisory: it shows pass, fail, skipped, unable, or error for each Rule without blocking saves or persisting results. Prerequisites: Custom Metadata edit access in Setup and a deployed `recordHealthCheck` component.

> [!NOTE]
> **Setup labels vs API names:** Each table lists the **Setup label** you see in the metadata editor, the **API name** (`__c` or `DeveloperName`), and what to enter. Use the Setup label in conversation and checklists: for example **Evaluation Type**, not informal terms like “check type.”

## Contents

| Section | What it covers |
| ------- | -------------- |
| [1. Mental model](#1-mental-model) | Check Set, Rule, and component wiring |
| [2. What it can check](#2-what-it-can-check) | Choosing the right Evaluation Type |
| [3. Check Set fields](#3-check-set-fields) | Link to [Check Set field reference](../metadata/check-set.md) |
| [4. Rule fields](#4-rule-fields) | Link to [Rule field reference](../metadata/rule-fields.md) and action links |
| [5. Result meanings](#5-result-meanings) | Status and severity |
| [6. Formula rules](#6-formula-rules) | Record-formula patterns |
| [7. Query rules](#7-query-rules) | Single-query patterns |
| [8. Compare two queries rules](#8-compare-two-queries-rules) | Dual-query patterns |
| [9. Apex rules](#9-apex-rules) | Use custom Apex patterns |
| [10. Applicability and dependencies](#10-applicability-and-dependencies) | Gating and prerequisites |
| [11. Merge tokens](#11-merge-tokens) | `{!record.Field}` in messages and SOQL |
| [12. Security and guardrails](#12-security-and-guardrails) | SOQL safety and permissions |
| [13. Troubleshooting](#13-troubleshooting) | Symptoms, causes, and fixes |
| [14. Review checklist](#14-review-checklist) | Pre-activation validation |
| [15. Runtime and integration](#15-runtime-and-integration) | Stack, programmatic API, edge cases |

For ready-to-deploy patterns, use the
[RecordHealthCheck-Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/catalog).
For detailed behavior, see the [Design specification](../reference/record-health-check-design-spec.md).

For setup, see [Getting started](../installation/getting-started.md). For action-link patterns, see
[Action links and Fix Message](action-links.md). For troubleshooting detail, see
[Show Diagnostics](show-diagnostics.md).

## 1. Mental Model

| Piece | What it means |
| ----- | ------------- |
| Component instance | The Lightning record page component. It points to one Check Set through the **Check Set** picker in App Builder (`checkSetName` in the LWC, sent to Apex as `checkSetDeveloperName`). |
| Check Set | A group of Rules for one base object (for example, Account). Stored in `Record_Health_Check_Set__mdt`. |
| Rule | One individual check inside a Check Set. Stored in `Record_Health_Check_Rule__mdt`. |
| Evaluation Type | How a Rule checks the record: Formula, Query, Compare Two Queries, or Apex. |
| Result | The outcome shown after a Rule runs. |

Wiring example:

```text
Lightning component Check Set: Example_Account_360_Health_Check
Check Set DeveloperName: Example_Account_360_Health_Check
Rule DeveloperName: Example_Recent_Activity
```

**Where to place the component:** Lightning **record pages** only. The component needs a record context (`recordId`). It is not exposed on App or Home pages.

**App Builder property:** Select a **Check Set** from the dropdown. It lists the active Check Sets whose object matches this record page, by `DeveloperName`. When the object has exactly one active Check Set, it is selected for you. This is the only property; comparison expanders start collapsed and follow the Check Set's **Found/Expected Display** setting.

## 2. What It Can Check

| Evaluation Type (Setup label) | API value | Use when |
| -------------------------- | --------- | -------- |
| **Verify with a formula** | `FORMULA` | The answer is on the current record (or a parent field reachable by formula). |
| **Verify with a query** | `QUERY` | One SOQL result must be compared to a static value, formula, second query, or list. |
| **Compare two queries** | `COMPARE_TWO_QUERIES` | Two independent SOQL results must be compared (single value or list). |
| **Verify with Apex** | `APEX` | Logic needs code (multi-object date math, scoring, external callouts in a custom plugin). |

Representative Account patterns (deployable versions are in the
[Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/catalog)):

- Formula: Billing City is required.
- Formula + applicability: Partner Accounts must have Billing Country; others are skipped.
- Query + `ONE_RESULT`: Account has at least one Contact.
- Query + `ANY_ROW_PASSES`: At least one open Opportunity exceeds 10% of Annual Revenue.
- `COMPARE_TWO_QUERIES`: Contact count equals open Opportunity count.
- Dependency: Contact Email checked only after "has Contacts" passes.
- Apex: Recent activity via an implementation from the Examples repository.

## 3. Check Set Fields

Every field on `Record_Health_Check_Set__mdt`: including picklist values for **When Checks Run**, **Found/Expected Display**, display modes, and **Show Diagnostics**: is documented in **[Check Set fields](../metadata/check-set.md)**.

## 4. Rule Fields

Every field on `Record_Health_Check_Rule__mdt` is documented in **[Rule fields](../metadata/rule-fields.md)**. Optional **Category** is metadata-only for now; the V2 card does not group rows by it. Optional **Fix Message**, **Action Label**, and **Action URL** fields render guidance and navigation on failed checks. Examples: [Action links and Fix Message](action-links.md).

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
| Critical (`CRITICAL`) | Important problem to fix. |
| Warning (`WARNING`) | Should be reviewed. |
| Info (`INFO`) | Contextual information. |

Severity applies **only** to `FAIL` results.

## 6. Formula Rules

Use Formula when the result is expressible with Salesforce formula syntax on the current record or
its parent relationships. Start with the [Formula example](../checks/formula-example.md); use the
[Formula reference](../checks/formula-reference.md) for the complete contract.

- `null` formula result (for example, `Parent.Field` with no parent) → **Unable To Evaluate**, not Fail.
- Only explicit `false` fails the check.

Use this one example as the model for a meaningful Formula Rule. It combines three business
requirements and traverses two parent levels. The Account passes when it has a contact channel, has
a billing country, and its revenue is at least 10% of the top-level portfolio Account's revenue.

```text
EvaluationType__c: FORMULA
PassConditionFormula__c: AND(
  OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website))),
  NOT(ISBLANK(BillingCountry)),
  AnnualRevenue >= Parent.Parent.AnnualRevenue * 0.10
)
DisplayFoundFormula__c: AnnualRevenue
DisplayExpectedFormula__c: Parent.Parent.AnnualRevenue * 0.10
FormulaResultType__c: NUMBER
FailureMessage__c: {!record.Name} needs a contact channel, billing country, and revenue equal to at least 10% of its top-level portfolio account.
```

If either parent relationship or a required revenue value is unavailable, the Rule cannot reach a
reliable conclusion and returns **Unable to Evaluate**. Use a shallower path when the object model
does not guarantee two Account parents.

### Formula operands can be formula or roll-up fields

`PassConditionFormula__c` (and the optional formulas below) may reference **calculated fields** — formula fields, roll-up summaries, and even formulas of formulas — at any depth, for any type (number, text, date, boolean, picklist) and any standard function. The engine loads the whole dependency chain, so you reference the field API names you use in Setup; you do **not** rewrite checks to point at the underlying source fields.

### Showing Found vs Expected (optional)

By default a Formula check shows only a **Passes when** line — the pass/fail formula text, unquoted — and no **Found** value. That **Passes when** line is **Advanced-tier**: users without `Record_Health_Check_View_Details` see the failure message only (plus any display-formula Found/Expected chips). For balance and comparison checks you can declare two optional single-value formulas so the row shows readable numbers (or text/dates) on each side, like a Query check:

| Field | Purpose |
| ----- | ------- |
| `DisplayFoundFormula__c` | single-value formula → **Found** (left side — what the record has). |
| `DisplayExpectedFormula__c` | single-value formula → **Expected** (right side — required or target value). |

`PassConditionFormula__c` still decides pass/fail (it must return Boolean); these two are display-only and additive.

> **Found and Expected are not compared to each other.** The engine evaluates each independently and displays them. `PassConditionFormula__c` performs the actual comparison (`FieldA = FieldB`, `Total >= 50000`, …) and is the only thing that determines pass/fail. If you put a formula in Found/Expected, it does **not** affect the result — it only changes what the row displays. There is no separate "formula comparison operator" setting: the comparison lives inside `PassConditionFormula__c`.

In the example above, a failing row displays the Account's revenue as **Found** and 10% of the
grandparent Account's revenue as **Expected**, while the complete Boolean formula remains the only
pass/fail decision.

> [!CAUTION]
> **Keep Found/Expected consistent with Pass Condition.** Because the engine does not compare the two sides itself, nothing stops you from showing values that disagree with the actual result. If `PassConditionFormula__c` compares A to B, use A for `DisplayFoundFormula__c` and B for `DisplayExpectedFormula__c`. Otherwise a row can **pass while Found ≠ Expected** or fail while the values look equal. A safe habit: copy each side of the comparison in `PassConditionFormula__c` verbatim into the matching display formula.

- **When to use boolean-only:** the formula is a simple presence/condition check (`NOT(ISBLANK(...))`, `ISPICKVAL(...)`) where echoing the condition as Expected is enough.
- **When to add Found/Expected:** the formula compares two values (balance, threshold, equality, date) and seeing both sides is more actionable than the formula text.
- Leave both blank to keep the original behavior (Expected = quoted `PassConditionFormula__c`, no Found).
- If a Found/Expected formula can't be resolved, the row silently falls back to the default display — it never changes pass/fail.
- Set **single-value formula Return Type** to the formulas' type (e.g. Number) to save FormulaEval calls in bulk/Flow runs; leave Auto if unsure.

### Which check type compares what?

If you want the *framework* to compare two sides with an operator (rather than encoding the comparison inside a formula), use a **Query** check — `ExpectedValueSource__c` already supports three right-hand sources:

| You want to compare… | Evaluation Type | How |
| -------------------- | ------------ | --- |
| A SOQL result vs a **fixed value** | Verify with a query | `ExpectedValueSource__c = FIXED_VALUE`, set `ExpectedFixedValue__c` |
| A SOQL result vs a **record formula** | Verify with a query | `ExpectedValueSource__c = RECORD_FORMULA`, set `ExpectedRecordFormula__c` |
| A SOQL result vs **another SOQL result** | Check records with a query / Compare two queries | `ExpectedValueSource__c = COMPARISON_QUERY` (or the Compare-two-queries method) |
| Two values **on the record** (formula vs formula, or formula vs fixed value) | Verify with a formula | Encode the comparison in `PassConditionFormula__c`; optionally add Found/Expected to display each side |

So "compare SOQL to a formula" and "compare SOQL to a fixed value" are existing Query-check features — no new setting is needed. Formula checks compare inside `PassConditionFormula__c`; Found/Expected only make that comparison *readable*.

## 7. Query Rules

Use Query when one SOQL result is the primary value. Start with the
[Query example](../checks/query-example.md); use the [Query reference](../checks/query-reference.md)
for result modes and edge cases.

At least one Contact:

```text
SourceQuery__c: SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}
QueryResultHandling__c: ONE_RESULT
ComparisonOperator__c: GREATER_THAN
ExpectedValueSource__c: FIXED_VALUE
ExpectedFixedValue__c: 0
```

Supported aggregates (alias required except bare `COUNT()`):

```text
COUNT(), COUNT(field), COUNT_DISTINCT(field), SUM(field), AVG(field), MIN(field), MAX(field)
```

SUM equals 10% of Annual Revenue:

```text
SourceQuery__c: SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
SourceQueryField__c: totalAmount
QueryResultHandling__c: ONE_RESULT
ComparisonOperator__c: Equals
ExpectedValueSource__c: RECORD_FORMULA
ExpectedRecordFormula__c: AnnualRevenue * 0.1
```

## 8. Compare Two Queries Rules

Use when both sides come from SOQL. Start with the
[Compare two queries example](../checks/compare-two-queries-example.md); use the
[Compare two queries reference](../checks/compare-two-queries-reference.md) for the complete
contract.

- `ONE_RESULT` + single-value operators for single values.
- `COMPARE_AS_LISTS` + `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, or `LISTS_MATCH_EXACTLY` for lists (**case-insensitive** list matching; `CONTAINS` / `DOES_NOT_CONTAIN` on single-value text are **case-sensitive**).

Contact count equals open Opportunity count:

```text
SourceQuery__c: SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}
ComparisonQuery__c: SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
QueryResultHandling__c: ONE_RESULT
ComparisonOperator__c: Equals
```

## 9. Apex Rules

Use Apex when metadata cannot express the Rule safely. See the
[Apex reference](../apex/apex-reference.md), the
[Apex examples](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/apex-advanced-checks),
and the [Apex example](../apex/apex-example.md).

**Examples-repository classes:** `AccountHasRecentActivityCheck` and
`AccountOpenOpportunityHealthCheck`. Install their pack before referencing either class in
**Apex Class**.

| Setup label | API name | Role |
| ----------- | -------- | ---- |
| Apex Class | `ApexClass__c` | Class implementing `RecordHealthCheckRule` |
| Apex Parameters (JSON) | `ApexParametersJson__c` | Optional tuning map passed as `context.parameters` |

For AI-assisted drafting, see [LLM Configuration Guide: Apex](llm-configuration.md#54-apex-evaluationtype__c--apex) and [recent-activity Apex pattern](llm-configuration.md#106-recent-taskevent-activity-apex-multi-object).

## 10. Applicability and Dependencies

**Applicability**: does this Rule run for this record?

| Mode | When to use |
| ---- | ----------- |
| All records | Universal data quality rules. |
| `FORMULA` | Condition is on the record (for example, `ISPICKVAL(Type, "Partner")`). |
| `SOQL` | Condition needs a related COUNT (for example, at least one open Opportunity exists). |

**Dependencies**: does this Rule wait for another Rule to pass?

Set **Prerequisite Rule** to the prerequisite `DeveloperName`. Use sparingly for checks that are misleading unless a foundation check passed first.

## 11. Merge Tokens

Messages and SOQL may use any readable field on the base record: **standard or custom**: by API name:

```text
{!record.Id}
{!record.Name}
{!record.BillingCity}
{!record.Parent.Name}
{!record.Customer_Tier__c}
{!record.Primary_Contact__c}
{!record.Contract_Renewal_Date__c}
```

- Use field API names exactly as shown in Setup (custom fields include the `__c` suffix).
- Missing message tokens become blank text.
- SOQL tokens are escaped and typed by the framework (strings quoted, numbers/dates/booleans unquoted).
- The engine loads every token field from the record before evaluation; if the running user lacks FLS, the check may return `RECORD_NOT_ACCESSIBLE` or `MISSING_BIND_VALUE`.

SOQL examples live in the
[Examples repository](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs).

## 11a. Multi-line messages

**Message When Failed** and **Message When Unable To Evaluate** support multiple lines. Press **Enter** in Setup to start a new line; each line renders as a separate line on the card. Use a blank line (press Enter twice) to add spacing between paragraphs.

```text
{!record.Name} is out of balance.

Debit total: {!record.Debit_Total__c}
Expected credit net: {!record.Credit_Net__c}

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
| Ask admin to set up a Check Set | No Check Set matches the page object | Create and activate a Check Set whose Object matches the page object. |
| Check Set was not found | Selected Check Set was renamed or deleted | Re-open App Builder and choose an active Check Set. |
| Check Set is inactive | Selected Check Set has `IsActive__c = false` | Activate it, or choose another active Check Set. |
| Invalid configuration | Blank/invalid Object, or a bad display setting | Object plus Passed/Skipped Checks Display, Run Checks When, How Checks Appear, Comparison Display. |
| Object mismatch | Check Set `ObjectApiName__c` does not match the page object | Check Set object vs record page object. |
| No active checks | Check Set has no active Rules (inactive Rules may still exist) | Activate an existing Rule, or add a new active Rule. |
| No checks run | Inactive Check Set or Rules | `IsActive__c` on Set and Rules. |
| Rule skipped | Applicability false or required check did not pass | Applicability fields and `PrerequisiteRule__c`. |
| Unable to Check | SOQL, formula, permissions, or limits | Rule fields, FLS, Show Diagnostics, reason code. |
| System Error | Apex or framework exception | Apex class, Salesforce logs, and Show Diagnostics. |
| Stale results after metadata edit | Component not reloaded | Refresh the record page. |
| Stale results after inline edit | No auto-rerun on record save | Click **Rerun** or refresh the page. |
| Prerequisite skipped | 25-check cap | Lower the prerequisite's Evaluation Order so it runs within the first 25, or reduce active Rules. |
| Custom automation runs slowly or hits limits | Call caps or too many Rules × records | Stay within `MAX_RECORDS_PER_CALL` (200) and `MAX_EVALUATIONS_PER_CALL` (15); prefer `runSet` with a focused Check Set; see [Apex API](../apex/public-api.md) or [Flow actions](../flow/actions.md). |
| Check passes in UI but fails from custom automation | Different running user (FLS) | Automation runs as the integration or invoking user: verify field access. |
| Expected a lifecycle event but none arrived | Publishing is off, the run was automatic page load, or the transaction rolled back | Enable **Publish Run Event** or **Publish Result Event**; use explicit Run/Rerun, Apex, or Flow; confirm the transaction committed; see [Platform events](../reference/lifecycle-events.md). |

For reason codes, see [Reason codes](../reference/reason-codes.md).

Pre-deployment metadata audit:

```apex
for (RecordHealthCheckMetadataValidator.ValidationIssue i :
        new RecordHealthCheckMetadataValidator().validate()) {
    System.debug(i.severity + ' ' + i.componentName + '.' + i.fieldName + ': ' + i.message);
}
```

## 14. Review Checklist

Before activating a Check Set:

- [ ] Permission Set `Record_Health_Check_User` assigned to users who run the card (assign `Record_Health_Check_Admin` when Show Diagnostics is needed).
- [ ] Component **Check Set** selection points to the intended active Check Set.
- [ ] `ObjectApiName__c` matches the record page object.
- [ ] Component is on a **record page** (not App/Home).
- [ ] Every active Rule has Check Title, Evaluation Order, Evaluation Type, Failure Severity, and Message When Failed.
- [ ] Longer panels use Category consistently for authoring (UI grouping not implemented yet), or leave it blank to group checks as Uncategorized.
- [ ] Any Fix Message or Action URL are advisory/read-only. They can guide users on failed checks, but Record Health Check does not update records.
- [ ] **Found/Expected Display** matches the amount of Found/Expected detail users need (`ON_DEMAND` for audit-friendly panels, `FAILURES_ONLY` for compact pass checks).
- [ ] Verify with a query and Compare two queries Rules have required query fields and **How To Read Query Results** set appropriately.
- [ ] `NoRowsResult__c` is set for `ANY_ROW_PASSES` / `ALL_ROWS_PASS` / `COMPARE_AS_LISTS` Rules.
- [ ] Apex Rules reference deployed `RecordHealthCheckRule` implementations.
- [ ] Dependencies reference active Rules with lower Evaluation Order in the same Check Set.
- [ ] **Show Diagnostics** is off for production unless actively troubleshooting (requires `Record_Health_Check_View_Details` via `Record_Health_Check_Admin`: see [Show Diagnostics](show-diagnostics.md)).
- [ ] Lifecycle publication switches stay off until subscribers and allocations are reviewed ([Lifecycle events](../reference/lifecycle-events.md)).
- [ ] Tested on records that pass, fail, skip, and unable-to-evaluate.

## 15. Runtime and Integration

**Salesforce components:** Custom Metadata → Apex evaluation classes → Lightning Web Component.
Automation uses the public `RecordHealthCheck` Apex class or the separate Rule and Check Set Flow actions.

**Runtime flow (record page):**

1. LWC calls `getCheckDefinitions(checkSetDeveloperName, recordId, runId)` (not cacheable).
2. Apex loads active Check Set, validates object, returns ordered Rule definitions.
3. LWC orchestrates runs (dependencies, concurrency, display modes, run token).
4. Apex evaluates each Rule (applicability, dependencies, evaluator routing).
5. LWC renders results and summaries. Automatic runs publish nothing; explicit Run and Rerun
   actions publish opted-in Rule events and one opted-in Set completion event.

**Programmatic flow (Apex / Flow):**

1. Caller invokes `RecordHealthCheck.runRule`, `runSet`, Flow **Run Record Health Check Rule**, or Flow **Run Record Health Check Set**.
2. The public Apex class enforces call limits and returns `RecordHealthCheckResult` or
   `RecordHealthCheckSetResult` (`contractVersion` `1.0`).
3. When publication switches are on, `RecordHealthCheckLifecyclePublisher` emits Publish After Commit events (`APEX_API` for public Apex and `FLOW` for packaged Flow actions). See [Apex API](../apex/public-api.md), [Flow actions](../flow/actions.md), and [Platform events](../reference/lifecycle-events.md).

**Boundaries:**

- Record-page results live in component state for the session; nothing is persisted from the card.
- Optional lifecycle platform events report deliberate LWC, Apex, and Flow runs without including record
  IDs, queries, messages, or field values.
- Read-only evaluation: no record mutations from checks.
- Formula checks require API v63.0+ (FormulaEval). Package source API version is 66.0.
- Up to **5** concurrent Apex evaluations per LWC run (queued beyond that) when Stop after a system error is off; fully sequential when it is on.
- Apex and Flow callers must stay within 200 records and 15 Rule evaluations per request.
- `recordId` changes after connect reload definitions; record-save does not auto-rerun checks.
- Server-side dependency gate re-evaluates prerequisites (safe for direct Apex calls; may duplicate work from the LWC path).
- Unsupported Apex plugin status strings are rejected with `APEX_EVALUATOR_ERROR`.
- All framework logs use `[RHC]` prefix with `runId` and running-user attribution via `RecordHealthCheckLogger`.
**Edge cases to plan for:**

| Scenario | Behavior |
| -------- | -------- |
| Child subquery with inner `ORDER BY`/`LIMIT` on any query-based check | Handled by depth-0-aware `RecordHealthCheckSoqlTemplate` on all paths |
| Multi-select picklist tokens | Unquoted `{!record.Field}` on a resolved multi-select expands to `('A', 'B')`; quoted `'{!record.Field}'` keeps `'A;B;C'`. Relationship paths follow the same rules when the related record is loaded. |
| Same `{!record.Field}` token used quoted and unquoted in one SOQL template | Each form substituted independently (2026-06-22). `Name LIKE '{!record.Name}%'` works when the exact `'{!record.Name}'` substring appears in the template. |
| Null field on existing row (multi-row Query) | Rows returned but value null + `SKIP_RECORD` → **SKIPPED** / `VALUE_IS_EMPTY` (not `NoRowsResult__c`) |
| `COMPARE_TWO_QUERIES` empty query side (`ONE_RESULT`) | Governed by **`NoRowsResult__c`** before null-field logic: distinct from null on a returned row |
| Semicolon-only multi-select bind | Value `;` alone can produce invalid `INCLUDES ()` SOQL: avoid blank multi-select values in bind tokens |
| Apex plugin `context.record` | Engine loads merge/formula fields referenced in messages and applicability; plugins needing other fields must query by `context.recordId` |
| Managed-package Apex class names | `Type.forName` without namespace may not resolve classes in a managed namespace: use fully qualified API names when required |
| Prerequisite Rule outside the 25-check cap | Dependents skip with `DEPENDENCY_NOT_IN_RUN` (LWC only) |
| Stop after a system error | Stops only on `ERROR`, not `FAIL` or `UNABLE_TO_EVALUATE` |
| Empty multi-row query result | Requires an explicit `NoRowsResult__c` value (`PASS` / `FAIL` / `SKIP` / `UNABLE_TO_EVALUATE`) |
| Static comparison values with locale formatting | Untyped text: may fall through to string comparison |

## Related

- [Getting Started](../installation/getting-started.md): first install and first Rule
- [Examples repository](https://github.com/gkolan/RecordHealthCheck-Examples): deployable patterns
- [Design Specification](../reference/record-health-check-design-spec.md): formal contract
