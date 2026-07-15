# Salesforce CLI Commands

Commands for deploying, testing, and maintaining this repository with the Salesforce CLI (`sf` v2). Run from the repository root unless noted otherwise.

You need the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) v2 and access to a target org.

## Contents

| Section | What it covers |
| ------- | -------------- |
| Prerequisites | CLI and Node tooling |
| Update CLI and tooling | `sf update`, plugins, Node |
| Deploy | Core from this repository; optional packs from the Examples repository |
| Test and lint | Jest, ESLint, Prettier |
| Regenerate docs | Design-spec split and manifests |

For copy-paste patterns see [Examples](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md). For the formal contract see [Design Specification](../reference/record-health-check-design-spec.md).

## Prerequisites

```bash
# Verify CLI is installed
sf version

# Install Node dependencies (LWC unit tests, Prettier, ESLint)
npm ci
```

## Update CLI and tooling

### Salesforce CLI (`sf`)

This project uses **Salesforce CLI v2** (`sf`). The legacy `sfdx` command still works in many installs but is an alias: prefer `sf` for new work.

```bash
# Show current version (note the "update available" hint if you're behind)
sf version

# Update to the latest stable release
sf update stable

# See all available versions
sf update --available

# Pick a version interactively
sf update --interactive

# Install a specific version
sf update --version 2.139.6
```

**How you installed affects the update path:**

| Install method | Update command |
| -------------- | -------------- |
| npm global | `npm install -g @salesforce/cli@latest` |
| Homebrew (macOS) | `brew upgrade sf` |
| Official installer | `sf update stable` |

After updating, confirm:

```bash
sf version
```

### CLI plugins

This repo uses the **code-analyzer** plugin in CI (`.github/workflows/salesforce-validate.yml`).

```bash
# List installed plugins
sf plugins

# Install a plugin (CI uses this for code-analyzer)
sf plugins install code-analyzer

# Update all user-installed plugins
sf plugins update

# Update or reinstall a single plugin
sf plugins install code-analyzer --force

# Remove a plugin
sf plugins uninstall code-analyzer
```

### Project npm dependencies

Local Jest, Prettier, and ESLint come from `package.json`, not the global CLI.

```bash
# Reinstall exact versions from package-lock.json (preferred for CI/contributors)
npm ci

# Check for newer versions (does not change files)
npm outdated

# Update within semver ranges allowed by package.json
npm update

# Update npm itself (optional)
npm install -g npm@latest
```

After changing Node dependencies, re-run the contributor checks:

```bash
npm run prettier:verify
npm run lint
npm test
```

### Legacy `sfdx` note

If you still have the old standalone **sfdx** CLI (pre-unification), migrate to `@salesforce/cli`:

```bash
npm uninstall -g sfdx-cli
npm install -g @salesforce/cli@latest
sf version
```

Org auth files under `.sf/` and `.sfdx/` remain valid: you do not need to re-authenticate after a CLI upgrade unless tokens expire.

## Authenticate an org

```bash
# Browser login (sandbox example: use login.salesforce.com for production)
sf org login web --alias mySandbox --instance-url https://test.salesforce.com

# Set default target org for subsequent commands
sf config set target-org mySandbox

# Or pass --target-org on each command instead of setting a default
```

**Dev Hub + scratch org (CI pattern):**

```bash
# Authenticate Dev Hub (auth URL from SFDX_AUTH_URL secret or local auth file)
echo "$SFDX_AUTH_URL" | sf org login sfdx-url --sfdx-url-stdin --alias devhub --set-default-dev-hub

# Create a scratch org from config/project-scratch-def.json
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias rhc-scratch \
  --set-default \
  --duration-days 7 \
  --wait 15

# Open the scratch org in a browser
sf org open --target-org rhc-scratch
```

## Deploy

### Core (recommended)

Deploy the production-safe Core manifest:

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org mySandbox \
  --wait 30

```

### Add an optional example pack

Deploy Core, then add scenario packs from
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples) — not from Core manifests.

```bash
# From the RecordHealthCheck (Core) repo
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org mySandbox \
  --wait 30

