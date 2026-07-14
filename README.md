# Record Health Check

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![CI](https://github.com/gkolan/RecordHealthCheck/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/RecordHealthCheck/actions/workflows/ci.yml)
[![Salesforce API](https://img.shields.io/badge/Salesforce%20API-66.0-00A1E0.svg)](sfdx-project.json)

Record Health Check is a metadata-driven framework for running data-quality checks against a Salesforce record, right on its **record page**. It is **advisory** and read-only, so it never blocks a save and never writes a field. You define **Check Sets** and **Rules** in Custom Metadata; the framework evaluates the open record, and the card shows each result as **Pass**, **Fail**, **Skipped**, or **Unable to Check** — with a failing check flagged by severity as **Critical**, **Warning**, or **Info**.

Because it runs at read time rather than save time, it can evaluate across related records, compare aggregates, and surface data that predates your rules. It does not stop a save — use validation rules, Flow, or Apex triggers when the requirement is to block one. A failing check can also offer an optional read-only **"Fix it" link** and fix instructions.

## Demo

<table>
  <tr>
    <td width="58%" valign="top">
      <p>The card reports each check as a row:</p>
      <ul>
        <li><b>Passed</b> checks collapse to a single line.</li>
        <li><b>Failed</b> checks explain what is wrong and can show a <b>"Fix it"</b> link with instructions.</li>
        <li><b>Warning</b> and <b>Info</b> rows flag lower-severity issues, from "worth a look" down to "just so you know."</li>
        <li><b>Skipped</b> checks say why they did not apply to this record.</li>
        <li>Any row can reveal <b>Found / Expected</b> detail and the rule behind it.</li>
      </ul>
      <p>The footer tallies <b>Passed / Failed / Warnings / Skipped</b> at a glance, and <b>Rerun</b> re-evaluates on demand.</p>
      <p>You choose when it runs: automatically as the page loads, or on demand when the user clicks <b>Run</b>.</p>
      <p>Every row is a <b>check</b> you author declaratively in metadata, so you add or retune checks without touching the component.</p>
      <p>Checks are grouped into a <b>check set</b> per object. This example is an Account, but the same card drops onto any object's record page.</p>
      <!-- Video walkthrough: replace the line below with
           <p><sub>▶ <a href="https://youtu.be/YOUR_VIDEO_ID">Watch the two-minute walkthrough</a></sub></p> -->
      <p><sub>▶ <a href="https://github.com/gkolan/RecordHealthCheck/blob/main/docs/assets/img/Account_Health_Check_Quick_Demo.gif" target="_blank">See it in motion (animated GIF)</a></sub></p>
    </td>
    <td width="42%" valign="top">
      <img src="docs/assets/img/Account_Health_Check.png" alt="Record Health Check card on an Account record page, showing passed, failed, warning, and skipped checks with Found/Expected details and Fix it links" width="100%" />
      <p align="center"><sub>The card above is the <b>Example - Account 360 Health Check</b> set. Its checks read across the account's contacts, opportunities, cases, contracts, and activities, and one links to a report filtered to this account.</sub></p>
    </td>
  </tr>
</table>

## Install

Install into a **sandbox** first. For V2, deploy Core and the Hero through their two manifests so
optional Examples content is not included.

> [!IMPORTANT]
> **Upgrading to V2:** V2 is a breaking metadata-contract release with no dual-read support for v1.x field names. Back up custom metadata and follow the [V2 upgrade and rollback guide](docs/v2/installation/upgrading-to-v2.md) before deploying.

**Option 1 — Salesforce CLI.**

```bash
git clone https://github.com/gkolan/RecordHealthCheck.git
cd RecordHealthCheck
sf project deploy start --manifest manifest/package-core.xml
sf project deploy start --manifest manifest/package-Example_Account_360_Health_Check.xml
sf org assign permset --name Record_Health_Check_User
```

**Option 2 — Change set or DevOps Center.** Deploy the components named by
`manifest/package-core.xml`, followed by `manifest/package-Example_Account_360_Health_Check.xml`.
Do not deploy every non-Hero Custom Metadata record from the Core source tree.

### After installing

Assign the **`Record_Health_Check_User`** permission set, add the **recordHealthCheck** component to a
Lightning record page, and choose `Example_Account_360_Health_Check` in App Builder. This Hero Check
Set is the only example owned by Core. Install every other example from
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples).

Full walkthrough: [First 10 Minutes](docs/v2/start/first-10-minutes.md)

## What You Get

- Lightning record-page card
- Custom Metadata configuration
- Formula, SOQL, compare-two-SOQL, and Apex checks
- Guided remediation: optional "Fix it" deep links and fix instructions on failing checks
- Per-placement visual treatment: SLDS 2 (default) or SLDS 1, set on the App Builder card — see [Design System](docs/v2/guides/design-system.md)
- One Hero Account Check Set for the first working card
- User and Admin Permission Sets

## Documentation

Current docs are under [`docs/v2/`](docs/v2/). Historical v1.x pages are under [`docs/v1/`](docs/v1/). Open only the page you need.

- Learn the concepts: [Admin Quick Start](docs/v2/installation/admin-quick-start.md)
- Create your first Rule: [Getting Started](docs/v2/installation/getting-started.md#step-4-create-your-first-rule)
- Install an example pack: [Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md)
- Add a "Fix it" link: [Action Links and Fix Instructions](docs/v2/guides/action-links.md)
- Full field reference: [Configuration Guide](docs/v2/guides/configuration-guide.md) or [Apex plugin reference](docs/v2/apex/plugin-reference.md)

## Example Library

Reusable scenarios, Rule patterns, and example Apex classes live in
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples). Core ships
one Hero Check Set (`Example_Account_360_Health_Check`). This is an intentional V2 change: V1
bundled examples with Core; V2 installs optional packs independently afterward. See the
[Core vs Examples boundary](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/core-and-examples-boundary.md).

- [Install packs (Setup · Git/CLI · Local DX)](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md)
- [Pack catalog by outcome](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/catalog/by-outcome.md)
- [Pattern library](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md)
- [Authoring guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/authoring-guide.md)
- [Pack index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md)

## Local Checks

For contributors:

```bash
npm run prettier:verify
npm run lint
npm test
npm run test:unit:coverage
```

Apex changes also need a validation deployment or org test run before release.

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
