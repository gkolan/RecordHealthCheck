# Install and verify

> [!NOTE]
> On this page, take Record Health Check from installation to a proven Lightning record-page result by configuring access, placing the card, and verifying as a representative user.

This tutorial takes Record Health Check from a sandbox install to an observable Rule result on a
Lightning record page. Complete the verification as a representative user before planning a
production release.

**You need:** a Salesforce sandbox, permission to install an unlocked package, and permission to
edit Lightning record pages.

> [!TIP]
> **Subscriber installs** use the promoted unlocked package only. Assign
> `rhc__Record_Health_Check_User`, place the card, and pick a Demo Check Set. You do not need this
> repository's package source, and you must not modify packaged test classes.
>
> **Already installed?** Use [Revalidate an installation](04-upgrading.md).
> **Want a scripted demo org from this repository?** Run `npm run setup` after cloning. See
> [Try the demo](05-create-rhc-scratch-org.md).

## What success looks like

| Milestone | Expected result |
| --- | --- |
| Record Health Check is installed | The Framework classes, Lightning Web Component, Custom Metadata Types, and Permission Sets exist in the sandbox as package `rhc` |
| User access is assigned | A representative user can run the protected Apex surface |
| A Check Set is available | Lightning App Builder can select an active Check Set for the record page object |
| The card is placed | The Record Health Check card appears on the matching Lightning record page |
| A Rule runs | The card shows Pass, Fail (Failed / Warning / Info), Skipped, Unable to Check, or System Error for the record |

## What the install includes

The Framework package includes the engine, permission sets, Lightning component, Custom Metadata
Types, public APIs, and four Demo Check Sets (`Example_…`, card titles prefixed with `Demo:`).

It does **not** create Acme demo Account data. Those deterministic records come only from
[Try the demo](05-create-rhc-scratch-org.md).

The current promoted subscriber package version is recorded in
[`config/package-releases.json`](../../config/package-releases.json).

## 1. Connect to the sandbox

Log in and give the sandbox an alias so every later command names its target explicitly:

```bash
sf org login web --instance-url https://test.salesforce.com --alias rhc-sandbox
sf org display --target-org rhc-sandbox
```

Confirm that `sf org display` identifies the intended sandbox before installing. If you install only
through the browser package installer, you can skip the CLI login until you need it.

## 2. Install the unlocked package

