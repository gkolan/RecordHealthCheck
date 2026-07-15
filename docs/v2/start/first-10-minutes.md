# First 10 Minutes

Start here to install Core and put one working Check Set on a record page.

## 1. Deploy Core

Use a sandbox for the first install. From the Core repository root, run:

```bash
sf project deploy start --manifest manifest/package.xml
sf org assign permset --name Record_Health_Check_User
```

Core installs the engine, Lightning component, metadata types, and permission sets. It deliberately
installs no example Check Sets or Rules.

## 2. Add a Check Set

Choose either path:

- Install a ready-made pack from
  [RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples) by following
  its [install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md).
- Create a Check Set and Rule under **Setup → Custom Metadata Types** by following
  [Getting Started](../installation/getting-started.md#step-4-create-your-first-rule).

The `account-data-quality` pack is the smallest Account example.

## 3. Add the card to a record page

1. Go to **Setup → Lightning App Builder**.
2. Edit a record page matching the Check Set's object.
3. Drag **Record Health Check** onto the page.
4. Select the installed or newly created Check Set.
5. Save and activate the page.

## 4. Verify the result

Open a matching record. If the card is configured for manual execution, click **Run**. The card
shows Pass, Fail, Skipped, or Unable to Check for each Rule. Edit relevant record data and rerun to
confirm the result changes.

## Next steps

- [Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/catalog/by-outcome.md)
- [Configuration guide](../guides/configuration-guide.md)
- [Admin quick start](../installation/admin-quick-start.md)
