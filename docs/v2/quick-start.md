# Record Health Check Quick Start

> **V2 current docs.** Historical v1.x pages are under [docs/v1](../v1/). Upgrading? See [Upgrading to V2](installation/upgrading-to-v2.md).

For Salesforce admins seeing Record Health Check for the first time. Start with one working card, then configure one useful Rule.

## First Path

1. [First 10 Minutes](start/first-10-minutes.md): install and show one card on an Account page.
2. [Admin Quick Start](installation/admin-quick-start.md): understand Check Sets, Rules, and result statuses.
3. [Create your first Rule](installation/getting-started.md#step-4-create-your-first-rule): add one check and test it on a record.
4. Copy one example below when you need a pattern.
5. Use [Troubleshooting](guides/configuration-guide.md#13-troubleshooting) when setup does not behave as expected.

## Copy One Pattern

Ready-made example packs live in the separate
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples) repository.
Install **one** pack, learn the pattern, then adapt it — don't read the whole catalog first.

- Browse packs by outcome: [Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/catalog)
- Start with **Account Data Quality** or **Account Everyday Readiness** for single-field and
  completeness patterns; **Account Relationships** for checks that read across related records.

## Build A Good First Check Set

- Keep it to 3-5 checks.
- Keep every failed message actionable.
- Remove checks that are interesting but not useful.
- Add one Rule at a time and test it before adding another.
- Use [Examples](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md) as a library.

## More Detail

- Install details: [Getting Started](installation/getting-started.md)
- Upgrade from v1.x: [Upgrading to V2](installation/upgrading-to-v2.md)
- Every field: [Configuration Guide](guides/configuration-guide.md)
- Metadata fields: [Metadata reference](metadata/index.md)
- Apex or Flow callers: [Programmatic API and Flow](apex/programmatic-api.md)
- Lifecycle events: [Lifecycle events](reference/lifecycle-events.md)
- Reason codes: [Reason codes](reference/reason-codes.md)
- Field sizes: [Field size registry](reference/field-size-registry.md)
- Custom Apex plugins: [Apex plugin reference](apex/plugin-reference.md)
- Full behavior contract: [Design Specification](reference/record-health-check-design-spec.md)
