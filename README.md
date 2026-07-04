# Record Health Check

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![CI](https://github.com/gkolan/recordHealthCheck/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/recordHealthCheck/actions/workflows/ci.yml)
[![Salesforce API](https://img.shields.io/badge/Salesforce%20API-66.0-00A1E0.svg)](sfdx-project.json)
[![Deploy to Salesforce](https://img.shields.io/badge/Deploy%20to-Salesforce-00A1E0?logo=salesforce&logoColor=white)](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=recordHealthCheck&ref=main)

Record Health Check is a metadata-driven framework for running data-quality checks against a Salesforce record, right on its **record page**. It is **advisory** and read-only, so it never blocks a save and never writes a field. You define **Check Sets** and **Rules** in Custom Metadata; the framework evaluates the open record, and the card shows each result as **Pass**, **Fail**, **Skipped**, or **Unable to evaluate** — with a failing check flagged by severity as **Error**, **Warning**, or **Info**.

Because it runs at read time rather than save time, it can evaluate across related records, compare aggregates, and surface data that predates your rules. It does not stop a save — use validation rules, Flow, or Apex triggers when the requirement is to block one. A failing check can also offer an optional read-only **"Fix it" link** and fix instructions.

## Demo

<table>
  <tr>
    <td width="58%" valign="top">
      <p>The card on an Account record page, evaluating the open record in place:</p>
      <ul>
        <li><b>Passed</b> checks collapse to a single line.</li>
        <li><b>Failed</b> checks explain what is wrong and can show a <b>"Fix it"</b> link with instructions.</li>
        <li><b>Warning</b> and <b>Info</b> rows flag lower-severity issues, from "worth a look" down to "just so you know."</li>
        <li><b>Skipped</b> checks say why they did not apply to this record.</li>
        <li>Any row can reveal <b>Found / Expected</b> detail and the rule behind it.</li>
      </ul>
      <p>The footer tallies <b>Passed / Failed / Warnings / Skipped</b> at a glance, and <b>Rerun</b> re-evaluates on demand.</p>
      <!-- Video walkthrough: replace the line below with
           <p>▶ <b>Watch the two-minute walkthrough:</b> <a href="https://youtu.be/YOUR_VIDEO_ID">youtu.be/YOUR_VIDEO_ID</a></p> -->
      <p>▶ <b><a href="https://github.com/gkolan/recordHealthCheck/blob/main/docs/assets/img/Account_Health_Check_Quick_Demo.gif" target="_blank">See the animated GIF for a quick demo</a></b>.</p>
    </td>
    <td width="42%" valign="top">
      <img src="docs/assets/img/Account_Health_Check.png" alt="Record Health Check card on an Account record page, showing passed, failed, warning, and skipped checks with Found/Expected details and Fix it links" width="100%" />
    </td>
  </tr>
</table>

## Install

Install into a **sandbox** first. Pick whichever path fits you — all three deploy the same `force-app` source.

**Option 1 — Deploy button (no command line).** Click **[Deploy to Salesforce](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=recordHealthCheck&ref=main)**, log in to your sandbox, and click Deploy. This installs the latest `main`; to pin a release, change `ref=main` to a tag such as `ref=v1.1.0` in the button link.

**Option 2 — Salesforce CLI.**

```bash
git clone https://github.com/gkolan/recordHealthCheck.git
cd recordHealthCheck
sf project deploy start --source-dir force-app
sf org assign permset --name Record_Health_Check_User
```

**Option 3 — Change set or DevOps Center.** Deploy the `force-app` folder through a change set, DevOps Center, or your deployment tool of choice.

### After installing

1. Assign the **`Record_Health_Check_User`** permission set.
2. On a Lightning **record page**, drag on the **recordHealthCheck** component.
3. Set **Check Set Developer Name** to a Check Set's Developer Name, for example `Account_Data_Quality`. It must match exactly — a mismatch is the most common setup mistake.
4. Save, activate, and open a record to see the card evaluate it.

Full walkthrough: [First 10 Minutes](docs/start/first-10-minutes.md)

## What You Get

- Lightning record-page card
- Custom Metadata configuration
- Formula, SOQL, compare-two-SOQL, and Apex checks
- Guided remediation: optional "Fix it" deep links and fix instructions on failing checks
- Sample Account Check Sets for learning
- User and Admin Permission Sets

## Documentation

Open only the page you need.

- Learn the concepts: [Admin Quick Start](docs/installation/admin-quick-start.md)
- Create your first Rule: [Getting Started](docs/installation/getting-started.md#step-4-create-your-first-rule)
- Copy an example: [Examples catalog](docs/examples/index.md)
- Add a "Fix it" link: [Action Links and Fix Instructions](docs/guides/action-links.md)
- Full field reference: [Configuration Guide](docs/guides/configuration-guide.md) or [Apex plugin reference](docs/apex/plugin-reference.md)

## Example Library

Start with one example. Use the full library when you need another pattern:

- [Formula examples](docs/examples/index.md#formula)
- [SOQL single-query examples](docs/examples/index.md#soql-single-query)
- [SOQL compare-two-queries examples](docs/examples/index.md#soql-compare-two-queries)
- [Apex examples](docs/examples/index.md#apex)
- [Sample Check Set packages](docs/examples/index.md#sample-check-set-packages)

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
