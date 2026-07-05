# Record Health Check Examples

Use this page as a library. Start with one core example, then return when a business rule needs a specific pattern.

For first setup, use [Quick Start](../quick-start.md). For field definitions, use [Configuration Guide](../guides/configuration-guide.md).

## Core Examples

These four examples cover the first patterns most admins need.

- Required field: [Formula: single required field](formula/01-single-required-field.md)
- Either/or field: [Formula: either/or field](formula/02-either-or-field.md)
- Related records: [SOQL: at least one Contact](soql/single-query/01-child-count-minimum-one.md)
- Conditional rule: [Formula: type-scoped rule](formula/06-type-scoped.md)

## Example Catalog

### Formula

Use these when the needed values are on the current record or reachable by formula relationship fields.

| Example | Pattern |
| ------- | ------- |
| [01 · Single required field](formula/01-single-required-field.md) | `NOT(ISBLANK(...))` |
| [02 · Either/or field requirement](formula/02-either-or-field.md) | `OR(...)` |
| [03 · Numeric threshold](formula/03-numeric-threshold.md) | Field greater than zero |
| [04 · Multiple required fields](formula/04-multiple-required-and.md) | `AND(...)` |
| [05 · Two fields compared](formula/05-two-fields-compared.md) | Field equality |
| [06 · Type-scoped rule](formula/06-type-scoped.md) | Applicability formula |
| [07 · Parent field traversal](formula/07-parent-field.md) | Parent field check |
| [08 · Found and expected values](formula/08-found-expected-values.md) | User-friendly comparison detail |

### SOQL: Single Query

Use these when one SOQL query returns the value or records to evaluate.

| Example | Pattern |
| ------- | ------- |
| [01 · Child count minimum one](soql/single-query/01-child-count-minimum-one.md) | `COUNT()` > 0 |
| [02 · Child count minimum two](soql/single-query/02-child-count-minimum-two.md) | `COUNT()` >= 2 |
| [03 · Empty result fails](soql/single-query/03-empty-result-fail.md) | No rows = fail |
| [04 · Empty result skips](soql/single-query/04-empty-result-skip.md) | No rows = skip |
| [05 · Any row static threshold](soql/single-query/05-any-row-static-threshold.md) | Any row passes |
| [06 · Any row formula threshold](soql/single-query/06-any-row-formula-threshold.md) | Any row vs record formula |
| [07 · All rows static threshold](soql/single-query/07-all-rows-static-threshold.md) | Every row passes |
| [08 · All rows Account field](soql/single-query/08-all-rows-account-field.md) | Every row vs record field |
| [09 · Contains substring](soql/single-query/09-contains-substring.md) | Text contains |
| [10 · Does not contain](soql/single-query/10-does-not-contain.md) | Text excludes |
| [11 · Is not blank](soql/single-query/11-is-not-blank.md) | Queried field populated |
| [12 · Is blank](soql/single-query/12-is-blank.md) | Queried field empty |
| [13 · Count upper limit](soql/single-query/13-count-upper-limit.md) | Count cap |
| [14 · Not equals rating](soql/single-query/14-not-equals-rating.md) | Scalar not equals |
| [15 · List contains any](soql/single-query/15-list-contains-any.md) | Record value in query list |
| [16 · List does not contain](soql/single-query/16-list-does-not-contain.md) | Record value absent from query list |
| [17 · Count vs second query](soql/single-query/17-count-vs-second-query.md) | Query count vs second query count |

### SOQL: Compare Two Queries

Use these when both sides are SOQL results.

| Example | Pattern |
| ------- | ------- |
| [01 · Aggregate counts](soql/compare-two-queries/01-aggregate-counts.md) | Count vs count |
| [02 · Aggregate vs Account scalar](soql/compare-two-queries/02-aggregate-vs-account-scalar.md) | Aggregate vs field |
| [03 · Scalar fields](soql/compare-two-queries/03-scalar-fields.md) | Query scalar vs query scalar |
| [04 · Lists overlap](soql/compare-two-queries/04-lists-overlap.md) | At least one shared value |
| [05 · List contains all](soql/compare-two-queries/05-list-contains-all.md) | Primary list contained by comparison list |
| [06 · Exact list match](soql/compare-two-queries/06-exact-list-match.md) | Same list values on both sides |

