# Documentation standard

> [!NOTE]
> On this page, learn the editorial and structural decisions that make every Record Health Check page accurate, approachable, Salesforce-native, and consistent with the rest of the library.

Use this standard across the documentation tree. It adapts the recurring practices identified in
[DreamFactory's API documentation examples](https://blog.dreamfactory.com/8-api-documentation-examples)
to Salesforce-native APIs and applies progressive disclosure to administrator, installation, and
reference pages.

Use the [Salesforce naming and metadata writing standard](salesforce-naming-and-metadata-writing-standard.md)
when creating Apex identifiers, labels, API names, descriptions, help text, picklist values, or
Custom Metadata Types. This page governs how documentation presents those names and values.
Use the [Salesforce engineering standard](salesforce-engineering-standard.md) for reusable Apex,
security, testing, Metadata API, permission, and deployment requirements.
Use the [code analysis standard](code-analysis-standard.md) for automated documentation and source
checks and for the review required before excluding a rule.

## Standards for every page

- Begin every page with one native GitHub **Note** immediately after the page title. Its single
  sentence begins “On this page,” and captures why the reader came, what the page helps them do,
  and the useful outcome. Example and reference pages
  may add a second **Reference** label identifying scope and the deeper primary companion.
- Put the shortest successful path before exhaustive detail. Link prerequisites before the first
  task when they cannot fit on the page.
- Keep one idea per paragraph, normally in one or two sentences. Split procedures into numbered
  steps and split independent facts into labeled bullets.
- Remove lead-ins that merely announce the heading, table, code block, or number of items that
  immediately follows. Skip restating facts already evident from names or examples.
- Use exact Setup labels for people and exact API names in code, tables, and automation contracts.
- Keep one primary source for each fact. Link to it instead of copying long field, reason-code, or
  event definitions into several guides.
- Prefer plain technical language in explanations; see
  [Prefer plain technical language](#prefer-plain-technical-language-avoid-cs-jargon).
- Write as a peer documenting how the product works. Prefer “Use X” and “Record Health Check
  supplies Y” over imperative prohibitions such as “Do not invent…” or “Don’t put…”. State facts
  and preferred patterns; leave scolding out of guides and references.
- Distinguish `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, `ERROR`, and a thrown fault. Reserve “error”
  for thrown faults and the `ERROR` status, not as a catch-all for access or configuration outcomes.
- End task pages with **Next steps** and reference pages with **Related** or **See also** links.
- Use sentence-case headings, concise paragraphs, accessible link text, fenced code with a language,
  and tables only when readers need to compare repeated fields.
- Keep each topic filename aligned with its page title: use the lowercase kebab-case form of the
  title's subject, omitting only intentional ordering prefixes and unnecessary product-name words.
  Use `README.md` for a folder landing page. A filename must not describe a different concept from
  the title readers see.
- In `docs/metadata`, use a purpose-first prefix so related references sort together: `fields-*`
  for Custom Metadata field catalogs and `event-*` for Platform Event references. Put cross-cutting
  Framework limits in `docs/reference`.
- Lead merge-token examples with the bare form (`{!record.Name}`). Treat the quoted `fallback` attribute as
  optional. Any page that shows merge tokens must include at least one fallback example, such as
  `{!record.Name fallback="this record"}`, without putting a fallback on every tag. `{!record.Id}` stays bare.
  See [Reference: Merge tokens](../reference/reference-merge-tokens.md).

## Write for the person doing the work

Structural correctness is necessary but does not make a page useful or shareable. Every page also
needs an editorial review by a person reading it from top to bottom.

The reader-centered standard does not mean that every page needs a business scenario. Match the
opening and structure to the page's purpose:

| Page type | Opening and structure |
| --- | --- |
| Practical example | A credible Salesforce role, business moment, problem, expected outcome, and what the reader will learn |
| Tutorial | The result the reader will build, prerequisites, ordered steps, verification, and next steps |
| How-to guide | The task, starting condition, shortest successful procedure, and confirmation |
| Troubleshooting guide | The visible symptom, likely causes, diagnostic sequence, and recovery |
| Reference | What the page documents, when to consult it, lookup tables, exact behavior, and related references |
| Explanation or overview | The concept or decision being explained, mental model, boundaries, and links to tasks |
| Design specification | Scope, authority, intended technical audience, formal behavior, and compatibility boundaries |

Skip invented personas or business stories on reference, specification, command index, and
API contract pages. These pages still need purpose and audience clarity, but readers should reach the
technical information immediately.

For a tutorial or how-to guide, establish the task, prerequisites, observable result, and next
action before exhaustive detail. State the intended Salesforce role only when it helps readers
judge whether the procedure applies to them; keep the role factual rather than a manufactured
character or story.

For a practical example, establish these points before exhaustive reference detail:

1. **Who is doing the work.** Name the primary reader or Salesforce role, such as a Salesforce
   administrator, Flow builder, developer, service manager, or seller.
2. **What they are trying to accomplish.** Describe the Salesforce task or decision, not merely the
   Framework surface being documented.
3. **Why it matters.** State the manual work, uncertainty, late discovery, or unsafe automation the
   task prevents.
4. **What they will see.** Describe the card result, Flow branch, Apex response, Setup value, event,
   or other observable outcome.
5. **What they can do next.** Give the reader a working path, a way to prove success, and a useful
   next action when the result differs from expectations.

Use this learning path for practical examples and longer tutorials:

1. Goal and reader context
2. Choice or prerequisites
3. Shortest working path
4. Expected result
5. Explanation of why it works
6. Security, limits, and troubleshooting
7. Advanced or exhaustive reference detail
8. Next steps

Begin a learning page with the task and shortest working path. Place engine architecture, response
versions, internal wrappers, and “what this is not” lists after the reader can recognize the task
and complete the main path.

### Preserve exact terminology

Reader-friendly writing does not replace official names with invented shorthand.

- Use the Framework terms **Check Set**, **Rule**, **Evaluation Type**, **Verify with a formula**,
  **Verify with a query**, **Compare two queries**, **Verify with Apex**, **Found**, **Expected**,
  **Show Diagnostics**, and the documented result statuses.
- Use Salesforce terms exactly when they identify a product, tool, object, field, or Setup control:
  **Flow Builder**, **Lightning App Builder**, **Custom Metadata Types**, **Permission Set**, Apex,
  SOQL, Account, Contact, Opportunity, Case, Task, Event, and other standard object names.
- Use Setup labels in instructions and API names in code, metadata, and reference tables. Explain
  the relationship the first time both appear.
- Explain an unfamiliar term in ordinary language when it first matters. Keep the exact term so the
  reader can find it in Salesforce or the Framework.
- Branch automation on documented statuses, reason codes, Developer Names, and API values rather
  than administrator-authored display text.

### Prefer plain technical language (avoid CS jargon)

Write explanations the way a Salesforce administrator or Apex developer would say them out loud.
Prefer everyday technical words over computer-science shorthand. This applies to documentation,
ApexDoc, and code comments. It does **not** apply to Setup labels, field help that ships in
metadata, user-facing runtime messages, API identifiers, or method names.

#### Leave these alone

| Keep as written | Why |
| --- | --- |
| Setup **labels**, picklist labels, and shipped field **Description** / help text | Admins see these in Salesforce; changing them is a product change |
| User-facing messages (for example “Formula checks require Formula to be populated.”) | Runtime / validator copy |
| Code identifiers already in the codebase (`emit`, `coercionLabel`, `populateRequiredFields`, `flush`, …) | Renaming breaks callers and tests. This protects names that already exist; it is not licence to coin new jargon. Give a new identifier a plain name from the start. |
| Salesforce platform terms (**Invocable**, `@AuraEnabled`, `WITH USER_MODE`, Platform Event, Custom Metadata, Developer Name, App Builder, FormulaEval, …) | Official product vocabulary |
| Admin English **“populated”** meaning a field **has a value** (for example “Billing City is populated”) | Ordinary Salesforce Setup language, not “fill a DTO” |
| Literal configuration example strings (for example `"City, State, and Country populated"`) | Must match what admins paste into Setup |

#### Avoid → prefer

Use this map when drafting or reviewing explanations. Prefer the right-hand wording unless the
left-hand word is an identifier, label, or Salesforce term.

| Avoid in explanations | Prefer |
| --- | --- |
| populate / populated *(fill an object, response, or fields in code)* | fill in / set / filled in |
| DTO | data holder |
| payload | response / event body / data |
| emit / emits / emitted | return / publish / add / report |
| coerce / coercion *(prose only; keep `coercionLabel`)* | convert / conversion |
| short-circuit / short-circuits | return early / exit early |
| idempotent | safe to call more than once / safe to run again |
| sentinel *(prose only; keep constant names)* | placeholder |
| probe / probing / re-probe | try / check / look up / retry |
| headroom | spare room |
| durable *(logging)* | platform event / held for platform event |
| sink | destination |
| allowlist / allowlisted | allowed list / allowed |
| verbatim | exactly / word for word |
| lockstep | together / at the same time |
| drift | get out of sync / unexpected differences |
| canonical | official / primary / main |
| vocabulary *(for codes or terms)* | list of values / terms / codes |
| wire strings | older string values |
| fail closed / fail-closed | fall back to the safer default |
| authoritative | server-side / trusted / true |
| de-duplication / dedup | unique |
| gates on / gated by | checks / only when |
| applicability gate *(in architecture or guide prose)* | applicability check |
| downgraded | changed to |
| primitives | helpers |
| Opt-in / opt-in *(behavior prose)* | optional |
| well-formed | valid |
| sanitize / sanitization | clean up / safe handling |
| centralize / centralizes | keep in one place / provide shared |
| fails fast / fail-fast | fails immediately |
| degrades / degrades to | becomes / falls back to |
| side effect / side-effect | rewrite (“also does X” / “while validating”) |
| buffered | held |
| transaction-scoped | for the current transaction |
| package surface / integration surface | package / public API |
| Fluent builder | chainable builder |
| resolvable / unresolvable | can be resolved / unresolved |
| result shell | empty result |
| transport cap / row cap / request caps | request limit / row limit / request limits |
| invocation | call |
| overflow *(limit exceeded)* | over the limit / excess |

#### Quick examples

| Instead of | Write |
| --- | --- |
| “callers populate the DTO” | “callers set the fields” |
| “the publisher emits events” | “the publisher publishes events” |
| “unknown sources fail closed” | “unknown sources fall back to the safer default” |
| “opt-in platform events” | “optional platform events” |
| “transaction-scoped describe cache” | “describe cache for the current transaction” |
| “shared validation primitives” | “shared validation helpers” |

When an LLM or reviewer is unsure, keep the Salesforce or Framework term and explain the behavior in
plain words around it. Keep Setup labels and API names exact; softer synonyms belong only in
explanations around those terms.

### Capitalize named concepts consistently

Use the published form when prose, headings, or tables refer to a named Framework or Salesforce
concept. Preserve the implementation's exact casing inside code spans.

| Concept group | Published form | Code or API examples |
| --- | --- | --- |
| Framework configuration | Check Set, Rule, Evaluation Type | `Record_Health_Check_Set__mdt`, `EvaluationType__c` |
| Result information | Status, Reason Code, Failure Severity, Found / Expected | `status`, `reasonCode`, `severity`, `actualValue`, `expectedValue` |
| Identifiers | Run ID, Record ID, User ID, Developer Name | `runId`, `recordId`, `userId`, `DeveloperName` |
| Access | Permission Set, Custom Permission | `Record_Health_Check_Admin`, `Record_Health_Check_View_Details` |
| User interface | Record Health Check card, Show Diagnostics, Lightning record page | `ShowDiagnostics__c` |

Sentence case still applies to ordinary descriptions. For example, “the result has no message” is
ordinary prose, while “branch on Status and Reason Code” names contract fields.

### Apply the single-link test

Treat every task, guide, and example as the only URL a reader may receive. From that page alone, the
reader should be able to understand the purpose, complete the main task, recognize success, handle
the most likely failure, and know where to go next. Reference links provide optional depth; they do
not replace missing instructions or context.

Before publishing, read the page as prose and answer:

- Would the intended Salesforce reader recognize the situation?
- Does the page explain what Record Health Check contributes to the work?
- Can the reader reach a useful result before encountering exhaustive details?
- Are Framework and Salesforce terms exact and explained at the right moment?
- Does every section help the reader choose, configure, run, understand, troubleshoot, or extend?

Automated validation can verify headings, links, tables, and required sections. It cannot award an
editorial quality score or replace this human review.

### Table readability

- Use prose or bullets when rows do not compare the same attributes. Prefer prose over a
  one-row table that only restates a paragraph.
- Keep useful comparison tables. Fix column sizing or horizontal overflow instead of replacing a
  table solely because identifiers wrap.
- Put the API-name column near the left and wrap every literal API name in backticks so it remains
  visually distinct and copyable.
- In example configuration tables, link every field API name to its primary Rule or Check Set
  metadata reference section, where readers can review requirements and allowed values.
- Put **Notes**, **Description**, **Meaning**, **Purpose**, **Behavior**, or similar explanation in
  the final column. That column must not use more than 50% of the rendered table width.
- Prefer four or fewer columns. Use five or six only for dense primary registries where removing a
  column would hide type, required/default, size, or runtime-contract information.
- Move long examples, exceptions, and corrective actions below the table when they are specific to
  only one row.
- Keep table surroundings lean: skip prose that only repeats the heading, rows, or conclusion.
- Include a corrective action only when it adds a non-obvious diagnostic step, location, or
  decision. Prefer **What to investigate** when “corrective action” would restate the failure.
- Keep API names whole in published tables: no shortened forms, inserted spaces, or mid-name line
  splits for fit. Tables scroll horizontally on narrow screens when needed.

## Requirements by page type

| Page type | Required content |
| --- | --- |
| Quick start / installation | Prerequisites, numbered working path, expected result, common failures, next steps |
| Guide | Outcome, safe examples, constraints, review or troubleshooting guidance, related references |
| API / integration | Fast start, operations and schemas, access, limits, errors with remedies, version/deprecation policy |
| Metadata reference | Exact API name, type or allowed values, defaults, runtime effect, primary related guides |
| Architecture / design | Scope, trusted contracts, diagrams or mappings only when useful, limitations, related task pages |

Every Custom Metadata field reference must give each field its own anchored section containing the
Setup label, API name, type and capacity, required status, default, shipped description, inline help
text, allowed values, dependencies or conditional use, and realistic examples where they add
information. Checkbox and picklist fields do not repeat their allowed values as examples. Picklist
allowed values and defaults show both the Setup label and stored API value.

Document a Description as the administrator-facing explanation of purpose and important
dependencies. Document inline help as the guidance shown when a person enters or chooses a value.
Do not use one as a copy of the other. When object fields or validation rules change, verify that the
object Description and its reference page still describe the current behavior.

Descriptions and help text use short paragraphs by default. Use bullets only for genuine choices,
independent requirements, or procedures; do not turn every sentence into a bullet.

## Required on every API page

- **Fast start:** provide a working first call or configuration that a reader can complete in about
  five minutes. Keep prerequisites on the same page or link them immediately before the example.
- **Complete reference:** document every public operation, input, output, allowed value, limit, and
  relevant transaction behavior. Use stable headings and direct links from the documentation index.
- **Copy-ready examples:** include the request and the returned shape or decision pattern. Apex APIs
  use Apex examples; Flow APIs use numbered builder steps; events include subscriber and event-body
  guidance.
- **Access requirements:** state the execution user, sharing behavior, record and field access, and
  any Permission Set or Custom Permission that changes the returned detail.
- **Errors and outcomes:** distinguish returned business outcomes from thrown faults. For each
  documented fault, provide useful investigation guidance; omit obvious restatements.
- **Versioning:** state the contract version, compatibility promise, deprecation process, and any
  separate product or event version.
- **Human- and automation-readable names:** use exact API names, meaningful field names, explicit
  types, stable status/reason values, and concrete descriptions. Automation branches on those
  values, not on display text.
- **Related navigation:** end with links to the integration overview and the primary references for
  Statuses, Reason Codes, configuration, and events.

## Salesforce equivalents for web-API practices

| General API documentation practice | Record Health Check implementation |
| --- | --- |
| Runnable browser console | Copy-ready Anonymous Apex plus sandbox instructions; Flow builder steps for invocable actions |
| Endpoint and schema reference | Apex signatures, Flow input/output tables, result classes, and platform-event field tables |
| Authentication and scopes | Running-user context, class/action access, sharing, object and field access, Permission Sets, and Custom Permissions |
| Request and response examples in several languages | One native example per supported Salesforce surface; no unsupported language examples |
| OpenAPI source of truth | Apex classes and Salesforce metadata are the source of truth because this package does not expose a REST API |
| Interactive search and deep links | Stable Markdown headings, documentation-index links, and repository/site search |

## Example-page pattern

Use [Seller research readiness](../examples/formula/01-account-research-ready.md) as the presentation baseline for practical example pages:

- One realistic business scenario and one primary end-to-end example per page.
- One native GitHub **Note** with a natural “On this page,” sentence followed by **Reference**.
- Exact Setup navigation, Custom Metadata Type, labels, API names, and record Developer Names.
- Explain `recordId` where it enters the surface; keep it visible rather than burying it inside an
  unexplained query.
- Use one parameter object effectively. When the surface supports multiple parameters, demonstrate
  at least two related values in that one object.
- Comment code where the reader must understand framework input, security, defaults, decisions, or
  returned values. Leave self-explanatory syntax uncommented.
- Separate configuration from testing. When applicable, show both a direct programmatic test, such
  as Execute Anonymous, and the user-facing Lightning component path.
- Present **What the user sees** as a table with individual rows for `PASS`, `FAIL`, `SKIPPED`,
  **Found**, and **Expected**. When the example cannot produce an outcome, explain why in that row
  instead of omitting it. Use exact Framework Status values as row labels and explain friendly card
  language such as **Needs attention** in the description.
- Keep contract definitions, compatibility policies, evaluator internals, and advanced patterns on
  the companion reference page rather than interrupting the example.
- Maintain one **Example** page and one **Reference** page for every shipped Evaluation Type:
  `FORMULA`, `QUERY`, `COMPARE_TWO_QUERIES`, and `APEX`. The example explains why that type fits and
  provides one complete path; the reference owns the full contract and edge cases.

Document Apex, Flow, Lightning, and platform-event surfaces with the Salesforce-native references
in this tree. OpenAPI describes HTTP operations and would misrepresent these contracts. If a REST
API is added later, generate its reference from a version-controlled OpenAPI document and link it
from this page.

## Version and deprecation policy

- The synchronous Apex and Flow result contract and the independent lifecycle-event contract are
  both stable at `1.0`. Their matching numbers do not make them one schema: each contract versions
  independently. Product release numbers do not replace either contract version.
- Additive fields may appear within a contract version. Consumers must ignore fields they do not
  recognize and branch only on documented stable fields.
- Removing or renaming a public operation, field, status, or reason value requires a new contract
  version.
- Deprecations must be announced in the documentation index, the affected reference page, the upgrade guide,
  and the changelog. The notice must name the replacement and the earliest removal release.
- No public surface is currently deprecated.

## Review checklist

Before publishing an API documentation change, verify it against the implementation and answer
yes to each question:

1. Can a new consumer reach a working result from the first example?
2. Are every public input, output, allowed value, cap, and access requirement documented?
3. Does every thrown fault have a cause and a remedy, separate from returned statuses?
4. Are contract versions and compatibility expectations visible?
5. Do links resolve to one primary reference for each fact?
6. Do examples use current names and compile or map to actual Flow metadata?
7. Do explanations avoid CS jargon from
   [Prefer plain technical language](#prefer-plain-technical-language-avoid-cs-jargon), while leaving
   Setup labels, user-facing messages, and identifiers unchanged?

For non-API pages, also verify the requirements for that page type above, that status terminology is
exact, and that the final navigation points to the next likely task.

## Related

- [Documentation index](../README.md)
- [Salesforce naming and metadata writing standard](salesforce-naming-and-metadata-writing-standard.md)
- [Salesforce engineering standard](salesforce-engineering-standard.md)
- [Integration overview](../integration/README.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
- [Architecture reference](../reference/reference-architecture.md)
