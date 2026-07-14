# First 10 Minutes

Start here if you want to get one card working before opening the deeper configuration docs.

By the end, you will have an Account record page with a health check card that shows at least one result: pass, fail, skipped, or unable to check. No Apex coding is required.

## What you are installing

Record Health Check adds a read-only card to a Salesforce record page. The card looks at the open record and shows whether it meets checks you define.

For this first pass, use `Example_Account_360_Health_Check`, the Check Set shown in the README screenshot. It bundles nine Account checks (owner is active, has a contact, contacts have email, recent activity is logged, open pipeline covers revenue, no high-priority open cases, an active contract, and more), so you see the full range of results. Several of these checks look beyond the Account itself, at its contacts, opportunities, cases, contracts, and activities, and one has a "Fix it" link to the `High_Priority_Open_Cases` report, filtered to this account. What each row reports depends on the account's data, so a well-populated account shows the most.

Want something smaller first? After core is installed, deploy the optional `account-data-quality` pack from [RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples) and select Check Set `Account_Data_Quality`. Install paths (Setup, Git/CLI, Local DX): [Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md).

## 1. Deploy the starter metadata

Use a sandbox for the first install. From the Core repository root, run:

```bash
sf project deploy start --manifest manifest/package-core.xml
sf project deploy start --manifest manifest/package-Example_Account_360_Health_Check.xml
sf org assign permset --name Record_Health_Check_User
```

The first command installs the component and metadata types. The second installs the Account 360 Check Set, its rules, and the report one of its checks links to.

Optional packs come from
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples).

## 2. Add the card to an Account page

1. Go to **Setup -> Lightning App Builder**.
2. Edit an **Account** record page.
3. Drag the **recordHealthCheck** component onto the page.
4. In the component properties, choose **Check Set**:

   ```text
   Example_Account_360_Health_Check
   ```

5. Save and activate the page.

If the card shows no checks, confirm the selected Check Set is active and targets the page's object.

## 3. Open an Account

Open any Account record that uses the page you edited.

If the card runs automatically, results appear after the page loads. If it waits for input, click **Run**.

The card shows rows for the starter checks:

- **Pass:** this record meets the Rule.
- **Fail:** something needs attention. A failing check carries a severity of Critical, Warning, or Info (`CRITICAL` / `WARNING` / `INFO`).
- **Skipped:** the Rule does not apply to this record right now.
- **Unable to Check:** the framework could not finish the check. Review setup, permissions, or troubleshooting details.

## 4. Make a result change

To prove the card is reading live data, edit the Account and refresh the page.

Try one of these:

- Clear both **Phone** and **Website**: the "Account has a phone or website" check stops passing.
- Add a **Phone** or **Website** back: that check passes again.
- Add a **Contact** to an Account that had none: the "Account has a contact" check turns to a pass.

This is the first success moment: the card responds to record data without a validation rule, Flow, or Apex trigger.

## 5. Know the two building blocks

You only need two words to keep going:

- **Check Set:** the group of checks shown by one card. `Example_Account_360_Health_Check` is your first Check Set.
- **Rule:** one row inside the card. Example: "Account has a phone or website."

Everything else in the docs builds on those two ideas.

## Next

- Create one Rule: [Getting Started](../installation/getting-started.md#step-4-create-your-first-rule)
- Install optional packs: [Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md) (Setup · Git/CLI · Local DX)
- Browse packs by outcome: [Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/catalog/by-outcome.md)
- Troubleshoot setup: [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting)
- Understand the card model: [Admin Quick Start](../installation/admin-quick-start.md)
