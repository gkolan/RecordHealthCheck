# Apex API

> [!NOTE]
> Use this page to build requests for the synchronous Record Health Check Apex entry
> point. A request selects one qualified Check Set or Rule and supplies the complete record scope.

## Basic Apex pattern

Evaluate a Check Set for several records:

```apex
RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
  'Account_Data_Quality',
  accountIds
).withRunId('nightly-' + Date.today());

RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
Set<Id> recordsNeedingAttention = new Set<Id>();
for (RecordHealthCheckResultItem item : response.results) {
  if (item.evaluation.status == RecordHealthCheckStatus.FAIL) {
    recordsNeedingAttention.add(item.recordId);
  }
}
```

The example collects business failures for the caller to handle. In production, pass that set to
the approved notification, persistence, or orchestration service for your use case. Do not write
record details to a debug log.

Evaluate one Rule by its Custom Metadata `QualifiedApiName`:

```apex
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forRule('Customer_Contact_Required', accountId)
);
```

In a namespaced install, use the identity Salesforce returns, such as
`rhc__Customer_Contact_Required`. Subscriber-owned records remain unprefixed.

## Request contract

`RecordHealthCheckRequest` requires exactly one selection and a non-null list of record
IDs. The factories are:

| Factory | Selection |
| --- | --- |
| `forCheckSet(qualifiedApiName, recordId)` | One Check Set and one record |
| `forCheckSet(qualifiedApiName, recordIds)` | One Check Set and a record scope |
| `forRule(qualifiedApiName, recordId)` | One Rule and one record |
| `forRule(qualifiedApiName, recordIds)` | One Rule and a record scope |

Options are applied with fluent methods:

| Method | Default | Purpose |
| --- | --- | --- |
| `withResultMode(...)` | `EVALUATION` | Choose machine results only or evaluation plus display data |
| `withEventPublication(...)` | `NONE` | Choose `NONE`, `ACTIONABLE`, or `ALL` publication |
| `withRunId(...)` | Generated when blank | Supply caller correlation |
| `withExecutionOrigin(...)` | `APEX_API` | Attribute published events to Apex, Batch, Queueable, Scheduled, Future, Agent, or a Record Health Check adapter |

Programmatic evaluation publishes nothing unless the caller explicitly selects a
publication mode. Metadata fields still decide whether a user-requested event is enabled.
Execution origin is caller-supplied attribution, not a security assertion. Record Health Check Flow
and LWC adapters set their own origin automatically.

## Response contract

Every call returns `RecordHealthCheckResponse` with:

| Field | Meaning |
| --- | --- |
| `runId` | Correlation ID for this evaluation |
| `recordIds` | Normalized record scope |
| `ruleQualifiedApiNames` | Ordered Rules selected for the run |
| `results` | Ordered `RecordHealthCheckResultItem` entries |
| `summary` | Counts and aggregate run status |

Each item always has `evaluation`. It has `display` only when the request uses
`EVALUATION_WITH_DISPLAY`. Machine values use `RecordHealthCheckValue`, so callers do not
receive untyped `Object` values.

## Publish lifecycle events

Requests do not publish lifecycle events unless you enable publication. Add
`withEventPublication(RecordHealthCheckEventPublication.ACTIONABLE)` to publish actionable results,
or use `ALL` when an integration needs every result.

## Limits and access

- One request accepts at most `RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE` records.
- Query, compare-query, and conforming Apex Rules run once for the complete scope.
- Formula Rules use one platform Formula evaluation per expression and record, so the
  request planner may require a smaller scope.
- Record and query access runs in user mode. Subscriber Apex plugins must enforce
  their own user-mode access and should extend `RecordHealthCheckRuleContractTest`.
- `MaxQueryRows__c` is a per-scope budget.

## Flow adapters

The Rule and Check Set Flow actions are thin adapters over the same request API. Their
publication input defaults to `NONE`; set it explicitly when the Flow is intended to
publish lifecycle events.

## Related

- [API examples](README.md)
- [Apex plugin contract](../reference/reference-apex.md)
- [Apex class catalog](../reference/reference-apex-classes.md)
- [Flow API](flow.md)
- [Upgrade guide](../installation/04-upgrading.md)
