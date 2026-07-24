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

## Contents

| Section | What it covers |
| ------- | -------------- |
| [1. Mental model](#1-mental-model) | Check Set, Rule, and component wiring |
| [2. What it can check](#2-what-it-can-check) | Choosing the right Evaluation Type |
| [3. Check Set fields](#3-check-set-fields) | Link to [Check Set field reference](../metadata/fields-check-set.md) |
| [4. Rule fields](#4-rule-fields) | Link to [Rule field reference](../metadata/fields-check-rule.md) and action links |
| [5. Result meanings](#5-result-meanings) | Status and severity |
| [6. Formula rules](#6-formula-rules) | Record-formula patterns |
| [7. Verify with a query Rules](#7-verify-with-a-query-rules) | Single-query patterns |
| [8. Compare two queries Rules](#8-compare-two-queries-rules) | Dual-query patterns |
| [9. Apex rules](#9-apex-rules) | Custom Apex patterns |
| [10. Applicability and dependencies](#10-applicability-and-dependencies) | Gating and prerequisites |
| [11. Merge tokens](#11-merge-tokens) | `{!record.Field}` in messages and SOQL <!-- merge-fallback-optional-example --> |
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
Lightning component Check Set: Example_Account_Relationship_Risk
Check Set DeveloperName: Example_Account_Relationship_Risk
Rule DeveloperName: Example_Customer_Engagement_Current
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

Every field on `Record_Health_Check_Rule__mdt` is documented in **[Rule fields](../metadata/fields-check-rule.md)**. Optional **Category** is metadata-only for now; the current card does not group rows by it. Optional **Fix Message**, **Action Label**, and **Action URL** fields render guidance and navigation on failed checks. Examples: [Configure action links](configure-action-links.md).

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

| Formula result | Rule status |
| --- | --- |
| `true` | Pass |
| `false` | Fail |
| `null`, including an unavailable parent relationship such as `Parent.Field` with no parent | Unable to Evaluate |

Use this one example as the model for a meaningful Formula Rule. It combines three business
requirements and traverses two parent levels. The Account passes when it has a contact channel, has
a billing country, and its revenue is at least 10% of the top-level portfolio Account's revenue.

<table>
  <thead><tr><th>Setup field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Evaluation Type</td><td><code>FORMULA</code></td></tr>
    <tr><td>Pass Condition</td><td><pre><code>AND(
  OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website))),
  NOT(ISBLANK(BillingCountry)),
  AnnualRevenue &gt;= Parent.Parent.AnnualRevenue * 0.10
)</code></pre></td></tr>
    <tr><td>Display Found Formula</td><td><code>AnnualRevenue</code></td></tr>
    <tr><td>Display Expected Formula</td><td><code>Parent.Parent.AnnualRevenue * 0.10</code></td></tr>
    <tr><td>Formula Result Type</td><td><code>NUMBER</code></td></tr>
    <tr><td>Message When Failed</td><td><code>{!record.Name|this record} needs a contact channel, billing country, and revenue equal to at least 10% of its top-level portfolio account.</code></td></tr>
  </tbody>
</table>

If either parent relationship or a required revenue value is unavailable, the Rule cannot reach a
reliable conclusion and returns **Unable to Evaluate**. Use a shallower path when the object model
does not guarantee two Account parents.

### Formula operands can be formula or roll-up fields

| Supported operand | How to use it |
| --- | --- |
| Formula field | Reference its field API name directly. |
| Roll-up summary field | Reference its field API name directly. |
| Formula that depends on another formula | Reference the final field API name; the engine loads the dependency chain. |
| Number, text, date, Boolean, or picklist calculation | Use its normal Salesforce formula type and functions. |

Calculated dependencies can be nested to any depth. Do not rewrite the check to use the calculated
field's underlying source fields.

### Showing Found vs Expected (optional)

By default a Formula check shows only a **Passes when** line: the pass/fail formula text, unquoted: and no **Found** value. That **Passes when** line is **Advanced-tier**: users without `Record_Health_Check_View_Diagnostics` see the failure message only (plus any display-formula Found/Expected chips). For balance and comparison checks you can declare two optional single-value formulas so the row shows readable numbers (or text/dates) on each side, like a Query check:

| Setup field | Effect on pass or fail | Purpose |
| --- | --- | --- |
| Display Found Formula (`DisplayFoundFormula__c`) | Display only | Single-value formula shown as **Found**, representing what the record has. |
| Display Expected Formula (`DisplayExpectedFormula__c`) | Display only | Single-value formula shown as **Expected**, representing the required or target value. |
| Pass Condition (`PassConditionFormula__c`) | Decides pass or fail | Boolean formula that decides the result. |

`PassConditionFormula__c` still decides pass/fail (it must return Boolean); these two are display-only and additive. The engine does not compare Found and Expected to each other: there is no separate "formula comparison operator" setting; the comparison lives inside `PassConditionFormula__c`.

In the example above, a failing row displays the Account's revenue as **Found** and 10% of the
grandparent Account's revenue as **Expected**, while the complete Boolean formula remains the only
pass/fail decision.

> [!CAUTION]
> **Keep Found/Expected consistent with Pass Condition.** Because the engine does not compare the two sides itself, nothing stops you from showing values that disagree with the actual result. If `PassConditionFormula__c` compares A to B, use A for `DisplayFoundFormula__c` and B for `DisplayExpectedFormula__c`. Otherwise a row can **pass while Found ≠ Expected** or fail while the values look equal. A safe habit: copy each side of the comparison in `PassConditionFormula__c` verbatim into the matching display formula.

| Situation | Configuration | Display behavior |
| --- | --- | --- |
| Simple presence or condition check, such as `NOT(ISBLANK(Phone))` or `ISPICKVAL(Type, "Partner")` | Leave Display Found Formula and Display Expected Formula blank. | Shows the default Expected value from Pass Condition and no Found value. |
| Balance, threshold, equality, or date comparison | Put the actual value in Display Found Formula and the target value in Display Expected Formula. | Shows both values without changing the pass/fail decision. |
| A display formula cannot be resolved | No configuration change is required. | Silently returns to the default display and never changes pass/fail. |
| Formula type is known | Set Single-Value Formula Return Type to Number, Text, Date, or the matching type. | Avoids unnecessary FormulaEval calls in bulk and Flow runs. |
| Formula type is uncertain | Leave Single-Value Formula Return Type as Auto. | The Framework determines the type. |

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

### At least one Contact

| Setup field | Value |
| --- | --- |
| Source Query | <code>SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id&#124;001000000000000AAA}</code> |
| How To Read Query Results | `ONE_RESULT` |
| Comparison Operator | `GREATER_THAN` |
| Expected Value Source | `FIXED_VALUE` |
| Expected Fixed Value | `0` |

### Supported aggregate functions

An alias is required except for bare `COUNT()`.

| Aggregate | Example | Result |
| --- | --- | --- |
| `COUNT()` | `SELECT COUNT() FROM Contact` | Number of returned records |
| `COUNT(field)` | `SELECT COUNT(Email) emailCount FROM Contact` | Number of non-null field values |
| `COUNT_DISTINCT(field)` | `SELECT COUNT_DISTINCT(LeadSource) sourceCount FROM Contact` | Number of distinct non-null values |
| `SUM(field)` | `SELECT SUM(Amount) totalAmount FROM Opportunity` | Total numeric value |
| `AVG(field)` | `SELECT AVG(Amount) averageAmount FROM Opportunity` | Average numeric value |
| `MIN(field)` | `SELECT MIN(CloseDate) earliestCloseDate FROM Opportunity` | Lowest value |
| `MAX(field)` | `SELECT MAX(CloseDate) latestCloseDate FROM Opportunity` | Highest value |

### Open pipeline equals 10% of Annual Revenue

| Setup field | Value |
| --- | --- |
| Source Query | <code>SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id&#124;001000000000000AAA} AND IsClosed = false</code> |
| Source Query Field | `totalAmount` |
| How To Read Query Results | `ONE_RESULT` |
| Comparison Operator | `EQUALS` |
| Expected Value Source | `RECORD_FORMULA` |
| Expected Record Formula | `AnnualRevenue * 0.1` |

## 8. Compare two queries Rules

Use when both sides come from SOQL. Start with the
[Opportunity Contact Role coverage](../examples/compare-two-queries/01-opportunity-contact-role-coverage.md); use the
[Compare two queries reference](../reference/reference-compare-two-queries.md) for the complete
contract.

| Result shape | How To Read Query Results | Comparison operators | Matching behavior |
| --- | --- | --- | --- |
| One value from each query | `ONE_RESULT` | Single-value operators | `CONTAINS` and `DOES_NOT_CONTAIN` text comparisons are case-sensitive. |
| A list from each query | `COMPARE_AS_LISTS` | `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY` | List matching is case-insensitive. |

### Customer contact coverage keeps pace with open pipeline

| Setup field | Value |
| --- | --- |
| Source Query | <code>SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id&#124;001000000000000AAA}</code> |
| Comparison Query | <code>SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id&#124;001000000000000AAA} AND IsClosed = false</code> |
| How To Read Query Results | `ONE_RESULT` |
| Comparison Operator | `GREATER_THAN_OR_EQUAL` |

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

Merge tokens let one Rule speak about the record, its configuration, and its result without hard-coding those
values. Use the namespace and property exactly as shown. For the complete namespace, surface,
fallback, and limit contract, see the [Merge-token reference](../reference/reference-merge-tokens.md).

The fallback is optional. A token without one inserts the resolved value when populated and inserts blank text when
the value is null, empty, or whitespace-only:

`{!rhcRule.checkTitle}` <!-- merge-fallback-optional-example -->

For example, adding ` needs attention.` after that token produces `Data quality needs attention.` when the Check
Title is `Data quality`. If the Check Title is blank, it produces ` needs attention.`. Check Title is required on
active Rules, but the same blank behavior matters for optional record fields and relationships.

Append `|fallback text` when a blank value should produce clear wording instead:

```text
{!record.Parent.Name|Independent account}
{!record.Owner.Manager.Name|No manager assigned}
{!rhcResult.foundValue|Not measured}
```

The fallback is literal text; it is not parsed as another merge token. Without an explicit fallback, display text
keeps the existing graceful behavior and inserts blank text. A URL with a blank token and no fallback is suppressed
instead of producing a broken link. In SOQL, the fallback is converted to the field's type; an invalid number,
date, date/time, time, or Boolean fallback returns `MISSING_BIND_VALUE` rather than running a misleading query.

### `record`: Record fields

Use any readable field API name from the current record. Relationship paths may cross up to five lookups.

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!record.Name|this record}</code></td><td>The current record's Name.</td><td><code>Review {!record.Name|this record} before approval.</code></td></tr>
    <tr><td><code>{!record.FieldApiName|Fallback value}</code></td><td>Any readable field on the current record. Replace <code>FieldApiName</code> with the Salesforce API name.</td><td><code>{!record.Customer_Tier__c|Standard} customers require an annual review.</code></td></tr>
    <tr><td><code>{!record.Owner.Name|an unassigned owner}</code></td><td>A field from a related record.</td><td><code>Ask {!record.Owner.Name|an unassigned owner} to confirm the account details.</code></td></tr>
    <tr><td><code>{!record.Parent.Parent.Name|no top-level account}</code></td><td>A field reached through multiple lookup relationships.</td><td><code>Escalate the review to {!record.Parent.Parent.Name|no top-level account}.</code></td></tr>
  </tbody>
</table>

### `rhcRule`: Current Rule

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcRule.developerName|rule unavailable}</code></td><td>The Rule's stable Developer Name.</td><td><code>Give support rule {!rhcRule.developerName|rule unavailable}.</code></td></tr>
    <tr><td><code>{!rhcRule.masterLabel|Unnamed rule}</code></td><td>The Rule label shown in Setup.</td><td><code>Review the configuration for {!rhcRule.masterLabel|Unnamed rule}.</code></td></tr>
    <tr><td><code>{!rhcRule.checkTitle|this check}</code></td><td>The user-facing Check Title.</td><td><code>{!rhcRule.checkTitle|This check} needs attention.</code></td></tr>
    <tr><td><code>{!rhcRule.checkDescription|No description provided}</code></td><td>The Check Description.</td><td><code>Requirement: {!rhcRule.checkDescription|No description provided}.</code></td></tr>
    <tr><td><code>{!rhcRule.category|general}</code></td><td>The Rule's Category label.</td><td><code>This is a {!rhcRule.category|general} readiness requirement.</code></td></tr>
    <tr><td><code>{!rhcRule.evaluationType|not assigned}</code></td><td>The Evaluation Type label.</td><td><code>This requirement uses {!rhcRule.evaluationType|an unassigned evaluation method}.</code></td></tr>
    <tr><td><code>{!rhcRule.failureSeverity|important}</code></td><td>The Failure Severity label.</td><td><code>This is a {!rhcRule.failureSeverity|important} issue.</code></td></tr>
    <tr><td><code>{!rhcRule.evaluationOrder|not assigned}</code></td><td>The Rule's evaluation order.</td><td><code>This requirement runs at position {!rhcRule.evaluationOrder|not assigned}.</code></td></tr>
  </tbody>
</table>

### `rhcSet`: Current Check Set

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcSet.developerName|set unavailable}</code></td><td>The Check Set's stable Developer Name.</td><td><code>Give support Check Set {!rhcSet.developerName|set unavailable}.</code></td></tr>
    <tr><td><code>{!rhcSet.masterLabel|Unnamed check set}</code></td><td>The Check Set label shown in Setup.</td><td><code>Review the configuration for {!rhcSet.masterLabel|Unnamed check set}.</code></td></tr>
    <tr><td><code>{!rhcSet.cardTitle|Record Health Check}</code></td><td>The title users see on the card.</td><td><code>Return to {!rhcSet.cardTitle|Record Health Check} after making the correction.</code></td></tr>
    <tr><td><code>{!rhcSet.cardSubtitle|No additional details}</code></td><td>The subtitle users see on the card.</td><td><code>Review scope: {!rhcSet.cardSubtitle|No additional details}.</code></td></tr>
    <tr><td><code>{!rhcSet.objectApiName|object unavailable}</code></td><td>The Salesforce object API name configured for the Check Set.</td><td><code>This requirement evaluates a {!rhcSet.objectApiName|record} record.</code></td></tr>
  </tbody>
</table>

### `rhcResult`: Final Rule result

These values are available after the Rule has been evaluated.

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcResult.status|an unknown result}</code></td><td>The final status, such as Pass, Fail, Skipped, or Unable to Evaluate.</td><td><code>The review returned {!rhcResult.status|an unknown result}.</code></td></tr>
    <tr><td><code>{!rhcResult.foundValue|not measured}</code></td><td>The value the Rule found.</td><td><code>Found {!rhcResult.foundValue|not measured} open cases.</code></td></tr>
    <tr><td><code>{!rhcResult.foundValuePluralSuffix|s}</code></td><td>An empty value for one item or <code>s</code> for multiple items.</td><td><code>Found {!rhcResult.foundValue|no} issue{!rhcResult.foundValuePluralSuffix|s}.</code></td></tr>
    <tr><td><code>{!rhcResult.expectedValue|the configured target}</code></td><td>The value the Rule expected.</td><td><code>Expected {!rhcResult.expectedValue|the configured target}.</code></td></tr>
    <tr><td><code>{!rhcResult.failedRecordCount|0}</code></td><td>The number of returned records that failed.</td><td><code>{!rhcResult.failedRecordCount|No} contacts are missing email.</code></td></tr>
    <tr><td><code>{!rhcResult.totalRecordCount|0}</code></td><td>The total number of returned records evaluated.</td><td><code>Reviewed {!rhcResult.totalRecordCount|no} related contacts.</code></td></tr>
    <tr><td><code>{!rhcResult.reasonCode|reason unavailable}</code></td><td>The diagnostic Reason Code.</td><td><code>The check could not finish because {!rhcResult.reasonCode|the reason is unavailable}.</code></td></tr>
  </tbody>
</table>

### `rhcRun`: Current run

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcRun.runId|unavailable}</code></td><td>The identifier shared by checks in the same run.</td><td><code>If the problem continues, give support run {!rhcRun.runId|unavailable}.</code></td></tr>
    <tr><td><code>{!rhcRun.source|an unknown source}</code></td><td>Where the run started, such as the record page, Apex, or Flow.</td><td><code>This review was started from {!rhcRun.source|an unknown source}.</code></td></tr>
    <tr><td><code>{!rhcRun.startedAt|start time unavailable}</code></td><td>When the run started.</td><td><code>The review started at {!rhcRun.startedAt|an unknown time}.</code></td></tr>
    <tr><td><code>{!rhcRun.completedAt|completion time unavailable}</code></td><td>When the run completed.</td><td><code>The review completed at {!rhcRun.completedAt|an unknown time}.</code></td></tr>
    <tr><td><code>{!rhcRun.durationMs|0}</code></td><td>How many milliseconds the run took.</td><td><code>The review completed in {!rhcRun.durationMs|0} milliseconds.</code></td></tr>
  </tbody>
</table>

The field determines which contexts are valid:

| Rule field type | Valid token namespaces |
| --- | --- |
| Failure, unable-to-evaluate, not-applicable, fix, action-label, Found-text, and Expected-text fields | `record`, `rhcResult`, `rhcRun`, `rhcRule`, `rhcSet` |
| Action URL | `record`, `rhcRun`, `rhcRule`, `rhcSet`; result tokens are intentionally rejected |
| Source Query, Comparison Query, and applicability Count Query | `record` only |
| Salesforce formula fields | Use Salesforce formula syntax directly; do not put merge tokens inside formulas |

- Use field API names exactly as shown in Setup; custom fields include the `__c` suffix.
- Record tokens support text, ID/reference, number, currency, percent, checkbox, date, date/time, picklist,
  multi-select picklist, email, phone, URL, encrypted-text values, and relationship fields when readable.
- A blank value resolves to blank text. A null relationship makes its record token blank.
- The explicit fallback applies to null, empty, and whitespace-only values. It does not replace `0`, `false`, or a
  populated value.
- Fallback text may contain spaces and additional `|` characters; everything after the first `|` is the fallback.
- Fallback text is inserted once and never recursively expanded.
- Curly braces are reserved for complete merge tokens. Extra, nested, or unmatched braces are rejected as
  `MALFORMED_TOKEN` instead of being rendered as text.
- Quotes, apostrophes, slashes, and additional pipes in a fallback are literal characters; they do not enable
  formulas, Markdown, HTML, nested tokens, or code execution.
- URL token values are URL-encoded automatically.
- SOQL tokens are escaped and typed automatically: strings are quoted; numbers, dates, date/times, and Booleans
  are bound in their native form. An unquoted multi-select token expands to a value tuple for `INCLUDES` or
  `EXCLUDES`; a quoted token preserves its semicolon-delimited text.
- The engine loads token fields before evaluation. If the running user lacks object or field access, the result
  can be `RECORD_NOT_ACCESSIBLE` or `MISSING_BIND_VALUE`.

SOQL examples live in the local [Query](../examples/README.md#query-examples) and
[Compare two queries](../examples/README.md#compare-two-queries-examples) libraries.

## 11a. Multi-line messages

**Message When Failed** and **Message When Unable To Evaluate** support multiple lines. Press **Enter** in Setup to start a new line; each line renders as a separate line on the card. Use a blank line (press Enter twice) to add spacing between paragraphs.

```text
{!record.Name|this record} is out of balance.

Debit total: {!record.Debit_Total__c|0}
Expected credit net: {!record.Credit_Net__c|0}

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
| Prerequisite skipped | Framework run cap | Lower the prerequisite's Evaluation Order so it falls within the configured execution window, or reduce active Rules. |
| Custom automation runs slowly or hits limits | Call caps or too many Rules × records | Keep Apex calls within `MAX_EVALUATIONS_PER_CALL` (15); Flow invocations also accept at most `MAX_FLOW_RECORDS_PER_CALL` (200) requests. Prefer `runSet` with a focused Check Set; see [Apex API](../reference/reference-apex-api.md) or [Flow actions](../integration/flow-actions.md). |
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
- [ ] **Show Diagnostics** is off for production unless actively troubleshooting (requires `Record_Health_Check_View_Diagnostics` via `Record_Health_Check_Admin`: see [Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md)).
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
- Apex callers must stay within 15 planned Rule evaluations per request. Flow invocations also
  accept at most 200 request records per transaction.
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
| Multi-select picklist tokens | Unquoted `{!record.Field\|Fallback value}` on a resolved multi-select expands to `('A', 'B')`; quoted `'{!record.Field\|Fallback value}'` keeps `'A;B;C'`. Relationship paths follow the same rules when the related record is loaded. |
| Same `{!record.Field\|Fallback value}` token used quoted and unquoted in one SOQL template | Each form substituted independently (2026-06-22). `Name LIKE '{!record.Name\|this record}%'` works when the exact `'{!record.Name\|this record}'` substring appears in the template. |
| Null field on existing row (multi-row Query) | Rows returned but value null + `SKIP_RECORD` → **SKIPPED** / `VALUE_IS_EMPTY` (not `NoRowsResult__c`) |
| `COMPARE_TWO_QUERIES` empty query side (`ONE_RESULT`) | Governed by **`NoRowsResult__c`** before null-field logic: distinct from null on a returned row |
| Semicolon-only multi-select bind | Value `;` alone can produce invalid `INCLUDES ()` SOQL: avoid blank multi-select values in bind tokens |
| Apex plugin `context.record` | Engine loads merge/formula fields referenced in messages and applicability; plugins needing other fields must query by `context.recordId` |
| Managed-package Apex class names | `Type.forName` without namespace may not resolve classes in a managed namespace: use fully qualified API names when required |
| Prerequisite Rule outside the Framework run cap | Dependents skip with `DEPENDENCY_NOT_IN_RUN` (LWC only) |
| Stop after a system error | Stops only on `ERROR`, not `FAIL` or `UNABLE_TO_EVALUATE` |
| Empty multi-row query result | Requires an explicit `NoRowsResult__c` value (`PASS` / `FAIL` / `SKIP` / `UNABLE_TO_EVALUATE`) |
| Static comparison values with locale formatting | Untyped text: may fall through to string comparison |

## Related

- [Create your first Rule](../installation/03-create-your-first-rule.md): first install and first Rule
- [Examples library](../examples/README.md): practical patterns by Evaluation Type
- [Architecture](../reference/reference-architecture-map.md): published Framework architecture and source ownership