# From the RecordHealthCheck-Examples repo (optional pack)
sf project deploy start \
  --manifest packs/account-data-quality/manifest/package.xml \
  --target-org mySandbox \
  --wait 30
```

See the [Examples pack index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md)
and [Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md).

### Source directory

For repeatable release deployment, use `manifest/package.xml`. It is the explicit allowlist for
Core and excludes integration fixtures.
### Deploy with tests (release gate)

Same command used in `.github/workflows/salesforce-validate.yml`:

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org rhc-scratch \
  --test-level RunLocalTests \
  --wait 30
```

### Validate only (no changes applied)

```bash
sf project deploy validate \
  --manifest manifest/package.xml \
  --target-org mySandbox \
  --test-level RunLocalTests \
  --wait 30
```

### Deploy a single metadata type or file

```bash
# One Apex class
sf project deploy start \
  --source-dir force-app/main/default/classes/RecordHealthCheckTestDataFactory.cls \
  --target-org mySandbox

# Custom metadata records only
sf project deploy start \
  --source-dir force-app/main/default/customMetadata \
  --target-org mySandbox
```

## Run Apex tests

```bash
# All local tests with coverage report
sf apex run test \
  --target-org mySandbox \
  --test-level RunLocalTests \
  --code-coverage \
  --wait 30 \
  --result-format human

# Specific test class
sf apex run test \
  --target-org mySandbox \
  --tests RecordHealthCheckCoverageTest \
  --code-coverage \
  --wait 30 \
  --result-format human

# JSON output (for scripting)
sf apex run test \
  --target-org mySandbox \
  --test-level RunLocalTests \
  --code-coverage \
  --wait 30 \
  --result-format json
```

## Execute Anonymous Apex

### Validate deployed metadata

Fails if `RecordHealthCheckMetadataValidator` reports any `ERROR`-severity issue:

```bash
sf apex run \
  --target-org mySandbox \
  --file scripts/apex/validateMetadata.apex
```

### Run a Check Set against a record

Edit `CONFIG_NAME` and `RECORD_ID` in the script first, then:

```bash
sf apex run \
  --target-org mySandbox \
  --file scripts/apex/runHealthCheck.apex
```

## Retrieve metadata from an org

```bash
# Retrieve everything in manifest/package.xml from the org into force-app
sf project retrieve start \
  --manifest manifest/package.xml \
  --target-org mySandbox \
  --wait 30
```

## Permission sets

Assign after deploy so users can run the component:

```bash
# Assign Record Health Check User to the current default user
sf org assign permset \
  --name Record_Health_Check_User \
  --target-org mySandbox

# Assign Admin Permission Set for troubleshooting details and validator access
sf org assign permset \
  --name Record_Health_Check_Admin \
  --target-org mySandbox
```

## Local development (npm)

Not Salesforce CLI, but part of the contributor workflow from `CONTRIBUTING.md`:

```bash
# Format check
npm run prettier:verify

# Lint LWC JavaScript
npm run lint

# LWC unit tests
npm test

# LWC tests with coverage thresholds
npm run test:unit:coverage

# Format all project files
npm run prettier
```

## Code Analyzer (release gate)

Used in CI before scratch-org deploy:

```bash
sf plugins install code-analyzer

sf code-analyzer run \
  --workspace force-app \
  --rule-selector Recommended \
  --output-file code-analyzer.html \
  --severity-threshold 2
```

## Scratch org cleanup

```bash
sf org delete scratch --target-org rhc-scratch --no-prompt
```

## Useful org commands

```bash
# List authenticated orgs
sf org list

# Show default org
sf config get target-org

# Open org in browser
sf org open --target-org mySandbox

# Display org limits and API version
sf org display --target-org mySandbox
```

## Manifest reference

| File | Purpose |
| ---- | ------- |
| `manifest/package.xml` | Production Core: engine, schema, LWC, permissions, and self-contained tests |

Every other Check Set manifest belongs in
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples).

All manifests target API version **66.0** (see `sfdx-project.json`).

## Related

- [Getting Started](../installation/getting-started.md): CLI install path (Option A)
- [CONTRIBUTING.md](../../../CONTRIBUTING.md): PR checks before opening a pull request
- [Configuration Guide](configuration-guide.md): permission sets and Setup tasks after deploy
