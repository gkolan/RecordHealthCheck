# Install or revalidate Record Health Check

> [!NOTE]
> On this page, choose a safe route for a new installation or an existing-org revalidation and see the Salesforce outcome each step is designed to prove.

Use the new-install path when the org does not already contain Record Health Check. Use the
revalidation path when the org already has Custom Metadata configuration, Lightning placement,
Apex callers, Flow integrations, or Platform Event subscribers.

## Choose your path

| Your starting point | Follow this path | What you will accomplish |
| --- | --- | --- |
| Record Health Check is new to the org | [How it works](01-how-it-works.md) → [Install and verify](02-install-and-verify.md) → [Create your first Rule](03-create-your-first-rule.md) | Understand the Framework, deploy Record Health Check, place the Lightning card, and evaluate a Formula Rule |
| You want the complete project demo | [Create the demo scratch org](05-create-rhc-scratch-org.md) | Reproduce the maintained demo org, data, record page, permissions, and verified outcomes |
| Record Health Check is already installed | [Revalidate an installation](04-upgrading.md) | Back up the existing configuration, validate and deploy the current repository, verify integrations, and retain a rollback path |
| Record Health Check is installed and you want another Rule | [Examples library](../examples/README.md) | Choose an Evaluation Type and adapt a distinct, tested configuration pattern |

## New installation sequence

| Step | Page | What you learn or verify |
| ---: | --- | --- |
| 1 | [How Record Health Check works](01-how-it-works.md) | How Check Sets, Rules, Evaluation Types, and outcomes fit together |
| 2 | [Install and verify](02-install-and-verify.md) | How to deploy Record Health Check to a sandbox, assign Framework access, place the Lightning card, and verify a result |
| 3 | [Create your first Rule](03-create-your-first-rule.md) | How to create a Check Set and Formula Rule in Salesforce Setup and test both PASS and FAIL |

## Existing-installation sequence

The [revalidation guide](04-upgrading.md) starts with a restorable configuration backup. It uses the
same manifest for dry-run validation and deployment, then verifies Lightning pages, user access,
business outcomes, integrations, event subscribers, and rollback evidence.

## Next steps

- [Documentation home](../README.md): choose configuration, integration, metadata, or troubleshooting guidance
- [Examples library](../examples/README.md): learn through complete Salesforce scenarios
- [Metadata reference](../metadata/README.md): look up current Setup labels, API names, allowed values, and defaults
