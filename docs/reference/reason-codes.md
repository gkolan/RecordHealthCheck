# Record Health Check reason codes

Reason codes explain why a check did not produce a normal pass or fail outcome. Integrations must use the code, never the display message. Codes are additive and use `UPPER_SNAKE_CASE`.

| Code | Status | Visibility | Meaning |
| --- | --- | --- | --- |
| `NOT_APPLICABLE_BY_FORMULA` | `SKIPPED` | Normal | The applicability formula returned false. |
| `NOT_APPLICABLE_BY_COUNT` | `SKIPPED` | Normal | The applicability count condition was not met. |
| `PREREQUISITE_NOT_MET` | `SKIPPED` | Normal | The prerequisite Rule did not pass. |
| `CANNOT_EVALUATE` | `UNABLE_TO_EVALUATE` | Normal | Neutral reason used when disclosing the technical cause is not authorized. |
| `FIELD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only | A required field was inaccessible. |
| `RECORD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only | The record could not be read in user mode. |
| `INVALID_OPERATOR` | `UNABLE_TO_EVALUATE` | Normal | The comparison operator is missing or is not valid for the Rule shape. |

`FIELD_NOT_ACCESSIBLE` and `RECORD_NOT_ACCESSIBLE` never appear as the public `reasonCode`. When authorized diagnostics is active, the specific code is placed in `adminDetail`; otherwise `adminDetail` is null.
