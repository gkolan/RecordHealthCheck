# 13 · Count capped at an upper limit

> Passes when open Case count is below the configured cap; fails when open Cases reach or exceed the cap.

| | |
| --- | --- |
| **Evaluator** | Check records with a query |
| **Sample** | [`Fewer_Than_Ten_Open_Cases`](../../../../force-app/main/default/customMetadata/Record_Health_Check_Rule__mdt.Fewer_Than_Ten_Open_Cases.md-meta.xml) |
| **Check Set** | `Account_Examples_Query` · [`package-Account_Examples_Query.xml`](../../../../manifest/package-Account_Examples_Query.xml) |

## What it checks

The Account must have fewer open Cases than the configured upper bound. A `COUNT()` on open Cases is compared with a less-than operator against a fixed value.

## When to use this

Reach for this pattern to flag volume overload: too many open cases, tasks, or any child object where an upper bound signals risk. Less than enforces a cap; pair with greater-than examples for minimums.

## Why this evaluator

Upper-bound child count via aggregate query.

| Alternative | How it compares | Fit for this check |
| ----------- | --------------- | ------------------ |
| Check fields on this record | | Cannot count open Cases. |
| Check records with a query | `COUNT()` less than fixed value | **This example.** |
| Compare two queries | Contact count vs Case count | Compares two counts to each other, not to a fixed cap. |
| Use custom Apex | Apex count cap | Same outcome when metadata suffices. |

**When the simpler option is enough**

| Need | Use instead |
| ---- | ----------- |
| Minimum child count | [Child count minimum one](01-child-count-minimum-one.md) |
| Compare two counts | [Count vs second query](17-count-vs-second-query.md) |

**Verdict:** Check records with a query with Less than and a static Expected Value is the right evaluator for an upper bound on child row count. Use Compare two queries when the cap is another query's count, not a literal.

## Configuration

| Setup label | Value |
| ----------- | ----- |
| Check Name | Fewer Than Ten Open Cases |
| Developer Name | Fewer_Than_Ten_Open_Cases |
| Check Type | Check records with a query |
| Primary Query (SOQL) | `SELECT COUNT() FROM Case WHERE AccountId = {!Id} AND IsClosed = false` |
| How To Interpret Query Results | Expect one row or aggregate result |
| Operator | Less than |
| Expected Value Comes From | A fixed value |
| Expected Value | 10 |
| Applies To | All records |
| Severity | Warning |
| Message When Check Fails | This account has 10 or more open cases. |

> [!NOTE]
> This table is the control panel for the check: the single source of truth for every value, so edits here take effect with no code change. Edit Expected Value to change the open Case cap.

## How it works

The engine runs Primary Query (SOQL) and passes when the open Case count is less than the fixed value.

```sql
SELECT COUNT() FROM Case
WHERE AccountId = {!Id} AND IsClosed = false
```

**What this demonstrates**

- **Less than on `COUNT()`**: upper-bound enforcement.
- **Open Cases only**: `IsClosed = false` scopes the volume signal.

## Get this example

This rule ships in the **`Account_Examples_Query`** Check Set. Deploy the engine once, then the Check Set, then wire the component to it:

```bash
sf project deploy start --manifest manifest/package-core.xml              # engine + types: once per org
sf project deploy start --manifest manifest/package-Account_Examples_Query.xml  # this example's Check Set
```

Set the component's **Check Set Developer Name** to `Account_Examples_Query`. See the [example catalog](../../index.md#sample-check-set-packages) for every Check Set and what it contains.

## Try it

Add open Cases until the count reaches the cap to fail; reduce open Cases below the cap to pass.

[← Examples index](../../index.md) · [← Prev: Is blank](12-is-blank.md) · [Next: Not equals rating →](14-not-equals-rating.md)
