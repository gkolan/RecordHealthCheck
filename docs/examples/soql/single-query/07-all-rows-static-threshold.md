# 07 · All child records match a static threshold

> Passes when every open Opportunity has a positive Amount; skips when there are no open Opportunities; fails when any open Opportunity has a zero or missing Amount.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Ex_Q_AllOppsPositiveAmt`](../../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Ex_Q_AllOppsPositiveAmt.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

When open Opportunities exist, every one must have Amount greater than zero. Accounts with no open Opportunities are skipped. One bad row fails the entire check.

## When to use this

Reach for this pattern when data quality must hold across the entire child set: every open deal has value, every contact has email, every case has a subject. **Every record must pass** enforces AND logic across returned rows.

## Why this evaluator

Universal child-row validation with skip-on-empty.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot iterate child rows. |
| Check records with a query | Every record must pass + zero rows skip | **This example.** Every row is checked; empty set skips. |
| Compare two queries | | No second query involved. |
| Custom Apex | Apex `allMatch` | Same outcome when metadata modes suffice. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Only one row needs to pass | [Any row static threshold](05-any-row-static-threshold.md) |
| Compare each row to an Account field | [All rows Account field](08-all-rows-account-field.md) |

**Verdict:** Check records with a query with Every record must pass is the right evaluator when the entire child set must satisfy one condition. Pair it with Skip the check when zero rows means "nothing to audit."

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | All Open Opportunities Have Positive Amount |
| Developer Name | Ex_Q_AllOppsPositiveAmt |
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
| Message When Check Fails | One or more open opportunities has a zero or missing Amount. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change.

## How it works

With zero open Opportunities, the check is skipped. Otherwise each returned Amount must be greater than the fixed value.

```sql
SELECT Amount FROM Opportunity
WHERE AccountId = {!Id} AND IsClosed = false
```

**What this demonstrates**

- **Every record must pass**: one failing row fails the check.
- **Skip on empty**: no pipeline means no audit row.
- **Static Fixed Value**: the same positive-Amount bar applies to every Account.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set** to `Account_Examples_Query`. See the [example catalog](../../index.md#sample-check-set-packages) for every Check Set and what it contains.

## Try it

On an Account with open Opportunities, set one Amount to zero or blank to fail; ensure every open Opportunity has a positive Amount to pass. Remove all open Opportunities to see the check skipped.

[← Examples index](../../index.md) · [← Prev: Any row formula threshold](06-any-row-formula-threshold.md) · [Next: All rows Account field →](08-all-rows-account-field.md)
