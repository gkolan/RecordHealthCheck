# Reference: Reason Codes

> [!NOTE]
> On this page, translate a stable Reason Code into the Framework decision that produced it and the first useful Salesforce configuration, access, query, Formula, Apex, or token check to perform.

Use this registry to translate a stable **Reason Code** into its status, meaning, and first useful
investigation. Reason Codes let administrators and integrations identify causes without interpreting
administrator-authored display messages.

## How to use a Reason Code

| Reader | Use the code to… |
| --- | --- |
| Salesforce administrator | Decide whether to inspect applicability, dependencies, field access, Formula configuration, SOQL, or Apex |
| Flow builder | Route a known non-normal result without treating display text as an API |
| Apex developer | Branch or log using a stable `UPPER_SNAKE_CASE` value |
| Support or release engineer | Correlate the public result with authorized Show Diagnostics and logs |

Reason Codes explain why a Rule did not produce a normal `PASS` or `FAIL`, or why a card could not
load. Codes are additive `UPPER_SNAKE_CASE` strings. Integrations must key on the code, never on
display text.

> [!IMPORTANT]
> **Public vs diagnostics-only:** `FIELD_NOT_ACCESSIBLE` and `RECORD_NOT_ACCESSIBLE` never appear as the public `reasonCode` on a result. The engine remaps them to `CANNOT_EVALUATE`. When **Show Diagnostics** is on and the user has `Record_Health_Check_View_Diagnostics`, the specific code is available on `adminDetail.reasonCode`.

The Framework uses a neutral public code because revealing whether a hidden record or field exists
can disclose Salesforce access information to someone who is not allowed to see it. Authorized
administrators still receive the specific cause through Show Diagnostics, where they can distinguish
a missing record from missing field access without weakening the normal user's security boundary.

Registry helpers for the remapped pair live in `RecordHealthCheckReasonCodes`. Other codes are emitted directly by the engine, evaluators, template service, LWC, or plugins.

---

## Applicability and prerequisites

| Code | Typical status | Meaning |
| --- | --- | --- |
| `NOT_APPLICABLE_BY_FORMULA` | `SKIPPED` | Applicability mode `WHEN_FORMULA_TRUE` returned false. |
| `NOT_APPLICABLE_BY_COUNT` | `SKIPPED` | Applicability count gate was not met. |
| `PREREQUISITE_NOT_MET` | `SKIPPED` | Prerequisite Rule did not return `PASS`. |
| `CIRCULAR_DEPENDENCY` | `UNABLE_TO_EVALUATE` | Prerequisite cycle detected (LWC may pre-seed without calling Apex). |
| `DEPENDENCY_NOT_IN_RUN` | `SKIPPED` | LWC-only: prerequisite was omitted by the 25-Rule run cap. |
| `APPLICABILITY_NOT_MET` | `SKIPPED` | Query empty-result path chose skip via `NoRowsResult__c = SKIP` (distinct from applicability gates above). |
| `VALUE_IS_EMPTY` | `SKIPPED` | Row comparison skipped because a compared field value was empty under `EmptyValueHandling__c = SKIP_RECORD`. |

---

## Access and permissions

| Code | Typical status | Visibility | Meaning |
| --- | --- | --- | --- |
| `CANNOT_EVALUATE` | `UNABLE_TO_EVALUATE` | Public | Neutral substitute when a diagnostics-only access code is remapped. |
| `FIELD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only (remapped publicly) | Required field not readable in user mode. |
| `RECORD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only (remapped publicly) | Record not readable in user mode / missing context. |
| `NO_RECORD_CONTEXT` | `UNABLE_TO_EVALUATE` | Public | Evaluation called without a usable record Id. |

---

## Configuration and identity

| Code | Typical status | Meaning |
| --- | --- | --- |
| `CONFIG_NOT_FOUND` | `UNABLE_TO_EVALUATE` / setup | Check Set DeveloperName not found. |
| `CONFIG_INACTIVE` | `UNABLE_TO_EVALUATE` / setup | Check Set is inactive. |
| `OBJECT_MISMATCH` | `UNABLE_TO_EVALUATE` / setup | Check Set object does not match the record. |
| `RULE_NOT_FOUND` | `UNABLE_TO_EVALUATE` | Rule DeveloperName not found in the Check Set. |
| `RULE_INACTIVE` | `UNABLE_TO_EVALUATE` | Rule is inactive. |
| `INVALID_CHECK_TYPE` | `UNABLE_TO_EVALUATE` | Evaluation Type missing or unrecognized. |
| `INVALID_CONFIG` | definition / unable | Invalid Check Set display or identity configuration. |
| `MISSING_REQUIRED_FIELD` | validation | A required Check Set or Rule field (e.g. Base Object API Name, Card Title) is blank (deploy/CI validator). |
| `CHECK_LIMIT_EXCEEDED` | definition / validation | More than 25 active Rules selected for a run (runtime omit + validator). |
| `INVALID_DEPENDENCY` | validation | Prerequisite metadata is invalid (deploy/CI validator). |

---

## Query and comparison

