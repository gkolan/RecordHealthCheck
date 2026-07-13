# Record Health Check: LLM Configuration Guide

**Version:** 1.2.0 (2026-07-09)

This file is the single source for AI assistants translating business requirements into correct Custom Metadata configuration. Paste the output tables into Setup; see [Getting Started: Step 4](../installation/getting-started.md#step-4-create-your-first-rule). For every field explained, see the [Configuration Guide](configuration-guide.md). For formal contracts, see the [Design Specification](../reference/record-health-check-design-spec.md).

## 1. What this product does (one paragraph)

Record Health Check is a **read-time, advisory** Lightning card on **record pages**. Check Sets (`Record_Health_Check_Set__mdt`) and Rules (`Record_Health_Check_Rule__mdt`) live in Custom Metadata. The component evaluates the current record and shows each Rule as **Pass**, **Fail**, **Skipped**, **Unable to evaluate**, or **Error**. It does **not** block saves. Use it when data *should* be healthy but must not hard-stop users (related-record checks, aggregates, coaching on existing records).

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
Name the pattern (e.g. "Query + OneResult + RecordFormula") and cite a shipped DeveloperName if one exists.

## Class sketch (Apex only)
When EvaluationType__c = Apex: list SOQL/objects to read, JSON keys for ApexParametersJson__c, PASS/FAIL logic, and the required actualValue/expectedValue fields. Cite shipped class if applicable.

## Applicability & dependencies
Only if not All records / no dependency.

## Why not a validation rule?
One sentence when relevant.

RULES YOU MUST FOLLOW:
1. Use exact API names (__c suffix) in configuration tables.
2. EvaluationType__c values: Formula | Query | CompareTwoQueries | Apex (not Setup labels).
3. Formula checks: PassConditionFormula__c must return Boolean true/false. Ignore ExpectedValueSource__c, ComparisonOperator__c, SourceQuery__c.
4. Query checks: primary value usually from SourceQuery__c; comparison via ExpectedValueSource__c = FixedValue | RecordFormula | AnotherQuery.
5. CompareTwoQueries: both sides from SOQL; no ExpectedValueSource__c.
6. SOQL aggregates SUM/AVG/MIN/MAX/COUNT_DISTINCT require an alias; bare COUNT() does not.
7. SOQL merge tokens: {!record.FieldApiName} on the current record (e.g. {!record.Id}, {!record.AnnualRevenue}, {!record.Customer_Tier__c}).
8. Max 25 active Rules per Check Set per run. Use applicability gates to reduce noise.
9. Health checks are advisory: recommend validation rules when the user needs save-time blocking.
10. If metadata cannot express the rule, recommend Apex (RecordHealthCheckRule interface) and say what the class must do. Cite an example from docs/examples/apex/ (1=multi-object OR, 2=child aggregation, 3=composite score). Ship class API name only if it exists in the package: AccountHasRecentActivityCheck, AccountOpenOpportunityHealthCheck. Do not recommend Apex for save-time field format rules: use validation rules.
11. QueryResultHandling__c = OneResult for aggregates and single COUNT(); AnyRowPasses / AllRowsPass for row-by-row; CompareAsLists for list operators.
12. ListContainsAny / ListDoesNotContainAny: primary single value from FindInListFormula__c, list from ComparisonQuery__c (not SourceQuery__c). PassConditionFormula__c is record-formula-only.
13. Do not invent field API names: use names the user provided or mark them as placeholders to verify in Setup.

DECISION ORDER:
- On-record only, no SOQL → Formula
- One SOQL result vs static / formula / second query → Query
- Two SOQL results compared → CompareTwoQueries
- Complex date math, scoring, callouts → Apex

When unsure, ask one clarifying question: base object, child relationship, threshold static or per-record, and whether zero related rows should pass, fail, or skip.
```

## 3. Decision tree

```text
User describes a business rule
│
├─ Answer is only on the current record (or Parent.Field via formula)?
│  └─ YES → EvaluationType__c = Formula
│            Required: PassConditionFormula__c (Boolean)
│
├─ One query result compared to something?
│  └─ YES → EvaluationType__c = Query
│            Primary: SourceQuery__c (+ SourceQueryField__c unless bare COUNT())
│            Compare to: FixedValue | RecordFormula | AnotherQuery | (none for IsBlank/IsNotBlank)
│
├─ Two independent queries compared?
│  └─ YES → EvaluationType__c = CompareTwoQueries
│            SourceQuery__c + ComparisonQuery__c
│
├─ single value must appear in / stay out of a query result list?
│  └─ YES → EvaluationType__c = Query
│            FindInListFormula__c = single value (field or formula on record)
│            ComparisonQuery__c = list source
│            QueryResultHandling__c = CompareAsLists
│            ComparisonOperator__c = ListContainsAny | ListDoesNotContainAny
│
└─ Needs code, external data, or unsupported shape?
   └─ EvaluationType__c = Apex
      ApexClass__c = class implementing RecordHealthCheckRule
      ApexParametersJson__c = optional JSON object for per-Rule tuning
      See docs/examples/index.md#example-catalog for the apex examples
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
| `ObjectApiName__c` | Record Object API Name | Yes | `Account` |
| `CardTitle__c` | Card Title | Yes | `Sales Pipeline Health` |
| `CardSubtitle__c` | Card Subtitle | No | `Open pipeline vs revenue targets` |
| `CardRunMode__c` | Start Checks | Yes | `Automatic` or `Manual` |
| `CardRevealMode__c` | How checks appear | Yes | `AllAtOnce` or `OneAtATime` |
| `PassedChecksDisplay__c` | Passed Checks | Yes | `Show` or `Hide` |
| `SkippedChecksDisplay__c` | Skipped Checks | Yes | `Show` or `Hide` |
| `FoundExpectedDisplay__c` | Found/Expected Display | Yes | `OnDemand` (default), `FailuresOnly`, or `AllRows` |
| `IsActive__c` | Active | No | `true` |
| `ShowDiagnostics__c` | Show Troubleshooting Details | No | `false` in production. When `true`, user also needs `Record_Health_Check_View_Details` (from `Record_Health_Check_Admin`). See [Show Troubleshooting Details guide](show-diagnostics.md). |

**Component wiring:** In Lightning App Builder, select the intended **Check Set** for the record page. The stored LWC property is `checkSetName`; Apex still receives that value as `configName`.

### 4.3 Rule table

Always include (all Check Types):

| API field | Setup label | Required | Example |
| --- | --- | --- | --- |
| `DeveloperName` | Developer Name | Yes | `Account_Pipeline_Meets_15x_Revenue` |
| `MasterLabel` | Label | Yes | `Sales Pipeline Meets 1.5x Revenue` |
| `Record_Health_Check_Set__c` | Check Set | Yes | `Account_Pipeline_Health` |
| `CheckTitle__c` | Check Name (user-facing row title) | Yes | `Open pipeline ≥ 1.5× annual revenue` |
| `EvaluationType__c` | Check Type | Yes | `Query` |
| `EvaluationOrder__c` | Run Order (lower runs first) | Yes | `10` (use gaps: 10, 20, 30…) |
| `Category__c` | Category | No | `Sales Pipeline`, `Required Field Completeness`, `Data Quality`, or blank. Metadata only — UI grouping not implemented yet. |
| `FailureSeverity__c` | Failure Severity | Yes | `Error`, `Warning`, or `Info` |
| `FailureMessage__c` | Message When Check Fails | Yes | `{!record.Name} pipeline is below 1.5× annual revenue.` |
| `FixMessage__c` | Fix Instructions | No | `Review open opportunities…` (renders on FAIL rows) |
| `ActionLabel__c` | Action Button Label | No | `Open pipeline playbook` |
| `ActionUrl__c` | Action Button URL | No | `/lightning/r/Report/00O.../view?fv0={!record.Id}` or `https://example.com/pipeline-playbook` |
| `ApplicabilityMode__c` | Applies To | Yes | `Always`, `Formula`, or `SOQL` |
| `IsActive__c` | Active | No | `true` |

Add type-specific fields from Section 5.

Use remediation fields only for read-only guidance or deep links. Do not describe an automatic write action; the card remains advisory. Unsafe or overlong URLs are dropped, but Fix Instructions can still render. For report links, related-list links, and external playbook examples, see [Action Links and Fix Instructions](action-links.md).

### 4.4 Pattern citation

Name the pattern and reference a shipped example when possible (Section 7-8). For Apex, cite the complexity level and doc under `examples/apex/`.

### 4.5 Class sketch (Apex only)

When `EvaluationType__c` = `Apex`, add a section after the Rule table. See [Apex plugin reference](../apex/plugin-reference.md) for full patterns.

| Item | What to include |
| ---- | --------------- |
| `recordId` | `context.recordId` for SOQL; query extra fields: `context.record` is partial |
| Parent / custom fields | `Parent.BillingCity` in SELECT, or `Primary_Contact__r.Email` |
| JSON defaults | Apex constants + `ApexParametersJson__c` keys (e.g. `daysBack`) with bounds |
| Shipped vs custom | `AccountHasRecentActivityCheck`, `AccountOpenOpportunityHealthCheck` only when pattern matches |
| Outcome | `PASS`/`FAIL`; required `actualValue`/`expectedValue` on both statuses |
| Applicability | Why `ApplicabilityMode__c` is not `Always` if gated |

## 5. Rule fields by Check Type

### 5.1 Formula (`EvaluationType__c` = `Formula`)

Setup label: **Check fields on this record**.

| API field | Required | Value |
| --- | --- | --- |
| `PassConditionFormula__c` | Yes | Boolean formula; `true` = pass |
| `DisplayFoundFormula__c` | Optional | single-value formula shown as **Found** (left side of a comparison). Display only — does not affect pass/fail. |
| `DisplayExpectedFormula__c` | Optional | single-value formula shown as **Expected** (right side). Display only; blank = Expected echoes `PassConditionFormula__c`. |
| `FormulaResultType__c` | Optional | Type of the Found/Expected scalars (`Number`/`Text`/`Date`/`DateTime`/`Boolean`), or `Auto`. |

Operands in any of these formulas may be calculated fields (formula, roll-up) at any depth — the engine loads the full dependency chain.

**Found/Expected are display-only and NOT compared to each other.** `PassConditionFormula__c` performs the comparison and decides pass/fail. Set Found/Expected only for comparison/balance checks, and mirror each side of the Pass/Fail comparison (Found = left operand, Expected = right) so the row does not mislead. For framework-driven comparison with an operator, use a Query check (`ExpectedValueSource__c` = `FixedValue` / `RecordFormula` / `AnotherQuery`).

**Leave unset:** `SourceQuery__c`, `ComparisonOperator__c`, `ExpectedValueSource__c`, `QueryResultHandling__c` (ignored).

**Examples:**

```text
NOT(ISBLANK(BillingCity))
OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))
AnnualRevenue > 0
BillingCity = ShippingCity
NOT(ISBLANK(Parent.BillingCity))
```

### 5.2 Query (`EvaluationType__c` = `Query`)

Setup label: **Check records with a query**.

| API field | When required |
| --- | --- |
| `SourceQuery__c` | Always, except `ListContainsAny` / `ListDoesNotContainAny` |
| `SourceQueryField__c` | When query selects fields or aliased aggregates; omit for bare `COUNT()` |
| `QueryResultHandling__c` | Always: `OneResult`, `AnyRowPasses`, `AllRowsPass`, `CompareAsLists` |
| `ComparisonOperator__c` | Always (see Section 6) |
| `ExpectedValueSource__c` | When comparison operator needs a right-hand side (`FixedValue`, `RecordFormula`, `AnotherQuery`) |
| `ExpectedFixedValue__c` | When `ExpectedValueSource__c` = `FixedValue` |
| `ExpectedRecordFormula__c` | When `ExpectedValueSource__c` = `RecordFormula` |
| `ComparisonQuery__c` | When `ExpectedValueSource__c` = `AnotherQuery`, or list operators |
| `ComparisonQueryField__c` | When comparison query returns field values (not bare `COUNT()`) |
| `NoRowsResult__c` | Required for `AnyRowPasses`, `AllRowsPass`, `CompareAsLists` |
| `EmptyValueHandling__c` | Recommended for row-by-row modes; default `SkipRecordsWithMissingValue` |

**List membership exception** (`ListContainsAny`, `ListDoesNotContainAny`):

| API field | Role |
| --- | --- |
| `FindInListFormula__c` | Primary single value (field or formula on record). |
| `ComparisonQuery__c` | SOQL returning the list |
| `ComparisonQueryField__c` | Column to read from list query |
| `QueryResultHandling__c` | `CompareAsLists` |

### 5.3 Compare two queries (`EvaluationType__c` = `CompareTwoQueries`)

| API field | Required |
| --- | --- |
| `SourceQuery__c` | Yes: primary side |
| `ComparisonQuery__c` | Yes: comparison side |
| `SourceQueryField__c` | When primary returns fields or aliased aggregates |
| `ComparisonQueryField__c` | When comparison returns fields or aliased aggregates |
| `QueryResultHandling__c` | `OneResult` (single value) or `CompareAsLists` (list operators) |
| `ComparisonOperator__c` | single value or list comparison operator |

**Leave unset:** `ExpectedValueSource__c` (both sides are queries).

List operators for `CompareAsLists`: `ListsOverlap`, `ListContainsAll`, `ExactListMatch`.

### 5.4 Apex (`EvaluationType__c` = `Apex`)

Full walkthroughs: [Apex examples index](../examples/index.md#example-catalog) · [Apex plugin reference](../apex/plugin-reference.md) · [Contract](../apex/plugin-contract.md)

| API field | Required | Notes |
| --- | --- | --- |
| `ApexClass__c` | Yes | Class implementing `RecordHealthCheckRule`: deploy before activating Rule |
| `ApexParametersJson__c` | No | JSON **object** (not array), e.g. `{"daysBack": 90}`, `{"minDigits": 10}`, `{"staleDays": 30}` |

**Plugin contract (summary):** Full how-to: [Apex plugin reference](../apex/plugin-reference.md).

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
- Pair with applicability (`ApplicabilityMode__c` = `Formula` or `SOQL`) when the check should not run for every record.

**Shipped classes:**

| Class | JSON keys | Pattern |
| --- | --- | --- |
| `AccountHasRecentActivityCheck` | `daysBack` (1-3650, default 30) | Task + Event window |
| `AccountOpenOpportunityHealthCheck` | `staleDays` (1-3650, default 30) | Unhealthy open Opportunity detection |

Do **not** invent class names as shipped unless listed above. For composite scoring, name a **new** class and include a Class sketch for implementation (see [example 3](../examples/apex/03-strategic-readiness.md)).

### 5.5 Applicability (all rules)

| `ApplicabilityMode__c` | Additional fields |
| --- | --- |
| `Always` | None |
| `Formula` | `ApplicabilityFormula__c` (Boolean, `true` = run check) |
| `SOQL` | `ApplicabilityCountQuery__c` (`SELECT COUNT()` or `SELECT COUNT(Id)`), `ApplicabilityCountOperator__c`, `ApplicabilityCountThreshold__c` |

### 5.6 Dependencies

| API field | Value |
| --- | --- |
| `PrerequisiteRule__c` | `DeveloperName` of prerequisite Rule in same Check Set (must have lower `EvaluationOrder__c`) |

Prerequisite must return `PASS` or dependent is `SKIPPED`.

## 6. operators (`ComparisonOperator__c`)

| API value | Setup label (approx.) | Needs right-hand side? | Valid with |
| --- | --- | --- | --- |
| `Equals` | Equals | Yes | Query, CompareTwoQueries |
| `NotEquals` | Not equals | Yes | Query, CompareTwoQueries |
| `GreaterThan` | Greater than | Yes | Query, CompareTwoQueries |
| `GreaterThanOrEqual` | At least | Yes | Query, CompareTwoQueries |
| `LessThan` | Less than | Yes | Query, CompareTwoQueries |
| `LessThanOrEqual` | At most | Yes | Query, CompareTwoQueries |
| `Contains` | Contains | Yes | Query, CompareTwoQueries (case-sensitive) |
| `DoesNotContain` | Does not contain | Yes | Query, CompareTwoQueries (case-sensitive) |
| `IsBlank` | Is empty | No | Query |
| `IsNotBlank` | Is not empty | No | Query |
| `ListContainsAny` | List includes any of | List in `ComparisonQuery__c` | Query only |
| `ListDoesNotContainAny` | List excludes all of | List in `ComparisonQuery__c` | Query only |
| `ListsOverlap` | Lists overlap | Second query list | CompareTwoQueries + CompareAsLists |
| `ListContainsAll` | List contains all | Second query list | CompareTwoQueries + CompareAsLists |
| `ExactListMatch` | Exact list match | Second query list | CompareTwoQueries + CompareAsLists |

## 7. Pattern reference

| Business intent | CheckMethod | WhenMultipleRows | CompareAgainst / notes |
| --- | --- | --- | --- |
| Field required on record | Formula | | `NOT(ISBLANK(Field))` |
| Either field A or B required | Formula | | `OR(NOT(ISBLANK(A)), NOT(ISBLANK(B)))` |
| At least N related records | Query | OneResult | `COUNT()` > FixedValue |
| Every child row meets bar | Query | AllRowsPass | vs FixedValue or RecordFormula |
| Any child row meets bar | Query | AnyRowPasses | vs FixedValue or RecordFormula |
| Aggregate ≥ static threshold | Query | OneResult | SUM/AVG/etc. vs FixedValue |
| Aggregate ≥ per-record formula | Query | OneResult | SUM/etc. vs RecordFormula |
| Aggregate ≥ second query | Query | OneResult | vs AnotherQuery |
| Two counts or aggregates compared | CompareTwoQueries | OneResult | single-value operator |
| Account field in child list | Query | CompareAsLists | ListContainsAny + ValueToTest |
| Field not in reference list | Query | CompareAsLists | ListDoesNotContainAny |
| Two lists overlap / contain / match | CompareTwoQueries | CompareAsLists | ListsOverlap / ListContainsAll / ExactListMatch |
| Type-specific rule only | Formula | | Applicability Formula: `ISPICKVAL(Type, "Partner")` |
| Run only when children exist | | | Applicability SOQL: COUNT > 0 |
| Recent activity (Task or Event) | Apex | | `AccountHasRecentActivityCheck` |
| Unhealthy child rows (combined) | Apex | | `AccountOpenOpportunityHealthCheck` |
| Weighted readiness score | Apex | | Custom class: [apex/03-strategic-readiness.md](../examples/apex/03-strategic-readiness.md) |

## 8. Supported vs unsupported combinations

### Supported (configure with confidence)

| Shape | How |
| --- | --- |
| SOQL left, static right | Query + `FixedValue` |
| SOQL left, record formula right | Query + `RecordFormula` |
| SOQL left, second query right | Query + `AnotherQuery` |
| Two queries compared | CompareTwoQueries |
| Formula single value in query list | Query + `ListContainsAny` / `ListDoesNotContainAny` |
| SUM vs `AnnualRevenue * 1.5` | Query + OneResult + `RecordFormula` |

### Unsupported or awkward (recommend workaround)

| Shape | Problem | Workaround |
| --- | --- | --- |
| Formula check + Expected Value Comes From | Formula path ignores comparison fields | Put full logic in `PassConditionFormula__c` |
| Formula left, SOQL single value right (Equals, GreaterThan, …) | Primary must be `SourceQuery__c` for single-value operators | Flip: query left, `RecordFormula` right; or CompareTwoQueries; or Apex |
| `SELECT SUM(x) FROM ...` without alias | Framework cannot read column | Add alias: `SUM(Amount) totalAmt` + `SourceQueryField__c = totalAmt` |
| Multiplier on CompareTwoQueries right side | Both sides are raw query values only | Use Query + `RecordFormula`, or Apex |
| Blocking save on fail | Product is read-time only | Validation rule or Flow |
| More than 25 active rules | Hard cap per run | Split Check Sets or deactivate low-value rules |
| Org-wide batch audit | No packaged scheduler | Apex batch calling `RecordHealthCheck.run` |

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
- **`NoRowsResult__c`:** `Pass`, `Fail`, `Skip`, `UnableToEvaluate` when a query returns **zero rows** (including CompareTwoQueries OneResult when either side's query is empty).
- **`EmptyValueHandling__c`:** when rows exist but a field under test is null and the comparison operator cannot decide (typically `SkipRecordsWithMissingValue`), the check is **SKIPPED** with `VALUE_IS_EMPTY`: not governed by `NoRowsResult__c`.

## 10. Worked examples (copy-ready)

### 10.1 Billing City required (Formula)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Formula` |
| `PassConditionFormula__c` | `NOT(ISBLANK(BillingCity))` |
| `ApplicabilityMode__c` | `Always` |
| `FailureSeverity__c` | `Error` |
| `FailureMessage__c` | `{!record.Name} is missing Billing City.` |

Shipped: `Account_DQ_BillingCity` in `Account_Data_Quality`.

### 10.2 At least one Contact (Query)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Query` |
| `SourceQuery__c` | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| `QueryResultHandling__c` | `OneResult` |
| `ComparisonOperator__c` | `GreaterThan` |
| `ExpectedValueSource__c` | `FixedValue` |
| `ExpectedFixedValue__c` | `0` |

Shipped: `Account_EU_HasAtLeastOneContact`.

### 10.3 Open pipeline ≥ 1.5× annual revenue (Query + aggregate + formula)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Query` |
| `SourceQuery__c` | `SELECT SUM(TotalPrice) totalPipeline FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND TotalPrice != null` |
| `SourceQueryField__c` | `totalPipeline` |
| `QueryResultHandling__c` | `OneResult` |
| `ComparisonOperator__c` | `GreaterThanOrEqual` |
| `ExpectedValueSource__c` | `RecordFormula` |
| `ExpectedRecordFormula__c` | `AnnualRevenue * 1.5` |
| `EmptyValueHandling__c` | `SkipRecordsWithMissingValue` |
| `ApplicabilityMode__c` | `Formula` |
| `ApplicabilityFormula__c` | `NOT(ISBLANK(AnnualRevenue)) && AnnualRevenue > 0` |

Use `Amount` instead of `TotalPrice` if products are not used. Similar shipped pattern: `Account_CTQ_SumVsAnnualRevenue` (1:1 revenue, via CompareTwoQueries).

### 10.4 Billing State appears in Contact states (list membership)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Query` |
| `FindInListFormula__c` | `BillingState` |
| `ComparisonQuery__c` | `SELECT MailingState FROM Contact WHERE AccountId = {!record.Id} AND MailingState != null` |
| `ComparisonQueryField__c` | `MailingState` |
| `QueryResultHandling__c` | `CompareAsLists` |
| `ComparisonOperator__c` | `ListContainsAny` |
| `NoRowsResult__c` | `Skip` |

Shipped: `Account_QC_ListContainsAny`.

### 10.5 Partner accounts need Billing Country (Formula + applicability)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Formula` |
| `PassConditionFormula__c` | `NOT(ISBLANK(BillingCountry))` |
| `ApplicabilityMode__c` | `Formula` |
| `ApplicabilityFormula__c` | `ISPICKVAL(Type, "Partner")` |

Shipped: `Account_Adv_PartnerBillingCountry`.

### 10.6 Recent Task/Event activity (Apex: multi-object)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Apex` |
| `ApexClass__c` | `AccountHasRecentActivityCheck` |
| `ApexParametersJson__c` | `{"daysBack": 90}` |
| `ApplicabilityMode__c` | `Always` |
| `FailureSeverity__c` | `Warning` |
| `FailureMessage__c` | `{!record.Name} has no completed tasks or logged events in the last 90 days.` |

Sample Rule in `package-Account_Advanced_Checks.xml`: `Account_Adv_RecentActivity`. Doc: [apex/01-recent-activity.md](../examples/apex/01-recent-activity.md).

### 10.7 Unhealthy open Opportunities (Apex: child aggregation)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Apex` |
| `ApexClass__c` | `AccountOpenOpportunityHealthCheck` |
| `ApexParametersJson__c` | `{"staleDays": 30}` |
| `ApplicabilityMode__c` | `SOQL` |
| `ApplicabilityCountQuery__c` | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| `ApplicabilityCountOperator__c` | `GreaterThan` |
| `ApplicabilityCountThreshold__c` | `0` |
| `FailureSeverity__c` | `Error` |
| `FailureMessage__c` | One or more open opportunities are stale, missing a Next Step, or have no close date this quarter. |

Doc: [apex/02-open-opportunity-health.md](../examples/apex/02-open-opportunity-health.md).

### 10.8 Strategic readiness score (Apex: composite, custom deploy)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `Apex` |
| `ApexClass__c` | `AccountStrategicReadinessCheck` *(not in package: deploy separately)* |
| `ApexParametersJson__c` | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApplicabilityMode__c` | `Formula` |
| `ApplicabilityFormula__c` | `ISPICKVAL(Type, "Strategic")` |

Include a **Class sketch** when outputting this pattern. Full reference code: [apex/03-strategic-readiness.md](../examples/apex/03-strategic-readiness.md).

## 11. Naming conventions

| Item | Convention | Example |
| --- | --- | --- |
| Check Set `DeveloperName` | `Object_Purpose` | `Account_Pipeline_Health` |
| Rule `DeveloperName` | `Object_ShortDescription` | `Account_Pipeline_Meets_15x_Revenue` |
| Rule `MasterLabel` | Spaces, readable in Setup | `Sales Pipeline Meets 1.5x Revenue` |
| Rule `CheckTitle__c` | User-facing, concise | `Open pipeline ≥ 1.5× revenue` |
| `EvaluationOrder__c` | Gaps of 10 | 10, 20, 30 (dependencies: prerequisite lower) |

## 12. Sample Check Sets (reference for LLMs)

Deploy `manifest/package-core.xml` first, then `manifest/package-<DeveloperName>.xml`.

| Check Set DeveloperName | Manifest | Rules | Best for copying |
| --- | --- | --- | --- |
| `Account_Everyday_Use_Cases` | `package-Account_Everyday_Use_Cases.xml` | 16 | Production-style everyday patterns |
| `Account_Data_Quality` | `package-Account_Data_Quality.xml` | 4 | Simple formula basics |
| `Account_Formula_Coverage` | `package-Account_Formula_Coverage.xml` | 7 | Formula variations |
| `Account_Query_Coverage` | `package-Account_Query_Coverage.xml` | 17 | Every Query comparison operator |
| `Account_Aggregate_Coverage` | `package-Account_Aggregate_Coverage.xml` | 6 | SUM, AVG, MIN, MAX, COUNT |
| `Account_Compare_Queries` | `package-Account_Compare_Queries.xml` | 10 | Dual-query patterns |
| `Account_Advanced_Checks` | `package-Account_Advanced_Checks.xml` | 8 | Dependencies, thresholds, Apex |
| `Account_Compliance_Audit` | `package-Account_Compliance_Audit.xml` | 10 | Compliance patterns |
| `Account_AppComp_Coverage` | `package-Account_AppComp_Coverage.xml` | 6 | SOQL applicability gates |
| `Account_Relationships` | `package-Account_Relationships.xml` | 4 | Relationship existence checks |

Full rule list: [Examples: Sample Check Set packages](../examples/index.md#sample-check-set-packages).

## 13. Framework limits (do not exceed in recommendations)

| Limit | Value |
| --- | --- |
| Active rules per run | 25 (lowest `EvaluationOrder__c` first) |
| SOQL rows per query | 2000 default (`MaxQueryRows__c` can lower, not raise) |
| Formula eval calls per Apex transaction | 100 platform; framework guards at ~95 |
| Concurrent evaluate calls (LWC) | 5 when Stop After System Error is off |
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
| Pattern matrix + merge tokens | [Examples README](../examples/index.md) |
| When to use which Check Type | [Configuration Guide: what it can check](configuration-guide.md#2-what-it-can-check) |
| Copy-paste examples by type | [Formula](../examples/index.md#example-catalog), [Query](../examples/index.md#example-catalog), [Compare two queries](../examples/index.md#example-catalog), [Aggregates](../examples/index.md#pattern-reference-aggregates) |
| Reason codes & contracts | [Design Specification](../reference/record-health-check-design-spec.md) |
| Install & first rule | [Getting Started](../installation/getting-started.md) |

## 16. Gemini gem checklist

When building a Gemini gem for this project:

1. Upload this file as primary knowledge.
2. Add `configuration-guide.md` and `examples/index.md` as secondary knowledge.
3. Paste Section 2 (system prompt) into gem instructions.
4. Tell users to paste: base object, fields involved, pass/fail semantics, and whether zero children should pass or skip.
5. Require gem output to use Section 4 tables (API names, not Setup-only labels).
6. Link humans to [Getting Started](../installation/getting-started.md) for entering metadata in Setup.
