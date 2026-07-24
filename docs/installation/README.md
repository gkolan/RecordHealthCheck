# Install or upgrade Record Health Check

> [!NOTE]
> On this page, choose a safe route for a new installation or an existing-org upgrade and see the Salesforce outcome each step is designed to prove.

Use the new-install path when the org does not already contain Record Health Check. Use the upgrade
path when any earlier version, Custom Metadata configuration, Lightning placement, Apex caller, or
Flow integration exists.

## Choose your path

| Your starting point | Follow this path | What you will accomplish |
| --- | --- | --- |
| Record Health Check is new to the org | [How it works](01-how-it-works.md) → [Install and verify](02-install-and-verify.md) → [Create your first Rule](03-create-your-first-rule.md) | Understand the Framework, deploy Core, place the Lightning card, and evaluate a Formula Rule |
| You want the complete project demo | [Create the demo scratch org](05-create-rhc-scratch-org.md) | Reproduce the maintained demo org, data, record page, permissions, and verified outcomes |
| The org uses an earlier release | [Upgrading Record Health Check](04-upgrading.md) | Back up the existing configuration, map earlier fields to current fields, deploy, verify integrations, and retain a rollback path |
| Core is installed and you want another Rule | [Examples library](../examples/README.md) | Choose an Evaluation Type and adapt a distinct, tested configuration pattern |

## New installation sequence

| Step | Page | What you learn or verify |
| ---: | --- | --- |
| 1 | [How Record Health Check works](01-how-it-works.md) | How Check Sets, Rules, Evaluation Types, and outcomes fit together |
| 2 | [Install and verify](02-install-and-verify.md) | How to deploy Core to a sandbox, assign Framework access, place the Lightning card, and verify a result |
| 3 | [Create your first Rule](03-create-your-first-rule.md) | How to create a Check Set and Formula Rule in Salesforce Setup and test both PASS and FAIL |

## Upgrade sequence

The [upgrade guide](04-upgrading.md) contains the complete field migration reference. Keep
the map beside the exported Custom Metadata while converting old Rule and Check Set fields. The same
guide covers renamed values, integration changes, verification, and rollback.

## Next steps

- [Documentation home](../README.md): choose configuration, integration, metadata, or troubleshooting guidance
- [Examples library](../examples/README.md): learn through complete Salesforce scenarios
- [Metadata reference](../metadata/README.md): look up current Setup labels, API names, allowed values, and defaults
