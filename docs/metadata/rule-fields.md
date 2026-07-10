# Rule fields (`Record_Health_Check_Rule__mdt`)

One individual check inside a Check Set. Walkthroughs by Check Type: [Configuration Guide: result meanings through Apex rules](../guides/configuration-guide.md#5-result-meanings).

> [!NOTE]
> This reference is the source of truth for Rule fields. Guides and examples link here rather than restating these values.

## Field reference

Fields below apply to **all** Rules unless marked otherwise.

### Identity, order, and presentation

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Developer Name | `DeveloperName` | Text | Yes | Stable API identifier (for example, `Account_DQ_BillingCity`). Referenced by **Prerequisite Check (Developer Name)** and Apex evaluation. |
| Label | Master Label | Text | Yes | Setup list name. Convention: spaces instead of underscores. Internal metadata identity. |
| Check Set | `Record_Health_Check_Set__c` | Metadata relationship | Yes | Parent Check Set. Scopes the Rule to one object and one component configuration. |
| Run Order (lower runs first) | `RunOrder__c` | Number | Yes | Run and display order (lower first). Use increments of 10. Controls sequence and dependency ordering. |
| Active | `IsActive__c` | Checkbox | No | Include Rule in evaluation when checked. Defaults to checked. Disable without deleting. |
| Check Name (shown to users) | `CheckName__c` | Text | Yes | User-facing row title in the component (for example, `Billing City Present`). |
| Description (hover tooltip) | `Tooltip__c` | Text | No | Help text shown as a hover/focus tooltip on the row (not inline under the label). Announced to screen readers via the row accessible name. |

> [!NOTE]
> **Two Label fields:** Setup shows **Label** (Master Label) on the record header and **Check Name (shown to users)** (`CheckName__c`) in the rule details. Master Label is the metadata list name in Setup; `CheckName__c` is what appears on the record page.

### Check Type and messages

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Check Type | `CheckMethod__c` | Picklist | Yes | **Check fields on this record** (`Formula`), **Check records with a query** (`Query`), **Compare two queries** (`CompareTwoQueries`), or **Use custom Apex** (`Apex`). Chooses evaluator and which fields below are required. |
| Category | `Category__c` | Picklist | No | Optional grouping label for longer panels. Blank groups the check as Uncategorized. Values: `Data Quality`, `Compliance`, `Sales Readiness`, `Support Readiness`, `Renewal Risk`, `AI Readiness`, `Integration Readiness`, `Required Field Completeness`, `Recent Activity`, `Related Record Coverage`, `Sales Pipeline`, and `Recent or Current Data`. **Metadata only today:** the LWC does not group rows by category yet; use for authoring consistency and future UI. |
| Failure Severity | `Severity__c` | Picklist | Yes | `Error`, `Warning`, or `Info`: **only when the Rule fails**. Visual weight of failures; does not affect pass/fail logic. |
| Message When Check Fails | `MessageWhenFailed__c` | Text | Yes | User message on failure. Supports `{!Field}` tokens. |
| Message When Check Cannot Run | `MessageWhenCannotRun__c` | Text | No | Overrides default unable-to-evaluate text when SOQL or permissions block the check. |

### Guided remediation

These optional fields add read-only guidance to a failed check. They do not update records. Link them only to guidance, playbooks, or Salesforce pages that help the user fix the issue. Examples: [Action Links and Fix Instructions](../guides/action-links.md).

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Fix Instructions | `FixInstructions__c` | Long Text Area | No | User-facing steps or context for resolving the failed check. Rendered as quiet helper text under the remediation link on a **FAIL** row. Supports `{!FieldName}` tokens. |
| Action Button Label | `PrimaryActionLabel__c` | Text | No | Label for the read-only remediation link, for example `View contacts to fix`. Defaults to `Fix this` when a URL is set without a label. |
| Action Button URL | `PrimaryActionUrl__c` | Long Text Area (2000) | No | Read-only deep link shown on a **FAIL** row. Supports one or more `{!FieldName}` tokens, including relationship paths (`{!Owner.ManagerId}`), resolved against the record and URL-encoded. Only same-org relative paths (`/lightning/…`) or `https://` URLs are allowed; anything else (or over 2000 chars after resolution) is dropped. A filtered-report link (`/lightning/r/Report/00O…/view?fv0={!Id}`) needs the report's Id, which exists only after the report is deployed. See [Action Links and Fix Instructions](../guides/action-links.md). |
| Advanced: Found Summary (Text) | `FoundSummaryOverride__c` | Text | No | Optional plain-text (not a formula) **Found** wording for a multi-row (`Every record must pass`) Query check. Supports the count tokens `{!failCount}` / `{!totalCount}` plus `{!FieldName}` tokens, e.g. `{!failCount} of {!totalCount} contacts missing email`. |
| Advanced: Expected Summary (Text) | `ExpectedSummaryOverride__c` | Text | No | Optional plain-text (not a formula) **Expected** wording for a multi-row check, e.g. `every contact has an email`. |

**Found / Expected (automatic, not a metadata field):** When a Query or Compare Two Queries check fails, the card also shows what the record produced (**Found**) and what the rule required (**Expected**) as stacked labelled chips beneath **Message When Check Fails**: for example Found `"Cold"` and Expected `does not equal "Cold"`. Values are quoted uniformly and humanized: numbers show thousands separators (`"50,000"`), Booleans read `"Yes"` / `"No"`, dates and datetimes render in the viewer's locale and time zone, and multi-select picklists render comma-separated. A long value clamps to two lines with a quiet **`...`** / **`less`** toggle. Visibility on passing checks is governed by Check Set **Found/Expected Display** (`ComparisonDisplay__c`). These value lines are derived from the comparator and comparison value. A **multi-row** `Every record must pass` Query check summarizes the result as a count (`1 of 5 Contacts did not pass`) instead of dumping every row value; the `Advanced: Found Summary (Text)` / `Advanced: Expected Summary (Text)` fields let an admin replace that wording (`1 of 5 contacts missing email` / `every contact has an email`). Formula failures show a **Passes when** line only (the unquoted pass/fail formula) unless display formulas are configured; that **Passes when** line is **Advanced-tier** (`Record_Health_Check_View_Details`). Comparison provenance (`actualValueDetail` / `expectedValueDetail`) does not render on the card — it appears in the F12 `[RHC] Source detail` console group, under the conditions in [Troubleshooting Details](../guides/debug-mode.md#what-you-see-in-the-browser-console). Skipped, unable, and error rows do not show comparison. See [Design Specification: comparison display](../reference/record-health-check-design-spec.md#comparison-display-contract) and [Examples: seeing Found / Expected](../examples/index.md#seeing-found-expected).

### Dependencies

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Prerequisite Check (Developer Name) | `RequiresCheck__c` | Text | No | `DeveloperName` of a prerequisite Rule in the **same** Check Set. Run this Rule only after another returns `PASS`. Prerequisite must have lower **Run Order (lower runs first)**. Enforced in the LWC before each Apex call and again on the server. Circular dependencies show as `ERROR` in the LWC and `UNABLE_TO_EVALUATE` on direct Apex evaluation. |

### Applicability (all Rules)

Applicability runs **before** the evaluator. If the gate is false, the Rule is `SKIPPED` and the evaluator does not run.

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Applies To | `RunThisCheckWhen__c` | Picklist | Yes | API values: `Always`, `Formula`, or `SOQL`. Skip checks that do not apply to this record. |
| Applies When Formula Is True | `RunWhenFormula__c` | Text | When mode = Formula | Boolean formula; `true` = run the check. On-record gate without SOQL. |
| Applies When Count Query Matches | `RunWhenCountQuery__c` | Text | When mode = SOQL | COUNT query; use `SELECT COUNT()` or `SELECT COUNT(Id)` with **no alias**. Gate based on related data. |
| Count Must Be | `CountOperator__c` | Picklist | When mode = SOQL | Setup labels: Equal to, Not equal to, Greater than, At least, Less than, At most. Compare COUNT to threshold. |
| Count Value | `CountThreshold__c` | Number | When mode = SOQL | Whole number (for example, `0`). Threshold for the gate. |

### Formula Rules (`CheckMethod__c` = Formula)

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Pass Condition (Formula) | `PassFailFormula__c` | Text | Yes | Boolean Salesforce formula. `true` = pass, `false` = fail. Used only when Check Type is **Check fields on this record**; list membership Query checks use **Value To Test (list checks only)**. |
| Advanced: Found Value (Formula) | `FoundValueFormula__c` | Text | No | Optional formula (not a plain value) whose result is shown as Found for record-formula checks. A fixed value must use formula syntax: text `"Cold"`, number `100`, `TRUE`/`FALSE`, date `DATE(2025,1,31)`. |
| Advanced: Expected Value (Formula) | `ExpectedValueFormula__c` | Text | No | Optional formula (not a plain value) whose result is shown as Expected for record-formula checks. Same formula syntax as Found Value (Formula). |
| Advanced: Formula Result Type | `ScalarFormulaReturnType__c` | Picklist | No | Optional type hint for the Found/Expected display formulas and for formula comparison/list values. Leave `Auto` unless you know the formula returns a specific type. |

### Query and Compare Two Queries Rules

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Primary Query (SOQL) | `DataQuery__c` | Text | Yes* | SOQL template with `{!Id}` tokens. Retrieves values to evaluate. *Exception: `ListContainsAny` / `ListDoesNotContainAny` use **Value To Test (list checks only)** as the primary scalar instead. |
| Primary Query Field/Alias | `FieldToRead__c` | Text | When query returns field values | Field or aggregate alias from Primary Query. Omit for bare `COUNT()`. |
| Comparison Operator | `Operator__c` | Picklist | Yes | Comparison operator (see [Design Specification: operators](../reference/record-health-check-design-spec.md#7-operators-operator__c)). |
| Expected Value Comes From | `CompareAgainst__c` | Picklist | When the Operator needs a right-hand side | Setup labels: A fixed value, A formula on this record, A second query result. Not used for Is empty / Is not empty. |
| Expected Value (Fixed) | `FixedValue__c` | Text | When source = FixedValue | Plain literal, not a formula (for example, `0`, `Approved`, `2025-01-31`). For numeric checks, this can be the threshold. |
| Expected Formula (on this record) | `RecordFormulaValue__c` | Text | When source = RecordFormula | Formula on the base record. Per-record threshold. |
| Second Query | `CompareToQuery__c` | Text | CompareTwoQueries; or Query with `AnotherQuery` | Second SOQL template. Second data source. |
| Second Query Field/Alias | `CompareToField__c` | Text | When comparison query returns field values | Field or alias from Second Query. |
| Value To Test (list checks only) | `ValueToTest__c` | Text | `ListContainsAny` / `ListDoesNotContainAny` | Formula returning the value to test, e.g. `BillingCountry`. Primary value for list membership checks. |
| How To Interpret Query Results | `WhenMultipleRows__c` | Picklist | Yes for Check records with a query | Setup labels: Expect one row or aggregate result, At least one record must pass, Every record must pass, Compare query results as lists. API: `OneResult`, `AnyRowPasses`, `AllRowsPass`, `CompareAsLists`. How query results are interpreted. |
| If Query Finds No Records | `WhenZeroRows__c` | Picklist | Required for Any/All/CompareAsLists | Setup labels: Pass the check, Fail the check, Skip the check, Show cannot check. Default and blank runtime behavior: Skip the check (`Skip`). |
| If Query Field Value Is Empty | `WhenValueIsEmpty__c` | Picklist | Recommended for row comparisons | Setup labels: Ignore records with empty values, Treat empty values as blank, Treat empty values as not matching. Default: Ignore records with empty values (`SkipRecordsWithMissingValue`). How nulls behave row-by-row. |
| Max Rows (safety cap, max 2000) | `MaxRows__c` | Number | No | 1-2000; lowers default 2000 row cap. Cannot exceed 2000. Tighter safety on broad queries. |

> [!IMPORTANT]
> **No records vs empty field values:** **`WhenZeroRows__c`** applies when a query finds **no records** (or, for CompareTwoQueries OneResult, when either side's query is empty). When records exist but a field under test is null and the comparator cannot decide (typically **`SkipRecordsWithMissingValue`**), the check is **SKIPPED** with reason `VALUE_IS_EMPTY`: governed by **`WhenValueIsEmpty__c`**, not `WhenZeroRows__c`. See [Design Specification: open limitations](../reference/record-health-check-design-spec.md#20-open-limitations-and-edge-cases).

### Apex Rules (`CheckMethod__c` = Apex)

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Apex Class Name | `ApexClass__c` | Text | Yes | Class implementing `RecordHealthCheckRule` (for example, `AccountHasRecentActivityCheck`). |
| Apex Settings (JSON) | `ApexSettingsJson__c` | Text | No | JSON object (for example, `{"daysBack": 90}`). Configure Apex without code changes. Invalid JSON → unable to evaluate. |

## See also

- [Check Set fields](check-set.md)
- [Configuration Guide](../guides/configuration-guide.md)
- [Apex plugin reference](../apex/plugin-reference.md)
