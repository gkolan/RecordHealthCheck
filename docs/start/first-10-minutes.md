# First 10 Minutes

Start here if you want to get one card working before opening the deeper configuration docs.

By the end, you will have an Account record page with a health check card that shows at least one result: pass, fail, skipped, or error. No Apex coding is required.

## What you are installing

Record Health Check adds a read-only card to a Salesforce record page. The card looks at the open record and shows whether it meets checks you define.

For this first pass, use the starter Check Set named `Account_Data_Quality`. It contains four Account checks: Billing City, Industry, Phone, and Website.

## 1. Deploy the starter metadata

Choose one install path. Use a sandbox for the first install.

| Deploy button | Salesforce CLI |
| ------------- | -------------- |
| Click [Deploy to Salesforce](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=recordHealthCheck&ref=main), log in to a sandbox, and click **Deploy**. | From the repository root, run the commands below. |
| After deployment, assign the Permission Set named `Record_Health_Check_User` in **Setup → Permission Sets**. | The third command assigns the Permission Set named `Record_Health_Check_User`. |

CLI commands:

```bash
sf project deploy start --manifest manifest/package-core.xml
sf project deploy start --manifest manifest/package-Account_Data_Quality.xml
sf org assign permset --name Record_Health_Check_User
```

The first command installs the component and metadata types. The second command installs the starter Account checks.

## 2. Add the card to an Account page

1. Go to **Setup -> Lightning App Builder**.
2. Edit an **Account** record page.
3. Drag the **recordHealthCheck** component onto the page.
4. In the component properties, set **Check Set Developer Name** to:

   ```text
   Account_Data_Quality
   ```

5. Save and activate the page.

The name must match exactly. If the card shows no checks, this is the first thing to re-check.

## 3. Open an Account

Open any Account record that uses the page you edited.

If the card runs automatically, results appear after the page loads. If it waits for input, click **Run**.

The card shows rows for the starter checks:

- **Pass:** this record meets the Rule.
- **Fail:** something needs attention.
- **Skipped:** the Rule does not apply to this record right now.
- **Error:** the framework did not finish the check. Review setup, permissions, or troubleshooting details.

## 4. Make a result change

To prove the card is reading live data, edit the Account and refresh the page.

Try one of these:

- Clear **Billing City**: the Billing City check fails.
- Add **Billing City**: the Billing City check passes.
- Clear **Phone**: the Phone check fails.
- Clear **Website**: the Website check fails.

This is the first success moment: the card responds to record data without a validation rule, Flow, or Apex trigger.

## 5. Know the two building blocks

You only need two words to keep going:

- **Check Set:** the group of checks shown by one card. `Account_Data_Quality` is your first Check Set.
- **Rule:** one row inside the card. Example: "Billing City is required."

Everything else in the docs builds on those two ideas.

## Next

- Create one Rule: [Getting Started](../installation/getting-started.md#step-4-create-your-first-rule)
- See copyable patterns: [Examples catalog](../examples/index.md#core-examples)
- Troubleshoot setup: [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting)
- Understand the admin model: [Admin Quick Start](../installation/admin-quick-start.md)
