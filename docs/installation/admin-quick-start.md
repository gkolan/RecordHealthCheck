# Admin Quick Start

Use this after [First 10 Minutes](../start/first-10-minutes.md), once the card is visible.

## The plain-English model

Record Health Check is a read-only checklist on a record page. It looks at the record, runs the checks you configured, and shows what looks healthy or needs attention.

It does not stop users from saving. Use validation rules when a user must be blocked from saving bad data.

## The words you need

- **Check Set:** the whole card. It decides which object the card is for, when it runs, and which Rules belong together.
- **Rule:** one row on the card. A Rule asks one question, such as "Has there been recent activity?"
- **Pass:** the record meets the Rule.
- **Fail:** the Rule found something that needs attention.
- **Skipped:** the Rule did not apply to this record right now, or it was waiting for another Rule to pass first.
- **Error:** the Rule did not run because of setup, permissions, SOQL, formula, or code trouble.
- **Applicability:** a condition that decides whether a Rule runs. Example: only check Partner requirements on Partner Accounts.
- **Formula-based check:** a check that looks at fields on the current record, or parent fields Salesforce formula syntax can reach.
- **Query-based check:** a check that looks for related records with SOQL, such as Contacts, Opportunities, Cases, Tasks, or Events.
- **Regular user:** a user who sees clean pass/fail/skipped results. Assign the Permission Set named `Record_Health_Check_User`.
- **Troubleshooting user:** a user who can see extra technical detail when the Check Set enables troubleshooting details. Assign the Permission Set named `Record_Health_Check_Admin` for troubleshooting sessions.

## Example: Account has recent activity

Business question:

```text
Has anyone completed a Task or logged an Event on this Account in the last 90 days?
```

Why this is a health check:

- It is useful when someone opens the Account.
- It coaches users at read time instead of blocking saves.
- It reads Tasks and Events, not only Account fields.

How it appears to users:

- **Pass:** the Account has recent activity.
- **Fail:** the Account has no completed Task or logged Event inside the configured look-back window.
- **Skipped:** the Rule did not apply because of its setup conditions.
- **Error:** the activity check did not run; review setup or troubleshooting details.

The shipped Apex example is `AccountHasRecentActivityCheck`. If you want a simpler no-code freshness check, use the `Account_Everyday_Use_Cases` sample Rule that checks the Account's `LastActivityDate` field.

## First troubleshooting checks

- **Component shows no checks:** confirm the component's **Check Set Developer Name** exactly matches the Check Set Developer Name, such as `Account_Data_Quality`.
- **Check Set is not found:** confirm the Check Set metadata was deployed and is active.
- **Rule is skipped:** review **Applies To**, dependencies, and whether the record meets the applicability condition.
- **SOQL query returns no rows:** confirm related records exist and the query uses the current record token `{!Id}` when it filters records for the open record.
- **SOQL query returns more than one row:** use an aggregate such as `COUNT()` or choose a multi-row setting such as "At least one record must pass."
- **Formula errors:** confirm the formula returns true/false for pass/fail and uses valid field API names.
- **User does not see troubleshooting details:** confirm the Check Set enables troubleshooting details and the user has the Permission Set named `Record_Health_Check_Admin`.

For deeper fixes, use [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting).

Next: [Getting Started](getting-started.md), then create your first Rule.
