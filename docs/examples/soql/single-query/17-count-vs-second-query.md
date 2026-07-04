# 17 · Primary count compared against a second query count

> Passes when Contact count is greater than or equal to open Case count; fails when open Cases outnumber Contacts.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Contact_Count_Covers_Open_Case_Count`](../../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Contact_Count_Covers_Open_Case_Count.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

Contact count on the Account must be greater than or equal to open Case count. Primary Query (SOQL) supplies the primary `COUNT()`; Expected Value Comes From = A second query result runs a second `COUNT()` for the comparison side before the operator applies.

## When to use this

Reach for this pattern when the right-hand side of a count comparison is a second SOQL result rather than a fixed literal or Account formula: staffing vs workload, coverage ratios, or any "count A vs count B" rule inside Check records with a query. Compare two queries is the alternative when both queries are first-class Primary Query (SOQL) and Second Query fields.

## Why this evaluator

Two dynamic counts from different child objects compared in one Check records with a query rule via A second query result.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot count Contacts and Cases. |
| Check records with a query | Primary Query (SOQL) `COUNT()` vs Second Query `COUNT()` | **This example.** A second query result as compare side. |
| Compare two queries | Primary Query (SOQL) + Second Query both `COUNT()` | Equivalent dual-count pattern with Compare two queries Check Type. |
| Use custom Apex | Apex two counts | Same outcome when metadata chains queries. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Count vs fixed literal | [Child count minimum one](01-child-count-minimum-one.md) |
| Dual `COUNT()` as Compare two queries | [Two aggregate counts](../compare-two-queries/01-aggregate-counts.md) |

**Verdict:** Check records with a query with Expected Value Comes From = A second query result suits count-vs-count when Primary Query (SOQL) is the primary count. Use Compare two queries when neither side is "primary + compare-to" and both queries are peers.

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | Contact Count Covers Open Case Count |
| Developer Name | Contact_Count_Covers_Open_Case_Count |
| Check Type | Check records with a query |
| Primary Query (SOQL) | `SELECT COUNT() FROM Contact WHERE AccountId = {!Id}` |
| How To Interpret Query Results | Expect one row or aggregate result |
| Operator | At least |
| Expected Value Comes From | A second query result |
| Second Query | `SELECT COUNT() FROM Case WHERE AccountId = {!Id} AND IsClosed = false` |
| Applies To | All records |
| Severity | Warning |
| Message When Check Fails | Open case count exceeds contact count. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change. Edit Second Query to change what the primary count is compared against.

## How it works

The engine runs Primary Query (SOQL) and Second Query, reads one `COUNT()` from each, and applies greater than or equal.

```sql
-- Primary Query (SOQL)
SELECT COUNT() FROM Contact WHERE AccountId = {!Id}

-- Second Query
SELECT COUNT() FROM Case
WHERE AccountId = {!Id} AND IsClosed = false
```

**What this demonstrates**

- **A second query result compare side**: second `COUNT()` without switching to Compare two queries Check Type.
- **Ratio-style policy**: Contacts must cover open Case volume.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set Developer Name** to `Account_Examples_Query`. See the [example catalog](../../index.md#sample-check-set-packages) for every Check Set and what it contains.

## Try it

Add open Cases until Case count exceeds Contact count to fail; add Contacts or close Cases until Contact count is greater than or equal to open Case count to pass.

[← Examples index](../../index.md) · [← Prev: List does not contain](16-list-does-not-contain.md)
