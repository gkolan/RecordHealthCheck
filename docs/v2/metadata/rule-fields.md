# Rule fields (`Record_Health_Check_Rule__mdt`)

One individual check inside a Check Set. Walkthroughs by evaluation type: [Configuration Guide: result meanings through Apex rules](../guides/configuration-guide.md#5-result-meanings).

> [!NOTE]
> This reference is the source of truth for Rule fields. Setup labels and stored picklist values match shipped Custom Metadata. Guides and examples link here rather than restating these values.

Stored picklist values are `UPPER_SNAKE_CASE`. Author metadata with those API values.

## Field reference

Fields below apply to **all** Rules unless marked otherwise. Section numbering matches the Setup layout.

### 1. Basics

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Developer Name | `DeveloperName` | Text | Yes | Stable API identifier (for example, `Account_DQ_BillingCity`). Referenced by **Prerequisite Rule** and Apex evaluation. |
| Label | Master Label | Text | Yes | Setup list name. Internal metadata identity. |
| Check Set | `Record_Health_Check_Set__c` | Metadata relationship | Yes | Parent Check Set. Scopes the Rule to one object and one component configuration. |
| Evaluation Order | `EvaluationOrder__c` | Number | No | Run and display order (lower first). Default `100`. Use increments of 10. |
| Active | `IsActive__c` | Checkbox | No | Include Rule in evaluation when checked. Defaults to checked. |

### 2. What Users See

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Check Title | `CheckTitle__c` | Text | Yes | User-facing row title on the card (for example, `Billing City present`). |
| Check Description | `CheckDescription__c` | Text | No | Optional hover/focus tooltip on the row title. |
| Category | `Category__c` | Picklist | No | Optional grouping vocabulary. Blank = ungrouped. See [Category values](#category-category__c). Metadata for authoring consistency; the LWC does not group rows by category yet. |
| Failure Severity | `FailureSeverity__c` | Picklist | No | Visual weight **only when the Rule fails**. Default `WARNING`. See [Failure Severity](#failure-severity-failureseverity__c). There is no Error severity — unexpected problems use the separate `ERROR` result status. |
| Message When Failed | `FailureMessage__c` | Long Text Area | No | User message on failure. Supports `{!record.Field}` tokens. |
| Message When Unable To Evaluate | `UnableToEvaluateMessage__c` | Long Text Area | No | Overrides default unable-to-evaluate text when SOQL or permissions block the check. |
| Fix Message | `FixMessage__c` | Long Text Area | No | User-facing guidance on a **FAIL** row. Supports `{!record.FieldName}` tokens. |
| Action Label | `ActionLabel__c` | Text | No | Label for the read-only remediation link. Defaults to `Fix this` when a URL is set without a label. |
| Action URL | `ActionUrl__c` | Long Text Area | No | Read-only deep link on a **FAIL** row. Supports `{!record.FieldName}` tokens. Only same-org relative paths or `https://` URLs are allowed. See [Action Links and Fix Instructions](../guides/action-links.md). |

> [!NOTE]
> **Two name fields:** Setup **Label** (Master Label) is the metadata list name. **Check Title** (`CheckTitle__c`) is what appears on the record page.

### 3. Check Type (`EvaluationType__c`)

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Evaluation Type | `EvaluationType__c` | Picklist | Yes | Chooses the evaluator and which fields below are required. No default — you must pick one. |

| Value (API) | Setup label |
| ----------- | ----------- |
| `FORMULA` | Verify with a formula |
| `QUERY` | Verify with a query |
| `COMPARE_TWO_QUERIES` | Compare two queries |
| `APEX` | Verify with Apex |

### 4. Check Fields On This Record (`FORMULA`)

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Pass Condition | `PassConditionFormula__c` | Long Text Area | Yes for `FORMULA` | Boolean Salesforce formula. `true` = pass, `false` = fail. |
| Display: Found Formula | `DisplayFoundFormula__c` | Long Text Area | No | Display only. Formula whose result is shown as Found. |
| Display: Expected Formula | `DisplayExpectedFormula__c` | Long Text Area | No | Display only. Formula whose result is shown as Expected. |
| Formula Result Type | `FormulaResultType__c` | Picklist | No | Type hint for formula results. Default `AUTO`. See [Formula Result Type](#formula-result-type-formularesulttype__c). |

### 5. Query Sources (`QUERY` / `COMPARE_TWO_QUERIES`)

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Source Query | `SourceQuery__c` | Long Text Area | Yes* | SOQL template with `{!record.Id}` tokens. *Exception: list membership checks that use **Value to find in the list (formula)** as the primary single value. |
| Source Query Field | `SourceQueryField__c` | Text | When the query returns field values | Field or aggregate alias from the Source Query. Omit for bare `COUNT()`. |
| Comparison Query | `ComparisonQuery__c` | Long Text Area | `COMPARE_TWO_QUERIES`, or `QUERY` with expected source `COMPARISON_QUERY` | Second SOQL template. |
| Comparison Query Field | `ComparisonQueryField__c` | Text | When the comparison query returns field values | Field or alias from the Comparison Query. |
| Value to find in the list (formula) | `FindInListFormula__c` | Long Text Area | `LIST_CONTAINS_ANY` / `LIST_CONTAINS_NONE` | Formula returning the value to look up in the query list. |

### 6. Query Comparison

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Comparison Operator | `ComparisonOperator__c` | Picklist | Yes for query types | See [Comparison Operator](#comparison-operator-comparisonoperator__c). |
| Expected Value Comes From | `ExpectedValueSource__c` | Picklist | When the operator needs a right-hand side | Not used for `IS_BLANK` / `IS_NOT_BLANK`. See [Expected Value Comes From](#expected-value-comes-from-expectedvaluesource__c). |
| Expected Value (Fixed) | `ExpectedFixedValue__c` | Text | When source = `FIXED_VALUE` | Plain literal (for example, `0`, `Approved`, `2025-01-31`). |
| Expected Value (Formula) | `ExpectedRecordFormula__c` | Long Text Area | When source = `RECORD_FORMULA` | Formula on the base record. |

### 7. Advanced Query Behavior

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| How To Read Query Results | `QueryResultHandling__c` | Picklist | Yes for `QUERY` / `COMPARE_TWO_QUERIES` | Default `ONE_RESULT`. See [How To Read Query Results](#how-to-read-query-results-queryresulthandling__c). |
| If Query Finds No Records | `NoRowsResult__c` | Picklist | Required for multi-row / list modes | No default — you must choose. See [If Query Finds No Records](#if-query-finds-no-records-norowsresult__c). |
| If Field Value Is Empty | `EmptyValueHandling__c` | Picklist | Recommended for row comparisons | Default `AS_NO_MATCH`. See [If Field Value Is Empty](#if-field-value-is-empty-emptyvaluehandling__c). |
| Max Query Rows (1-2000) | `MaxQueryRows__c` | Number | No | Safety cap. Default `200`. Maximum `2000`. |

> [!IMPORTANT]
> **No records vs empty field values:** **`NoRowsResult__c`** applies when a query finds **no records**. When records exist but a compared field is empty, behavior is governed by **`EmptyValueHandling__c`** (often `SKIPPED` with reason `VALUE_IS_EMPTY` when `SKIP_RECORD`).

### 8. Advanced Display Text

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Display: Found Text | `DisplayFoundText__c` | Text | No | Optional plain-text **Found** wording for a multi-row (`ALL_ROWS_PASS`) query check. Supports count tokens such as `{!rhcResult.failedRecordCount}` / `{!rhcResult.totalRecordCount}` plus `{!record.FieldName}`. |
| Display: Expected Text | `DisplayExpectedText__c` | Text | No | Optional plain-text **Expected** wording for a multi-row check. |

**Found / Expected (automatic):** Query and Compare Two Queries evaluators populate Found/Expected chips from the comparison. Visibility for passing checks follows Check Set **Found/Expected Display**. Detailed source notes appear only in console diagnostics for entitled viewers. See [Design Specification: comparison display](../reference/record-health-check-design-spec.md#comparison-display-contract).

### 9. When This Check Applies

Applicability runs **before** the evaluator. If the gate is false, the Rule is `SKIPPED` and the evaluator does not run.

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Applies To | `ApplicabilityMode__c` | Picklist | No | Default `ALL_RECORDS`. See [Applies To](#applies-to-applicabilitymode__c). |
| Applies When (Formula) | `ApplicabilityFormula__c` | Long Text Area | When mode = `WHEN_FORMULA_TRUE` | Boolean formula; `true` = run the check. |
| Applies When (Count Query) | `ApplicabilityCountQuery__c` | Long Text Area | When mode = `WHEN_COUNT_QUERY_MATCHES` | `COUNT()` query with **no alias**. |
| Count Must Be | `ApplicabilityCountOperator__c` | Picklist | When mode = `WHEN_COUNT_QUERY_MATCHES` | See [Count Must Be](#count-must-be-applicabilitycountoperator__c). |
| Count Value | `ApplicabilityCountThreshold__c` | Number | When mode = `WHEN_COUNT_QUERY_MATCHES` | Integer threshold. |
| Prerequisite Rule | `PrerequisiteRule__c` | Text | No | `DeveloperName` of a prerequisite Rule in the **same** Check Set. Prerequisite must have a lower **Evaluation Order**. |

### 10. Custom Apex (`APEX`)

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Apex Class | `ApexClass__c` | Text | Yes for `APEX` | Class implementing `RecordHealthCheckRule`. |
| Apex Parameters (JSON) | `ApexParametersJson__c` | Long Text Area | No | JSON object (for example, `{"daysBack": 90}`). Invalid JSON → unable to evaluate. |

### Lifecycle Events

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Publish Result Event | `PublishResultEvent__c` | Checkbox | No | Publishes a Rule Result event after a deliberately initiated run. Page-load runs never publish. Off by default. |

## Picklist values

### Category (`Category__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `COMPLETENESS` | Completeness |
| `CONSISTENCY` | Consistency |
| `TIMELINESS` | Timeliness |
| `ELIGIBILITY` | Eligibility |
| `READINESS` | Readiness |
| `RISK` | Risk |
| `COMPLIANCE` | Compliance |
| `RELATIONSHIP_COVERAGE` | Relationship coverage |

### Failure Severity (`FailureSeverity__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `CRITICAL` | Critical |
| `WARNING` | Warning (**default**) |
| `INFO` | Info |

### Applies To (`ApplicabilityMode__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `ALL_RECORDS` | All records (**default**) |
| `WHEN_FORMULA_TRUE` | When a formula is true |
| `WHEN_COUNT_QUERY_MATCHES` | When a count query matches |

### Count Must Be (`ApplicabilityCountOperator__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `EQUALS` | Equal to |
| `NOT_EQUALS` | Not equal to |
| `GREATER_THAN` | Greater than |
| `GREATER_THAN_OR_EQUAL` | At least |
| `LESS_THAN` | Less than |
| `LESS_THAN_OR_EQUAL` | At most |

### Comparison Operator (`ComparisonOperator__c`)

| Value (API) | Setup label | Needs expected value |
| ----------- | ----------- | -------------------- |
| `EQUALS` | Equals | Yes |
| `NOT_EQUALS` | Does not equal | Yes |
| `GREATER_THAN` | Greater than | Yes |
| `GREATER_THAN_OR_EQUAL` | Greater than or equal | Yes |
| `LESS_THAN` | Less than | Yes |
| `LESS_THAN_OR_EQUAL` | Less than or equal | Yes |
| `CONTAINS` | Contains text | Yes |
| `DOES_NOT_CONTAIN` | Does not contain text | Yes |
| `IS_BLANK` | Is empty | No |
| `IS_NOT_BLANK` | Is not empty | No |
| `LIST_CONTAINS_ANY` | List contains any | List + find formula |
| `LIST_CONTAINS_NONE` | List contains none | List + find formula |
| `LISTS_OVERLAP` | Lists overlap | Second query list |
| `LISTS_CONTAIN_ALL` | Lists contain all | Second query list |
| `LISTS_MATCH_EXACTLY` | Lists match exactly | Second query list |

List-vs-list operators (`LISTS_*`) are valid only on `COMPARE_TWO_QUERIES` with `COMPARE_AS_LISTS`.

### Expected Value Comes From (`ExpectedValueSource__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `FIXED_VALUE` | Fixed value |
| `RECORD_FORMULA` | Record formula |
| `COMPARISON_QUERY` | Comparison query |

### How To Read Query Results (`QueryResultHandling__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `ONE_RESULT` | One row or aggregate (**default**) |
| `ANY_ROW_PASSES` | Any record passes |
| `ALL_ROWS_PASS` | Every record passes |
| `COMPARE_AS_LISTS` | Compare as lists |

### If Query Finds No Records (`NoRowsResult__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `PASS` | Pass |
| `FAIL` | Fail |
| `SKIP` | Skip |
| `UNABLE_TO_EVALUATE` | Unable to evaluate |

### If Field Value Is Empty (`EmptyValueHandling__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `SKIP_RECORD` | Ignore the record |
| `AS_BLANK` | Treat as blank |
| `AS_NO_MATCH` | Treat as not matching (**default**) |

### Formula Result Type (`FormulaResultType__c`)

| Value (API) | Setup label |
| ----------- | ----------- |
| `AUTO` | Auto (**default**) |
| `BOOLEAN` | Checkbox |
| `NUMBER` | Number |
| `DATE` | Date |
| `DATETIME` | Date/Time |
| `TEXT` | Text |

## See also

- [Check Set fields](check-set.md)
- [Configuration Guide](../guides/configuration-guide.md)
- [Reason codes](../reference/reason-codes.md)
- [Apex plugin reference](../apex/plugin-reference.md)
