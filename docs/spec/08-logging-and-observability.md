# Logging and Observability

> [!NOTE]
> **Canonical source:** Section numbers and anchors in the [full design specification](../reference/record-health-check-design-spec.md) are stable for cross-links.

## 14. Logging and Observability

All framework log lines flow through `RecordHealthCheckLogger`: the engine, controller, and evaluators never call `System.debug` directly. The sink can be swapped in one place (for example, Nebula Logger) without touching other classes.

### Structured debug log format

```text
[RHC] <LEVEL> <EVENT> | runId=… user=… config=… check=… record=… <sorted key=value fields>
```

| Concept | Behavior |
| ------- | -------- |
| `runId` | Correlation id: one id is reused for an Automatic definition request and its automatic run; manual reruns receive a fresh id. Callers may supply one to `RecordHealthCheck.run`. Control characters and excessive lengths are removed by the logger. |
| `user` | `UserInfo.getUserId()`: authoritative, not client-supplied. |
| Levels | `ERROR`, `WARN`, `INFO`, `DEBUG` (maps to `FINE` in `System.debug`). |

### Client-side diagnostics (Show Troubleshooting Details)

Requires **both** `DebugMode__c` on the Check Set **and** `Record_Health_Check_Debug` on the running user (included in permission set `Record_Health_Check_Admin`). See [Show Troubleshooting Details guide](../guides/debug-mode.md).

When enabled, after a run completes the LWC:

- Renders a compact per-row debug-meta line under each result.
- Shows expandable **Troubleshooting detail** (`adminDetailMessage`) on errors.
- Shows footnote: **Check console (F12) for diagnostics.**
- Logs to the browser console: `[RHC] Health Check run …` with full run JSON and `console.table` of per-check results.

### Comparison provenance (separate from debug)

`actualValueDetail` / `expectedValueDetail` on each result are gated by **`Record_Health_Check_View_Details`** (also in `Record_Health_Check_Admin`). This is independent of `DebugMode__c` and `Record_Health_Check_Debug`. The LWC shows provenance only when the user expands a row's comparison caret.
