# Record Health Check Quick Start

> **V1 historical docs.** Current product documentation is under [docs/v2](../v2/).

For Salesforce admins seeing Record Health Check for the first time. Start with one working card, then configure one useful Rule.

## First Path

1. [First 10 Minutes](start/first-10-minutes.md): install and show one card on an Account page.
2. [Admin Quick Start](installation/admin-quick-start.md): understand Check Sets, Rules, and result statuses.
3. [Create your first Rule](installation/getting-started.md#step-4-create-your-first-rule): add one check and test it on a record.
4. Copy one example below when you need a pattern.
5. Use [Troubleshooting](guides/configuration-guide.md#13-troubleshooting) when setup does not behave as expected.

## Copy One Pattern

Start with one. Do not read the full catalog first.

- Required field: [Single required field](examples/formula/01-single-required-field.md)
- Either/or field: [Phone or Website required](examples/formula/02-either-or-field.md)
- Related records: [At least one Contact](examples/soql/single-query/01-child-count-minimum-one.md)
- Conditional rule: [Partner-only Billing Country](examples/formula/06-type-scoped.md)

## Build A Good First Check Set

- Keep it to 3-5 checks.
- Keep every failed message actionable.
- Remove checks that are interesting but not useful.
- Add one Rule at a time and test it before adding another.
- Use [Examples](examples/index.md) as a library.

## More Detail

- Install details: [Getting Started](installation/getting-started.md)
- Every field: [Configuration Guide](guides/configuration-guide.md)
- Metadata fields: [Metadata reference](metadata/index.md)
- Custom Apex: [Apex plugin reference](apex/plugin-reference.md)
- Full behavior contract: [Design Specification](reference/record-health-check-design-spec.md)
