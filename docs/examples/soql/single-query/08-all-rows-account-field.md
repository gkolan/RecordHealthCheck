# 08 · All child records match a field from the Account

> Passes when every Contact's Mailing State equals the Account Billing State; passes vacuously when the Account has no Contacts; fails when any Contact's state differs.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Ex_Q_ContactStateVsBilling`](../../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Ex_Q_ContactStateVsBilling.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

Every Contact on the Account must have Mailing State equal to the Account's Billing State. Accounts with no Contacts pass via Pass the check on zero rows: the rule is vacuously satisfied when there is nothing to compare.

## When to use this

Reach for this pattern when each child row must match a parent field value that changes per Account. Expected Formula (on this record) supplies the comparison side from the Account; Every record must pass walks the Contact list.

## Why this evaluator

Per-row child-to-parent field correlation requires querying children and comparing each row to a formula on the Account.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot iterate Contacts. |
| Check records with a query | Every record must pass + Expected Formula (on this record) | **This example.** Each Contact vs parent Billing State. |
| Compare two queries | Scalar vs scalar | Does not enforce all Contacts match: compares one picked row. |
| Custom Apex | Apex loop | Same outcome when Every record must pass suffices. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Fixed numeric threshold on every row | [Every record static threshold](07-all-rows-static-threshold.md) |
| Billing State appears in any Contact state | [List contains any](15-list-contains-any.md) |

**Verdict:** Check records with a query with Expected Value Comes From = A formula on this record and Every record must pass is the right evaluator when every child row must match a parent field. Use Pass the check on zero rows when an empty child set should not fail.

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | Contact Mailing State Matches Billing State |
| Developer Name | Ex_Q_ContactStateVsBilling |
| Check Type | Check records with a query |
| Data Query | `SELECT MailingState FROM Contact WHERE AccountId = {!Id}` |
| Field To Read | MailingState |
| How To Interpret Query Results | Every record must pass |
| Operator | Equals |
| Expected Value Comes From | A formula on this record |
| Expected Formula (on this record) | `BillingState` |
| If Query Finds No Records | Pass the check |
| Run This Check When | Always |
| Severity | Warning |
| Message When Check Fails | One or more contacts have a Mailing State that does not match Account Billing State. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change. Edit Expected Formula (on this record) to compare against a different Account field.

## How it works

For each Contact row, Mailing State is compared to Expected Formula (on this record) evaluated on the Account. Zero Contacts yields pass via Pass the check.

```sql
SELECT MailingState FROM Contact WHERE AccountId = {!Id}
```

```text
-- Expected Formula (on this record) (evaluated on the Account)
BillingState
```

**What this demonstrates**

- **Per-Account comparison value**: Billing State varies per Account.
- **Pass the check on zero rows**: no Contacts means pass, not skip.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set Developer Name** to `Account_Examples_Query`. See the [example catalog](../../index.md#sample-check-set-packages) for every Check Set and what it contains.

## Try it

Mismatch one Contact's Mailing State from Billing State to fail; align all Contacts to pass. Remove all Contacts to see pass via zero-row behavior.

[← Examples index](../../index.md) · [← Prev: Every record static threshold](07-all-rows-static-threshold.md) · [Next: Contains substring →](09-contains-substring.md)
