# 15 · Primary value appears in a child list

> Passes when Account Billing State appears among Contact Mailing States; skipped when no Contact has Mailing State; fails when Billing State matches none of them.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Billing_State_In_Contact_Mailing_States`](../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Billing_State_In_Contact_Mailing_States.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

The Account's Billing State must appear in at least one Contact's Mailing State on the same Account. Value To Test supplies the scalar from the Account; Second Query builds the Contact list. The check runs only when at least one Contact has Mailing State set.

## When to use this

Reach for this pattern when a parent scalar must appear somewhere in a child list: billing state among contact states, tier among product lines, account code among child references. List includes any of is the Check records with a query list operator (Compare both results as lists mode).

## Why this evaluator

Scalar-from-parent tested against a query-built list: not a row-by-row All rows pass.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot list-scan Contact states. |
| Check records with a query | Value To Test + Second Query + List includes any of | **This example.** |
| Compare two queries | Two full queries compared | Check records with a query list mode uses Value To Test instead of Primary Query (SOQL). |
| Use custom Apex | Apex list contains | Same outcome when list operator suffices. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Every Contact state must equal Billing State | [All rows Account field](08-all-rows-account-field.md) |
| Scalar must not appear in list | [List does not contain](16-list-does-not-contain.md) |

**Verdict:** Check records with a query with Compare both results as lists and List includes any of is the right evaluator when a record field must appear in a query result list. Use Compare two queries when both sides come from full queries without Value To Test.

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | Billing State Appears in Contact Mailing States |
| Developer Name | Billing_State_In_Contact_Mailing_States |
| Check Type | Check records with a query |
| Value To Test (list checks only) | BillingState |
| Second Query | `SELECT MailingState FROM Contact WHERE AccountId = {!Id} AND MailingState != null` |
| Second Query Field/Alias | MailingState |
| If Query Returns Multiple Rows | Compare both results as lists |
| Operator | List includes any of |
| Applies To | Only records where a count query matches |
| Applies When Count Query Matches | `SELECT COUNT() FROM Contact WHERE AccountId = {!Id} AND MailingState != null` |
| Count Must Be | Greater than |
| Count Value | `0` |
| Severity | Warning |
| Message When Failed | Account Billing State does not match any Contact Mailing State. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change. Edit Value To Test (list checks only) to test a different Account field against the Contact list.

## How it works

When the applicability count query returns greater than zero, the engine resolves Value To Test from the Account, loads Mailing State from Second Query, and passes if List includes any of finds a match.

```sql
-- Second Query
SELECT MailingState FROM Contact
WHERE AccountId = {!Id} AND MailingState != null

-- Applicability (Applies When Count Query Matches)
SELECT COUNT() FROM Contact
WHERE AccountId = {!Id} AND MailingState != null
```

```text
-- Value To Test (list checks only): resolved from the Account
BillingState
```

**What this demonstrates**

- **Value To Test (list checks only)**: parent scalar without a Primary Query (SOQL).
- **List includes any of**: membership test, not full equality.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set Developer Name** to `Account_Examples_Query`. See the [example catalog](../index.md#example-doc-check-sets-numbered-walkthroughs) for every Check Set and what it contains.

## Try it

Set Billing State to a value no Contact shares to fail; match at least one Contact Mailing State to pass. Remove all Contacts with Mailing State to see the check skipped.

[← Examples index](../index.md) · [← Prev: Not equals rating](14-not-equals-rating.md) · [Next: List does not contain →](16-list-does-not-contain.md)
