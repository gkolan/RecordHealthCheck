# Explore the Examples

Core ships **one** hero Check Set (`Example_Account_360_Health_Check`) so the card works right
after install. Every other ready-made scenario lives in the separate
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples) repository
as an independently installable **pack**. That is intentional for V2: Core stays the product;
Examples teaches patterns you add only when you need them.

## Two ways to learn

| Need                                          | Go here                                                                                                                                                                                                            |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Deploy a ready-made Check Set                 | A **pack** under [`packs/`](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs) — start with the [install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md) |
| Copy one Rule pattern into your own Check Set | The [pattern library](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md) (formula, SOQL, Apex walkthroughs)                                                             |

## Deployable packs

Browse the generated catalog —
[by outcome](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/catalog/by-outcome.md),
[by Evaluation Type](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/catalog/by-mechanism.md),
or [by cloud](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/catalog/by-cloud.md) —
or pick from this list:

| Pack                                                                                                                                            | What it demonstrates                               | Status     |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | ---------- |
| [Account Data Quality](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/account-data-quality)                               | Completeness checks on core Account fields         | Deployable |
| [Account Everyday Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/account-everyday-readiness)                   | Day-to-day "is this account in good shape?" checks | Deployable |
| [Account Relationships](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/account-relationships)                             | Checks across contacts, opportunities, and cases   | Deployable |
| [Opportunity Sales Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/opportunity-sales-readiness)                 | Opportunity pipeline readiness patterns            | Deployable |
| [Case Service Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/case-service-readiness)                           | Case intake and service readiness patterns         | Deployable |
| [Apex Advanced Checks](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/apex-advanced-checks)                               | Custom Apex evaluation (scoring, approvals)        | Deployable |
| [Grantmaking Application Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/grantmaking-application-readiness)     | Nonprofit / grantmaking eligibility scenarios      | Docs pack  |
| [Financial Services Client Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/financial-services-client-readiness) | Financial Services Cloud client scenarios          | Docs pack  |
| [CPQ Quote Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/cpq-quote-readiness)                                 | Salesforce CPQ Quote readiness scenarios           | Docs pack  |
| [CPQ Quote Line Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/cpq-quote-line-readiness)                       | Salesforce CPQ Quote Line scenarios                | Docs pack  |
| [Advanced Approvals Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/advanced-approvals-readiness)               | Advanced Approvals scenarios                       | Docs pack  |
| [Revenue Cloud Transaction Readiness](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/packs/revenue-cloud-transaction-readiness) | Revenue Cloud Quote / Order scenarios              | Docs pack  |

Full pack index with check counts:
[docs/examples-index.md](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md).

**Deployable** packs include Custom Metadata (and Apex when needed). **Docs pack** means the
scenarios are written for you to adapt; they do not yet ship a `force-app` payload.

## Install one pack

1. Install **Core** and the hero Check Set, and assign `Record_Health_Check_User` — see
   **[[Install the Core]]**.
2. Open the [Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md).
3. Deploy **one** pack. Each pack README covers what it checks, what the user sees, prerequisites,
   and how to remove it.

You do not need the whole catalog to get value.

## Adapt it

A pack's Rules are ordinary Custom Metadata. Clone a Rule into your own Check Set, change the
formula or query, and rewrite the failure message for your process. Nothing in a pack is locked.

## Next

- Understand the fields you're editing → **[[Author Checks]]**
- Run a Check Set from Apex or Flow → **[[Integrate]]**