### Apex

Use Apex only when formulas and SOQL would be unclear or cannot express the rule safely.

| Example | Class |
| ------- | ----- |
| [01 · Recent activity](apex/01-recent-activity.md) | `AccountHasRecentActivityCheck` |
| [02 · Open Opportunity health](apex/02-open-opportunity-health.md) | `AccountOpenOpportunityHealthCheck` |
| [03 · Strategic readiness](apex/03-strategic-readiness.md) | `AccountStrategicReadinessCheck` |
| [04 · Inactive approver](apex/04-inactive-approver.md) | `ApprovalInactiveApproverCheck` |

## Sample Check Set Packages

Deploy `manifest/package-core.xml` first, then add only the sample set you want. Deploy `manifest/package.xml` only in a sandbox or demo org when you want everything.

| Check Set | Rules | Start here |
| --------- | ----: | ---------- |
| `Account_Data_Quality` | 4 | [Formula: single required field](formula/01-single-required-field.md) |
| `Account_Everyday_Use_Cases` | 16 | [Formula: single required field](formula/01-single-required-field.md) |
| `Account_Compliance_Audit` | 10 | [SOQL: is not blank](soql/single-query/11-is-not-blank.md) |
| `Account_Relationships` | 4 | [SOQL: child count minimum one](soql/single-query/01-child-count-minimum-one.md) |
| `Account_Formula_Coverage` | 7 | [Formula catalog](#formula) |
| `Account_Query_Coverage` | 17 | [SOQL: is not blank](soql/single-query/11-is-not-blank.md) |
| `Account_Aggregate_Coverage` | 6 | [Aggregate examples](#pattern-reference-aggregates) |
| `Account_AppComp_Coverage` | 6 | [Formula: type-scoped rule](formula/06-type-scoped.md) |
| `Account_Compare_Queries` | 10 | [SOQL: aggregate counts](soql/compare-two-queries/01-aggregate-counts.md) |
| `Account_Advanced_Checks` | 8 | [Apex: recent activity](apex/01-recent-activity.md) |
| `Account_Examples_Formula` | 8 | [Formula catalog](#formula) |
| `Account_Examples_Query` | 17 | [SOQL single-query catalog](#soql-single-query) |
| `Account_Examples_Compare_Two_Queries` | 6 | [SOQL compare-two catalog](#soql-compare-two-queries) |
| `Account_Examples_Apex` | 4 | [Apex catalog](#apex) |
| `Example_Account_360_Health_Check` | 9 | Demo Check Set: deploy `manifest/package-Example_Account_360_Health_Check.xml` |

## Pattern Reference

Use the catalog above for examples. Use the guides below for rules and field details.

- Merge tokens in SOQL: [Configuration Guide: Merge Tokens](../guides/configuration-guide.md#11-merge-tokens)
- Action links and report links: [Action Links and Fix Instructions](../guides/action-links.md)
- Applicability and dependencies: [Configuration Guide: Applicability and Dependencies](../guides/configuration-guide.md#10-applicability-and-dependencies)
- Every Rule field: [Rule fields](../metadata/rule-fields.md)
- Every Check Set field: [Check Set fields](../metadata/check-set.md)
- Apex contract: [Apex plugin contract](../apex/plugin-contract.md)

### Seeing Found / Expected

Found / Expected values are controlled by the Check Set **Found/Expected Display** setting and are shown automatically when the evaluator captures comparison values. Start with [Formula: Found and expected values](formula/08-found-expected-values.md) for display formulas, or use any failing Query example above to see the comparator-derived Found / Expected chips.

### Pattern Reference: Aggregates

Aggregate SOQL examples live in:

- [SOQL: aggregate counts](soql/compare-two-queries/01-aggregate-counts.md)
- [SOQL: aggregate vs Account scalar](soql/compare-two-queries/02-aggregate-vs-account-scalar.md)

Use an alias for aggregate functions other than `COUNT()`, for example `SELECT SUM(Amount) totalPipeline FROM Opportunity ...`, then set the field to read to that alias.
