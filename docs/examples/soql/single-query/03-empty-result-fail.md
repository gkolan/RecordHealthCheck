# 03 · Empty result is a failure

> Passes when the Account has at least one Closed Won Opportunity; fails when the query returns zero rows.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Has_Closed_Won_Opportunity`](../../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Has_Closed_Won_Opportunity.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

The Account must have at least one Closed Won Opportunity. When the query returns no rows, the check fails: zero matches is itself the problem, not a reason to skip.

## When to use this

Reach for this pattern when an empty child set should surface as a failure: no conversions, no active contracts, no qualifying related rows. Pair If Query Finds No Records = Fail the check with At least one record must pass and an Is not empty operator on a selected field.

## Why this evaluator

The rule depends on whether any related row exists and passes a field test.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot see Closed Won Opportunities. |
| Check records with a query | Any row passes + zero rows fail | **This example.** Empty set is explicit failure. |
| Compare two queries | | No second scalar or list to compare. |
| Custom Apex | Apex existence check | Same outcome when zero-row behavior is configured. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Zero rows should skip, not fail | [Empty result skip](04-empty-result-skip.md) |
| Only need a count ≥ 1 | [Child count minimum one](01-child-count-minimum-one.md) |

**Verdict:** Check records with a query with Fail the check on zero rows is the right evaluator when no matching child rows is a hard failure. Use Skip the check when an empty set means "nothing to audit."

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | Has At Least One Closed Won Opportunity |
| Developer Name | Has_Closed_Won_Opportunity |
| Check Type | Check records with a query |
| Data Query | `SELECT Amount FROM Opportunity WHERE AccountId = {!Id} AND StageName = 'Closed Won'` |
| Field To Read | Amount |
| How To Interpret Query Results | At least one record must pass |
| Operator | Is not empty |
| If Query Finds No Records | Fail the check |
| Run This Check When | Always |
| Severity | Warning |
| Message When Check Fails | This account has no Closed Won opportunities. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change.

## How it works

The engine runs Data Query. With zero rows, If Query Finds No Records forces fail. With one or more rows, At least one record must pass applies Is not empty to Field To Read.

```sql
SELECT Amount FROM Opportunity
WHERE AccountId = {!Id} AND StageName = 'Closed Won'
```

**What this demonstrates**

- **Fail the check on zero rows**: empty child set fails outright.
- **Is not empty on Any row passes**: any returned row with a non-blank Amount satisfies the check.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set Developer Name** to `Account_Examples_Query`. See the [example catalog](../../index.md#sample-check-set-packages) for every Check Set and what it contains.

## Try it

Remove all Closed Won Opportunities to fail; add one Closed Won Opportunity to pass.

[← Examples index](../../index.md) · [← Prev: Child count minimum two](02-child-count-minimum-two.md) · [Next: Empty result skip →](04-empty-result-skip.md)