Use a sandbox for the first install. Single-currency and multi-currency orgs use the same install
steps; currency mode only changes how Found / Expected currency values render. See
[Does Record Health Check work in single-currency and multi-currency orgs?](../guides/02-faq.md#does-record-health-check-work-in-single-currency-and-multi-currency-orgs).

Install the promoted **Record Health Check** unlocked package (`rhc`). Stable install links are
published from [`config/package-releases.json`](../../config/package-releases.json).

[![Install in Sandbox](https://img.shields.io/badge/Install_in_Sandbox-032D60?style=for-the-badge&logo=salesforce&logoColor=white)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO)
[![Install in Production](https://img.shields.io/badge/Install_in_Production-0176D3?style=for-the-badge&logo=salesforce&logoColor=white)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO)

| Org type | Login host | Install |
| --- | --- | --- |
| Sandbox | `test.salesforce.com` | [Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO) |
| Production / Developer Edition | `login.salesforce.com` | [Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO) |

Both buttons install the same artifact, the promoted namespaced unlocked package `Record Health
Check` (`rhc`) version **2.0.0.6** (`04tak000000ZXVlAAO`); only the login host differs. Install to a
sandbox first. If you are already logged into the target org in that browser, the button takes you
straight to the install screen; otherwise it prompts for login first. On the install screen choose
**Install for Admins Only** unless you have a reason not to. Access is granted through the permission
sets below, not through the install-time profile choice.

The links above are gated against
[`config/package-releases.json`](../../config/package-releases.json) by
`npm run check:distribution-boundary`, so they cannot drift from the promoted release.

Or with the Salesforce CLI, which is the route to use in a DevOps pipeline:

```bash
sf package install \
  --package 04tak000000ZXVlAAO \
  --target-org rhc-sandbox \
  --upgrade-type DeprecateOnly \
  --wait 30 \
  --publish-wait 10
```

Then assign the runner permission set (CLI or Setup → Permission Sets). On a namespaced package
install, use the `rhc__` prefix:

```bash
sf org assign permset --name rhc__Record_Health_Check_User --target-org rhc-sandbox
```

Users who configure Check Sets or troubleshoot results can also receive
`rhc__Record_Health_Check_Admin`; do not assign that access to users who only need to run checks.

Do not modify packaged Apex or test utilities after install. Subscriber-specific tests belong in
your own repository. See
[Package testing and upgrades](../reference/framework/07-package-testing-and-upgrades.md).

After install, discover Demo Check Set identities with:

```sql
SELECT DeveloperName, QualifiedApiName, rhc__CardTitle__c
FROM rhc__Record_Health_Check_Set__mdt
WHERE DeveloperName LIKE 'Example_%'
ORDER BY QualifiedApiName
```

Use the `QualifiedApiName` value exactly when Apex, Flow, or docs ask for a Check Set identity. See
[Configuration identity](../reference/framework/06-configuration-identity.md) if you call the Framework
from code.

### Referring to packaged components from your own code

Everything the package installs lives in the `rhc` namespace, so your own Apex, SOQL, Flows, and
metadata must qualify it. Your org keeps no namespace of its own, and records you create against
packaged Custom Metadata Types stay unnamespaced even though the type is prefixed.

| What you are referencing | Write it as |
| --- | --- |
| Custom Metadata Type | `rhc__Record_Health_Check_Set__mdt`, `rhc__Record_Health_Check_Rule__mdt` |
| A packaged field on those types | `rhc__CardTitle__c`, `rhc__IsActive__c` |
| Standard fields on those types | `DeveloperName`, `QualifiedApiName` (no prefix) |
| Apex classes and public API types | `rhc.RecordHealthCheck`, `rhc.RecordHealthCheckRequest`, `rhc.RecordHealthCheckResponse` |
| Permission sets | `rhc__Record_Health_Check_User`, `rhc__Record_Health_Check_Admin` |
| Your own Check Set record file | `rhc__Record_Health_Check_Set__mdt.My_Check_Set.md-meta.xml`, with `rhc__`-prefixed `<field>` names |

Omitting a prefix fails at compile or query time. `FROM Record_Health_Check_Rule__mdt` raises
`sObject type 'Record_Health_Check_Rule__mdt' is not supported`, and unqualified Apex types will not
resolve. `subscriber-app/` in this repository is a working example of subscriber-owned code and
metadata written against the installed package.

## 3. Choose or add a Check Set

The install includes four Demo Check Sets you can select immediately (Account Profile Readiness,
Account Relationship & Risk, Contact Relationship Readiness, and Opportunity Deal Readiness).
Review every Demo Rule before adapting it for production policy.

![Demo Account Relationship and Risk health check card on an Account record page](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)

To author your own configuration, create a Check Set under **Setup → Custom Metadata Types** by
following [Create your first Rule](03-create-your-first-rule.md).

## 4. Add the card to a record page

1. Go to **Setup → Lightning App Builder**.
2. Edit a record page matching the Check Set's object.
3. Drag **Record Health Check** onto the page.
4. Select the installed or newly created Check Set.
5. Save and activate the page.

## 5. Verify the result

Open a matching record. If the card is configured for manual execution, click **Run**. The card
shows Pass, Fail (Failed, Warning, or Info by severity), Skipped, Unable to Check, or System Error
for each Rule. Edit relevant record data and rerun to
confirm the result changes. Repeat the verification as a representative user, not only as the
user who installed Record Health Check.

| Verification | Expected result |
| --- | --- |
| Open the record as a user with `rhc__Record_Health_Check_User` | The Record Health Check card is visible and can run the selected Check Set |
| Run a manually configured Check Set | Each Rule shows Pass, Fail, Skipped, Unable to Check, or System Error |
| Change data used by a Rule, save, and select **Rerun** | The result reflects the saved record data |
| Open the page as a user without Framework access | The user cannot call the protected Apex surface |

## If installation or verification fails

| Symptom | What to check |
| --- | --- |
| The installation reports an Apex or metadata permission error | Confirm that the authenticated user can install unlocked packages. |
| The card has no Check Set to select | Select an active Demo Check Set whose Object matches the Lightning record page object, or create and activate your own Check Set. |
| A user cannot see or run the card | Assign `rhc__Record_Health_Check_User`, then review record, object, and field access. |
| The Lightning component is under **Custom**, not a package | The org was not installed from the promoted package. Reinstall with the stable `04t` in a clean org. |
| Install fails with `Apex action method 'RecordHealthCheckController…' with public access modifier must be in the same package with caller 'markup://rhc:recordHealthCheck'` | The org already contains unpackaged Framework source, so the packaged component resolves against those local classes instead of the package. Install into an org that has never had this repository's `force-app` deployed to it. |
| A Rule shows Unable to Check | Review its Reason Code, Rule configuration, and the running user's Salesforce access. |
| A Rule shows System Error | Review the Reason Code, Apex plugin if any, Salesforce logs, and Show Diagnostics. |

If the card does not appear or a Rule will not evaluate, see
[Configuration Guide: Troubleshooting](../guides/03-configure-check-sets-and-rules.md#13-troubleshooting)
or the [FAQ](../guides/02-faq.md).

## Next steps

- [Try the demo](05-create-rhc-scratch-org.md): subscriber demo org via `npm run setup`
- [Examples library](../examples/README.md): adapt another Rule pattern
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md): configure every field
- [How It Works](01-how-it-works.md): learn the result terms and codes
- [Uninstall and rollback](06-uninstall-and-rollback.md): remove the card, subscribers, and package when needed
- [Security and data access](../reference/framework/02-security.md): review the trust model before production
