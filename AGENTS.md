# RecordHealthCheck agent instructions

## Salesforce skills

The official Salesforce skills from `forcedotcom/sf-skills` are installed globally. Before starting
a Salesforce task, inspect the available skills and use every skill that materially applies to the
requested work. Read each selected `SKILL.md` completely before acting.

For work in this repository, prefer these skill groups when relevant:

- Apex implementation and verification: `platform-apex-generate`,
  `platform-apex-test-generate`, `platform-apex-test-run`, and
  `platform-apex-logs-debug`.
- Metadata work: `platform-metadata-api-context-get`, `platform-metadata-retrieve`,
  `platform-metadata-deploy`, `platform-custom-object-generate`,
  `platform-custom-field-generate`, `platform-value-set-generate`, and
  `platform-permission-set-generate`.
- Lightning and SLDS work: `experience-lwc-generate`, `design-systems-slds-apply`,
  `design-systems-slds-validate`, and `design-systems-slds2-migrate`.
- Quality and org work: `dx-code-analyzer-run`, `dx-code-analyzer-configure`, `dx-org-manage`,
  `platform-soql-query`, and `platform-docs-get`.
- Flow, event, and architecture work: `automation-flow-generate`,
  `integration-eventing-cdc-configure`, `integration-eventing-subscription-configure`, and
  `external-diagram-mermaid-generate`.

Use multiple skills in a sensible sequence when they cover different parts of the same task. For
example, an Apex feature can use generation, test generation, test execution, code analysis, and
metadata deployment skills. Do not use a Salesforce skill when its product area or action is
unrelated to the request.

When writing documentation, ApexDoc, comments, labels, API names, descriptions, or help text, follow:

- `docs/development/documentation-standard.md`
- `docs/development/salesforce-naming-and-metadata-writing-standard.md`

## Salesforce CLI network access

Salesforce CLI commands require network access and the macOS credential store. If a sandboxed
command reports `ENOTFOUND`, retry with the tool's approved unsandboxed or escalated execution mode
before treating the result as a Salesforce outage. Set `SF_DISABLE_LOG_FILE=true` and
`SFDX_DISABLE_DNS_CHECK=true` to quiet the CLI and skip its preliminary DNS check.
