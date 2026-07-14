# Record Health Check documentation — V2 (current)

These pages describe the **current V2** metadata contract, setup vocabulary, programmatic façade, Flow action, lifecycle events, and extension surfaces. Prefer this tree for all new work.

Migrating from v1.x? Start with [Upgrading to V2](installation/upgrading-to-v2.md). Historical v1.x pages live under [docs/v1](../v1/).

## Start here

- [Quick Start](quick-start.md)
- [First 10 Minutes](start/first-10-minutes.md)
- [Admin Quick Start](installation/admin-quick-start.md)
- [Getting Started](installation/getting-started.md)
- [What changed in V2](https://github.com/gkolan/RecordHealthCheck/wiki/What-Is-New-in-V2)
- [Troubleshooting](https://github.com/gkolan/RecordHealthCheck/wiki/Troubleshooting)
- [Install in a sandbox](installation/sandbox.md)
- [Upgrading to V2](installation/upgrading-to-v2.md)

## Configure

- [Configuration Guide](guides/configuration-guide.md)
- [Action Links](guides/action-links.md)
- [Configure with AI](guides/llm-configuration.md)
- [Show Diagnostics](guides/show-diagnostics.md)
- [CLI commands](guides/cli-commands.md)

## Integrate

- [Programmatic API and Flow](apex/programmatic-api.md)
- [Lifecycle events](reference/lifecycle-events.md)
- [Reason codes](reference/reason-codes.md)
- [Apex plugin contract](apex/plugin-contract.md)
- [Apex plugin reference](apex/plugin-reference.md)

## Reference

- [Metadata reference](metadata/index.md)
- [Check Set fields](metadata/check-set.md)
- [Rule fields](metadata/rule-fields.md)
- [Field size registry](reference/field-size-registry.md)
- [Architecture map](reference/architecture-map.md)
- [Design Specification](reference/record-health-check-design-spec.md)

## V2 contract highlights

- Field API names and picklist values follow the V2 migration map (`releases/v2/field-migration-before-after.md`).
- Failure severity uses **Critical / Warning / Info** (`CRITICAL` / `WARNING` / `INFO`). There is no Error severity; unexpected problems use the separate `ERROR` result status.
- Tokens use namespaced `{!record.FieldApiName}` syntax.
- Public façade: `RecordHealthCheck.run` / `runSet` (sync contract `0.1`) and packaged Flow action **Run Record Health Check**.
- Opt-in lifecycle events (contract `1.0`, Publish After Commit); page-load card runs never publish.
