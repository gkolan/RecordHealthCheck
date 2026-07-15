# Record Health Check quick start

> **V2 current docs.** Upgrading from v1.x? See [Upgrading to V2](installation/upgrading-to-v2.md).

For Salesforce admins seeing Record Health Check for the first time. Start with one working card, then configure one useful Rule.

## First path

1. [First 10 Minutes](start/first-10-minutes.md): install and show one card on an Account page.
2. [Admin Quick Start](installation/admin-quick-start.md): understand Check Sets, Rules, and result statuses.
3. [Create your first Rule](installation/getting-started.md#step-4-create-your-first-rule): add one check and test it on a record.
4. Copy one example below when you need a pattern.
5. Use [Troubleshooting](guides/configuration-guide.md#13-troubleshooting) when setup does not behave as expected.

## Copy one pattern

Ready-made example packs live in the separate
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples) repository.
Install **one** pack, learn the pattern, then adapt it — don't read the whole catalog first.

- Browse packs by outcome: [Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/catalog)
- Start with **Account Data Quality** or **Account Everyday Readiness** for single-field and
  completeness patterns; **Account Relationships** for checks that read across related records.

## Build a good first Check Set

- Keep it to 3-5 checks.
- Keep every failed message actionable.
- Remove checks that are interesting but not useful.
- Add one Rule at a time and test it before adding another.
- Use [Examples](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md) as a library.

## Next steps

- Install details: [Getting Started](installation/getting-started.md)
- Upgrade from v1.x: [Upgrading to V2](installation/upgrading-to-v2.md)
- Every field: [Configuration Guide](guides/configuration-guide.md)
- Metadata fields: [Metadata reference](metadata/index.md)
- Apex callers: [Apex API](apex/public-api.md)
- Flow builders: [Flow actions](flow/actions.md)
- Lightning component behavior: [Lightning component runs](lwc/runs-and-events.md)
- Lifecycle events: [Lifecycle events](reference/lifecycle-events.md)
- Reason codes: [Reason codes](reference/reason-codes.md)
- Field sizes: [Field size registry](reference/field-size-registry.md)
- Custom Apex Rules: [Apex example](apex/apex-example.md) · [Apex reference](apex/apex-reference.md)
- Full behavior contract: [Design Specification](reference/record-health-check-design-spec.md)
