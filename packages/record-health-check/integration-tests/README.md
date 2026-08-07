# Integration tests (CI fixtures only)

This directory is **not** part of the Framework install.

It holds fixture Custom Metadata, a small custom object, Apex smoke coverage, and
platform-event subscriber triggers used by the manual Salesforce release gate
(`.github/workflows/salesforce-validate.yml`). It must never be deployed to a
customer sandbox or production org.

## Safe deploy paths

| Path                                                                                             | What deploys                                                                                      |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| README / install-guide **package install** links                                                 | Unlocked package `Record Health Check` (`rhc`); not this directory                                |
| Subscriber `npm run setup`                                                                       | Promoted `04t` package + `subscriber-app`; not this directory                                     |
| Contributor `npm run dev:setup`                                                                  | `force-app`, then this directory for maintainer gates                                             |
| `sf project deploy start --manifest manifest/package.xml` (from `packages/record-health-check/`) | Framework + four Demo Check Sets (`Example_…`, `Demo:` card titles)                               |
| Release gate                                                                                     | Explicit `--source-dir packages/record-health-check/integration-tests` after the Framework deploy |

Keep this path out of the root `sfdx-project.json` `packageDirectories`. The nested packaging
project at `packages/record-health-check/sfdx-project.json` registers only `force-app`.

## Contents (high level)

- Fixture Check Sets and Rules, including a retained copy of the four Demo `Example_` Check Sets
  that also ship in `force-app`
- `Account_Display_Formats`: one Check Set whose Rules cover every **Display: Value Format**
  option across Query, Formula, and Compare two queries. Set it up with
  `./scripts/setup-display-formats.sh`, which creates a scratch org, seeds the Account and
  Opportunity the Rules read, and prints every Found and Expected chip.

## Display-format scratch orgs and deterministic data

Run the maintained fixture in both currency modes. Both commands deploy Framework and the integration
fixtures, seed the same Account and Opportunity, and execute `verifyDisplayFormats.apex`:

```bash
# Multi-currency (default): activates EUR and seeds EUR Account/Opportunity rows.
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-display-formats.sh rhc-display-mc 7

# Single-currency: uses the same values without CurrencyIsoCode fields.
DEV_HUB_ALIAS=my-dev-hub \
SCRATCH_DEF=config/project-scratch-def.json \
./scripts/setup-display-formats.sh rhc-display-single 7
```

> [!NOTE]
> These two commands are shell scripts, so the `VAR=value` prefix is required and is bash/zsh only.
> On Windows run them from **Git Bash**. The `npm run` entry points below take `--dev-hub` instead
> and work in PowerShell and cmd as well.

Run both commands from the repository root. `SCRATCH_DEF` is resolved under
`packages/record-health-check/config/` by the script.

The seeded Account is **Display Format Coverage**. Its Annual Revenue, employee count, postal code,
Account Number, Created Date, Rating, and related Opportunity Amount, Probability, and Close Date
exercise currency, number, leading-zero text, date-shaped text, date/time, picklist labels, percent,
ratio-percent, per-side currency, and list-row formatting. The verifier fails visibly by reporting
any missing format and prints every Found and Expected value for inspection.

- `RHC_Event_Export__c` helper object for lifecycle-event export smoke tests
- Platform-event triggers used only in CI orgs
- Apex classes that exercise the Framework against those fixtures

## Apex API and Flow-action demos

Two anonymous Apex scripts provide repeatable demonstrations without adding demo-only classes to
the installed Framework:

| Script                           | Demonstrates                                                                                             |
| -------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `scripts/demo_apex_api.apex`     | `RecordHealthCheck.evaluate(request)`, typed responses, correlation IDs, and status handling             |
| `scripts/demo_flow_actions.apex` | The exact `@InvocableMethod` Set and Rule actions exposed in Flow Builder, including their output fields |

Deploy Framework before the fixtures, then run the scripts in order. Work from the nested package
project or pass full paths from the repository root:

```bash
cd packages/record-health-check

sf project deploy start --source-dir force-app --target-org my-scratch-org --wait 30
sf project deploy start --source-dir integration-tests --target-org my-scratch-org --wait 30
sf org assign permset --name Record_Health_Check_Admin --target-org my-scratch-org
sf apex run --file integration-tests/scripts/demo_apex_api.apex --target-org my-scratch-org
sf apex run --file integration-tests/scripts/demo_flow_actions.apex --target-org my-scratch-org
```

Or use the maintained contributor shortcut:

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias my-scratch-org
```

`integration-tests` intentionally remains outside the root `sfdx-project.json`. A subscriber package
install never deploys this directory; deploying demo fixtures always requires an explicit contributor
command.

The Framework package already includes the four Demo `Example_` Check Sets. Matching copies here
exist so integration runs can deploy the same configurations alongside broader fixtures.

## Example fixture data

Subscriber demo orgs use `npm run setup` and seed data from `scripts/subscriber/data/`. See the
[scratch-org setup guide](../../../docs/installation/05-create-rhc-scratch-org.md) for the complete
subscriber demo scenario.
