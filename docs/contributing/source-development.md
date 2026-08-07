# Source development (contributors only)

> [!IMPORTANT]
> Contributor setup deploys the unpackaged Framework source into a development org. Do **not** use
> this workflow to install or upgrade Record Health Check in a subscriber sandbox or production org.

Subscribers install the promoted unlocked package (`04t`). Contributors who change Framework code
work inside the nested packaging project:

```text
packages/record-health-check/
```

## Prerequisites

- Salesforce CLI (`sf`)
- A Dev Hub org (`DEV_HUB_ALIAS`)
- Node.js 22+ and `npm ci`

## Quick start

```bash
git clone https://github.com/gkolan/record-health-check.git
cd record-health-check
npm ci

sf org login web --set-default-dev-hub --alias my-dev-hub

npm run dev:setup -- --dev-hub my-dev-hub --alias rhc-dev
```

This command:

1. Creates a package-development scratch org
2. Deploys `packages/record-health-check/force-app`
3. Deploys maintainer integration fixtures from `packages/record-health-check/integration-tests`
4. Runs package `RunLocalTests` during the Framework deploy

It does **not** install the public `04t` subscriber package.

## Run package tests again

```bash
npm run dev:test -- --alias rhc-dev
```

## Manual package-project commands

When you need finer control, work from the nested project:

```bash
cd packages/record-health-check

sf project deploy start \
  --manifest manifest/package.xml \
  --target-org rhc-dev \
  --test-level RunLocalTests \
  --wait 30
```

Keep `integration-tests/` out of subscriber installs. That directory is CI-only fixture metadata.
See [`packages/record-health-check/integration-tests/README.md`](../../packages/record-health-check/integration-tests/README.md).

## Related

- [Contributing](../../.github/CONTRIBUTING.md)
- [Releasing](../../.github/RELEASING.md)
- [Package testing and upgrades](../reference/framework/07-package-testing-and-upgrades.md)
