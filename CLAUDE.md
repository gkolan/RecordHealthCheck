# RecordHealthCheck: instructions for Claude

Project-wide guidance for Claude Code sessions in this repo. The V2 release workspace has its
own rules in [`releases/v2/CLAUDE.md`](releases/v2/CLAUDE.md); read that when working under
`releases/v2/`.

## Salesforce skills

The complete official `forcedotcom/sf-skills` catalog is installed globally. Before starting a
Salesforce task, inspect the available skills and use every skill that materially applies. Read each
selected `SKILL.md` completely before acting.

For this repository, prefer the Apex generation, Apex testing, Apex log, metadata context,
metadata deployment, permission set, Lightning Web Component, SLDS, code analyzer, org management,
SOQL, Flow, eventing, and Salesforce documentation skills when their actions match the request. Use
multiple relevant skills in sequence when they cover different parts of the work. Do not add an
unrelated product-area skill merely to increase the number used.

Shared skill selection guidance and the names of the most relevant skills are in [`AGENTS.md`](AGENTS.md).

## Documentation and comments: plain technical language

When writing or editing docs, ApexDoc, or code comments, follow
[`docs/development/documentation-standard.md`](docs/development/documentation-standard.md),
especially
[Prefer plain technical language](docs/development/documentation-standard.md#prefer-plain-technical-language-avoid-cs-jargon).
Use
[`docs/development/salesforce-naming-and-metadata-writing-standard.md`](docs/development/salesforce-naming-and-metadata-writing-standard.md)
for new Apex names, labels, API names, descriptions, help text, and stored values.

- Prefer everyday technical words over CS shorthand (`DTO`, `emit`, `coerce`, `fail closed`,
  `opt-in`, `payload`, `canonical`, …).
- Leave Setup labels, shipped field Description/help text, user-facing runtime messages, and code
  identifiers unchanged.
- Write as a peer: prefer “Use X” / how the product works over imperative “Do not invent…”
  prohibitions in guides and references.
- Admin English such as “Billing City is populated” (meaning the field has a value) is fine.

## Salesforce CLI access

Salesforce CLI commands require network access and access to the local credential store. When an
agent sandbox blocks either one, use that agent's approved elevated execution mode. Keep org aliases,
instance domains, usernames, and other environment-specific values out of repository instructions.
Scratch orgs expire; confirm an alias is active before treating an authentication failure as a
product failure.
