# Record Health Check: LLM configuration guide

**Version:** 2.0.0 (2026-07-13)

This file is the single source for AI assistants translating business requirements into correct Custom Metadata configuration. Paste the output tables into Setup; see [Getting Started: Step 4](../installation/getting-started.md#step-4-create-your-first-rule). For every field explained, see the [Configuration Guide](configuration-guide.md). For formal contracts, see the [Design Specification](../reference/record-health-check-design-spec.md).

## 1. What this product does

Record Health Check is a **read-time, advisory** Lightning card on **record pages**. Check Sets
(`Record_Health_Check_Set__mdt`) and Rules (`Record_Health_Check_Rule__mdt`) live in Custom Metadata.

The component evaluates the current record and shows each Rule as **Pass**, **Fail**, **Skipped**,
**Unable to evaluate**, or **Error**. It does not block saves. Use it when data should be healthy but
must not hard-stop users, including related-record checks, aggregates, and coaching on existing
records.

## 2. System prompt (copy into a Gemini gem or custom GPT)

```text
You are a Salesforce Record Health Check configuration assistant.

Your job: translate business requirements into Custom Metadata for Record_Health_Check_Set__mdt (Check Sets) and Record_Health_Check_Rule__mdt (Rules).

ALWAYS output recommendations in this structure:

## Summary
One sentence: what the check does and when it runs.

## Check Set (create or reuse)
Table: API field name | Value | Notes (Setup label in parentheses)

## Rule
Table: API field name | Value | Notes

## Pattern
Name the pattern (e.g. "QUERY + ONE_RESULT + RECORD_FORMULA") and cite a shipped DeveloperName if one exists.

## Class sketch (Apex only)
When EvaluationType__c = APEX: list SOQL/objects to read, JSON keys for ApexParametersJson__c, PASS/FAIL logic, and the required actualValue/expectedValue fields. Cite the optional Examples pack when applicable.

## Applicability & dependencies
Only if not ALL_RECORDS / no dependency.

## Why not a validation rule?
One sentence when relevant.

RULES YOU MUST FOLLOW:
1. Use exact API names (__c suffix) in configuration tables.
2. EvaluationType__c values: FORMULA | QUERY | COMPARE_TWO_QUERIES | APEX (not Setup labels).
3. Formula checks: PassConditionFormula__c must return Boolean true/false. Ignore ExpectedValueSource__c, ComparisonOperator__c, SourceQuery__c.
4. Query checks: primary value usually from SourceQuery__c; comparison via ExpectedValueSource__c = FIXED_VALUE | RECORD_FORMULA | COMPARISON_QUERY.
5. COMPARE_TWO_QUERIES: both sides from SOQL; no ExpectedValueSource__c.
6. SOQL aggregates SUM/AVG/MIN/MAX/COUNT_DISTINCT require an alias; bare COUNT() does not.
7. SOQL merge tokens: {!record.FieldApiName} on the current record (e.g. {!record.Id}, {!record.AnnualRevenue}, {!record.Customer_Tier__c}).
8. Max 25 active Rules per Check Set per run. Use applicability gates to reduce noise.
9. Health checks are advisory: recommend validation rules when the user needs save-time blocking.
10. If metadata cannot express the rule, recommend Apex (RecordHealthCheckRule interface) and say what the class must do. Cite an example from https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/apex/ (1=multi-object OR, 2=child aggregation, 3=composite score). Treat every example class as an optional Examples-pack dependency; Core ships no example implementations. Do not recommend Apex for save-time field format rules: use validation rules.
11. QueryResultHandling__c = ONE_RESULT for aggregates and single COUNT(); ANY_ROW_PASSES / ALL_ROWS_PASS for row-by-row; COMPARE_AS_LISTS for list operators.
12. LIST_CONTAINS_ANY / LIST_CONTAINS_NONE: primary single value from FindInListFormula__c, list from ComparisonQuery__c (not SourceQuery__c). PassConditionFormula__c is record-formula-only.
13. Do not invent field API names: use names the user provided or mark them as placeholders to verify in Setup.

DECISION ORDER:
- On-record only, no SOQL → FORMULA
- One SOQL result vs static / formula / second query → QUERY
- Two SOQL results compared → COMPARE_TWO_QUERIES
- Complex date math, scoring, callouts → APEX

When unsure, ask one clarifying question: base object, child relationship, threshold static or per-record, and whether zero related rows should pass, fail, or skip.
```

## 3. Decision tree

```text
User describes a business rule
│
├─ Answer is only on the current record (or Parent.Field via formula)?
│  └─ YES → EvaluationType__c = FORMULA
│            Required: PassConditionFormula__c (Boolean)
│
├─ One query result compared to something?
│  └─ YES → EvaluationType__c = QUERY
│            Primary: SourceQuery__c (+ SourceQueryField__c unless bare COUNT())
│            Compare to: FIXED_VALUE | RECORD_FORMULA | COMPARISON_QUERY | (none for IS_BLANK/IS_NOT_BLANK)
│
├─ Two independent queries compared?
│  └─ YES → EvaluationType__c = COMPARE_TWO_QUERIES
│            SourceQuery__c + ComparisonQuery__c
│
├─ single value must appear in / stay out of a query result list?
│  └─ YES → EvaluationType__c = QUERY
│            FindInListFormula__c = single value (field or formula on record)
│            ComparisonQuery__c = list source
│            QueryResultHandling__c = COMPARE_AS_LISTS
│            ComparisonOperator__c = LIST_CONTAINS_ANY | LIST_CONTAINS_NONE
│
└─ Needs code, external data, or unsupported shape?
   └─ EvaluationType__c = APEX
      ApexClass__c = class implementing RecordHealthCheckRule
      ApexParametersJson__c = optional JSON object for per-Rule tuning
      See https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#example-catalog for the apex examples
```

**Apex complexity ladder (pick the smallest level that fits):**

| Level | When | Shipped class (if any) | Doc |
| ----- | ---- | ---------------------- | --- |
| 1 Multi-object | Task **or** Event in **one** row | `AccountHasRecentActivityCheck` | `apex/01-recent-activity.md` |
| 2 Child aggregation | Same child must fail combined conditions | `AccountOpenOpportunityHealthCheck` | `apex/02-open-opportunity-health.md` |
| 3 Composite | Weighted score, one collapsed indicator | *(reference: user deploys)* | `apex/03-strategic-readiness.md` |

Do **not** recommend Apex for phone/email format or required-field-on-save rules: use **validation rules**.

When recommending Apex, also output a **Class sketch** section: what to query, what `status` to return, required `actualValue`/`expectedValue` for `PASS` / `FAIL`, and suggested `ApexParametersJson__c` keys.

### Validation rule vs health check

| If the rule… | Recommend |
| --- | --- |
| Must be true **to save**; single record; willing to block user | **Validation rule** (not this product) |
| Must be true; needs automation or cross-object writes on save | **Flow / Apex trigger** |
| Should be true for health; uses related data or aggregates; must **not** block save | **Record Health Check** |

## 4. Required output template

Every LLM response configuring metadata should include these sections.

### 4.1 Summary

Plain English: what passes, what fails, what object, when the rule runs.

### 4.2 Check Set table

Minimum fields when creating a new Check Set:

| API field | Setup label | Required | Example |
| --- | --- | --- | --- |
| `DeveloperName` | Developer Name | Yes | `Account_Pipeline_Health` |
| `MasterLabel` | Label | Yes | `Account Sales Pipeline Health` |
| `ObjectApiName__c` | Object | Yes | `Account` |
| `CardTitle__c` | Card Title | Yes | `Sales Pipeline Health` |
| `CardSubtitle__c` | Card Subtitle | No | `Open pipeline vs revenue targets` |
| `CardRunMode__c` | When Checks Run | Yes | `RUN_ON_LOAD` or `RUN_ON_REQUEST` (default) |
| `CardRevealMode__c` | Reveal Mode | Yes | `ALL_AT_ONCE` or `ONE_BY_ONE` |
| `PassedChecksDisplay__c` | Passed Checks | Yes | `SHOW_EACH_CHECK` or `SHOW_COUNT_ONLY` |
| `SkippedChecksDisplay__c` | Skipped Checks | Yes | `SHOW_EACH_CHECK` or `SHOW_COUNT_ONLY` |
| `FoundExpectedDisplay__c` | Found/Expected Display | Yes | `ON_DEMAND` (default), `FAILURES_ONLY`, or `ALL_ROWS` |
| `IsActive__c` | Active | No | `true` |
| `ShowDiagnostics__c` | Show Diagnostics | No | `false` in production. When `true`, user also needs `Record_Health_Check_View_Details` (from `Record_Health_Check_Admin`). See [Show Diagnostics guide](show-diagnostics.md). |
| `PublishRunEvent__c` | Publish Run Event | No | `false` by default; page-load runs never publish |

**Component wiring:** In Lightning App Builder, select the intended **Check Set** for the record page. The stored LWC property is `checkSetName`; Apex still receives that value as `checkSetDeveloperName`.

### 4.3 Rule table

Always include (all Evaluation Types):

| API field | Setup label | Required | Example |
| --- | --- | --- | --- |
| `DeveloperName` | Developer Name | Yes | `Account_Pipeline_Meets_15x_Revenue` |
| `MasterLabel` | Label | Yes | `Sales Pipeline Meets 1.5x Revenue` |
| `Record_Health_Check_Set__c` | Check Set | Yes | `Account_Pipeline_Health` |
| `CheckTitle__c` | Check Title | Yes | `Open pipeline ≥ 1.5× annual revenue` |
| `EvaluationType__c` | Evaluation Type | Yes | `QUERY` |
| `EvaluationOrder__c` | Evaluation Order | Yes | `10` (use gaps: 10, 20, 30…) |
| `Category__c` | Category | No | `COMPLETENESS`, `READINESS`, `COMPLIANCE`, `RELATIONSHIP_COVERAGE`, or blank. Metadata only — UI grouping not implemented yet. |
| `FailureSeverity__c` | Failure Severity | Yes | `CRITICAL`, `WARNING`, or `INFO` |
| `FailureMessage__c` | Message When Failed | Yes | `{!record.Name} pipeline is below 1.5× annual revenue.` |
| `FixMessage__c` | Fix Message | No | `Review open opportunities…` (renders on FAIL rows) |
| `ActionLabel__c` | Action Label | No | `Open pipeline playbook` |
| `ActionUrl__c` | Action URL | No | `/lightning/r/Report/00O.../view?fv0={!record.Id}` or `https://example.com/pipeline-playbook` |
| `ApplicabilityMode__c` | Applies To | Yes | `ALL_RECORDS`, `WHEN_FORMULA_TRUE`, or `WHEN_COUNT_QUERY_MATCHES` |
| `PublishResultEvent__c` | Publish Result Event | No | `false` by default; page-load runs never publish |
| `IsActive__c` | Active | No | `true` |

Add type-specific fields from Section 5.

Use remediation fields for guidance and explicit navigation. Rendering or opening a link does not
make Record Health Check perform DML, although a destination can be an edit or prefilled create page
where the user chooses whether to save. Unsafe or overlong URLs are dropped, but Fix Message can
still render. For create-page, Knowledge, report, related-list, and external examples, see
[Action links and Fix Message](action-links.md).

### 4.4 Pattern citation

Name the pattern and reference a shipped example when possible (Section 7-8). For Apex, cite the complexity level and doc under `RecordHealthCheck-Examples` pattern library Apex pages.

### 4.5 Class sketch (Apex only)

When `EvaluationType__c` = `APEX`, add a section after the Rule table. See [Apex reference](../apex/apex-reference.md) for full patterns.

| Item | What to include |
| ---- | --------------- |
| `recordId` | `context.recordId` for SOQL; query extra fields: `context.record` is partial |
| Parent / custom fields | `Parent.BillingCity` in SELECT, or `Primary_Contact__r.Email` |
| JSON defaults | Apex constants + `ApexParametersJson__c` keys (e.g. `daysBack`) with bounds |
| Examples-pack vs custom | Use an Examples-pack class only when that pack is installed and the pattern matches |
| Outcome | `PASS`/`FAIL`; required `actualValue`/`expectedValue` on both statuses |
| Applicability | Why `ApplicabilityMode__c` is not `ALL_RECORDS` if gated |

## 5. Rule fields by Evaluation Type

### 5.1 Formula (`EvaluationType__c` = `FORMULA`)

Setup label: **Verify with a formula**.

| API field | Required | Value |
| --- | --- | --- |
| `PassConditionFormula__c` | Yes | Boolean formula; `true` = pass |
| `DisplayFoundFormula__c` | Optional | single-value formula shown as **Found** (left side of a comparison). Display only — does not affect pass/fail. |
| `DisplayExpectedFormula__c` | Optional | single-value formula shown as **Expected** (right side). Display only; blank = Expected echoes `PassConditionFormula__c`. |
| `FormulaResultType__c` | Optional | Type of the Found/Expected single values (`NUMBER` / `TEXT` / `DATE` / `DATETIME` / `BOOLEAN`), or `AUTO`. |

Operands in any of these formulas may be calculated fields (formula, roll-up) at any depth — the engine loads the full dependency chain.

**Found/Expected are display-only and NOT compared to each other.** `PassConditionFormula__c` performs the comparison and decides pass/fail. Set Found/Expected only for comparison/balance checks, and mirror each side of the Pass/Fail comparison (Found = left operand, Expected = right) so the row does not mislead. For framework-driven comparison with an operator, use a Query check (`ExpectedValueSource__c` = `FIXED_VALUE` / `RECORD_FORMULA` / `COMPARISON_QUERY`).

**Leave unset:** `SourceQuery__c`, `ComparisonOperator__c`, `ExpectedValueSource__c`, `QueryResultHandling__c` (ignored).

**Examples:**

```text
NOT(ISBLANK(BillingCity))
OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))
AnnualRevenue > 0
BillingCity = ShippingCity
NOT(ISBLANK(Parent.BillingCity))
```

### 5.2 Query (`EvaluationType__c` = `QUERY`)

Setup label: **Verify with a query**.

| API field | When required |
| --- | --- |
| `SourceQuery__c` | Always, except `LIST_CONTAINS_ANY` / `LIST_CONTAINS_NONE` |
| `SourceQueryField__c` | When query selects fields or aliased aggregates; omit for bare `COUNT()` |
| `QueryResultHandling__c` | Always: `ONE_RESULT`, `ANY_ROW_PASSES`, `ALL_ROWS_PASS`, `COMPARE_AS_LISTS` |
| `ComparisonOperator__c` | Always (see Section 6) |
| `ExpectedValueSource__c` | When comparison operator needs a right-hand side (`FIXED_VALUE`, `RECORD_FORMULA`, `COMPARISON_QUERY`) |
| `ExpectedFixedValue__c` | When `ExpectedValueSource__c` = `FIXED_VALUE` |
| `ExpectedRecordFormula__c` | When `ExpectedValueSource__c` = `RECORD_FORMULA` |
| `ComparisonQuery__c` | When `ExpectedValueSource__c` = `COMPARISON_QUERY`, or list operators |
| `ComparisonQueryField__c` | When comparison query returns field values (not bare `COUNT()`) |
| `NoRowsResult__c` | Required for `ANY_ROW_PASSES`, `ALL_ROWS_PASS`, `COMPARE_AS_LISTS` |
| `EmptyValueHandling__c` | Recommended for row-by-row modes; default `AS_NO_MATCH` |

**List membership exception** (`LIST_CONTAINS_ANY`, `LIST_CONTAINS_NONE`):

| API field | Role |
| --- | --- |
| `FindInListFormula__c` | Primary single value (field or formula on record). |
| `ComparisonQuery__c` | SOQL returning the list |
| `ComparisonQueryField__c` | Column to read from list query |
| `QueryResultHandling__c` | `COMPARE_AS_LISTS` |

### 5.3 Compare two queries (`EvaluationType__c` = `COMPARE_TWO_QUERIES`)

| API field | Required |
| --- | --- |
| `SourceQuery__c` | Yes: primary side |
| `ComparisonQuery__c` | Yes: comparison side |
| `SourceQueryField__c` | When primary returns fields or aliased aggregates |
| `ComparisonQueryField__c` | When comparison returns fields or aliased aggregates |
| `QueryResultHandling__c` | `ONE_RESULT` (single value) or `COMPARE_AS_LISTS` (list operators) |
| `ComparisonOperator__c` | single value or list comparison operator |

**Leave unset:** `ExpectedValueSource__c` (both sides are queries).

List operators for `COMPARE_AS_LISTS`: `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY`.

### 5.4 Apex (`EvaluationType__c` = `APEX`)

Full walkthroughs: [Apex examples index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#example-catalog) · [Apex example](../apex/apex-example.md) · [Apex reference](../apex/apex-reference.md)

| API field | Required | Notes |
| --- | --- | --- |
| `ApexClass__c` | Yes | Class implementing `RecordHealthCheckRule`: deploy before activating Rule |
| `ApexParametersJson__c` | No | JSON **object** (not array), e.g. `{"daysBack": 90}`, `{"minDigits": 10}`, `{"staleDays": 30}` |

**Apex interface summary:** Full patterns: [Apex reference](../apex/apex-reference.md).

```apex
public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
  Id recordId = context.recordId;           // page record: use in SOQL binds
  Map<String, Object> params = context.parameters;  // from ApexParametersJson__c
  // Query fields WITH USER_MODE: do not assume context.record is complete
  RecordHealthCheckResult result = new RecordHealthCheckResult();
  result.status = 'PASS' or 'FAIL';
  result.actualValue / result.expectedValue  // required for PASS / FAIL
  return result;
}
```

- Query with `WITH USER_MODE`. Load fields not on `context.record` via SOQL.
- On `FAIL`, set `message` only when metadata **FailureMessage__c** is not enough; metadata still supplies **Severity**.
- Pair with applicability (`ApplicabilityMode__c` = `FORMULA` or `SOQL`) when the check should not run for every record.

**Shipped classes:**

| Class | JSON keys | Pattern |
| --- | --- | --- |
| `AccountHasRecentActivityCheck` | `daysBack` (1-3650, default 30) | Task + Event window |
| `AccountOpenOpportunityHealthCheck` | `staleDays` (1-3650, default 30) | Unhealthy open Opportunity detection |

Do **not** invent class names as shipped unless listed above. For composite scoring, name a **new** class and include a Class sketch for implementation (see [example 3](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/apex/03-strategic-readiness.md)).

### 5.5 Applicability (all rules)

| `ApplicabilityMode__c` | Additional fields |
| --- | --- |
| `ALL_RECORDS` | None |
| `FORMULA` | `ApplicabilityFormula__c` (Boolean, `true` = run check) |
| `WHEN_COUNT_QUERY_MATCHES` | `ApplicabilityCountQuery__c` (`SELECT COUNT()` or `SELECT COUNT(Id)`), `ApplicabilityCountOperator__c`, `ApplicabilityCountThreshold__c` |

### 5.6 Dependencies

| API field | Value |
| --- | --- |
| `PrerequisiteRule__c` | `DeveloperName` of prerequisite Rule in same Check Set (must have lower `EvaluationOrder__c`) |

Prerequisite must return `PASS` or dependent is `SKIPPED`.

## 6. operators (`ComparisonOperator__c`)

| API value | Setup label | Needs right-hand side? | Valid with |
| --- | --- | --- | --- |
| `EQUALS` | Equals | Yes | QUERY, COMPARE_TWO_QUERIES |
| `NOT_EQUALS` | Does not equal | Yes | QUERY, COMPARE_TWO_QUERIES |
| `GREATER_THAN` | Greater than | Yes | QUERY, COMPARE_TWO_QUERIES |
| `GREATER_THAN_OR_EQUAL` | Greater than or equal | Yes | QUERY, COMPARE_TWO_QUERIES |
| `LESS_THAN` | Less than | Yes | QUERY, COMPARE_TWO_QUERIES |
| `LESS_THAN_OR_EQUAL` | Less than or equal | Yes | QUERY, COMPARE_TWO_QUERIES |
| `CONTAINS` | Contains text | Yes | QUERY, COMPARE_TWO_QUERIES (case-sensitive) |
| `DOES_NOT_CONTAIN` | Does not contain text | Yes | QUERY, COMPARE_TWO_QUERIES (case-sensitive) |
| `IS_BLANK` | Is empty | No | QUERY |
| `IS_NOT_BLANK` | Is not empty | No | QUERY |
| `LIST_CONTAINS_ANY` | List contains any | List in `ComparisonQuery__c` | QUERY only |
| `LIST_CONTAINS_NONE` | List contains none | List in `ComparisonQuery__c` | QUERY only |
| `LISTS_OVERLAP` | Lists overlap | Second query list | COMPARE_TWO_QUERIES + COMPARE_AS_LISTS |
| `LISTS_CONTAIN_ALL` | Lists contain all | Second query list | COMPARE_TWO_QUERIES + COMPARE_AS_LISTS |
| `LISTS_MATCH_EXACTLY` | Lists match exactly | Second query list | COMPARE_TWO_QUERIES + COMPARE_AS_LISTS |

## 7. Pattern reference

| Business intent | EvaluationType | QueryResultHandling | Expected source / notes |
| --- | --- | --- | --- |
| Field required on record | FORMULA | | `NOT(ISBLANK(Field))` |
| Either field A or B required | FORMULA | | `OR(NOT(ISBLANK(A)), NOT(ISBLANK(B)))` |
| At least N related records | QUERY | ONE_RESULT | `COUNT()` > FIXED_VALUE |
| Every child row meets bar | QUERY | ALL_ROWS_PASS | vs FIXED_VALUE or RECORD_FORMULA |
| Any child row meets bar | QUERY | ANY_ROW_PASSES | vs FIXED_VALUE or RECORD_FORMULA |
| Aggregate ≥ static threshold | QUERY | ONE_RESULT | SUM/AVG/etc. vs FIXED_VALUE |
| Aggregate ≥ per-record formula | QUERY | ONE_RESULT | SUM/etc. vs RECORD_FORMULA |
| Aggregate ≥ second query | QUERY | ONE_RESULT | vs COMPARISON_QUERY |
| Two counts or aggregates compared | COMPARE_TWO_QUERIES | ONE_RESULT | single-value operator |
| Account field in child list | QUERY | COMPARE_AS_LISTS | LIST_CONTAINS_ANY + FindInListFormula |
| Field not in reference list | QUERY | COMPARE_AS_LISTS | LIST_CONTAINS_NONE |
| Two lists overlap / contain / match | COMPARE_TWO_QUERIES | COMPARE_AS_LISTS | LISTS_OVERLAP / LISTS_CONTAIN_ALL / LISTS_MATCH_EXACTLY |
| Type-specific rule only | FORMULA | | Applicability Formula: `ISPICKVAL(Type, "Partner")` |
| Run only when children exist | | | Applicability SOQL: COUNT > 0 |
| Recent activity (Task or Event) | APEX | | `AccountHasRecentActivityCheck` |
| Unhealthy child rows (combined) | APEX | | `AccountOpenOpportunityHealthCheck` |
| Weighted readiness score | Apex | | Custom class: [apex/03-strategic-readiness.md](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/apex/03-strategic-readiness.md) |

## 8. Supported vs unsupported combinations

### Supported (configure with confidence)

| Shape | How |
| --- | --- |
| SOQL left, static right | Query + `FIXED_VALUE` |
| SOQL left, record formula right | Query + `RECORD_FORMULA` |
| SOQL left, second query right | Query + `COMPARISON_QUERY` |
| Two queries compared | COMPARE_TWO_QUERIES |
| Formula single value in query list | Query + `LIST_CONTAINS_ANY` / `LIST_CONTAINS_NONE` |
| SUM vs `AnnualRevenue * 1.5` | QUERY + ONE_RESULT + RECORD_FORMULA |

### Unsupported or awkward (recommend workaround)

| Shape | Problem | Workaround |
| --- | --- | --- |
| Formula check + Expected Value Comes From | Formula path ignores comparison fields | Put full logic in `PassConditionFormula__c` |
| Formula left, SOQL single value right (EQUALS, GREATER_THAN, …) | Primary must be `SourceQuery__c` for single-value operators | Flip: query left, `RECORD_FORMULA` right; or COMPARE_TWO_QUERIES; or APEX |
| `SELECT SUM(x) FROM ...` without alias | Framework cannot read column | Add alias: `SUM(Amount) totalAmt` + `SourceQueryField__c = totalAmt` |
| Multiplier on COMPARE_TWO_QUERIES right side | Both sides are raw query values only | Use QUERY + RECORD_FORMULA, or APEX |
| Blocking save on fail | Product is read-time only | Validation rule or Flow |
| More than 25 active rules | Hard cap per run | Split Check Sets or deactivate low-value rules |
| Org-wide batch audit | No packaged scheduler | Apex batch calling `RecordHealthCheck.runRule` |

## 9. SOQL rules for LLMs

### Merge tokens

- Syntax: `{!record.FieldApiName}` on the **base record** (the record page object).
- Examples: `{!record.Id}`, `{!record.OwnerId}`, `{!record.AnnualRevenue}`, `{!record.Parent.BillingCity}`, `{!record.Customer_Tier__c}`.
- Strings are quoted and escaped automatically; numbers and dates are unquoted.
- The exact substring `'{!record.Field}'` inside a larger literal works (for example `Name LIKE '{!record.Name}%'`).
- A token may appear both quoted and unquoted in one template: each form is substituted independently.
- User must have read FLS on token fields or check returns `UNABLE_TO_EVALUATE`.

### Aggregates

| Function | Alias required? | `SourceQueryField__c` |
| --- | --- | --- |
| `COUNT()` | No | Leave blank |
| `COUNT(field)` | Yes | Alias name |
| `COUNT_DISTINCT(field)` | Yes | Alias name |
| `SUM(field)` | Yes | Alias name |
| `AVG(field)` | Yes | Alias name |
| `MIN(field)` | Yes | Alias name |
| `MAX(field)` | Yes | Alias name |

**Wrong:** `SELECT SUM(Amount) FROM Opportunity WHERE AccountId = {!record.Id}`
**Right:** `SELECT SUM(Amount) pipelineTotal FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` + `SourceQueryField__c = pipelineTotal`

### Null / empty rows

- Aggregates return `null` when no rows match: pair with applicability SOQL (`COUNT > 0`) or `EmptyValueHandling__c = SkipRecordsWithMissingValue`.
- **`NoRowsResult__c`:** `PASS`, `FAIL`, `SKIP`, `UNABLE_TO_EVALUATE` when a query returns **zero rows** (including COMPARE_TWO_QUERIES ONE_RESULT when either side's query is empty).
- **`EmptyValueHandling__c`:** when rows exist but a field under test is null and the comparison operator cannot decide (typically `SKIP_RECORD`), the check is **SKIPPED** with `VALUE_IS_EMPTY`: not governed by `NoRowsResult__c`.

## 10. Worked examples (copy-ready)

### 10.1 Portfolio readiness (Formula)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `FORMULA` |
| `PassConditionFormula__c` | `AND(OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website))), NOT(ISBLANK(BillingCountry)), AnnualRevenue >= Parent.Parent.AnnualRevenue * 0.10)` |
| `DisplayFoundFormula__c` | `AnnualRevenue` |
| `DisplayExpectedFormula__c` | `Parent.Parent.AnnualRevenue * 0.10` |
| `FormulaResultType__c` | `NUMBER` |
| `ApplicabilityMode__c` | `ALL_RECORDS` |
| `FailureSeverity__c` | `CRITICAL` |
| `FailureMessage__c` | `{!record.Name} needs a contact channel, billing country, and revenue equal to at least 10% of its top-level portfolio account.` |

This example deliberately demonstrates multiple conditions and a two-level parent relationship.
Ask whether the org guarantees both parent levels; otherwise recommend a shallower relationship or
an applicability condition.

### 10.2 At least one Contact (Query)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `QUERY` |
| `SourceQuery__c` | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| `QueryResultHandling__c` | `ONE_RESULT` |
| `ComparisonOperator__c` | `GREATER_THAN` |
| `ExpectedValueSource__c` | `FIXED_VALUE` |
| `ExpectedFixedValue__c` | `0` |

Shipped: `Account_EU_HasAtLeastOneContact`.

### 10.3 Open pipeline ≥ 1.5× annual revenue (Query + aggregate + formula)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `QUERY` |
| `SourceQuery__c` | `SELECT SUM(TotalPrice) totalPipeline FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND TotalPrice != null` |
| `SourceQueryField__c` | `totalPipeline` |
| `QueryResultHandling__c` | `ONE_RESULT` |
| `ComparisonOperator__c` | `GREATER_THAN_OR_EQUAL` |
| `ExpectedValueSource__c` | `RECORD_FORMULA` |
| `ExpectedRecordFormula__c` | `AnnualRevenue * 1.5` |
| `EmptyValueHandling__c` | `SKIP_RECORD` |
| `ApplicabilityMode__c` | `FORMULA` |
| `ApplicabilityFormula__c` | `NOT(ISBLANK(AnnualRevenue)) && AnnualRevenue > 0` |

Use `Amount` instead of `TotalPrice` if products are not used. Similar shipped pattern: `Account_CTQ_SumVsAnnualRevenue` (1:1 revenue, via COMPARE_TWO_QUERIES).

### 10.4 Billing State appears in Contact states (list membership)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `QUERY` |
| `FindInListFormula__c` | `BillingState` |
| `ComparisonQuery__c` | `SELECT MailingState FROM Contact WHERE AccountId = {!record.Id} AND MailingState != null` |
| `ComparisonQueryField__c` | `MailingState` |
| `QueryResultHandling__c` | `COMPARE_AS_LISTS` |
| `ComparisonOperator__c` | `LIST_CONTAINS_ANY` |
| `NoRowsResult__c` | `SKIP` |

Shipped: `Account_QC_ListContainsAny` (`LIST_CONTAINS_ANY`).

### 10.5 Partner accounts need Billing Country (Formula + applicability)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `FORMULA` |
| `PassConditionFormula__c` | `NOT(ISBLANK(BillingCountry))` |
| `ApplicabilityMode__c` | `FORMULA` |
| `ApplicabilityFormula__c` | `ISPICKVAL(Type, "Partner")` |

Shipped: `Account_Adv_PartnerBillingCountry`.

### 10.6 Recent Task/Event activity (Apex: Multi-object)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `APEX` |
| `ApexClass__c` | `AccountHasRecentActivityCheck` |
| `ApexParametersJson__c` | `{"daysBack": 90}` |
| `ApplicabilityMode__c` | `ALL_RECORDS` |
| `FailureSeverity__c` | `WARNING` |
| `FailureMessage__c` | `{!record.Name} has no completed tasks or logged events in the last 90 days.` |

Sample Rule in the Examples **apex-advanced-checks** pack (see pack README). Doc: [apex/01-recent-activity.md](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/apex/01-recent-activity.md).

### 10.7 Unhealthy open Opportunities (Apex: Child aggregation)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `APEX` |
| `ApexClass__c` | `AccountOpenOpportunityHealthCheck` |
| `ApexParametersJson__c` | `{"staleDays": 30}` |
| `ApplicabilityMode__c` | `SOQL` |
| `ApplicabilityCountQuery__c` | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| `ApplicabilityCountOperator__c` | `GREATER_THAN` |
| `ApplicabilityCountThreshold__c` | `0` |
| `FailureSeverity__c` | `CRITICAL` |
| `FailureMessage__c` | One or more open opportunities are stale, missing a Next Step, or have no close date this quarter. |

Doc: [apex/02-open-opportunity-health.md](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/apex/02-open-opportunity-health.md).

### 10.8 Strategic readiness score (Apex: Composite, custom deploy)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `APEX` |
| `ApexClass__c` | `AccountStrategicReadinessCheck` *(not in package: deploy separately)* |
| `ApexParametersJson__c` | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApplicabilityMode__c` | `FORMULA` |
| `ApplicabilityFormula__c` | `ISPICKVAL(Type, "Strategic")` |

Include a **Class sketch** when outputting this pattern. Full reference code: [apex/03-strategic-readiness.md](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/apex/03-strategic-readiness.md).

## 11. Naming conventions

| Item | Convention | Example |
| --- | --- | --- |
| Check Set `DeveloperName` | `Object_Purpose` | `Account_Pipeline_Health` |
| Rule `DeveloperName` | `Object_ShortDescription` | `Account_Pipeline_Meets_15x_Revenue` |
| Rule `MasterLabel` | Spaces, readable in Setup | `Sales Pipeline Meets 1.5x Revenue` |
| Rule `CheckTitle__c` | User-facing, concise | `Open pipeline ≥ 1.5× revenue` |
| `EvaluationOrder__c` | Gaps of 10 | 10, 20, 30 (dependencies: prerequisite lower) |

## 12. Example packs (reference for LLMs)

**Core** ships only the hero Check Set `Example_Account_360_Health_Check`. All other teachable
Check Sets live in
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples).

Install Core first, then deploy **one** pack from that repository
([install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md)).

| Pack id | Typical Check Set / focus | Best for copying |
| --- | --- | --- |
| `account-data-quality` | `Account_Data_Quality` | Simple formula completeness |
| `account-everyday-readiness` | `Account_Everyday_Use_Cases` | Everyday Account readiness |
| `account-relationships` | `Account_Relationships` | Related-record existence |
| `opportunity-sales-readiness` | Opportunity readiness | Sales pipeline patterns |
| `case-service-readiness` | Case readiness | Service intake patterns |
| `apex-advanced-checks` | Apex-backed Account checks | Apex plugins / scoring |
| Industry / docs packs | grantmaking, FSC, CPQ, Revenue Cloud | Scenario outlines (some docs-only) |

Full pack list: [Examples pack index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md).
Single-rule patterns: [pattern library](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md).

## 13. Framework limits (do not exceed in recommendations)

| Limit | Value |
| --- | --- |
| Active rules per run | 25 (lowest `EvaluationOrder__c` first) |
| SOQL rows per query | 2000 default (`MaxQueryRows__c` can lower, not raise) |
| Formula eval calls per Apex transaction | 100 platform; framework guards at ~95 |
| Concurrent evaluate calls (LWC) | 5 when Stop after a system error is off |
| Component placement | Record pages only (needs `recordId`) |
| Base object | Check Set `ObjectApiName__c` must match page object |

## 14. Clarifying questions (ask when requirements are vague)

1. **Base object**: Account, Opportunity, Contact, or custom?
2. **Child relationship**: which object and filter (open only, won, last 90 days)?
3. **Threshold**: fixed number or derived from a field on the record?
4. **Zero related rows**: should that pass, fail, or skip the check?
5. **Blank threshold field**: skip or fail (e.g. no `AnnualRevenue`)?
6. **Blocking**: if user says "must not save", recommend validation rule instead.

## 15. Deeper documentation map

| Need | Document |
| --- | --- |
| Every Setup field explained | [Configuration Guide](configuration-guide.md) |
| Pattern matrix + merge tokens | [Examples README](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md) |
| When to use which Evaluation Type | [Configuration Guide: what it can check](configuration-guide.md#2-what-it-can-check) |
| Copy-paste examples by type | [Formula](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#example-catalog), [Query](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#example-catalog), [Compare two queries](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#example-catalog), [Aggregates](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#pattern-reference-aggregates) |
| Reason codes & contracts | [Design Specification](../reference/record-health-check-design-spec.md) |
| Install & first rule | [Getting Started](../installation/getting-started.md) |

## 16. Gemini gem checklist

When building a Gemini gem for this project:

1. Upload this file as primary knowledge.
2. Add `configuration-guide.md` and `https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md` as secondary knowledge.
3. Paste Section 2 (system prompt) into gem instructions.
4. Tell users to paste: base object, fields involved, pass/fail semantics, and whether zero children should pass or skip.
5. Require gem output to use Section 4 tables (API names, not Setup-only labels).
6. Link humans to [Getting Started](../installation/getting-started.md) for entering metadata in Setup.

## Related

- [Configuration guide](configuration-guide.md)
- [Metadata reference](../metadata/index.md)
- [Apex reference](../apex/apex-reference.md)
- [Reason codes](../reference/reason-codes.md)
