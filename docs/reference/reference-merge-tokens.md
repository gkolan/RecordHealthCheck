# Reference: Merge tokens

Merge tokens insert record, Rule, Check Set, result, or run data into Framework-authored display
text and action URLs. Use strict namespaced syntax:

```text
{!record.Name|Unnamed record}
{!rhcRule.checkTitle|Health check}
{!rhcSet.cardTitle|Record health}
{!rhcResult.foundValue|No value}
{!rhcRun.runId|No run id}
```

## Namespaces and availability

| Namespace | Source | Typical properties |
| --- | --- | --- |
| `record` | Current Salesforce record | Field API paths such as `Name` or `Parent.Name` |
| `rhcRule` | Current Rule metadata | `developerName`, `checkTitle`, `category`, `failureSeverity` |
| `rhcSet` | Current Check Set metadata | `developerName`, `cardTitle`, `objectApiName` |
| `rhcResult` | Finalized Rule result | `status`, `foundValue`, `expectedValue`, `reasonCode` |
| `rhcRun` | Current run context | `runId`, `source`, `startedAt`, `completedAt`, `durationMs` |

Not every namespace is available on every surface. Record-query templates allow only record-field
tokens. Display text can use the registered namespaces when that data exists in the current phase;
action URLs URL-encode each inserted value before the final URL allowed list runs.

Use `{!namespace.property|fallback text}` when a supported token may resolve to blank. Unknown
namespaces and properties are configuration errors; the Framework does not silently accept legacy
flat-token syntax.

## Limits

- One template can contain at most 100 tokens. Exceeding this returns
  `TOKEN_LIMIT_EXCEEDED`.
- Completed text can contain at most 20,000 characters. Exceeding this returns
  `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`.
- Action URLs can contain at most 2,000 characters and must be a same-org relative path or use
  `https://`. Unsafe links are suppressed while Fix Message guidance remains available.
- Record relationship paths can traverse at most five parent relationships.

## Related

- [Field limits](reference-fields-limits.md)
- [Reason Codes](reference-reason-codes.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
