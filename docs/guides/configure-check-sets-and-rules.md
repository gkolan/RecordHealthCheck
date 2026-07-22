# Configure Check Sets and Rules

> [!NOTE]
> On this page, turn a Salesforce readiness question into a Check Set and ordered Rules whose Evaluation Types, outcomes, display behavior, and troubleshooting choices work together coherently.

Use this guide to turn a business review into a Check Set and ordered Rules on a Salesforce record
page. It explains where each answer can come from, what users see, and what happens when a Rule does
not apply or cannot evaluate.

The guide uses the Framework's **Check Set**, **Rule**, and **Evaluation Type** terminology. The card
is advisory: it reports readiness without blocking saves or changing record data.

**Prerequisites:** Custom Metadata edit access in Setup and a deployed **Record Health Check**
Lightning Web Component.

## What you can accomplish

| Goal | Start with | What you will learn |
| --- | --- | --- |
| Design one card for a business review | [Mental model](#1-mental-model) | Separate card-level Check Set choices from individual Rule decisions |
| Choose how a Rule gets its answer | [What it can check](#2-what-it-can-check) | Select Verify with a formula, Verify with a query, Compare two queries, or Verify with Apex |
| Make results understandable | [Result meanings](#5-result-meanings) | Distinguish business failures, skipped Rules, unavailable answers, and system problems |
| Limit a Rule to the right records | [Applicability and dependencies](#10-applicability-and-dependencies) | Use formula, count-query, or Apex applicability without turning a non-applicable record into a failure |
| Guide users toward a correction | [Configure action links](configure-action-links.md) | Add Fix Message and safe Action URL guidance to failed Rules |
| Diagnose a problem before release | [Troubleshooting](#13-troubleshooting) | Investigate configuration, access, query, formula, Apex, and component issues |
| Review production readiness | [Review checklist](#14-review-checklist) | Confirm security, behavior, messages, limits, and representative test coverage |

> [!NOTE]
> **Setup labels vs API names:** Each table lists the **Setup label** you see in the metadata editor, the **API name** (`__c` or `DeveloperName`), and what to enter. Use the Setup label in conversation and checklists: for example **Evaluation Type**, not informal terms like “check type.”

## Contents

| Section | What it covers |
| ------- | -------------- |
| [1. Mental model](#1-mental-model) | Check Set, Rule, and component wiring |
| [2. What it can check](#2-what-it-can-check) | Choosing the right Evaluation Type |
| [3. Check Set fields](#3-check-set-fields) | Link to [Check Set field reference](../metadata/fields-check-set.md) |
| [4. Rule fields](#4-rule-fields) | Link to [Rule field reference](../metadata/fields-rule.md) and action links |
| [5. Result meanings](#5-result-meanings) | Status and severity |
| [6. Formula rules](#6-formula-rules) | Record-formula patterns |
| [7. Verify with a query Rules](#7-verify-with-a-query-rules) | Single-query patterns |
| [8. Compare two queries Rules](#8-compare-two-queries-rules) | Dual-query patterns |
| [9. Apex rules](#9-apex-rules) | Custom Apex patterns |
| [10. Applicability and dependencies](#10-applicability-and-dependencies) | Gating and prerequisites |
| [11. Merge tokens](#11-merge-tokens) | `{!record.Field}` in messages and SOQL |
| [12. Security and guardrails](#12-security-and-guardrails) | SOQL safety and permissions |
| [13. Troubleshooting](#13-troubleshooting) | Symptoms, causes, and fixes |
| [14. Review checklist](#14-review-checklist) | Pre-activation validation |
| [15. Runtime and integration](#15-runtime-and-integration) | Stack, programmatic API, edge cases |

For practical patterns, use the local [examples library](../examples/README.md).
For detailed behavior, use the Evaluation Type references in the [examples library](../examples/README.md).

For setup, see [Create your first Rule](../installation/03-create-your-first-rule.md). For action-link patterns, see
[Configure action links](configure-action-links.md). For troubleshooting detail, see
[Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md).

## 1. Mental model

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

## 2. What it can check

| Evaluation Type (Setup label) | API value | Use when |
| -------------------------- | --------- | -------- |
| **Verify with a formula** | `FORMULA` | The answer is on the current record (or a parent field reachable by formula). |
| **Verify with a query** | `QUERY` | One SOQL result must be compared to a static value, formula, second query, or list. |
| **Compare two queries** | `COMPARE_TWO_QUERIES` | Two independent SOQL results must be compared (single value or list). |
| **Verify with Apex** | `APEX` | Logic needs code (multi-object date math, scoring, external callouts in a custom plugin). |

Representative Account patterns in the [examples library](../examples/README.md):

- Formula: Billing City is required.
- Formula + applicability: Partner Accounts must have Billing Country; others are skipped.
- Query + `ONE_RESULT`: Account has at least one Contact.
- Query + `ANY_ROW_PASSES`: At least one open Opportunity exceeds 10% of Annual Revenue.
- `COMPARE_TWO_QUERIES`: Contact count equals open Opportunity count.
- Dependency: Contact Email checked only after "has Contacts" passes.
- Apex: Recent activity across Tasks and Events.

## 3. Check Set fields

Every field on `Record_Health_Check_Set__mdt`: including picklist values for **When Checks Run**, **Found/Expected Display**, display modes, and **Show Diagnostics**: is documented in **[Check Set fields](../metadata/fields-check-set.md)**.

## 4. Rule fields

Every field on `Record_Health_Check_Rule__mdt` is documented in **[Rule fields](../metadata/fields-rule.md)**. Optional **Category** is metadata-only for now; the current card does not group rows by it. Optional **Fix Message**, **Action Label**, and **Action URL** fields render guidance and navigation on failed checks. Examples: [Configure action links](configure-action-links.md).

## 5. Result meanings

| Status | Meaning | Typical response |
| ------ | ------- | ---------------- |
| `PASS` | Rule ran and passed. | No action. |
| `FAIL` | Rule ran and found a data issue. | Record or process owner. |
| `SKIPPED` | Rule did not apply or dependency did not pass. | Review applicability or dependencies if unexpected. |
| `UNABLE_TO_EVALUATE` | Metadata, permissions, SOQL, or data blocked safe evaluation. | Review configuration, field-level security, and the Reason Code. |
| `ERROR` | Unexpected Framework or Apex exception. | Review the Apex plugin, Salesforce logs, and the Reason Code. |

| Severity | Use when |
| -------- | -------- |
| Critical (`CRITICAL`) | Important problem to fix. |
| Warning (`WARNING`) | Should be reviewed. |
| Info (`INFO`) | Contextual information. |

Severity applies **only** to `FAIL` results.

## 6. Formula rules

Use Formula when the result is expressible with Salesforce formula syntax on the current record or
its parent relationships. Start with [Seller research readiness](../examples/formula/01-account-research-ready.md); use the
[Formula reference](../reference/reference-formula.md) for the complete contract.

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

`PassConditionFormula__c` (and the optional formulas below) may reference **calculated fields**: formula fields, roll-up summaries, and even formulas of formulas: at any depth, for any type (number, text, date, boolean, picklist) and any standard function. The engine loads the whole dependency chain, so you reference the field API names you use in Setup; you do **not** rewrite checks to point at the underlying source fields.

### Showing Found vs Expected (optional)

By default a Formula check shows only a **Passes when** line: the pass/fail formula text, unquoted: and no **Found** value. That **Passes when** line is **Advanced-tier**: users without `Record_Health_Check_View_Details` see the failure message only (plus any display-formula Found/Expected chips). For balance and comparison checks you can declare two optional single-value formulas so the row shows readable numbers (or text/dates) on each side, like a Query check:

| Field | Purpose |
| ----- | ------- |
| `DisplayFoundFormula__c` | single-value formula → **Found** (left side: what the record has). |
| `DisplayExpectedFormula__c` | single-value formula → **Expected** (right side: required or target value). |

`PassConditionFormula__c` still decides pass/fail (it must return Boolean); these two are display-only and additive. The engine does not compare Found and Expected to each other: there is no separate "formula comparison operator" setting; the comparison lives inside `PassConditionFormula__c`.

In the example above, a failing row displays the Account's revenue as **Found** and 10% of the
grandparent Account's revenue as **Expected**, while the complete Boolean formula remains the only
pass/fail decision.

> [!CAUTION]
> **Keep Found/Expected consistent with Pass Condition.** Because the engine does not compare the two sides itself, nothing stops you from showing values that disagree with the actual result. If `PassConditionFormula__c` compares A to B, use A for `DisplayFoundFormula__c` and B for `DisplayExpectedFormula__c`. Otherwise a row can **pass while Found ≠ Expected** or fail while the values look equal. A safe habit: copy each side of the comparison in `PassConditionFormula__c` verbatim into the matching display formula.

- **When to use boolean-only:** the formula is a simple presence/condition check (`NOT(ISBLANK(...))`, `ISPICKVAL(...)`) where echoing the condition as Expected is enough.
- **When to add Found/Expected:** the formula compares two values (balance, threshold, equality, date) and seeing both sides is more actionable than the formula text.
- Leave both blank to keep the original behavior (Expected = quoted `PassConditionFormula__c`, no Found).
- If a Found/Expected formula can't be resolved, the row silently falls back to the default display: it never changes pass/fail.
- Set **single-value formula Return Type** to the formulas' type (e.g. Number) to save FormulaEval calls in bulk/Flow runs; leave Auto if unsure.

### Which Evaluation Type compares what?

To have the Framework compare two sides with a **Comparison Operator**, instead of encoding the comparison inside **Pass Condition**, use **Verify with a query**:

| You want to compare… | Evaluation Type | How |
| -------------------- | ------------ | --- |
| A SOQL result vs a **fixed value** | Verify with a query | `ExpectedValueSource__c = FIXED_VALUE`, set `ExpectedFixedValue__c` |
| A SOQL result vs a **record formula** | Verify with a query | `ExpectedValueSource__c = RECORD_FORMULA`, set `ExpectedRecordFormula__c` |
| A SOQL result vs **another SOQL result** | Verify with a query, or Compare two queries | `ExpectedValueSource__c = COMPARISON_QUERY` (or the **Compare two queries** Evaluation Type) |
| Two values **on the record** (formula vs formula, or formula vs fixed value) | Verify with a formula | Encode the comparison in `PassConditionFormula__c`; optionally add Found/Expected to display each side |

## 7. Verify with a query Rules

Use **Verify with a query** when one SOQL result is the primary value. Start with the
[Customer handoff](../examples/query/01-customer-contact.md); use the [Query reference](../reference/reference-query.md)
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

## 8. Compare two queries Rules

Use when both sides come from SOQL. Start with the
[Opportunity Contact Role coverage](../examples/compare-two-queries/01-opportunity-contact-role-coverage.md); use the
[Compare two queries reference](../reference/reference-compare-two-queries.md) for the complete
contract.

- `ONE_RESULT` + single-value operators for single values.
- `COMPARE_AS_LISTS` + `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, or `LISTS_MATCH_EXACTLY` for lists (**case-insensitive** list matching; `CONTAINS` / `DOES_NOT_CONTAIN` on single-value text are **case-sensitive**).

Customer contact coverage keeps pace with open pipeline:

```text
SourceQuery__c: SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}
ComparisonQuery__c: SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
QueryResultHandling__c: ONE_RESULT
ComparisonOperator__c: GREATER_THAN_OR_EQUAL
```

## 9. Apex rules

Use Apex when metadata cannot express the Rule safely. See the
[Apex reference](../reference/reference-apex.md), [Recent Account activity](../examples/apex/01-recent-activity.md),
and [Apex examples](../examples/README.md#apex-examples).

The documented Apex class names are examples. Create, test, and deploy your own class before
referencing it in **Apex Class**.

| Setup label | API name | Role |
| ----------- | -------- | ---- |
| Apex Class | `ApexClass__c` | Class implementing `RecordHealthCheckRule` |
| Apex Parameters (JSON) | `ApexParametersJson__c` | Optional configuration values passed as `context.parameters` |

For AI-assisted drafting, see [LLM Configuration Guide: Apex](draft-configuration-with-ai.md#54-apex-evaluationtype__c--apex) and [recent-activity Apex pattern](draft-configuration-with-ai.md#106-recent-taskevent-activity-apex-multi-object).

## 10. Applicability and dependencies

**Applicability**: does this Rule run for this record?

| Mode | When to use |
| ---- | ----------- |
| All records | Universal data quality rules. |
| `FORMULA` | Condition is on the record (for example, `ISPICKVAL(Type, "Partner")`). |
| `SOQL` | Condition needs a related COUNT (for example, at least one open Opportunity exists). |

**Dependencies**: does this Rule wait for another Rule to pass?

Set **Prerequisite Rule** to the prerequisite `DeveloperName`. Use sparingly for checks that are misleading unless a foundation check passed first.

## 11. Merge tokens

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

SOQL examples live in the local [Query](../examples/README.md#query-examples) and
[Compare two queries](../examples/README.md#compare-two-queries-examples) libraries.

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

## 12. Security and guardrails

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
| Unable to Check | SOQL, Formula, permissions, or limits | Rule fields, field-level security, Show Diagnostics, and the Reason Code. |
| System Error | Apex or framework exception | Apex class, Salesforce logs, and Show Diagnostics. |
| Stale results after metadata edit | Component not reloaded | Refresh the record page. |
| Stale results after inline edit | No auto-rerun on record save | Click **Rerun** or refresh the page. |
| Prerequisite skipped | 25-check cap | Lower the prerequisite's Evaluation Order so it runs within the first 25, or reduce active Rules. |
| Custom automation runs slowly or hits limits | Call caps or too many Rules × records | Stay within `MAX_RECORDS_PER_CALL` (200) and `MAX_EVALUATIONS_PER_CALL` (15); prefer `runSet` with a focused Check Set; see [Apex API](../reference/reference-apex-api.md) or [Flow actions](../integration/flow-actions.md). |
| Check passes in UI but fails from custom automation | Different running user (FLS) | Automation runs as the integration or invoking user: verify field access. |
| Expected a lifecycle event but none arrived | Publishing is off, the run was automatic page load, or the transaction rolled back | Enable **Publish Run Event** or **Publish Result Event**; use explicit Run/Rerun, Apex, or Flow; confirm the transaction committed; see [Platform events](../integration/lifecycle-events.md). |

For Reason Codes, see [Reason Codes](../reference/reference-reason-codes.md).

Pre-deployment metadata audit:

```apex
for (RecordHealthCheckMetadataValidator.ValidationIssue i :
        new RecordHealthCheckMetadataValidator().validate()) {
    System.debug(i.severity + ' ' + i.componentName + '.' + i.fieldName + ': ' + i.message);
}
```

## 14. Review checklist

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
- [ ] **Show Diagnostics** is off for production unless actively troubleshooting (requires `Record_Health_Check_View_Details` via `Record_Health_Check_Admin`: see [Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md)).
- [ ] Lifecycle publication switches stay off until subscribers and allocations are reviewed ([Lifecycle events](../integration/lifecycle-events.md)).
- [ ] Tested on records that pass, fail, skip, and unable-to-evaluate.

## 15. Runtime and integration

**Salesforce components:** Custom Metadata → Apex evaluation classes → Lightning Web Component.
Automation uses the public `RecordHealthCheck` Apex class or the separate Rule and Check Set Flow actions.

**Runtime flow (record page):**

1. LWC calls `getCheckDefinitions(checkSetDeveloperName, recordId, runId)` (not cacheable).
2. Apex loads active Check Set, validates object, returns ordered Rule definitions.
3. LWC coordinates runs (dependencies, concurrent evaluations, display modes, run token).
4. Apex evaluates each Rule (applicability, dependencies, evaluator routing).
5. LWC renders results and summaries. Automatic runs publish nothing; explicit Run and Rerun
   actions publish opted-in Rule events and one opted-in Set completion event.

**Programmatic flow (Apex / Flow):**

1. Caller invokes `RecordHealthCheck.runRule`, `runSet`, Flow **Run Record Health Check Rule**, or Flow **Run Record Health Check Set**.
2. The public Apex class enforces call limits and returns `RecordHealthCheckResult` or
   `RecordHealthCheckSetResult` (`contractVersion` `1.0`).
3. When publication switches are on, `RecordHealthCheckLifecyclePublisher` emits Publish After Commit events (`APEX_API` for public Apex and `FLOW` for packaged Flow actions). See [Apex API](../reference/reference-apex-api.md), [Flow actions](../integration/flow-actions.md), and [Platform events](../integration/lifecycle-events.md).

**Boundaries:**

- Record-page results live in component state for the session; nothing is persisted from the card.
- Optional lifecycle Platform Events report deliberate LWC, Apex, and Flow runs. They include
  `RecordId__c` when one evaluated record is available, but omit queries, messages, user identity,
  and field values so subscribers receive correlation and outcome facts without copying the
  evaluation's business data into the event.
- Read-only evaluation: no record mutations from checks.
- Formula checks require API v63.0+ (FormulaEval). Package source API version is 66.0.
- Up to **5** concurrent Apex evaluations per LWC run (queued beyond that) when Stop after a system error is off; fully sequential when it is on.
- Apex and Flow callers must stay within 200 records and 15 Rule evaluations per request.
- `recordId` changes after connect reload definitions; record-save does not auto-rerun checks.
- Server-side dependency gate re-evaluates prerequisites (safe for direct Apex calls; may duplicate work from the LWC path).
- Unsupported Apex plugin status strings are rejected with `APEX_EVALUATOR_ERROR`.
- All framework logs use `[RHC]` prefix with `runId` and running-user attribution via `RecordHealthCheckLogger`.

The Lightning concurrency boundary balances completion speed with predictable browser and
Salesforce load. **Stop after a system error** requires sequential evaluation because the component
must receive one Rule result before it can decide whether starting the next Rule is allowed.
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

- [Create your first Rule](../installation/03-create-your-first-rule.md): first install and first Rule
- [Examples library](../examples/README.md): practical patterns by Evaluation Type
- [Architecture map](../reference/reference-architecture-map.md): Framework source ownership
