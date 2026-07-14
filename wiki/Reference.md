# Reference

Use these pages when you need exact field names, limits, Apex methods, or platform event fields.

## Custom Metadata reference

- [Metadata reference](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/metadata/index.md) — every Check Set and Rule field
- [Field size registry](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/field-size-registry.md) — storage type, limits, and truncation behavior for all 53 fields _(generated)_
- [Reason codes](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/reason-codes.md) — stable codes explaining skipped and unable-to-check outcomes

## Apex, Flow, and platform events

- [Apex API and Flow](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/apex/programmatic-api.md) — public `RecordHealthCheck` methods and the Flow action
- [Lifecycle events](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/lifecycle-events.md) — platform event fields, publishing behavior, and subscriber guidance
- [Custom Apex check interface](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/apex/plugin-contract.md) — the `RecordHealthCheckRule` interface

## Behavior and design

- [Design specification](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/record-health-check-design-spec.md) — detailed behavior, boundaries, and limitations
- [Architecture map](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/architecture-map.md) — how the pieces fit
- [V2 release plan](https://github.com/gkolan/RecordHealthCheck/blob/main/releases/v2/V2-RELEASE-PLAN.md) — the canonical V2 design decisions and extension architecture

## Moving from v1.x

- [Upgrading to V2](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/installation/upgrading-to-v2.md) — field renames, defaults, and the breaking-change summary

## Troubleshooting

- **[[Troubleshooting]]** — start with the symptom shown on the card
- [Show Diagnostics](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/guides/show-diagnostics.md) — the authorized troubleshooting overlay
- [Configuration Guide](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/guides/configuration-guide.md) — field-by-field setup and troubleshooting