| Code | Typical status | Meaning |
| --- | --- | --- |
| `INVALID_SOQL_TEMPLATE` | `UNABLE_TO_EVALUATE` | SOQL template failed safety or parse checks. |
| `INVALID_OPERATOR` | `UNABLE_TO_EVALUATE` | Comparison operator missing or illegal for this Rule shape. |
| `INCOMPATIBLE_COMPARISON_TYPES` | `UNABLE_TO_EVALUATE` | Ordered comparison cannot coerce the two sides safely. |
| `MULTIPLE_ROWS_RETURNED` | `UNABLE_TO_EVALUATE` | `ONE_RESULT` expected one row/aggregate but got more. |
| `NO_ROWS_RETURNED` | `UNABLE_TO_EVALUATE` | Empty result handled as unable (`NoRowsResult__c = UNABLE_TO_EVALUATE`). |
| `MISSING_BIND_VALUE` | `UNABLE_TO_EVALUATE` | Merge token required for SOQL bind could not be resolved. |
| `GOVERNOR_LIMIT_RISK` | `UNABLE_TO_EVALUATE` | The Framework stopped before the query could consume an unsafe share of the transaction's remaining Salesforce limits. Reduce the Rule's row cap or narrow its SOQL. |

---

## Formula

| Code | Typical status | Meaning |
| --- | --- | --- |
| `INVALID_FORMULA` | `UNABLE_TO_EVALUATE` | Formula failed to compile/evaluate or returned a non-boolean where required. |
| `FORMULA_EVAL_LIMIT` | `UNABLE_TO_EVALUATE` | The Framework stopped before the transaction reached Salesforce's hard formula-evaluation limit, preserving a controlled result instead of risking an uncatchable transaction failure. Reduce the Rules evaluated together. |

---

## Apex plugins

| Code | Typical status | Meaning |
| --- | --- | --- |
| `APEX_CLASS_NOT_FOUND` | `UNABLE_TO_EVALUATE` | `ApexClass__c` could not be resolved to a `RecordHealthCheckRule`. |
| `INVALID_APEX_PARAMETERS` | `UNABLE_TO_EVALUATE` | `ApexParametersJson__c` is not valid JSON object input. |
| `APEX_EVALUATOR_ERROR` | `ERROR` / `UNABLE_TO_EVALUATE` | Plugin threw, returned an illegal status, or omitted required Found/Expected on `PASS`/`FAIL`. |
| `OBJECT_NOT_FOUND` | plugin-defined | Example plugins may emit domain-specific codes such as this. |

---

## Tokens and message templates

| Code | Typical status | Meaning |
| --- | --- | --- |
| `LEGACY_FLAT_TOKEN` | `UNABLE_TO_EVALUATE` | Legacy `{!Id\|not available}`-style token rejected under strict namespaced syntax. <!-- legacy-token-ok --> |
| `UNSUPPORTED_TOKEN_NAMESPACE` | `UNABLE_TO_EVALUATE` | Token namespace is not allowlisted. |
| `UNKNOWN_TOKEN_PROPERTY` | `UNABLE_TO_EVALUATE` | Token property path is not recognized. |
| `TOKEN_NOT_ALLOWED_ON_SURFACE` | `UNABLE_TO_EVALUATE` | Token used on a message/query surface that forbids it. |
| `TOKEN_NOT_AVAILABLE_IN_PHASE` | `UNABLE_TO_EVALUATE` | Token requires data not available in this resolution phase. |
| `MALFORMED_TOKEN` | `UNABLE_TO_EVALUATE` | Token syntax is malformed. |
| `TOKEN_LIMIT_EXCEEDED` | `UNABLE_TO_EVALUATE` | One template contains more than 100 merge tokens. Split or simplify it so one message cannot create disproportionate field discovery and resolution work. |
| `RESOLVED_TEMPLATE_TOO_LONG` | `UNABLE_TO_EVALUATE` | Completed text exceeded 20,000 characters. Shorten the template or inserted Salesforce values; the Framework does not return truncated guidance. |

---

## Card setup / load (LWC and definition response)

These often appear on the card chrome rather than a single Rule row:

| Code | Meaning |
| --- | --- |
| `SETUP_REQUIRED` | No Check Set selected, or availability probe fell back to setup guidance. |
| `NO_ACTIVE_CHECK_SETS` | No Check Sets exist for the page object. |
| `INACTIVE_CHECK_SETS_ONLY` | Check Sets exist but none are active. |
| `NO_ACTIVE_CHECKS` | Selected Check Set has no active Rules. |
| `LOAD_FAILED` | Definition load failed without a more specific reason. |

---

## Consumer guidance

1. Branch automation on `status` first, then `reasonCode`.
2. Treat unknown future codes as additive: do not reject a code just because you have not seen it before, unless you maintain an intentionally strict allowlist.
3. Never show diagnostics-only codes to unauthorized users; trust the remapped public `reasonCode`.
4. Log lines may mention events such as `DEPENDENCY_NOT_PASSED`; that is a **log event name**, not the public Rule `reasonCode` (`PREREQUISITE_NOT_MET` is).

## Related

- [Apex API](../reference/reference-apex-api.md)
- [Flow actions](../integration/flow-actions.md)
- [Lifecycle events](../integration/lifecycle-events.md)
- [Troubleshoot with Show Diagnostics](../guides/troubleshoot-with-show-diagnostics.md)
- [Architecture map](reference-architecture-map.md)
