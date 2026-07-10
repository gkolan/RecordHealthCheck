# First 10 Minutes

Start here if you want to get one card working before opening the deeper configuration docs.

By the end, you will have an Account record page with a health check card that shows at least one result: pass, fail, skipped, or unable to check. No Apex coding is required.

## What you are installing

Record Health Check adds a read-only card to a Salesforce record page. The card looks at the open record and shows whether it meets checks you define.

For this first pass, use `Example_Account_360_Health_Check`, the Check Set shown in the README screenshot. It bundles nine Account checks (owner is active, has a contact, contacts have email, recent activity is logged, open pipeline covers revenue, no high-priority open cases, an active contract, and more), so you see the full range of results. Several of these checks look beyond the Account itself, at its contacts, opportunities, cases, contracts, and activities, and one has a "Fix it" link to the `High_Priority_Open_Cases` report, filtered to this account. What each row reports depends on the account's data, so a well-populated account shows the most.

Want something smaller first? `Account_Data_Quality` is a lighter starter with four single-field checks: Billing City, Industry, Phone, and Website. Swap the Developer Name below if you prefer it.

## 1. Deploy the starter metadata

Choose one install path. Use a sandbox for the first install.

| Deploy button | Salesforce CLI |
| ------------- | -------------- |
| Click [Deploy to Salesforce](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=recordHealthCheck&ref=main), log in to a sandbox, and click **Deploy**. | From the repository root, run the commands below. |
| After deployment, assign the Permission Set named `Record_Health_Check_User` in **Setup → Permission Sets**. | The third command assigns the Permission Set named `Record_Health_Check_User`. |

CLI commands:

```bash
sf project deploy start --manifest manifest/package-core.xml
sf project deploy start --manifest manifest/package-Example_Account_360_Health_Check.xml
sf org assign permset --name Record_Health_Check_User
```

The first command installs the component and metadata types. The second installs the Account 360 Check Set, its rules, and the report one of its checks links to.

The two paths differ in scope: the Deploy button installs the full project, including every sample Check Set, while the CLI commands above install only the framework and the `Example_Account_360_Health_Check` set. Either way, you wire up just one Check Set in the next step.

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
- **Fail:** something needs attention. A failing check carries a severity of Error, Warning, or Info.
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
- See copyable patterns: [Examples catalog](../examples/index.md#core-examples)
- Troubleshoot setup: [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting)
- Understand the admin model: [Admin Quick Start](../installation/admin-quick-start.md)
