# Reference: Apex scope orchestration (L4)

> [!NOTE]
> On this page, look up the L4 classes that resolve a Check Set or Rule selection and evaluate
> one complete ordered record scope.

This page is part of the [Apex class reference](README.md).

## Scope orchestration (L4)

### `RecordHealthCheckFieldPlanner`

**Role:** Internal field-planning support used by the scope pipeline.
**Type:** Service class · `public with sharing`

Builds the approved set of readable record fields needed by a Rule before
`RecordHealthCheckScopePipeline` performs its scope-wide user-mode load. Public callers use
`RecordHealthCheck.evaluate(request)` and do not call the planner directly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `collectRecordFields(...)` | Plan the record fields needed by a Rule before the scope-wide user-mode load |

**Notable behavior:**
- **Gotcha:** candidate fields are resolved through describe metadata before entering dynamic SOQL;
  malformed, unavailable, and unreadable paths are ignored.

**See also:** [Architecture § How one Rule is evaluated](../framework/architecture.md#6-how-one-rule-is-evaluated)

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
