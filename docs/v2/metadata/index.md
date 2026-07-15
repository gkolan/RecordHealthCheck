# Custom Metadata Types and fields

Field reference for the two Custom Metadata Types that hold Record Health Check configuration. Setup
labels are what appear in the metadata editor; API names are what metadata XML, Apex, and the LLM
guide use.

| Plain name | Setup name | API type | Field reference |
| ---------- | ---------- | -------- | --------------- |
| **Check Set** | Record Health Check Set | `Record_Health_Check_Set__mdt` | [Check Set fields](check-set.md) |
| **Rule** | Record Health Check Rule | `Record_Health_Check_Rule__mdt` | [Rule fields](rule-fields.md) |

## How these docs fit together

| Document | Role |
| -------- | ---- |
| [Check Set fields](check-set.md) | Every field on the Check Set type |
| [Rule fields](rule-fields.md) | Every field on the Rule type |
| [Reason codes](../reference/reason-codes.md) | Stable codes for skipped, unable, setup, and error outcomes |
| [Platform events](../reference/lifecycle-events.md) | Opt-in Rule Result and Check Set Run events |
| [Apex API](../apex/public-api.md) | Public `runRule` / `runSet` methods |
| [Flow actions](../flow/actions.md) | Packaged Rule and Set Flow actions |
| [Lightning component runs](../lwc/runs-and-events.md) | Automatic versus explicit publication behavior |
| [Field size registry](../reference/field-size-registry.md) | Authoritative stored/runtime size limits |
| [Configuration Guide](../guides/configuration-guide.md) | Mental model, walkthroughs, troubleshooting, go-live checklist |
| [Design Specification](../reference/record-health-check-design-spec.md) | Formal runtime contract |

For merge tokens, applicability, and evaluator semantics, see the [Configuration Guide](../guides/configuration-guide.md) and the [design spec](../reference/record-health-check-design-spec.md).

## Related

- [Configuration Guide](../guides/configuration-guide.md): mental model and walkthroughs
- [Design Specification](../reference/record-health-check-design-spec.md): formal runtime contract
- [Upgrading to V2](../installation/upgrading-to-v2.md): breaking-change and rollback guide
- Example packs: [RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples)
