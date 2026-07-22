# Install and verify

> [!NOTE]
> **On this page**
>
> Deploy Core, assign user access, add a Check Set, place the Lightning card, and confirm that a Rule can run.

This tutorial takes Core from sandbox deployment to an observable Rule result on a Lightning record
page. Complete the verification as a representative user before planning a production release.

**You need:** a Salesforce sandbox, the Salesforce CLI (`sf`), and permission to deploy metadata
and edit Lightning record pages.

## What success looks like

| Milestone | Expected result |
| --- | --- |
| Core is deployed | The Framework classes, Lightning Web Component, Custom Metadata Types, and Permission Sets exist in the sandbox |
| User access is assigned | A representative user can run the protected Apex surface |
| A Check Set is available | Lightning App Builder can select an active Check Set for the record page object |
| The card is placed | The Record Health Check card appears on the matching Lightning record page |
| A Rule runs | The card shows Pass, Needs attention, Skipped, or Unable to check for the record |

## 1. Connect to the sandbox

Log in and give the sandbox an alias so every later command names its target explicitly:

```bash
sf org login web --instance-url https://test.salesforce.com --alias rhc-sandbox
sf org display --target-org rhc-sandbox
```

Confirm that `sf org display` identifies the intended sandbox before deploying.

## 2. Deploy Core

Use a sandbox for the first install. From the Core repository root, run:

```bash
sf project deploy start --manifest manifest/package.xml --target-org rhc-sandbox --wait 30
sf org assign permset --name Record_Health_Check_User --target-org rhc-sandbox
```

Core installs the engine, Lightning component, metadata types, and Permission Sets. It deliberately
installs no example Check Sets or Rules. Authors and troubleshooting administrators can also receive
`Record_Health_Check_Admin`; do not assign administrative access to users who only need to run checks.

## 3. Add a Check Set

Create a Check Set and Rule under **Setup → Custom Metadata Types** by following
[Create your first Rule](03-create-your-first-rule.md).

## 4. Add the card to a record page

1. Go to **Setup → Lightning App Builder**.
2. Edit a record page matching the Check Set's object.
3. Drag **Record Health Check** onto the page.
4. Select the installed or newly created Check Set.
5. Save and activate the page.

## 5. Verify the result

Open a matching record. If the card is configured for manual execution, click **Run**. The card
shows Pass, Fail, Skipped, or Unable to Check for each Rule. Edit relevant record data and rerun to
confirm the result changes. Repeat the verification as a representative user, not only as the
administrator who deployed Core.

| Verification | Expected result |
| --- | --- |
| Open the record as a user with `Record_Health_Check_User` | The Record Health Check card is visible and can run the selected Check Set |
| Run a manually configured Check Set | Each Rule shows Pass, Fail, Skipped, or Unable to Check |
| Change data used by a Rule, save, and select **Rerun** | The result reflects the saved record data |
| Open the page as a user without Framework access | The user cannot call the protected Apex surface |

## If installation or verification fails

| Symptom | What to check |
| --- | --- |
| The deployment reports an Apex or metadata permission error | Confirm that the authenticated user can deploy Apex and Custom Metadata. |
| The card has no Check Set to select | Create an active Check Set whose Object matches the Lightning record page object. |
| A user cannot see or run the card | Assign `Record_Health_Check_User`, then review record, object, and field access. |
| A Rule shows Unable to Check | Review its Reason Code, Rule configuration, and the running user's Salesforce access. |

If the card does not appear or a Rule will not evaluate, see
[Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting).

## Next steps

- [Examples library](../examples/README.md) — adapt another Rule pattern
- [Configuration guide](../guides/configuration-guide.md) — configure every field
- [How It Works](01-how-it-works.md) — learn the result vocabulary
