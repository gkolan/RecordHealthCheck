# Record Health Check

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Salesforce API](https://img.shields.io/badge/Salesforce%20API-66.0-00A1E0.svg)](sfdx-project.json)
[![CI](https://github.com/gkolan/RecordHealthCheck/actions/workflows/ci.yml/badge.svg)](https://github.com/gkolan/RecordHealthCheck/actions/workflows/ci.yml)
[![Deploy to Salesforce](https://img.shields.io/badge/Deploy%20to-Salesforce-00A1E0?logo=salesforce&logoColor=white)](https://githubsfdeploy.herokuapp.com/?owner=gkolan&repo=RecordHealthCheck&ref=main)

> **Make informed decisions before taking action on Salesforce data.**
>
> Record Health Check evaluates Salesforce records directly on the record page, surfacing what
> needs attention, why it matters, and how to resolve it without modifying the record or blocking
> users.

Every Rule returns **Pass**, **Fail**, **Skipped**, or **Unable to Check**. When a record needs
attention, the card can show its **Critical**, **Warning**, or **Info** severity; explain what was
**Found** and **Expected**; and provide fix instructions with an optional read-only **Fix it** link.

Administrators define **Check Sets** and **Rules** in Custom Metadata. The Framework evaluates them
at read time, so one card can review the current record, related records, aggregate results, and
data that existed before the Rules were created, without writing to the record.

> [!NOTE]
> Record Health Check provides advisory guidance; it never blocks a save. When Salesforce must
> prevent a record change, use a Validation Rule, Flow, or Apex trigger instead.

## Demo

<table>
  <tr>
    <td width="48%" valign="top">
      <p><b>Example: Account 360 Health Check</b><br />▶ <a href="https://github.com/gkolan/RecordHealthCheck/blob/main/assets/img/Account_Health_Check_Quick_Demo.gif" target="_blank">Animated GIF</a></p>
      <p>An account team can review whether an Account is ready for the next conversation without leaving the record page.</p>
      <ul>
        <li><b>Review the whole Account.</b> The Check Set evaluates the Account together with its Contacts, Opportunities, Cases, Contracts, and Activities.</li>
        <li><b>Start with the summary.</b> The footer shows how many results Passed, Failed, raised a Warning or Info issue, or were Skipped.</li>
        <li><b>Open the detail that matters.</b> Passed Rules remain compact. Other rows can explain the issue and severity, show what the Framework found and expected, or state why the Rule did not apply.</li>
        <li><b>Go directly to the next step.</b> When an issue has a clear destination, a <b>Fix it</b> link can take the user there. In this example, it opens a report already filtered to the Account.</li>
      </ul>
      <p><b>Administrators control the experience</b></p>
      <ul>
        <li>Each check shown on the card is a Rule in the selected Check Set.</li>
        <li>Custom Metadata defines what each Rule evaluates, when it applies, and whether the card runs when the page opens or when the user selects <b>Run</b>.</li>
        <li>The same component can be configured for any Salesforce object with a record page.</li>
      </ul>
    </td>
    <td width="52%" valign="top">
      <img src="assets/img/Account_Health_Check.png" alt="Record Health Check card on an Account record page, showing passed, failed, warning, and skipped checks with Found/Expected details and Fix it links" width="100%" />
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

> [!NOTE]
> **Upgrading an existing installation?** This release uses updated Custom Metadata field API
> names. Review the [upgrade guide](docs/installation/04-upgrading.md) for the field mapping and
> upgrade steps.

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
