# Record Health Check documentation

> [!NOTE]
> On this page, find the shortest path from your Salesforce goal to the Record Health Check guidance, example, or reference that will help you complete it.

Record Health Check helps Salesforce teams show whether a record is ready for a business process.
Administrators define the questions as Custom Metadata, and users see the results on a Lightning
record page. Developers can run the same checks from Apex or Flow.

Use this page to find the shortest path for what you want to accomplish. If you are new to Record
Health Check, begin with **Install and verify**, then create one Rule or copy an example.

## What do you want to do?

| I want to… | Start here | What you will learn |
| --- | --- | --- |
| Understand the product before installing it | [How Record Health Check works](installation/01-how-it-works.md) | Check Sets, Rules, result meanings, and when to use a health check |
| Install it and see a working card | [Install and verify](installation/02-install-and-verify.md) | Deploy Core, add a Check Set, place the card, and verify a result |
| Create my first check in Salesforce Setup | [Create your first Rule](installation/03-create-your-first-rule.md) | Configure a Formula Rule without writing Apex or using the command line |
| Copy a practical example | [Examples library](examples/README.md) | Choose Formula, Query, Compare Two Queries, or Apex and adapt a complete example |
| Configure advanced behavior | [Configure Check Sets and Rules](guides/configure-check-sets-and-rules.md) | Applicability, dependencies, messages, actions, display behavior, and troubleshooting |
| Upgrade an existing installation | [Upgrade Record Health Check](installation/04-upgrading.md) | Back up, migrate renamed fields, validate, and prepare rollback |
| Call health checks from code or automation | [Integration overview](integration/README.md) | Choose Lightning, Apex, Flow, or platform events |
| Look up one Setup field | [Metadata reference](metadata/README.md) | Find the exact label, API name, allowed values, default, and behavior |

> [!TIP]
> You do not need to read the documentation in order. Start with the task closest to your current
> goal and follow the links at the bottom of that page.

## Recommended path for new users

| Step | Task | Expected result |
| ---: | --- | --- |
| 1 | [Learn how it works](installation/01-how-it-works.md) | You can explain the difference between a Check Set and a Rule |
| 2 | [Install and verify](installation/02-install-and-verify.md) | A Record Health Check card appears on a sandbox record page |
| 3 | [Create your first Rule](installation/03-create-your-first-rule.md) | The card evaluates one Rule you configured in Setup |
| 4 | [Choose another example](examples/README.md) | You can select an Evaluation Type based on where the required data is stored |
| 5 | [Review the configuration guide](guides/configure-check-sets-and-rules.md) | The Check Set is ready for broader testing and release review |

## Learn by example

The examples library teaches one Rule at a time. Each page explains the business question, why its
Evaluation Type fits, the exact Setup values, what users see, and how to test it.

| Your data is… | Evaluation Type | Examples |
| --- | --- | --- |
| On the current record or a parent | Verify with a formula | [Formula examples](examples/formula/) |
| On related records | Verify with a query | [Query examples](examples/query/) |
| Returned by two independent queries | Compare two queries | [Compare-two-queries examples](examples/compare-two-queries/) |
| Part of a decision that needs custom code | Verify with Apex | [Apex examples](examples/apex/) |

[Browse every example and learning outcome →](examples/README.md)

## Configure and troubleshoot

[Browse all configuration and troubleshooting guides →](guides/README.md)

| Guide | Use it when… |
| --- | --- |
| [Configure Check Sets and Rules](guides/configure-check-sets-and-rules.md) | You need the complete mental model, Evaluation Type guidance, or go-live checklist |
| [Configure action links](guides/configure-action-links.md) | A failed Rule should tell users what to do or where to go |
| [Troubleshoot with Show Diagnostics](guides/troubleshoot-with-show-diagnostics.md) | An administrator needs authorized troubleshooting details |
| [Choose the card design system](guides/choose-card-design-system.md) | You need to choose SLDS 1 or SLDS 2 for a component placement |
| [Draft configuration with AI](guides/draft-configuration-with-ai.md) | You want an AI assistant to draft configuration from a business requirement |

## Integrate with Salesforce automation

| Surface | Use it when… | Documentation |
| --- | --- | --- |
| Lightning record page | Users need to see and rerun checks on a record | [Lightning component](integration/lightning-component.md) |
| Apex | Code needs a typed Rule or Check Set result immediately | [Apex API](reference/reference-apex-api.md) |
| Flow | Automation needs to branch on a result without custom code | [Flow actions](integration/flow-actions.md) |
| Platform events | Subscribers need an optional after-commit notification | [Lifecycle events](integration/lifecycle-events.md) |

Start with the [integration overview](integration/README.md) if you are unsure which surface fits.

## Look up technical details

[Browse all technical references →](reference/README.md)

| Reference | What it contains |
| --- | --- |
| [Check Set fields](metadata/fields-check-set.md) | Every Check Set field, default, dependency, and allowed value |
| [Rule fields](metadata/fields-check-rule.md) | Every Rule field grouped by purpose and Evaluation Type |
| [Reason Codes](reference/reference-reason-codes.md) | Stable explanations for skipped, unable-to-evaluate, and error outcomes |
| [Platform Event metadata](metadata/README.md#choose-a-platform-event-reference) | Fields and usage for Set Run, Rule Result, and Log events |
| [Field limits](reference/reference-fields-limits.md) | Salesforce storage limits and Framework completed-text limits |
| [Architecture](reference/reference-architecture.md) | Published Framework architecture: principles, layers, runtime, security, limits, ownership |
| [Apex classes](reference/reference-apex-classes.md) | What each production Apex class owns and when to use it |

## Important behavior to know

- Record Health Check reports readiness; it does not block a Salesforce record from being saved.
- A normal business issue returns `FAIL`. An unexpected execution problem returns `ERROR`.
- Formula and query evaluation uses the running user's Salesforce access.
- Lifecycle-event publication is optional and off by default.
- Core ships the Framework plus a clearly prefixed `Example_` Check Set and Rules. Use the
  [examples library](examples/README.md) for additional Formula, Query, Compare two queries, and Apex patterns.

## For documentation authors and AI assistants

- [Documentation standard](development/documentation-standard.md) — page structure, terminology, and
  [plain technical language](development/documentation-standard.md#prefer-plain-technical-language-avoid-cs-jargon)
  (CS jargon to avoid in explanations, and what to write instead)

## Related

- [Examples library](examples/README.md)
- [Configure Check Sets and Rules](guides/configure-check-sets-and-rules.md)
- [Integration overview](integration/README.md)
- [Metadata reference](metadata/README.md)
