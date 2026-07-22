# Custom Metadata Types and fields

> [!NOTE]
> **On this page**
>
> Choose the Check Set or Rule field reference and find related documentation for statuses, events, Apex, Flow, and limits.

Record Health Check configuration uses two Custom Metadata Types. The **Record Health Check Set**
controls the card and groups related Rules. The **Record Health Check Rule** defines one question
inside that card.

Use Setup labels while configuring records in **Setup → Custom Metadata Types**. Use API names in
metadata XML, Apex, automation, and generated configuration.

## Choose the field reference

| Plain name | Setup name | API type | Field reference |
| ---------- | ---------- | -------- | --------------- |
| **Check Set** | Record Health Check Set | `Record_Health_Check_Set__mdt` | [Check Set fields](fields-check-set.md) |
| **Rule** | Record Health Check Rule | `Record_Health_Check_Rule__mdt` | [Rule fields](fields-rule.md) |

## Choose a Platform Event reference

The Framework also defines three high-volume Salesforce Platform Events. Each event has a different
publication contract and security profile.

| Setup name | API name | Field reference | Purpose |
| --- | --- | --- | --- |
| Record Health Check Set Run | `Record_Health_Check_Set_Run__e` | [Check Set Run Platform Event](event-set-run.md) | One after-commit summary for a deliberate Check Set run |
| Record Health Check Rule Result | `Record_Health_Check_Rule_Result__e` | [Rule Result Platform Event](event-rule-result.md) | One after-commit public outcome for an enabled Rule |
| Record Health Check Log | `Record_Health_Check_Log__e` | [Log Platform Event](event-log.md) | Restricted, immediately published Framework `ERROR` diagnostics |

## How these docs fit together

| Document | Role |
| -------- | ---- |
| [Check Set fields](fields-check-set.md) | Every field on the Check Set type |
| [Rule fields](fields-rule.md) | Every field on the Rule type |
| [Reason Codes](../reference/reason-codes.md) | Stable codes for skipped, unable, setup, and error outcomes |
| [Lifecycle-events overview](../integration/lifecycle-events.md) | Publication behavior, source rules, opt-in choices, and subscriber failures |
| [Check Set Run Platform Event](event-set-run.md) | Every field, summary-event possibilities, examples, limits, and subscriber design |
| [Rule Result Platform Event](event-rule-result.md) | Every field, status interpretation, routing possibilities, limits, and subscriber design |
| [Log Platform Event](event-log.md) | Every diagnostic field, security requirements, loop protection, and limitations |
| [Apex API](../integration/apex-api/public-api.md) | Public `runRule` / `runSet` methods |
| [Flow actions](../integration/flow-actions.md) | Packaged Rule and Set Flow actions |
| [Lightning component](../integration/lightning-component.md) | Automatic versus explicit publication behavior |
| [Field limits](../reference/fields-limits.md) | Salesforce storage limits and Framework completed-text limits |
| [Configuration Guide](../guides/configuration-guide.md) | Mental model, walkthroughs, troubleshooting, go-live checklist |
| [Design Specification](../reference/record-health-check-design-spec.md) | Formal runtime contract |

For merge tokens, applicability, and evaluator behavior, see the [Configuration Guide](../guides/configuration-guide.md) and the [design spec](../reference/record-health-check-design-spec.md).

## Related

- [Configuration Guide](../guides/configuration-guide.md): mental model and walkthroughs
- [Design Specification](../reference/record-health-check-design-spec.md): formal runtime contract
- [Upgrading Record Health Check](../installation/04-upgrading.md): breaking-change and rollback guide
- [Examples library](../examples/README.md): practical Rule patterns by Evaluation Type
