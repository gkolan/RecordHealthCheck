# Release Record Health Check

Record Health Check ships primarily as the namespaced unlocked package `Record Health Check`.
Source deployment is a contributor workflow and is not the supported subscriber installation path.

## Version model

The Framework follows Semantic Versioning. `package.json` carries the Framework version and
`packages/record-health-check/sfdx-project.json` carries the Salesforce package version as
`MAJOR.MINOR.PATCH.NEXT`. Each package build uses `MAJOR.MINOR.PATCH.BUILD`; later build numbers are
immutable candidates for the same semantic release.

## Single source of truth for subscriber installs

All subscriber-facing install URLs, CLI scripts, and CI gates read from
[`config/package-releases.json`](../config/package-releases.json).

Rules:

1. `stable.subscriberPackageVersionId` must always refer to a **promoted** version.
2. Never update `stable` merely because package-version creation produced a new candidate `04t`.
3. Move the current stable `04t` into `previous` before replacing `stable`.
4. Refresh `installUrl.production` and `installUrl.sandbox` when `stable` changes.
5. Do not duplicate the stable `04t` across README badges, docs, and scripts—update
   `package-releases.json` first, then run doc checks.

## Required evidence

Before creating a release candidate:

1. Run every local gate, including docs, query shapes, permissions, formatting, lint, and Jest.
2. Run Code Analyzer and resolve every unsuppressed release finding.
3. Run `npm run package:verify` against the candidate `04t` (clean install and, when available,
   previous-to-candidate upgrade).
4. Confirm subscriber-owned Custom Metadata survives the upgrade gate.
5. Run the package-source org gate in CI (`salesforce-validate.yml`).

Never discard deploy, test, package, or install output. Archive JSON results with the release.

## Create a package candidate

```bash
DEV_HUB_ALIAS=<dev-hub> npm run package:create
```

Or manually from the nested package project:

```bash
cd packages/record-health-check

sf package version create \
  --package 0Hoak0000004kKPCAY \
  --path force-app \
  --definition-file config/project-scratch-def.json \
  --version-number 2.0.0.NEXT \
  --code-coverage \
  --installation-key-bypass \
  --wait 120 \
  --target-dev-hub <dev-hub>
```

Record the resulting `04t` ID. Do not promote it until subscriber verification gates pass.

## Verify before promote

```bash
DEV_HUB_ALIAS=<dev-hub> npm run package:verify -- --package <candidate-04t>
```

This runs:

- Clean no-namespace install of the candidate
- Subscriber harness deploy and `RHCSubscriberSmokeTest`
- Previous-to-candidate upgrade rehearsal when `previous` is a promoted `04t`

## Promote and publish

```bash
DEV_HUB_ALIAS=<dev-hub> npm run package:promote -- --package <candidate-04t>
```

Then update `config/package-releases.json`:

1. Move the current stable entry to `previous`.
2. Set `stable.subscriberPackageVersionId` to the promoted `04t`.
3. Refresh `installUrl` values.
4. Update `CHANGELOG.md` and create the GitHub release.

Also commit the exact source used to create the package, create the matching semantic-version tag,
and configure the public install redirect (`recordhealthcheck.com/install`) to the new stable `04t`.

Current promoted subscriber package version ID: see `config/package-releases.json`.

## Samples

Example Check Sets and Rules are optional learning assets, not Core defaults. Deliver them through
the documented sample installer or subscriber demo scripts after Core is installed. Never make a Core
package candidate depend on example records being packaged.

## Rollback

Salesforce package versions are immutable. Roll forward with a corrected package version when a
schema or installed metadata change cannot be safely reversed. For an application-only regression,
install the previously supported version only when Salesforce package ancestry and upgrade rules
permit it. Document data or configuration remediation separately.
