# Integration tests (CI fixtures only)

This directory is **not** part of the product install.

It holds fixture Custom Metadata, a small custom object, Apex smoke coverage, and
platform-event subscriber triggers used by the manual Salesforce release gate
(`.github/workflows/salesforce-validate.yml`). It must never be deployed to a
customer sandbox or production org.

## Safe deploy paths

| Path                                                      | What deploys                                                          |
| --------------------------------------------------------- | --------------------------------------------------------------------- |
| README **Deploy** buttons (`githubsfdeploy`)              | Default package directory only: `force-app`                           |
| `sf project deploy start --manifest manifest/package.xml` | Framework + `Example_` artifacts listed in the manifest               |
| `sf project deploy start` (no flags)                      | `force-app` only (this directory is not a `packageDirectories` entry) |
| Release gate                                              | Explicit `--source-dir integration-tests` after the Framework deploy  |

Keep this path out of `sfdx-project.json` `packageDirectories` so a bare
`sf project deploy start` stays Framework-only. Registering it without updating every
public install instruction would push fixture Rules, triggers, and related test
metadata into the target org.

## Contents (high level)

- Fixture Check Sets and Rules (not `Example_`-prefixed product samples)
- `Account_Display_Formats`: one Check Set whose Rules cover every **Display: Value Format**
  option across Query, Formula, and Compare two queries. Set it up with
  `./scripts/setup-display-formats.sh`, which creates a scratch org, seeds the Account and
  Opportunity the Rules read, and prints every Found and Expected chip.
- `RHC_Event_Export__c` helper object for lifecycle-event export smoke tests
- Platform-event triggers used only in CI orgs
- Apex classes that exercise the Framework against those fixtures

Product examples that ship to users live under `force-app` and are listed in
`manifest/package.xml`.
