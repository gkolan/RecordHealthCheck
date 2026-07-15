# Install Record Health Check in a sandbox

Install V2 Core in a Salesforce sandbox before considering a production deployment. V2 keeps all
examples in the separate
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples) repository.

## Before you start

You need a Salesforce sandbox, the Salesforce CLI (`sf`), permission to deploy Apex and Custom
Metadata, permission to edit Lightning record pages, and a local clone of Core. If you are upgrading
from V1, follow [Upgrading to V2](upgrading-to-v2.md) first.

## 1. Log in to the sandbox

```bash
sf org login web --instance-url https://test.salesforce.com --alias rhc-sandbox
sf org display --target-org rhc-sandbox
```

Confirm that the displayed org is the intended sandbox.

## 2. Deploy Core

From the `RecordHealthCheck` repository root:

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org rhc-sandbox \
  --wait 30

```

The first deployment installs the framework, Lightning Web Component, Custom Metadata Types, and
permission sets. Core does not install Check Set or Rule records.

## 3. Assign permission

```bash
sf org assign permset \
  --name Record_Health_Check_User \
  --target-org rhc-sandbox
```

Authors and troubleshooting administrators can also receive `Record_Health_Check_Admin`.

## 4. Add the card to an Account page

1. Open an Account in the sandbox.
2. Select **Setup → Edit Page**.
3. Add **Record Health Check** to the Lightning record page.
4. Select a Check Set you created or installed from the Examples repository.
5. Save and activate the page.

Open an Account and confirm the card shows Pass, Fail, Skipped, or Unable to Check results. The
results depend on that Account's data.

## 5. Add optional examples

Do not look for other examples in Core. Browse the
[Examples pack index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md)
and install only the pack you need by following the
[Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md).

## If deployment fails

| Problem | What to check |
| --- | --- |
| Apex deployment permission error | Ask a Salesforce administrator with deployment access to run the installation. |
| Example metadata cannot find a type or field | Confirm Core finished successfully before deploying the example pack. |
| Card has no Check Set choice | Create a Check Set or install an example pack for the record page's object. |
| User cannot see or run the card | Assign `Record_Health_Check_User` and check record, object, and field access. |
| A Rule shows Unable to Check | Review the reason code, Rule configuration, and the running user's field access. |

For deeper review, use [Show Diagnostics](../guides/show-diagnostics.md) and the
[reason-code reference](../reference/reason-codes.md).

## Next steps

- [Admin quick start](admin-quick-start.md) — learn the result model
- [Getting started](getting-started.md) — create and test a Rule
- [Configuration guide](../guides/configuration-guide.md) — configure advanced behavior
- [Upgrading to V2](upgrading-to-v2.md) — migrate an existing installation
