# Record Health Check documentation — V2 (current)

These pages describe the **current V2** metadata contract, setup vocabulary, programmatic façade, Flow action, lifecycle events, and extension surfaces. Prefer this tree for all new work.

Migrating from v1.x? Start with [Upgrading to V2](installation/upgrading-to-v2.md).

## Start here

- [Quick Start](quick-start.md)
- [First 10 Minutes](start/first-10-minutes.md)
- [Admin Quick Start](installation/admin-quick-start.md)
- [Getting Started](installation/getting-started.md)
- [What changed in V2](installation/upgrading-to-v2.md)
- [Diagnostics and troubleshooting](guides/show-diagnostics.md)
- [Install in a sandbox](installation/sandbox.md)
- [Upgrading to V2](installation/upgrading-to-v2.md)

## Configure

- [Configuration Guide](guides/configuration-guide.md)
- [Action Links](guides/action-links.md)
- [Configure with AI](guides/llm-configuration.md)
- [Show Diagnostics](guides/show-diagnostics.md)
- [CLI commands](guides/cli-commands.md)

## Integrate

- [Integration overview](integrate/overview.md)
- [Documentation standard](api-documentation-standard.md)
- [Apex API](apex/public-api.md)
- [Flow actions](flow/actions.md)
- [Lightning component runs and events](lwc/runs-and-events.md)
- [Platform events](reference/lifecycle-events.md)
- [Reason codes](reference/reason-codes.md)
- [Check type examples and references](checks/README.md)
- [Apex example](apex/apex-example.md)
- [Apex reference](apex/apex-reference.md)

## Reference

- [Metadata reference](metadata/index.md)
- [Check Set fields](metadata/check-set.md)
- [Rule fields](metadata/rule-fields.md)
- [Field size registry](reference/field-size-registry.md)
- [Architecture map](reference/architecture-map.md)
- [Design Specification](reference/record-health-check-design-spec.md)

## V2 contract highlights

- Field API names and picklist values follow the [V2 migration map](reference/field-migration-before-after.md).
- Failure severity uses **Critical / Warning / Info** (`CRITICAL` / `WARNING` / `INFO`). There is no Error severity; unexpected problems use the separate `ERROR` result status.
- Tokens use namespaced `{!record.FieldApiName}` syntax.
- Public façade: `RecordHealthCheck.runRule` / `runSet` (stable sync contract `1.0`) and separate packaged Rule and Set Flow actions.
- Opt-in lifecycle events (contract `1.0`, Publish After Commit); automatic page-load runs never
  publish, while explicit Run/Rerun can publish when enabled.

## Documentation contract

V2 pages follow the [documentation standard](api-documentation-standard.md): progressive
disclosure, task-oriented examples, exact Salesforce vocabulary, canonical references, stable
navigation, and—for public integrations—complete access, error, version, and deprecation guidance.
