# Technical references

> [!NOTE]
> On this page, choose the trusted technical reference for a Framework outcome, field limit, or source-code responsibility and find the related Salesforce configuration contract.

Use these references when you need exact Framework behavior rather than a task walkthrough. For a
guided configuration path, begin with the [documentation home](../README.md) or
[examples library](../examples/README.md).

## Choose a technical reference

| Your question | Reference | What it provides |
| --- | --- | --- |
| Which class, Lightning Web Component, or metadata definition owns this behavior? | [Reference: Architecture](reference-architecture.md) | Full published architecture: principles, layers, runtime, security, limits, and ownership |
| What does each Apex class do? | [Reference: Apex classes](reference-apex-classes.md) | Class-by-class guide: purpose, key members, and layer ownership |
| Why was a value rejected or completed text returned `UNABLE_TO_EVALUATE`? | [Reference: Field limits](reference-fields-limits.md) | Salesforce storage limits, Framework resolved limits, and remedies |
| Which merge-token namespaces, surfaces, and limits apply? | [Reference: Merge tokens](reference-merge-tokens.md) | Strict syntax, availability, fallback behavior, and limits |
| How are Found and Expected values formatted on the card? | [Reference: Display value format](reference-display-value-format.md) | Display: Value Format choices, plus blank, number, currency, Boolean, date, multi-select, and list preview formatting |
| What does this stable result code mean? | [Reference: Reason Codes](reference-reason-codes.md) | Status meanings and the first useful investigation for each code |

## Choose an Evaluation Type reference

Use these references when you know the Rule's Evaluation Type and need its complete setup contract,
operators, outcomes, limits, security behavior, or failure paths.

| Evaluation Type | Use it when the Rule needs to… | Complete reference |
| --- | --- | --- |
| **Verify with a formula** | Evaluate fields on the current record or a reachable parent record | [Reference: Formula](reference-formula.md) |
| **Verify with a query** | Evaluate related Salesforce records through one SOQL source | [Reference: Query](reference-query.md) |
| **Compare two queries** | Compare two independent SOQL results as counts, values, or lists | [Reference: Compare two queries](reference-compare-two-queries.md) |
| **Verify with Apex** | Run custom logic that Formula and Query Rules cannot express clearly | [Reference: Apex](reference-apex.md) |

## Other reference families

| Information you need | Reference family |
| --- | --- |
| Check Set and Rule Custom Metadata fields | [Metadata field references](../metadata/README.md) |
| Platform Event fields and subscriber possibilities | [Platform Event references](../metadata/README.md#choose-a-platform-event-reference) |
| Public Apex methods and response classes | [Reference: Apex API](../reference/reference-apex-api.md) |
| Every production Apex class and its responsibility | [Reference: Apex classes](reference-apex-classes.md) |

## Related

- [Documentation home](../README.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
- [Examples library](../examples/README.md)
- [Integration overview](../integration/README.md)
