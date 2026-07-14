# Install the Core

Get a working card on a record page in about ten minutes. You need a Salesforce org where you can
deploy metadata (a sandbox or scratch org) and permission to edit Lightning record pages.

## 1. Deploy Core

Use the Salesforce CLI with the two Core manifests:

```bash
git clone https://github.com/gkolan/RecordHealthCheck.git
cd RecordHealthCheck
sf project deploy start --manifest manifest/package-core.xml --target-org <your-org-alias>
sf project deploy start --manifest manifest/package-Example_Account_360_Health_Check.xml --target-org <your-org-alias>
```

This installs the engine, the `recordHealthCheck` component, the Check Set and Rule metadata types,
permission sets, and the hero example Check Set **`Example_Account_360_Health_Check`**.

Optional scenario packs (data quality, relationships, industry readiness, and more) are **not** in
Core. Install them from
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples) —
see [[Explore the Examples]].

## 2. Assign the permission set

Assign **`Record_Health_Check_User`** to yourself (and anyone who should see the card).
Administrators who will author checks also get **`Record_Health_Check_Admin`**.

```bash
sf org assign permset --name Record_Health_Check_User --target-org <your-org-alias>
```

## 3. Add the card to a record page

1. Open any **Account** record → gear → **Edit Page**.
2. Drag the **Record Health Check** component onto the page.
3. In the component's settings, select the Check Set **`Example_Account_360_Health_Check`**
   (App Builder lists the Check Set **Developer Name**).
4. **Save** and **Activate**.

## 4. See it work

Open an Account. The card evaluates the record and lists each check. Passed checks collapse to one
line; a failed check explains what's wrong and can show a **Fix it** link. Any row can reveal its
**Found / Expected** detail. The footer tallies the outcomes, and **Rerun** re-evaluates on demand.

That's the whole loop: **open a record → checks run → results display → nothing else happens.**

## What the results mean

| Outcome             | Meaning                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| **Pass**            | The record satisfies the check.                                                                |
| **Fail**            | The record does not — flagged **Critical**, **Warning**, or **Info** by the Rule's severity.   |
| **Skipped**         | The check didn't apply to this record (it says why).                                           |
| **Unable to Check** | The check couldn't run — usually a configuration or access issue, shown in the Rule's message. |

## Next

- Build your own checks → **[[Author Checks]]**
- Install a ready-made scenario pack → **[[Explore the Examples]]**
- Deeper install notes (sandbox, upgrading from v1.x): see
  [Getting Started](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/installation/getting-started.md)
  and [Upgrading to V2](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/installation/upgrading-to-v2.md).
