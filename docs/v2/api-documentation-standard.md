# V2 documentation standard

Use this standard across the V2 documentation tree. It adapts the recurring practices identified in
[DreamFactory's API documentation examples](https://blog.dreamfactory.com/8-api-documentation-examples)
to Salesforce-native APIs and applies progressive disclosure to administrator, installation, and
reference pages.

## Standards for every page

- Begin Example pages with one native GitHub **Note** containing two labeled sections:
  **In one line** states what the page helps the reader accomplish, and **Reference** identifies the
  example's scope and deeper canonical companion.
- Put the shortest successful path before exhaustive detail. Link prerequisites before the first
  task when they cannot fit on the page.
- Keep one idea per paragraph, normally in one or two sentences. Split procedures into numbered
  steps and split independent facts into labeled bullets.
- Remove lead-ins that merely announce the heading, table, code block, or number of items that
  immediately follows. Do not explain facts already evident from names or examples.
- Use exact Setup labels for people and exact API names in code, tables, and automation contracts.
- Keep one canonical source for each fact. Link to it instead of copying long field, reason-code, or
  event definitions into several guides.
- Distinguish `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, `ERROR`, and a thrown fault. Do not use
  “error” as a catch-all for access or configuration outcomes.
- End task pages with **Next steps** and reference pages with **Related** or **See also** links.
- Use sentence-case headings, concise paragraphs, accessible link text, fenced code with a language,
  and tables only when readers need to compare repeated fields.

### Table readability

- Use prose or bullets when rows do not compare the same attributes. Do not turn a paragraph into a
  one-row table.
- Keep useful comparison tables. Fix column sizing or horizontal overflow instead of replacing a
  table solely because identifiers wrap.
- Put the API-name column near the left and wrap every literal API name in backticks so it remains
  visually distinct and copyable.
- In example configuration tables, link every field API name to its canonical Rule or Check Set
  metadata reference section, where readers can review requirements and allowed values.
- Put **Notes**, **Description**, **Meaning**, **Purpose**, **Behavior**, or similar explanation in
  the final column. That column must not use more than 50% of the rendered table width.
- Prefer four or fewer columns. Use five or six only for dense canonical registries where removing a
  column would hide type, required/default, size, or runtime-contract information.
- Move long examples, exceptions, and corrective actions below the table when they are specific to
  only one row.
- Do not surround a table with prose that repeats its heading, rows, or conclusion.
- Include a corrective action only when it adds a non-obvious diagnostic step, location, or
  decision. Prefer **What to investigate** when “corrective action” would restate the failure.
- Never shorten, insert spaces into, or split an API name to make a table fit. Published tables keep
  inline code on one line and scroll horizontally on narrow screens.

## Requirements by page type

| Page type | Required content |
| --- | --- |
| Quick start / installation | Prerequisites, numbered working path, expected result, common failures, next steps |
| Guide | Outcome, safe examples, constraints, review or troubleshooting guidance, related references |
| API / integration | Fast start, operations and schemas, access, limits, errors with remedies, version/deprecation policy |
| Metadata reference | Exact API name, type or allowed values, defaults, runtime effect, canonical related guides |
| Architecture / design | Scope, authoritative contracts, diagrams or mappings only when useful, limitations, related task pages |

Every Custom Metadata field reference must give each field its own anchored section containing the
Setup label, API name, type and capacity, required status, default, shipped description, inline help
text, allowed values, dependencies or conditional use, and realistic examples where they add
information. Checkbox and picklist fields do not repeat their allowed values as examples. Picklist
allowed values and defaults show both the Setup label and stored API value.

Descriptions and help text use short paragraphs by default. Use bullets only for genuine choices,
independent requirements, or procedures; do not turn every sentence into a bullet.

## Required on every API page

- **Fast start:** provide a working first call or configuration that a reader can complete in about
  five minutes. Keep prerequisites on the same page or link them immediately before the example.
- **Complete reference:** document every public operation, input, output, allowed value, limit, and
  relevant transaction behavior. Use stable headings and direct links from this V2 index.
- **Copy-ready examples:** include the request and the returned shape or decision pattern. Apex APIs
  use Apex examples; Flow APIs use numbered builder steps; events include subscriber and payload
  guidance.
- **Access requirements:** state the execution user, sharing behavior, record and field access, and
  any permission set or custom permission that changes the returned detail.
- **Errors and outcomes:** distinguish returned business outcomes from thrown faults. For each
  documented fault, provide useful investigation guidance; omit obvious restatements.
- **Versioning:** state the contract version, compatibility promise, deprecation process, and any
  separate product or event version.
- **Human- and automation-readable names:** use exact API names, meaningful field names, explicit
  types, stable status/reason values, and concrete descriptions. Never require automation to parse
  display text.
- **Related navigation:** end with links to the integration overview and the canonical references for
  statuses, reason codes, configuration, and events.

## Salesforce equivalents for web-API practices

| General API documentation practice | Record Health Check implementation |
| --- | --- |
| Runnable browser console | Copy-ready Anonymous Apex plus sandbox instructions; Flow builder steps for invocable actions |
| Endpoint and schema reference | Apex signatures, Flow input/output tables, result classes, and platform-event field tables |
| Authentication and scopes | Running-user context, class/action access, sharing, CRUD/FLS, permission sets, and custom permissions |
| Request and response examples in several languages | One native example per supported Salesforce surface; no unsupported language examples |
| OpenAPI source of truth | Apex classes and Salesforce metadata are authoritative because this package does not expose a REST API |
| Interactive search and deep links | Stable Markdown headings, V2 index links, and repository/site search |

## Example-page pattern

Use [Apex example](apex/apex-example.md) as the presentation baseline for V2 task and example pages:

- One realistic business scenario and one canonical end-to-end example per page.
- One native GitHub **Note** with **In one line** followed by **Reference**.
- Exact Setup navigation, Custom Metadata Type, labels, API names, and record Developer Names.
- Explain `recordId` where it enters the surface; do not hide it inside an unexplained query.
- Use one parameter object effectively. When the surface supports multiple parameters, demonstrate
  at least two related values in that one object.
- Comment code where the reader must understand framework input, security, defaults, decisions, or
  returned values. Do not comment syntax that is already self-explanatory.
- Separate configuration from testing. When applicable, show both a direct programmatic test, such
  as Execute Anonymous, and the user-facing Lightning component path.
- Keep contract definitions, compatibility policies, evaluator internals, and advanced patterns on
  the companion reference page rather than interrupting the example.
- Maintain one **Example** page and one **Reference** page for every shipped Evaluation Type:
  `FORMULA`, `QUERY`, `COMPARE_TWO_QUERIES`, and `APEX`. The example explains why that type fits and
  provides one complete path; the reference owns the full contract and edge cases.

Do not publish an OpenAPI document for the Apex, Flow, Lightning, or platform-event surfaces. OpenAPI
describes HTTP operations and would misrepresent these Salesforce-native contracts. If a REST API is
added later, its reference must be generated from a version-controlled OpenAPI document and linked
from this page.

## Version and deprecation policy

- The synchronous Apex and Flow result contract and the independent lifecycle-event contract are
  both stable at `1.0`. Their matching numbers do not make them one schema: each contract versions
  independently. Product release numbers do not replace either contract version.
- Additive fields may appear within a contract version. Consumers must ignore fields they do not
  recognize and branch only on documented stable fields.
- Removing or renaming a public operation, field, status, or reason value requires a new contract
  version.
- Deprecations must be announced in the V2 index, the affected reference page, the upgrade guide,
  and the changelog. The notice must name the replacement and the earliest removal release.
- No V2 public surface is currently deprecated.

## Review checklist

Before publishing a V2 API documentation change, verify it against the implementation and answer
yes to each question:

1. Can a new consumer reach a working result from the first example?
2. Are every public input, output, allowed value, cap, and access requirement documented?
3. Does every thrown fault have a cause and a remedy, separate from returned statuses?
4. Are contract versions and compatibility expectations visible?
5. Do links resolve to one canonical reference for each fact?
6. Do examples use current V2 names and compile or map to actual Flow metadata?

For non-API pages, also verify the requirements for that page type above, that status terminology is
exact, and that the final navigation points to the next likely task.

## Related

- [V2 documentation index](README.md)
- [Integration overview](integrate/overview.md)
- [Configuration guide](guides/configuration-guide.md)
- [Design specification](reference/record-health-check-design-spec.md)
