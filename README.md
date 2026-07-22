# Record Health Check

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Salesforce API](https://img.shields.io/badge/Salesforce%20API-66.0-00A1E0.svg)](sfdx-project.json)
[![CI](https://github.com/gkolan/RecordHealthCheck/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/RecordHealthCheck/actions/workflows/ci.yml)
[![Deploy to Salesforce](https://img.shields.io/badge/Deploy%20to-Salesforce-00A1E0?logo=salesforce&logoColor=white)](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=RecordHealthCheck&ref=main)

**Can users trust this Salesforce record enough to move forward?**

_Record Health Check answers that question on the record page, then shows the user what needs
attention, why it matters, and how to act._

Every Rule returns **Pass**, **Fail**, **Skipped**, or **Unable to Check**. When a record needs
attention, the card can show its **Critical**, **Warning**, or **Info** severity; explain what was
**Found** and **Expected**; and provide fix instructions with an optional read-only **Fix it** link.

Administrators define **Check Sets** and **Rules** in Custom Metadata. The Framework evaluates them
at read time, so one card can review the current record, related records, aggregate results, and
data that existed before the Rules were created, without writing to the record.

> [!IMPORTANT]
> Record Health Check provides advisory guidance; it never blocks a save. When Salesforce must
> prevent a record change, use a Validation Rule, Flow, or Apex trigger instead.

## Demo

<table>
  <tr>
    <td width="48%" valign="top">
      <p><b>One view of record readiness</b></p>
      <p>This Account health check brings signals from the Account and its related records into the place where the user is already working.</p>
      <ul>
        <li><b>Scan the outcome.</b> The footer summarizes Passed, Failed, Warning, Info, and Skipped Rules.</li>
        <li><b>Focus attention.</b> Passed Rules stay compact, while failed Rules show their severity and guidance.</li>
        <li><b>Understand the result.</b> Expanded rows can show what the Framework found, what it expected, and why a Rule was skipped.</li>
        <li><b>Take the next step.</b> A failed Rule can provide fix instructions and an optional read-only <b>Fix it</b> link.</li>
      </ul>
      <p><b>Built for administrators to adapt</b></p>
      <p>Each row is a Rule in a Check Set. Administrators use Custom Metadata to decide what the card checks, when a Rule applies, and whether the card runs when the page opens or when the user selects <b>Run</b>. The same component can support any Salesforce object with a record page.</p>
      <!-- Video walkthrough: replace the line below with
           <p><sub>▶ <a href="https://youtu.be/YOUR_VIDEO_ID">Watch the two-minute walkthrough</a></sub></p> -->
      <p><sub>▶ <a href="https://github.com/gkolan/RecordHealthCheck/blob/main/assets/img/Account_Health_Check_Quick_Demo.gif" target="_blank">See it in motion (animated GIF)</a></sub></p>
    </td>
    <td width="52%" valign="top">
      <img src="assets/img/Account_Health_Check.png" alt="Record Health Check card on an Account record page, showing passed, failed, warning, and skipped checks with Found/Expected details and Fix it links" width="100%" />
      <p align="center"><sub><b>Example: Account 360 Health Check.</b> One Check Set reads across the Account's Contacts, Opportunities, Cases, Contracts, and Activities. A Fix it link opens a report already filtered to this Account.</sub></p>
    </td>
  </tr>
</table>

## Start here

Choose the path that matches where you are today. You do not need to read the documentation in
order.

| If you want to…                     | Start here                                                                |
| ----------------------------------- | ------------------------------------------------------------------------- |
| Understand the Framework            | [See how Record Health Check works](docs/installation/01-how-it-works.md) |
| Build a Check Set or Rule           | [Learn from a working example](docs/examples/README.md)                   |
| Find configuration or API specifics | [Search the documentation](docs/README.md)                                |

## Install

Start in a **sandbox**. The deployment installs the Framework, but it does not add example Check
Sets, Rules, or Apex implementations to your org.

> [!IMPORTANT]
> **Already using Record Health Check?** Back up your Custom Metadata before deploying. Earlier
> field API names are not supported by the current Framework, so follow the
> [upgrade and rollback guide](docs/installation/04-upgrading.md).

### Deploy to a sandbox

[![Deploy to Salesforce](https://img.shields.io/badge/Deploy%20to-Salesforce-00A1E0?logo=salesforce&logoColor=white)](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=RecordHealthCheck&ref=main)

The button opens Salesforce authentication and starts the deployment. Prefer the Salesforce CLI?

```bash
git clone https://github.com/gkolan/RecordHealthCheck.git
cd RecordHealthCheck
sf project deploy start --manifest manifest/package.xml
```

### After installing

1. Assign the **`Record_Health_Check_User`** permission set.
2. [Create your first Check Set and Rule](docs/installation/03-create-your-first-rule.md) in
   Salesforce Setup.
3. Add the **recordHealthCheck** component to a Lightning record page.
4. Select the Check Set in Lightning App Builder, save the page, and activate it.

For permissions, verification, and other deployment methods, follow
[Install and verify](docs/installation/02-install-and-verify.md).

## What you get

Record Health Check gives administrators a configurable Framework and gives users focused guidance
without leaving the Salesforce record page.

| Framework capability           | What it gives your org                                                                                                                                                            |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lightning record-page card     | Runs the selected Check Set and presents each Rule result where users already work                                                                                                |
| Custom Metadata configuration  | Lets administrators define, review, and deploy Check Sets and Rules without changing the Lightning component                                                                      |
| Four Evaluation Types          | Checks the current record with Formula, related data with Query, two SOQL results with Compare two queries, or custom logic with Apex                                             |
| Guided remediation             | Explains failed Rules with fix instructions and, when useful, an optional read-only **Fix it** link                                                                               |
| SLDS 1 and SLDS 2 support      | Lets administrators choose the card's visual treatment for each placement in Lightning App Builder; see [Choose the card design system](docs/guides/choose-card-design-system.md) |
| User and Admin permission sets | Provides clear starting access for people who run health checks and administrators who configure the Framework                                                                    |

## Contributing

Planning to contribute? See [Contributing](CONTRIBUTING.md) for local checks, testing requirements,
and pull request guidance.

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
