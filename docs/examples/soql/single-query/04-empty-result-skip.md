# 04 · Empty result is a skip

> Passes when every open Opportunity has a positive Amount; skipped when there are no open Opportunities; fails when any open Opportunity has a zero or missing Amount.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Open_Opportunities_Have_Amount`](../../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Open_Opportunities_Have_Amount.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

When open Opportunities exist on the Account, every one must have Amount greater than zero. When there are no open Opportunities, the check is skipped: auditing "every record must pass" is meaningless on an empty set.

## When to use this

Reach for this pattern when the rule applies only when matching child rows exist. "All open opportunities have an amount" should not vacuously pass on an Account with no pipeline. Skip the check on zero rows avoids that false pass.

## Why this evaluator

Every-row validation on a child collection with an empty-set escape hatch.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot iterate open Opportunities. |
| Check records with a query | Every record must pass + zero rows skip | **This example.** Empty set skips; populated set must all pass. |
| Compare two queries | | No cross-query comparison needed. |
| Custom Apex | Apex loop with empty guard | Same outcome when zero-row skip is configured. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Zero rows should fail | [Empty result fail](03-empty-result-fail.md) |
| Only one row needs to clear the bar | [Any row static threshold](05-any-row-static-threshold.md) |

**Verdict:** Check records with a query with Skip the check on zero rows is the right evaluator when the audit applies only when child rows exist. Use Fail the check when an empty set is itself a problem.

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | All Open Opportunities Have an Amount |
| Developer Name | Open_Opportunities_Have_Amount |
| Check Type | Check records with a query |
| Data Query | `SELECT Amount FROM Opportunity WHERE AccountId = {!Id} AND IsClosed = false` |
| Field To Read | Amount |
| How To Interpret Query Results | Every record must pass |
| Operator | Greater than |
| Expected Value Comes From | A fixed value |
| Fixed Value | 0 |
| If Query Finds No Records | Skip the check |
| Run This Check When | Always |
| Severity | Error |
| Message When Check Fails | One or more open opportunities is missing an Amount. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change.

## How it works

With zero matching rows, the check is skipped. With one or more rows, Every record must pass requires each Amount to be greater than the fixed value.

```sql
SELECT Amount FROM Opportunity
WHERE AccountId = {!Id} AND IsClosed = false
```

**What this demonstrates**

- **Skip the check on zero rows**: no open Opportunities means no audit row.
- **Every record must pass**: one failing Opportunity fails the whole check.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set** to `Account_Examples_Query`. See the [example catalog](../../index.md#sample-check-set-packages) for every Check Set and what it contains.

## Try it

On an Account with open Opportunities, clear or zero one Amount to fail; ensure every open Opportunity has a positive Amount to pass. Close or delete all open Opportunities to see the check skipped.

[← Examples index](../../index.md) · [← Prev: Empty result fail](03-empty-result-fail.md) · [Next: Any row static threshold →](05-any-row-static-threshold.md)
