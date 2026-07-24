# Integration tests (CI fixtures only)

This directory is **not** part of the product install.

It holds fixture Custom Metadata, a small custom object, Apex smoke coverage, and
platform-event subscriber triggers used by the manual Salesforce release gate
(`.github/workflows/salesforce-validate.yml`). It must never be deployed to a
customer sandbox or production org.

## Safe deploy paths

| Path                                                      | What deploys                                                             |
| --------------------------------------------------------- | ------------------------------------------------------------------------ |
| README **Deploy** buttons (`githubsfdeploy`)              | Default package directory only: `force-app`                              |
| `sf project deploy start --manifest manifest/package.xml` | Core + `Example_` artifacts listed in the manifest                       |
| `sf project deploy start` (no flags)                      | `force-app` only (this directory is not a `packageDirectories` entry)    |
| Release gate                                              | Explicit `--source-dir integration-tests` after the Core manifest deploy |

Do **not** add this path back to `sfdx-project.json` `packageDirectories` unless you
also change every public install instruction. A bare `sf project deploy start` with
this directory registered would push fixture Rules, triggers, and related test
metadata into the target org.

## Contents (high level)

- Fixture Check Sets and Rules (not `Example_`-prefixed product samples)
- `RHC_Event_Export__c` helper object for lifecycle-event export smoke tests
- Platform-event triggers used only in CI orgs
- Apex classes that exercise Core against those fixtures

Product examples that ship to users live under `force-app` and are listed in
`manifest/package.xml`.
