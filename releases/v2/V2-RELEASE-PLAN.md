# Record Health Check V2 Release Plan

## Brief idea

V2 turns Record Health Check into a clear, metadata-driven Salesforce product with three deliberate boundaries:

1. **Core stays independently useful.** It owns evaluation, validation, the LWC experience, stable contracts, and one small hero example.
2. **Configuration uses ordinary Salesforce language.** Custom metadata labels, API names, values, help text, runtime messages, and documentation describe the same concepts consistently.
3. **Optional content stays independently installable.** Reusable examples move to an examples library. Runtime add-ons consume small, versioned extension contracts and never patch core.

Concretely, the ecosystem is **three repositories**, and every deliverable belongs to exactly one:

- **Core** — `RecordHealthCheck`
- **Examples** — `RecordHealthCheck-Examples`
- **Extensions** — `RecordHealthCheck-Extensions`

A public, synchronous check-response façade (Section 4.18) lets callers evaluate a Rule or Check Set — programmatically or from Flow — and get a structured result.

The field migration is a coordinated V2 breaking change, not a compatibility shim. The final schema keeps `Record_Health_Check_Rule__mdt`, adopts the approved field names in the migration map, uses machine-safe `UPPER_SNAKE_CASE` stored values, and distinguishes configuration mistakes from system failures. The three repositories retain one shared governance and quality bar.

## 1. Canonical V2 decisions

### 1.1 Product boundaries

The ecosystem is organized into exactly **three repositories**, and every deliverable belongs to one of them:

1. **Core** (`RecordHealthCheck`) — the standalone product: engine, validators, LWC, permissions, metadata types, the public Apex check contract, the lifecycle contract, contract tests, and minimal working configuration. Core retains one hero example that proves the product immediately after installation; test fixtures stay in core but are not presented as deployable examples.
2. **Examples** (`RecordHealthCheck-Examples`) — reusable scenario packs and sample content, independently installable.
3. **Extensions** (`RecordHealthCheck-Extensions`) — optional runtime integrations, one independently deployable package directory each. "Plugin" remains the author-facing ecosystem term (Section 4.9); the repository itself is named Extensions.

These boundaries are refined by the following rules:

- No example or extension may require a core source edit, extension-specific branch in the engine, copied core class, or hidden dependency.
- The public synchronous check-response façade — evaluate one Rule or one Check Set, in user mode, in bulk, with a Flow-invocable wrapper — is a first-class V2 core contract for consuming a check response programmatically or from Flow. See Section 4.18.

### 1.2 Metadata model

- Keep `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt`.
- Use a separate `CheckTitle__c`; do not overload the custom metadata record's built-in Label.
- Use Lightning-facing **card** terminology, not panel terminology.
- Use `EvaluationType__c` as the router for Formula, Query, Compare Two Queries, and Apex evaluation.
- Use `FailureSeverity__c` with `CRITICAL`, `WARNING`, and `INFO`. Reserve system-error language for engine failures.
- Use `SourceQuery__c` and `ComparisonQuery__c`; avoid Primary/Second Query.
- Use `ExpectedValueSource__c` and `ComparisonOperator__c` with no meaning-changing defaults.
- Keep true two-state settings as checkboxes. Use picklists when a third state exists now or is plausible.
- Use descriptions for maintainers and inline help for administrators. Conditional requirements belong in validators.

### 1.3 Stored values and defaults

- Stored picklist values use `UPPER_SNAKE_CASE`; labels remain readable sentence case.
- Do not default fields where a guess can invert meaning: evaluation type, comparison operator, expected-value source, or no-record outcome.
- Safe presentation defaults are allowed, such as diagnostics off and found/expected details on demand.
- Query limits should be conservative and explicit. Validators enforce allowed ranges and cross-field requirements.

### 1.4 Extension contracts

Contract V1 promises only:

1. Apex check implementations through `RecordHealthCheckRule`.
2. Result consumers through a versioned evaluation lifecycle platform event.
3. Synchronous callers through the public check-response façade (Section 4.18), which returns a versioned, additive-only response for one Rule or one Check Set.

Evaluator providers, presentation extensions, and synchronous sinks remain private or deferred until a concrete second consumer proves the need. Observability is the first validator of the lifecycle contract, not the contract's namesake.

The lifecycle surface has two correlated levels: a **run** represents use of the component or public invocation façade, while an **evaluation** represents one Rule outcome within that run. This distinction supports both operational integrations and product-adoption analytics without treating a Rule result as a component-usage event.

### 1.5 Governance

- Contributions follow the Apache 2.0 license, Contributor Covenant, security policy, and repository PR process.
- Behavior changes require positive and negative tests.
- Apex changes require the Apex suite and a clean-org validation deployment.
- Documentation and code must agree in the same commit.
- Security, CRUD/FLS, run caps, concurrency limits, diagnostics authorization, and result normalization may not be weakened to satisfy tests.

## 2. Detailed custom metadata contract

> **Status legend.** Subsections are marked **✅ Completed** (implemented and verified), **🟡 Partial** (implemented in metadata, a release artifact remains), or **⬜ Open** (decision or work outstanding). The field migration (2.1–2.5) was verified in a clean scratch org on 2026-07-12; shipped metadata is the source of truth. Additive publish fields from 2.1/2.2 shipped with Section 4 (2026-07-13).

### 2.1 Check Set fields

**✅ Completed** — the 11 Check Set field migrations are implemented and verified (2026-07-12). The additive `PublishRunEvent__c` field shipped with Section 4.2 (2026-07-13).

| V1 field                  | V2 field                  | Purpose                               |
| ------------------------- | ------------------------- | ------------------------------------- |
| `PanelHeading__c`         | `CardTitle__c`            | User-facing card title                |
| `PanelSubheading__c`      | `CardSubtitle__c`         | Optional card subtitle                |
| `RunChecksWhen__c`        | `CardRunMode__c`          | Run on request or load                |
| `RowAppearance__c`        | `CardRevealMode__c`       | Reveal all checks or one by one       |
| `ComparisonDisplay__c`    | `FoundExpectedDisplay__c` | Found/expected visibility             |
| `DebugMode__c`            | `ShowDiagnostics__c`      | Authorized diagnostic display         |
| `ObjectApiName__c`        | retained                  | Target object API name                |
| `IsActive__c`             | retained                  | Set enabled state                     |
| `PassedChecksDisplay__c`  | retained                  | Show each passed check or count only  |
| `SkippedChecksDisplay__c` | retained                  | Show each skipped check or count only |
| `StopOnSystemError__c`    | retained                  | Stop after unexpected engine error    |

The extension architecture adds one affirmative Set checkbox when its event contract ships:

| New field            | Label             | Type/default      | Purpose                                                     |
| -------------------- | ----------------- | ----------------- | ----------------------------------------------------------- |
| `PublishRunEvent__c` | Publish Run Event | Checkbox, `false` | Publish `Record_Health_Check_Set_Run__e` for this Check Set |

This is an additive feature field, not one of the already verified 11 Set-field migrations. Adding it changes the shipped Set schema to 12 fields and requires contract, layout, permission, deployment, help-text, and test verification.

### 2.2 Rule identity, ordering, and messages

**✅ Completed** — the 40 Rule field migrations are implemented and verified (2026-07-12). The additive `PublishResultEvent__c` field shipped with Section 4.2 (2026-07-13).

| V1 field                  | V2 field                     |
| ------------------------- | ---------------------------- |
| `CheckName__c`            | `CheckTitle__c`              |
| `Tooltip__c`              | `CheckDescription__c`        |
| `RunOrder__c`             | `EvaluationOrder__c`         |
| `CheckMethod__c`          | `EvaluationType__c`          |
| `Severity__c`             | `FailureSeverity__c`         |
| `MessageWhenFailed__c`    | `FailureMessage__c`          |
| `MessageWhenCannotRun__c` | `UnableToEvaluateMessage__c` |
| `FixInstructions__c`      | `FixMessage__c`              |
| `PrimaryActionLabel__c`   | `ActionLabel__c`             |
| `PrimaryActionUrl__c`     | `ActionUrl__c`               |

`Category__c`, `IsActive__c`, and the parent `Record_Health_Check_Set__c` relationship remain. Category values should form one outcome-oriented level rather than mix industries, clouds, and mechanisms.

The extension architecture adds one affirmative Rule checkbox when its event contract ships:

| New field               | Label                | Type/default      | Purpose                                                                                  |
| ----------------------- | -------------------- | ----------------- | ---------------------------------------------------------------------------------------- |
| `PublishResultEvent__c` | Publish Result Event | Checkbox, `false` | Publish `Record_Health_Check_Rule_Result__e` after this Rule reaches a finalized outcome |

This is an additive feature field, not one of the already verified 40 Rule-field migrations. Adding it changes the shipped Rule schema to 41 fields and requires the same contract and release verification.

### 2.3 Applicability and prerequisites

**✅ Completed** — implemented and verified as part of the 2026-07-12 field migration.

| V1 field               | V2 field                         |
| ---------------------- | -------------------------------- |
| `RunThisCheckWhen__c`  | `ApplicabilityMode__c`           |
| `RunWhenFormula__c`    | `ApplicabilityFormula__c`        |
| `RunWhenCountQuery__c` | `ApplicabilityCountQuery__c`     |
| `CountOperator__c`     | `ApplicabilityCountOperator__c`  |
| `CountThreshold__c`    | `ApplicabilityCountThreshold__c` |
| `RequiresCheck__c`     | `PrerequisiteRule__c`            |

The validator requires only the fields selected by `ApplicabilityMode__c`. Prerequisite developer names remain text and are validated against the current Check Set.

### 2.4 Formula, query, and comparison

**✅ Completed** — implemented and verified as part of the 2026-07-12 field migration.

| V1 field                     | V2 field                    |
| ---------------------------- | --------------------------- |
| `PassFailFormula__c`         | `PassConditionFormula__c`   |
| `DataQuery__c`               | `SourceQuery__c`            |
| `FieldToRead__c`             | `SourceQueryField__c`       |
| `CompareToQuery__c`          | `ComparisonQuery__c`        |
| `CompareToField__c`          | `ComparisonQueryField__c`   |
| `Operator__c`                | `ComparisonOperator__c`     |
| `WhenMultipleRows__c`        | `QueryResultHandling__c`    |
| `WhenValueIsEmpty__c`        | `EmptyValueHandling__c`     |
| `WhenZeroRows__c`            | `NoRowsResult__c`           |
| `MaxRows__c`                 | `MaxQueryRows__c`           |
| `ValueToTest__c`             | `FindInListFormula__c`      |
| `FixedValue__c`              | `ExpectedFixedValue__c`     |
| `RecordFormulaValue__c`      | `ExpectedRecordFormula__c`  |
| `CompareAgainst__c`          | `ExpectedValueSource__c`    |
| `ExpectedValueFormula__c`    | `DisplayExpectedFormula__c` |
| `ScalarFormulaReturnType__c` | `FormulaResultType__c`      |

The query fields form one readable family: Source Query, Source Query Field, Comparison Query, and Comparison Query Field. Stored operators use explicit tokens such as `GREATER_THAN_OR_EQUAL`, `LISTS_OVERLAP`, and `IS_EMPTY`, while Setup shows readable labels.

### 2.5 Apex and display fields

**✅ Completed** — implemented and verified as part of the 2026-07-12 field migration.

| V1 field                     | V2 field                 |
| ---------------------------- | ------------------------ |
| `ApexSettingsJson__c`        | `ApexParametersJson__c`  |
| `FoundValueFormula__c`       | `DisplayFoundFormula__c` |
| `FoundSummaryOverride__c`    | `DisplayFoundText__c`    |
| `ExpectedSummaryOverride__c` | `DisplayExpectedText__c` |

`ApexClass__c` remains the extension implementation name. Display formulas and text override presentation only; they must not change the evaluation result.

### 2.6 Validation rules

**✅ Completed** — implemented in `RecordHealthCheckConfigValidator`, `RecordHealthCheckRuleValidator`, and `RecordHealthCheckMetadataValidator` (with tests). _Declarative_ Validation Rules on the CMDT remain an optional additive layer (Section 8 register).

- A field required by the selected evaluation or applicability mode must be present; unrelated fields may remain blank.
- Query syntax, row limits, field/alias selection, operator compatibility, expected-value source, and result handling are validated before execution.
- Formula result types must agree with how formula outputs are consumed.
- Compare Two Queries requires both query sides and compatible result modes.
- Apex checks require a class implementing the documented contract and valid JSON parameters when supplied.
- Action label and URL are paired.
- Invalid configuration produces an actionable unable-to-evaluate outcome; unexpected framework failures remain system errors.

### 2.7 Namespaced merge and binding architecture

**✅ Completed** — the namespaced merge/binding token workstream is implemented (`RecordHealthCheckMergeContext`, `RecordHealthCheckToken`, `RecordHealthCheckTokenIssue`, `RecordHealthCheckTokenRegistry`). The token registries, typed SOQL binding, and unsupported-context rules below reflect the shipped behavior.

V2 should replace ambiguous flat tokens such as `{!Id}`, `{!Name}`, and `{!Owner.ManagerId}` with namespaced tokens. The proposal's canonical record syntax is `{!record.Id}` (capital `I` because `Id` is the Salesforce field API name), rather than `{!record.id}`. Token namespaces are lowercase; record field paths preserve Salesforce API-name casing.

```text
{!record.Id}
{!record.Name}
{!record.Owner.ManagerId}
{!rhcRule.developerName}
{!rhcRule.masterLabel}
{!rhcRule.checkTitle}
{!rhcSet.developerName}
{!rhcSet.masterLabel}
{!rhcSet.cardTitle}
{!rhcResult.status}
{!rhcResult.foundValue}
{!rhcResult.expectedValue}
{!rhcResult.failedRecordCount}
{!rhcResult.totalRecordCount}
{!rhcResult.reasonCode}
{!rhcRun.runId}
{!rhcRun.source}
```

This is an architectural change, not merely a spelling change. The namespace identifies the data source, prevents collisions between record fields and framework values, allows the validator to determine when a token is available, and leaves room for future token families without guessing what a bare name means.

`rhcRule`, `rhcSet`, `rhcResult`, and `rhcRun` are deliberately product-qualified. Generic `{!check.*}`, `{!set.*}`, `{!result.*}`, and `{!run.*}` namespaces are not supported because those words can refer to unrelated concepts in formulas, extensions, or future host applications.

The property name must distinguish Setup identity from user-facing presentation:

- `masterLabel` means the Custom Metadata record's standard Label (`MasterLabel`).
- `developerName` means the stable Custom Metadata record API name (`DeveloperName`).
- `checkTitle` means the Rule's user-facing `CheckTitle__c`.
- `cardTitle` means the Set's user-facing `CardTitle__c`.

Token properties use lower camel case and preserve the canonical Salesforce/V2 concept name. A custom field drops only the `__c` suffix: `CheckTitle__c` becomes `checkTitle`, `CardTitle__c` becomes `cardTitle`, and `FailureSeverity__c` becomes `failureSeverity`. Standard metadata properties use their established names in lower camel case: `DeveloperName` becomes `developerName`, and `MasterLabel` becomes `masterLabel`. Do not shorten, alias, or invent synonyms such as `title`, `label`, `name`, or `severity`.

#### Rule token registry

Only these Rule properties are initially supported:

| Token                         | Source                     | Availability/use                                        |
| ----------------------------- | -------------------------- | ------------------------------------------------------- |
| `{!rhcRule.developerName}`    | Rule `DeveloperName`       | Stable identity; suitable for links and diagnostic text |
| `{!rhcRule.masterLabel}`      | Rule `MasterLabel`         | Setup label; not the result-row title                   |
| `{!rhcRule.checkTitle}`       | `CheckTitle__c`            | User-facing result-row title                            |
| `{!rhcRule.checkDescription}` | `CheckDescription__c`      | Optional user-facing explanation                        |
| `{!rhcRule.category}`         | `Category__c` label        | Display grouping; blank when ungrouped                  |
| `{!rhcRule.evaluationType}`   | `EvaluationType__c` label  | Display label, not the stored machine value             |
| `{!rhcRule.failureSeverity}`  | `FailureSeverity__c` label | Effective configured failure severity                   |
| `{!rhcRule.evaluationOrder}`  | `EvaluationOrder__c`       | Numeric ordering value                                  |

#### Check Set token registry

Only these Set properties are initially supported:

| Token                     | Source                    | Availability/use              |
| ------------------------- | ------------------------- | ----------------------------- |
| `{!rhcSet.developerName}` | Check Set `DeveloperName` | Stable Set identity           |
| `{!rhcSet.masterLabel}`   | Check Set `MasterLabel`   | Setup label                   |
| `{!rhcSet.cardTitle}`     | `CardTitle__c`            | User-facing card title        |
| `{!rhcSet.cardSubtitle}`  | `CardSubtitle__c`         | Optional user-facing subtitle |
| `{!rhcSet.objectApiName}` | `ObjectApiName__c`        | Target object API name        |

Do not expose arbitrary Rule/Set fields through dynamic reflection. Every token is allowlisted, typed, documented, and tested. Configuration fields containing SOQL, formulas, JSON, action URLs, messages, prerequisites, publication settings, or other potentially sensitive/recursive templates are not merge-token sources.

For integrations that need stored machine values rather than display labels, add an explicitly named property such as `evaluationTypeApiValue` in a later additive contract version. Never make one property sometimes return a label and sometimes an API value.

#### Result and run token boundary

Result tokens are available only after a Rule result is finalized. Initial properties are `status`, `reasonCode`, `foundValue`, `expectedValue`, `failedRecordCount`, and `totalRecordCount`. Found/expected values remain subject to diagnostics/detail authorization and data-classification policy.

Run tokens are available when a Check Set run context exists. Initial properties are `runId`, `source`, `startedAt`, `completedAt`, and `durationMs`; completion properties are blank or unavailable before finalization. Do not expose invoking-user identity through display merge fields by default. Identity belongs in authorized lifecycle contracts and extension storage policy.

#### Display merge fields

Display tokens are resolved as typed presentation values in Card Subtitle/description, Check Description, Failure Message, Unable to Evaluate Message when a record is available, Fix Message, Action Label, and multi-record Found/Expected summary text. `{!rhcResult.*}` tokens are available only after evaluation. The renderer must define null formatting, inaccessible-field behavior, unknown-token errors, relationship-depth limits, and resolved-length limits.

#### URL merge fields

`ActionUrl__c` supports record and other explicitly documented tokens. Each value is URL-encoded before insertion, and the final URL is sanitized. Permit only documented same-org relative paths and HTTPS URLs. Enforce the final resolved-length limit, not only the stored template length.

#### SOQL binding fields

`SourceQuery__c`, `ComparisonQuery__c`, and `ApplicabilityCountQuery__c` support record binding tokens, but the implementation must not perform raw string replacement. Core resolves `{!record.*}` using field-type-aware bind handling, escaping, multi-select behavior, CRUD/FLS policy, relationship-path validation, and explicit missing/inaccessible-bind errors.

#### Unsupported contexts

Do not resolve merge tokens in picklists, field names or aliases, comparison operators, configured fixed expected values, formula fields (which use Salesforce formula syntax), Apex parameters JSON, prerequisite developer names, category, or severity.

#### V2 migration policy

Because the repository is performing a coordinated V2 migration, bundled metadata and documentation should be converted from `{!Id}`/`{!FieldApiName}` to `{!record.Id}`/`{!record.FieldApiName}`. Runtime handling must follow one explicitly selected release policy:

- **Strict V2:** reject legacy flat tokens during validation with a message showing the namespaced replacement. This produces the cleanest long-term contract.
- **One-release compatibility:** accept legacy flat tokens temporarily, normalize them internally, emit an authorized diagnostic/deprecation warning, and remove support in the next major release.

The strict V2 policy is preferred for a fresh-start breaking release. Whichever policy is selected must be applied consistently in runtime resolution, metadata validation, examples, field help text, migration tooling, and tests.

### 2.8 Field sizing and storage rules

**✅ Completed** — shipped metadata and the generated 53-field registry (`docs/v2/reference/field-size-registry.md`) are authoritative (2026-07-13), including the two additive Section 4 publication fields.

The proposals considered a compact two-tier policy: 2,048 characters for human-readable long text and URLs, and 8,192 for formulas, SOQL, JSON, and list expressions. The implemented migration map currently uses `Text(255)` for `CheckDescription__c` and `CardSubtitle__c` because Salesforce Long Text Area starts at 256, and uses larger Long Text Area fields for unbounded configuration.

Before release, generate one authoritative size registry from shipped metadata. It must identify the storage type, stored maximum, post-resolution maximum, and truncation/error behavior for every field. In particular:

- API names, aliases, class names, prerequisite developer names, and summaries use bounded Text.
- `ActionLabel__c` remains short Text.
- messages, formulas, queries, JSON, and URL templates must have documented limits.
- URL validation applies after token resolution.
- character limits are not byte guarantees.
- runtime, validators, help text, and extension contracts must use the same limits.

### 2.9 Exact value-contract requirements

**✅ Completed** — restricted picklists and their `UPPER_SNAKE_CASE` values, labels, and defaults are shipped and verified as part of the field migration; shipped metadata is authoritative. Option A from §2.10 is adopted: applicability and prerequisite outcomes use `SKIPPED` with stable reason codes. A microscopic audit (2026-07-13) found `FailureSeverity__c` was the one picklist shipped without `<restricted>true</restricted>` — contradicting this contract and the size registry's own "Restricted value set" row; it was corrected and redeployed, so all 15 picklists across both objects are now restricted.

All picklists are restricted. The shipped V2 metadata is authoritative for exact `UPPER_SNAKE_CASE` values, labels, and defaults. The contract registry must cover at least:

- card run mode: run on load or on request;
- card reveal mode: all at once or one by one;
- passed/skipped display: each check or count only;
- found/expected display: on demand, failed checks, or all checks;
- evaluation type: Formula, Query, Compare Two Queries, or Apex, with no default;
- failure severity: Critical, Warning, or Info;
- category: the approved outcome list;
- formula result type;
- expected-value source, with no unsafe default;
- all comparison operators and their type/coercion semantics;
- query-result handling: one result, any record, every record, or list comparison;
- no-record result, explicitly chosen;
- empty-value handling;
- applicability mode and count operators.

For operators, document case sensitivity, whitespace, type coercion, list ordering, duplicates, and blank/null behavior. Status is an outcome category; reason code explains why; display messages are never integration keys.

### 2.10 Skip and not-applicable semantics

**✅ Completed** — V2 retains one `SKIPPED` outcome and distinguishes applicability and prerequisite causes with stable reason codes (2026-07-13). Lifecycle event propagation for skipped outcomes shipped with Section 4.2.

Applicability formula misses use `NOT_APPLICABLE_BY_FORMULA`, applicability count misses use `NOT_APPLICABLE_BY_COUNT`, and unmet prerequisites use `PREREQUISITE_NOT_MET`. The UI and summaries keep one skipped bucket; consumers use `reasonCode` when they need the cause.

### 2.11 Diagnostics display and field-level-security presentation

**✅ Completed** — implementation and local LWC verification are complete (108/108 Jest, 2026-07-13), and the previously blocked scratch-org security verification is now done. Server-side FLS/`USER_MODE` degradation is implemented in `RecordHealthCheckEngine`, `RecordHealthCheckValueResolver`, and `RecordHealthCheckFormulaEvaluator` (neutral-empty in normal mode; `FIELD_NOT_ACCESSIBLE` only under the diagnostics gate), and its `System.runAs`/`USER_MODE`/`FIELD_NOT_ACCESSIBLE` Apex tests pass as part of the full 183/183 run on a clean scratch org (`rhc-v2-audit`, 2026-07-13). The remaining human browser sign-off is the §9 Gate C smoke test, tracked in §9 — not a §2.11 implementation gap.

Two presentation behaviors follow the same principle as Section 4.19: the default view stays clean and non-alarming, and an authorized, view-time diagnostics overlay reveals the full technical picture without mutating stored configuration or exposing anything to unauthorized users.

#### Diagnostics expands every check

`ShowDiagnostics__c` (authorized by the diagnostics permission) is a troubleshooting overlay, not a stored preference. When it is active for an authorized user, the card shows **every** check individually, overriding `PassedChecksDisplay__c`/`SkippedChecksDisplay__c` set to `SHOW_COUNT_ONLY`. A count-only summary is useless for troubleshooting, so diagnostics auto-expands the suppressed rows.

- **Authorized only.** Expansion requires `ShowDiagnostics__c` and the admin permission. A normal user viewing the same card sees the configured summary; nothing extra is revealed to them.
- **View-time overlay.** It never rewrites the stored display picklists. Turning diagnostics off restores the configured summary.
- **Reveals more, never less.** It expands `SHOW_COUNT_ONLY` into the full list; a Set already on `SHOW_EACH_CHECK` is unchanged.
- **Presentation only.** It changes no evaluation result and publishes no event (Section 4.19).

#### Field-level-security presentation

Evaluation and the façade run in user mode, so a caller may lack FLS to a field a check reads or displays. The response must degrade without leaking the restriction:

- **Normal mode never announces a restriction.** An inaccessible display value renders as a neutral empty value, indistinguishable from a genuinely blank value. The UI does not show the field API name, the words "access" or "permission," or any "you cannot see this field" message. Revealing that a named field exists and is restricted is itself disclosure and reads as a broken component.
- **When an inaccessible field prevents evaluation**, the outcome is Unable to Evaluate with the Rule's author-written `UnableToEvaluateMessage__c` and a neutral, non-disclosing reason code — not a raw permission error, and not a restriction-specific code that would itself reveal the restriction.
- **Diagnostics may be honest.** For an authorized admin with diagnostics active, the overlay may state the technical reason plainly, including the field name and a `FIELD_NOT_ACCESSIBLE` reason code, because that is exactly what the admin needs to fix the permission or the configuration.
- **Enforced server-side.** The normal response must not carry the restricted value, the field name, a suppressed-detail flag, or a restriction-specific reason code to the browser and rely on the LWC to hide them; core strips inaccessible fields before returning, and the restriction-presence flag, field name, and specific reason code exist only inside the diagnostics-gated detail. The honest diagnostic detail is included only when the caller passes the diagnostics gate. A genuinely blank value and an FLS-withheld value must be indistinguishable in the normal response.

This resolves the field-level-security/unavailable-field response policy left open in Section 6 for both the LWC and the façade (Section 4.18); the remaining open work is the scratch-org verification of `USER_MODE` formula-evaluation behavior.

## 3. Examples repository architecture

**🟡 Repository populated; Core extraction incomplete.** The independent
[`RecordHealthCheck-Examples`](https://github.com/gkolan/RecordHealthCheck-Examples) repository now
contains 12 validated packs with generated catalogs and pack documentation. The release owner ended
the temporary duplication period on 2026-07-14. Core must migrate tests away from public example
names and remove every non-Hero example record, optional example Apex class, and non-Hero manifest
before V2 release. Boundary audit:
[`audits/2026-07-13-section-3-core-example-boundary-audit.md`](audits/2026-07-13-section-3-core-example-boundary-audit.md).

### 3.1 Purpose and boundary

**🟡 Content migrated; duplicate removal open.** The examples library teaches outcomes without a
hidden Core dependency. Core keeps `Example_Account_360_Health_Check` as the Hero plus internal test
fixtures that are not presented or deployed as examples. Public example names still used by Core
tests must be replaced with fixture-specific names before their duplicated metadata is removed.

### 3.2 Repository shape

**✅ Completed** — flat faceted catalog model (no root `sfdx-project.json`, no cloud folders). Isolated validation projects generated per pack.

```text
RecordHealthCheck-Examples/
  catalog/                 # generated
  docs/
  packs/<pack-id>/
    example.yml
    README.md
    manifest/
    force-app/
  scripts/
  tests/
  package.json             # Node tooling only
```

Every pack is independently deployable and removable. Catalog pages offer multiple discovery paths; each example has one source of truth in `packs/<id>/`.

### 3.3 Classification

**✅ Completed** — `docs/facet-vocabulary.yml` is the controlled vocabulary; `validate-packs.mjs` enforces it. Generated views: `catalog/by-cloud.md`, `by-outcome.md`, `by-mechanism.md`, etc.

Classify examples across separate facets rather than a single folder hierarchy:

- product/cloud;
- business outcome;
- evaluation mechanism;
- scope and dependencies;
- complexity;
- maturity/support status.

Outcome routes should use neutral language such as improve completeness, verify consistency, detect stale records, enforce eligibility, or monitor readiness. Do not label people by presumed role or skill level.

### 3.4 Required pack contract

**✅ Completed** — each migrated pack has `example.yml` (schema v1), ten-section README, `CHANGELOG.md`, deploy and destructive manifests. Template: `RecordHealthCheck-Examples/docs/pack-template/`.

Each `example.yml` records identity, version, compatible core range, package path, dependencies, target objects, mechanisms, outcomes, permissions, destructive metadata, and maturity. Each README explains:

1. what the example checks;
2. what the user sees;
3. when it is useful;
4. prerequisites;
5. installed components;
6. evaluation mechanics;
7. deploy and validation steps;
8. adaptation guidance;
9. removal steps;
10. technical references.

### 3.5 Migration sequence

**✅ Completed** (initial) — steps 1–5 and 8 executed; steps 6–7 partial (core manifest deduplication and scratch-org proof tracked in §9).

1. Record the current core/example boundary and dependencies.
2. Define the hero example and fixture policy.
3. Establish package directories and the catalog schema.
4. Move low-dependency metadata-only examples first.
5. Move Apex and feature-dependent packs after isolation tests exist.
6. Replace core docs with ecosystem links and outcome-based discovery.
7. Prove core-only, each pack alone, multiple packs together, upgrade, and uninstall paths.
8. Open contribution paths only after templates and CI enforce the quality bar.

### 3.6 Install and distribution experience

**✅ Completed** (source phase) — initial delivery is manifest deploy per pack; 2GP promotion deferred per `docs/packaging-guide.md`.

Supported delivery choices are source/manifest deployment, unlocked second-generation packages, and potentially managed 2GP for AppExchange. A Git tag is not an installable Salesforce package version. When 2GP is used, record the `04t` package version and declare the released core dependency in `sfdx-project.json`.

The adopter-facing path stays simple:

1. Install core and its hero example.
2. Assign `Record_Health_Check_User`.
3. Add the component to a record page and select a Check Set.
4. Optionally install one or more example packs.
5. Independently, optionally install extensions.

Offer Deploy to Salesforce buttons or package install links where feasible. The catalog, not the adopter, handles package directories and dependency ordering.

### 3.7 Compatibility, CI, and issue routing

**✅ Completed** (PR layer) — `catalog/compatibility.md` generated from `example.yml`; `.github/workflows/validate-packs.yml` runs schema, vocabulary, ownership, and catalog-drift checks. Scheduled full-pack org validation remains a §9 follow-up.

- Generate `COMPATIBILITY.md` from `example.yml`; do not hand-maintain duplicate compatibility facts.
- Validate core alone, then each pack against its minimum and current supported core versions.
- Cloud-specific packs require a correctly provisioned validation org. If automation is unavailable, publish the validation method and date.
- Require pass, fail, skipped, unable-to-evaluate, and relevant error scenarios; least-privilege permissions; query-cost and limit notes; removal instructions; and no secrets or customer data.
- Route engine, LWC, and schema defects to core; pack defects to examples; integration defects to extensions; organization-owned Apex check behavior remains with the organization unless it exposes a core contract defect.
- Do not create empty cloud folders or imply unvalidated coverage. Mark catalog gaps honestly.

## 4. Extension architecture

### 4.1 Existing Apex check contract

**✅ Completed** — the `RecordHealthCheckRule` interface, `RecordHealthCheckContext`, and `RecordHealthCheckResult` are implemented in core today. Cross-package visibility for the intended packaging model is verified only when packaging is undertaken (deferred; Section 9).

Core retains:

```apex
public interface RecordHealthCheckRule {
  RecordHealthCheckResult evaluate(RecordHealthCheckContext context);
}
```

Core constructs and validates context, invokes the implementation, normalizes failures, validates results, and enforces supported statuses and security boundaries. Implementations declare sharing, enforce CRUD/FLS as required, remain limit-conscious, avoid uncontrolled side effects, validate parameters defensively, and do not depend on engine internals.

Cross-package visibility must be tested against the intended unlocked or managed packaging model. Only the smallest contract surface should become `global`.

### 4.2 Evaluation lifecycle event

**✅ Completed** — V2 ships the two minimal, versioned, opt-in lifecycle events using high-volume Publish After Commit semantics. Publication is bulked, best effort, payload-minimized, and verified with rollback and two materially different consumers (2026-07-13). Independent rollup: [`audits/2026-07-13-section-4-extension-architecture-verification.md`](audits/2026-07-13-section-4-extension-architecture-verification.md).

The recommended result-consumer contract is core-owned `Record_Health_Check_Rule_Result__e`. It represents one finalized Rule-result fact and supports observability, alerts, work creation, external export, analytics, and automation without synchronous coupling. Its emission is bounded by the safety model in Section 4.19: on-load evaluations never publish, and publication is opt-in and limited to deliberately initiated contexts.

The contract must specify emission for top-level and dependency evaluations, skipped and unable outcomes, system errors, cache hits, transaction rollback, correlation IDs, payload version, and sensitive-detail policy. Event payloads should default to metadata identifiers and outcome data, not business record content.

Conceptual V1 fields are:

| Field                         | Contract purpose                                    |
| ----------------------------- | --------------------------------------------------- |
| `ContractVersion__c`          | Schema and semantic version                         |
| `EventId__c`                  | Core-generated idempotency key                      |
| `RunId__c`                    | Correlates one card/API run                         |
| `EvaluationId__c`             | Identifies this evaluation                          |
| `ParentEvaluationId__c`       | Links prerequisite/dependency evaluation            |
| `OccurredAt__c`               | Completion time                                     |
| `CheckSetDeveloperName__c`    | Stable Check Set identity                           |
| `RuleDeveloperName__c`        | Stable Rule identity                                |
| `RecordId__c`                 | Evaluated record, subject to data policy            |
| `ObjectApiName__c`            | Evaluated object                                    |
| `Status__c`                   | Terminal outcome                                    |
| `Severity__c`                 | Effective failure severity                          |
| `EvaluatorType__c`            | Stable evaluator identifier                         |
| `DurationMs__c`               | Defined evaluation duration                         |
| `ReasonCode__c`               | Stable machine-readable reason                      |
| `InvokedByUserId__c`          | Calling user when permitted                         |
| `OnBehalfOfUserId__c`         | Effective/delegated user                            |
| `Source__c`                   | LWC, Apex API, Flow, batch, or other registry value |
| `CoreVersion__c`              | Publishing core version                             |
| `ContainsRestrictedDetail__c` | Signals suppressed/classified details               |

Messages, raw queries, found/expected values, and full results are excluded by default. The result-consumer event context is intentionally different from `RecordHealthCheckContext`, which is input to check implementations.

Recommended semantics are one event per completed top-level evaluation request, all terminal outcomes, explicit dependency linkage when dependencies are emitted, no undocumented cache duplicates, best-effort publication, and no result change on publish failure. Contract V1 must explicitly choose **Publish Immediately** or **Publish After Commit**.

Consumers assume at-least-once delivery, possible duplicates, opaque/non-contiguous replay IDs, and no unsupported ordering guarantee. Use `EventId__c` or `EventUuid`, never Replay ID, for identity/idempotency. `EventBus.publish` success means enqueued, not finally delivered. Publish callbacks, if required, run separately as Automated Process and need explicit initiating-user context. Subscribers must be bulkified and define replay, retry, resume, monitoring, and idempotency behavior.

### 4.3 Competing synchronous sink proposal

Claude's plan proposed a synchronous `RecordHealthCheckResultSink`, sink context, dispatcher, and per-plugin registry records. This provides immediate in-transaction handling and can fit controlled unpackaged installations, but shares limits and latency with evaluation, complicates namespace resolution, and creates stronger failure-isolation obligations.

The consolidated recommendation chooses the lifecycle event as the primary result-consumer contract. The sink design is **not lost**: it is retained as a deferred, separately versioned opt-in contract if a real use case requires synchronous interception. If adopted later, use per-extension registry records rather than a shared comma-separated class list, isolate each failure, prohibit result mutation by best-effort sinks, and prove two independent sinks before publication.

### 4.4 Diagnostics

Diagnostic logging is separate from completed evaluation outcomes. It may later use a stable diagnostic event or configured adapter, but should not be conflated with the lifecycle event. A logger adapter must define failure behavior, limits, data classification, and security context.

Keep `RecordHealthCheckLogger` internal until there are at least two credible integrations. A future adapter may resemble `RecordHealthCheckLogAdapter.write(RecordHealthCheckLogEntry)`, but synchronous adapters share transaction limits and require dynamic loading/namespace rules. A diagnostic event offers better isolation but adds event volume and asynchronous visibility.

#### Three information levels

| Information level     | Contract                                   | Intended consumers                                                 |
| --------------------- | ------------------------------------------ | ------------------------------------------------------------------ |
| Check Set execution   | `Record_Health_Check_Set_Run__e`           | Adoption, usage, performance, aggregate outcome analytics          |
| Rule outcome          | `Record_Health_Check_Rule_Result__e`       | History, notifications, work creation, exports, audit integrations |
| Framework diagnostics | Future `Record_Health_Check_Diagnostic__e` | Troubleshooting, support tooling, diagnostic logging integrations  |

The first two contracts contain stable product facts. They are not debug dumps. The diagnostic contract is separate because diagnostic volume, sensitivity, retention, and compatibility differ from result telemetry.

#### Broadly useful structured facts

The Set Run event includes contract/core versions, event/run identity, Check Set identity, record/object subject to policy, lifecycle phase, invocation source and identity, timestamps, total duration, eligible/evaluated Rule counts, outcome counts, diagnostics authorization state, and a stable reason code.

The Rule Result event includes contract/event/run/evaluation identity, parent evaluation, Check Set and Rule identity, record/object subject to policy, status, failure severity, reason code, evaluation type and role, duration, source and identity, category/order where contractually useful, cache indicator, found/expected-detail presence flags, multi-record counts, core version, and completion timestamp.

Lifecycle events exclude raw SOQL, formula source, Apex JSON, stack traces, raw exception text, console output, arbitrary record values, found/expected values, user-authored messages, action URLs, session identifiers, and access tokens by default. Plugins use stable codes and typed fields, never display text, as integration keys.

#### Diagnostic event shape

If at least two credible diagnostic consumers justify a public contract, the core-owned event is `Record_Health_Check_Diagnostic__e`, shared by all diagnostic plugins. Conceptual fields are:

| Field                         | Purpose                                     |
| ----------------------------- | ------------------------------------------- |
| `ContractVersion__c`          | Diagnostic schema/semantic version          |
| `EventId__c`                  | Idempotency key                             |
| `RunId__c`                    | Check Set run correlation                   |
| `EvaluationId__c`             | Rule correlation when applicable            |
| `OccurredAt__c`               | Diagnostic timestamp                        |
| `Level__c`                    | Stable DEBUG/INFO/WARN/ERROR level registry |
| `Component__c`                | Stable core component identifier            |
| `DiagnosticCode__c`           | Stable machine-readable code                |
| `Summary__c`                  | Bounded, redacted human summary             |
| `DetailJson__c`               | Optional versioned/redacted detail payload  |
| `ContainsRestrictedDetail__c` | Indicates restricted detail classification  |
| `CoreVersion__c`              | Publishing core version                     |

`DiagnosticCode__c`, not `Summary__c` or `DetailJson__c`, is the integration key. Detail JSON has a documented schema/version, maximum length, redaction rules, and allowlist; it is never an arbitrary serialization of an exception or internal object.

#### Automatic error emission

Errors are emitted according to severity and the enabled contract:

| Condition                                                | Rule Result behavior                                                  | Diagnostic behavior                                                                               |
| -------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Normal Pass/Fail/Skipped                                 | Publish when the Rule's `PublishResultEvent__c` is on                 | No automatic diagnostic                                                                           |
| Unable to Evaluate from invalid configuration/data       | Publish status + stable reason when `PublishResultEvent__c` is on     | Optional WARN diagnostic when diagnostic publication is enabled                                   |
| Expected Apex Check exception normalized by the contract | Publish normalized status/reason when `PublishResultEvent__c` is on   | Optional WARN/ERROR diagnostic with redacted context                                              |
| Unexpected system/framework error                        | Publish SYSTEM_ERROR status/reason when `PublishResultEvent__c` is on | Automatically publish a minimal redacted ERROR diagnostic when the diagnostic contract is enabled |
| Set fails before a Rule begins                           | Set Run event reports FAILED_TO_START when `PublishRunEvent__c` is on | Automatically publish a minimal redacted ERROR diagnostic when enabled                            |
| Lifecycle/diagnostic event publication fails             | Returned health-check result remains unchanged                        | Record through a bounded non-event fallback; never recursively publish another diagnostic event   |

Automatic does not mean unconditional telemetry. Set Run and Rule Result publication still obey their metadata checkboxes. The future diagnostic stream requires an explicit org/Set diagnostic-publication policy. Within that enabled stream, unexpected system errors automatically emit the minimal redacted diagnostic even when interactive `ShowDiagnostics__c` is off, because operators need to detect production failures.

Detailed diagnostics remain separately gated: `ShowDiagnostics__c`, the Record Health Check diagnostic-detail custom permission, and the diagnostic publication policy must all allow detail. Without all gates, the event contains only stable identifiers, code, level, timestamp, correlation IDs, core version, and a safe summary. No stack trace, query, formula, record value, or user-authored content is included.

Use a recursion guard and a non-event fallback such as the existing bounded internal logger for publication failures. Core must not enter `publish failure → diagnostic event → publish failure` recursion.

### 4.5 Independent extension packages

Each extension owns its metadata, permissions, subscribers, storage, retries, tests, and documentation. An extension manifest declares core compatibility, consumed contract version, dependencies, permissions, data behavior, install steps, and removal steps.

Acceptance matrix:

- core alone works;
- core plus one extension works;
- core plus that extension and an unrelated extension works;
- removing the extension requires no core source change;
- extension failure does not alter evaluation unless the contract explicitly promises synchronous interception.

Every `extension.yml` must declare identity, capability, outcome, core and contract versions, extension dependencies, Salesforce features/editions/API version, packaging/namespace assumptions, subscribed and published events, objects/fields accessed or created, installed Apex/Flow/LWC/jobs/triggers/reports/credentials, permissions, execution contexts, volume/limit assumptions, data classification and retention, endpoints/authentication, failure/retry/replay/idempotency behavior, enable/disable/upgrade/uninstall behavior, maturity, and ownership.

Maturity is factual: Experimental, Preview, Supported, Community, or Deprecated. The root catalog is generated from manifests. There is no production `install-all` path and no shared runtime package unless several shipped extensions prove a substantial stable need.

### 4.6 Versioning and testing

- Maintain a registry of supported public types, fields, event schemas, statuses, and reason codes.
- Apply semantic versioning to public contracts and publish deprecation windows.
- Test core contract fixtures, extension consumer fixtures, version compatibility, namespace/package installation, event delivery realities, security context, limits, and a materially different second consumer.
- Do not expose evaluator internals merely to make the first add-on easier.

### 4.7 Extension anti-patterns

Core and extensions must not:

- branch in the engine for metrics, Slack, Cases, or another consumer;
- add extension fields to core result DTOs or extension permissions to core permission sets;
- import, copy, or manually patch core/extension classes across boundaries;
- use undocumented methods, fields, messages, labels, found values, or expected values as integration keys;
- store credentials in metadata, settings, Apex, or repository files;
- require sibling extensions unless a supported schema dependency is explicit;
- let best-effort consumer failure change or stop evaluation;
- register jobs, triggers, or subscribers without disable and removal instructions;
- create a public evaluator-provider API before discovery, configuration, validation, UI, namespace, security, conflict, and uninstall semantics are designed and proven by at least two implementations.

### 4.8 Observability migration and second-consumer proof

Observability is extracted only after the general lifecycle contract exists. Its storage, retention, reports, permissions, retries, and filters remain extension-owned. Core owns only the general Set Run and Rule Result publication checkboxes (plus an optional global emergency override), never observability-specific settings. Validate that observability can be absent, cannot alter results, deduplicates retries, distinguishes dependencies, respects identity/data visibility, and can be upgraded or removed without core changes.

Before freezing V1, validate the same event with a materially different notification, work-item, or export consumer. Scheduled assessment and Flow actions validate the separate public invocation façade, not the result event.

### 4.9 Complete plugin-authoring model

“Plugin” is an ecosystem term, not one runtime interface. Authors choose the smallest supported contract matching what they need to do.

| Plugin shape            | What it does                                                         | Contract used                                              | Execution model                           | Can change a Rule result?                                            |
| ----------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------- | -------------------------------------------------------------------- |
| Custom Check            | Implements organization-specific evaluation logic                    | `RecordHealthCheckRule`                                    | Synchronous during evaluation             | Yes, by returning its documented result                              |
| Result Consumer         | Reacts to each Rule outcome                                          | `Record_Health_Check_Rule_Result__e`                       | Asynchronous                              | No                                                                   |
| Run Consumer            | Tracks component/API usage and whole-Set-run completion              | `Record_Health_Check_Set_Run__e`                           | Asynchronous                              | No                                                                   |
| Invocation Adapter      | Starts health checks from Flow, schedule, batch, REST, or another UI | Public `RecordHealthCheck` façade                          | Caller-selected, within documented limits | Only by choosing documented invocation inputs                        |
| Reporting/Content Pack  | Reports on extension-owned history                                   | Extension storage schema                                   | Read/report time                          | No                                                                   |
| Remediation Experience  | Offers follow-up UI/actions based on outcomes                        | Public read API plus documented action/navigation contract | Separate user action                      | Never retroactively                                                  |
| Diagnostic Integration  | Routes framework diagnostic entries                                  | Future diagnostic event or logger adapter                  | Prefer asynchronous                       | No                                                                   |
| Synchronous Interceptor | Must act before evaluation returns                                   | Future opt-in sink contract                                | Synchronous, shared limits                | No by default; any mutation contract would be separate and high risk |
| Evaluator Provider      | Adds a new metadata-driven evaluation mechanism                      | Future provider contract                                   | Synchronous                               | Potentially; deferred                                                |

The first four shapes are the practical V2 ecosystem. The final three remain deferred until multiple implementations demonstrate stable requirements.

### 4.10 Two-level lifecycle contract

These are **two core-owned domain event types for the entire ecosystem**, not event types created per plugin. A plugin never adds `Slack_Event__e`, `Metrics_Event__e`, `Case_Event__e`, or another core publication. Fifty plugins may consume the same run and evaluation streams; the number of event schemas remains two unless the core domain itself gains a genuinely different lifecycle fact.

#### Run lifecycle

Core publishes `Record_Health_Check_Set_Run__e` for use of the component or public façade. It describes one Check Set run containing zero or more Rule evaluations.

Recommended run phases are `STARTED`, `COMPLETED`, `CANCELLED`, and `FAILED_TO_START`. A page view alone should not count as a run unless automatic execution actually begins. If the product needs component-impression analytics, add a separately consented `COMPONENT_VIEWED` activity rather than silently redefining a health-check run. Automatic on-load evaluation is observational: it displays results but never publishes Rule Result events, regardless of publication settings (Section 4.19).

Conceptual run fields:

| Field                      | Purpose                                                                      |
| -------------------------- | ---------------------------------------------------------------------------- |
| `ContractVersion__c`       | Run-event schema/semantic version                                            |
| `EventId__c`               | Event idempotency key                                                        |
| `RunId__c`                 | Stable correlation ID shared by every Rule event                             |
| `Phase__c`                 | Started, completed, cancelled, or failed to start                            |
| `OccurredAt__c`            | Phase timestamp                                                              |
| `CheckSetDeveloperName__c` | Stable Check Set identity                                                    |
| `RecordId__c`              | Evaluated record when policy permits                                         |
| `ObjectApiName__c`         | Evaluated object                                                             |
| `InvokedByUserId__c`       | User who initiated the run                                                   |
| `OnBehalfOfUserId__c`      | Effective/delegated user when applicable                                     |
| `Source__c`                | LWC, Apex, Flow, batch, schedule, REST, or registry value                    |
| `ClientSessionId__c`       | Optional bounded correlation for one UI session, never a browser fingerprint |
| `EligibleRuleCount__c`     | Rules eligible after configuration/applicability loading                     |
| `EvaluatedRuleCount__c`    | Rules that reached evaluation                                                |
| `PassedCount__c`           | Passed Rules                                                                 |
| `FailedCount__c`           | Failed Rules                                                                 |
| `SkippedCount__c`          | Skipped/not-applicable Rules under the final status contract                 |
| `UnableCount__c`           | Unable-to-evaluate Rules                                                     |
| `SystemErrorCount__c`      | Unexpected framework/extension errors                                        |
| `DurationMs__c`            | Whole-run duration with defined clock boundaries                             |
| `DiagnosticsEnabled__c`    | Whether diagnostics were requested and authorized                            |
| `CoreVersion__c`           | Publishing core version                                                      |
| `ReasonCode__c`            | Stable reason for cancellation/failure-to-start                              |

The completion event must be derivable from the actual finalized result collection. Consumers must tolerate a `STARTED` event with no completion due to rollback, browser navigation, limits, or asynchronous publication failure. Analytics extensions define a timeout policy for abandoned runs rather than asking core to fabricate completion.

#### Rule-evaluation lifecycle

`Record_Health_Check_Rule_Result__e` publishes one event for each finalized Rule outcome and carries the `RunId__c`. It includes prerequisite/dependency linkage, evaluator type, status, severity, reason, duration, and stable metadata identity. Whether prerequisite evaluations emit their own events is explicit; if they do, `ParentEvaluationId__c` and an evaluation-role value distinguish them from top-level Rules.

The lifecycle publisher should accept the finalized run and result model at one internal seam, bulk publish event lists, and contain no extension-specific branches.

### 4.11 Plugin capability permutations

The supported contracts combine into common plugin designs:

| Desired plugin                     | Contracts and extension-owned assets                                                                             |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Capture every Rule outcome         | Rule event subscriber, history object, retention CMDT, cleanup job, reports, permission sets                     |
| Measure component adoption         | Run event subscriber, daily/user/Check Set aggregates, dashboards, retention rules                               |
| Identify who ran checks            | Run events with invoking/effective identity under explicit privacy and permissions policy                        |
| Detect unused Check Sets or Rules  | Run + Rule history, catalog snapshot, scheduled aggregation; never infer from current CMDT alone                 |
| Notify on critical failures        | Rule subscriber, filter/recipient CMDT, queueable/callout, Named Credential, cooldown/idempotency store          |
| Create Cases, Tasks, or work items | Rule subscriber, mapping CMDT, idempotency key, user-mode or explicitly justified system-mode DML                |
| Export to SIEM/data lake           | Run and/or Rule subscriber, queueable, Named/External Credential, retry/dead-letter storage                      |
| Durable audit history              | Minimal classified event payload, immutable extension storage, retention/legal-hold policy, restricted reporting |
| Operational performance monitoring | Run and Rule duration/reason aggregates; no business values required                                             |
| Scheduled assessments              | Schedulable/batch invocation adapter using the façade; optional lifecycle consumer for history                   |
| Flow action                        | Invocable wrapper around the façade with documented DTO mapping and bulk limits                                  |
| REST/API wrapper                   | Authenticated façade adapter; no exposure of internal evaluator classes                                          |
| Additional dashboard pack          | Reports/dashboards depending explicitly on a supported observability storage package                             |
| Custom remediation UI              | LWC plus public read/action contract; extension permission set; no core component patch                          |
| Reusable Apex Rule library         | Apex Check contract plus optional example CMDT in an examples/rule pack                                          |
| Logging framework integration      | Future diagnostic contract for debug entries plus lifecycle events for outcomes                                  |
| Custom evaluation mechanism        | Keep in core or use Apex Check until provider discovery/config/UI/security contracts exist                       |

Plugins may consume both run and Rule events. They may also invoke checks and then consume their events. This does not permit circular synchronous calls, recursively starting checks from their own lifecycle subscriber without an explicit recursion/idempotency guard, or assuming delivery before the invoking transaction returns.

### 4.12 Configuration permutations and ownership

Core configuration remains general:

- optional global/org lifecycle publication policy or emergency kill switch;
- `PublishRunEvent__c` on the Check Set for Set Run event publication;
- `PublishResultEvent__c` on each Rule for Rule Result event publication;
- security permission controlling restricted diagnostic/detail publication;
- stable contract/version registries.

The checkboxes are independent:

| Set `PublishRunEvent__c` | Rule `PublishResultEvent__c` | Published behavior                                                                        |
| -----------------------: | ---------------------------: | ----------------------------------------------------------------------------------------- |
|                      Off |                          Off | No lifecycle event for the run or that Rule                                               |
|                       On |                          Off | Set Run events only                                                                       |
|                      Off |                           On | Rule Result event only; it still carries `RunId__c`, but no Set Run envelope is published |
|                       On |                           On | Both streams publish and correlate through `RunId__c`                                     |

Rule publication does not inherit from or require the Set checkbox. Each checkbox controls only the event type named in its label. This avoids one overloaded master switch and lets an organization capture adoption without Rule details, selected Rule outcomes without Set-run telemetry, or both.

Both fields default to `false`, so installing or upgrading core does not silently begin publishing user/activity data or consuming event allocations. An administrator opts in deliberately. Even when enabled, `RUN_ON_LOAD` evaluations never publish Rule Result events; the switches apply only to deliberately initiated contexts such as the public façade, a scheduled run, or an explicit user-initiated run (Section 4.19). Inactive Sets and Rules publish nothing because they do not run. A finalized skipped/unable/error result publishes when the Rule checkbox is on; the plugin filters statuses downstream rather than changing publication semantics.

Core should expose the effective publication state in authorized diagnostics and administrative validation. Consumers and dashboards must distinguish “no activity” from “publication disabled.” A global emergency kill switch, if implemented, overrides both checkboxes but never silently rewrites their stored values.

Every plugin owns its behavior-specific settings. Examples include:

- observability retention days, aggregation grain, and included statuses;
- notification status/severity filters, recipients, cooldown, and channel;
- work-item object, record type, owner, deduplication window, and field mappings;
- exporter endpoint reference, batch size, retry policy, and data classification;
- scheduler selection query, cadence, scope size, and effective user;
- dashboard package dependency on a specific storage schema version.

Plugin settings may use extension-owned CMDT for deployable configuration, custom settings/custom objects for subscriber-editable or secret-free operational state, Platform Cache only for non-durable acceleration, and Named/External Credentials for secrets. Never place credentials in CMDT, Apex, event payloads, or repository files.

### 4.13 Identity, privacy, and activity measurement

Activity data can become employee-monitoring or sensitive operational data. The contract therefore distinguishes:

- **invoked by:** who initiated the request;
- **on behalf of:** whose authority/context was intended;
- **running as:** actual Apex/event subscriber execution identity;
- **record owner:** business ownership, not invocation identity;
- **Automated Process:** event delivery identity, never a substitute for the initiator.

Recommended telemetry profiles:

| Profile                | Included by default                                             | Excluded by default                                          |
| ---------------------- | --------------------------------------------------------------- | ------------------------------------------------------------ |
| Minimal operations     | Metadata identity, status, reason, source, timing, version      | User, record, messages, values                               |
| Adoption analytics     | Above plus invoking user and run counts, where policy permits   | Record values, queries, messages                             |
| Record audit           | Above plus Record ID under restricted permissions and retention | Found/expected values and raw configuration                  |
| Restricted diagnostics | Explicitly enabled detail under custom permission               | Unbounded payloads, secrets, raw session/browser identifiers |

Core should publish the minimum profile required by the selected contract. Extensions cannot recover omitted sensitive values by querying inaccessible records in system mode. Every storage plugin documents purpose, lawful/organizational policy, access, retention, deletion, export, encryption considerations, and whether users can be identified in reports.

“How active is the component?” must be defined through measures, not one ambiguous counter:

- runs started and completed;
- unique invoking users in a period;
- active Check Sets;
- records assessed;
- median and percentile duration;
- completion/abandonment rate;
- Rules evaluated, skipped, unable, and errored;
- last-used timestamp per Check Set/Rule;
- invocation source distribution;
- automatic versus user-requested runs.

Do not fingerprint browsers, count mere component rendering as evaluation, or retain per-user data indefinitely merely because it is technically available.

### 4.14 Failure, volume, and transaction permutations

| Situation                     | Required behavior                                                                              |
| ----------------------------- | ---------------------------------------------------------------------------------------------- |
| No plugin installed           | Core evaluates normally                                                                        |
| One subscriber fails          | Core result and other subscribers remain unaffected                                            |
| Duplicate event               | Consumer deduplicates by stable event/evaluation ID                                            |
| Events delivered in a batch   | Subscriber bulk-processes and avoids per-event SOQL/DML                                        |
| Publish enqueue fails         | Core records bounded diagnostics; result remains unchanged                                     |
| Publish ultimately fails      | Callback/monitoring handles it if the contract promises confirmation                           |
| Caller transaction rolls back | Behavior follows documented publish mode                                                       |
| User closes/navigates away    | Started run may become abandoned under extension timeout policy                                |
| Extension callout fails       | Queueable retry with bounded backoff/dead-letter policy                                        |
| Storage reaches limits        | Extension degrades/alerts according to its own operational contract                            |
| High-volume automatic runs    | Aggregation, sampling, or publication policy is explicit; no silent data loss                  |
| Subscriber replays events     | Idempotency and retention window are documented                                                |
| Plugin uninstalled            | Core and sibling plugins continue; jobs/subscribers/config/storage removal behavior documented |

Event publication consumes platform allocations and Apex limits. Contract tests must measure worst-case Rules per run, bulk runs, dependency evaluations, event batch sizes, subscriber retries, and storage growth. Product owners must decide whether every Rule event is always published, filtered by Check Set, sampled only for analytics, or disabled by default. Sampling is never appropriate for audit plugins unless explicitly documented.

### 4.15 Packaging and composition permutations

- **Source deploy:** suitable for OSS evaluation; dependencies and removal are manual.
- **Unlocked 2GP:** versioned installation and clean dependency declaration; suitable for independently installable open extensions.
- **Managed 2GP:** appropriate for AppExchange/commercial distribution; requires deliberate `global` contract visibility and namespace tests.
- **Same namespace packages:** test namespace-access mechanisms before widening APIs.
- **Extension composition:** allowed only through declared supported schemas. For example, dashboards may depend on observability storage; notifications should normally subscribe directly to core events.
- **Convenience bundles:** may document a tested set but cannot become the only supported install path.
- **Organization-owned plugin:** may remain unpackaged, but must still use public contracts and avoid internal dependencies.

Every packaging permutation is tested for fresh install, minimum-supported upgrade, current upgrade, permission assignment, disable, uninstall where possible, namespace visibility, and coexistence with an unrelated plugin.

### 4.16 Plugin-author acceptance checklist

A plugin is publishable only when:

1. Its plugin shape and consumed contract are explicit.
2. Core needs no source, permission-set, result-DTO, or extension-specific metadata change.
3. Its manifest declares versions, packaging, features, installed assets, data behavior, execution context, limits, retries, idempotency, and removal.
4. Security documents sharing, CRUD/FLS, user/system mode, event access, credentials, and sensitive fields.
5. Tests prove core alone, plugin alone with core, coexistence with an unrelated plugin, bulk delivery, duplicates, failure isolation, upgrade, disable, and uninstall behavior.
6. Machine logic uses stable status/reason/identity fields, never labels or messages.
7. Operational monitoring tells administrators when subscribers, jobs, callouts, or storage fail.
8. Documentation explains purpose, exact side effects, configuration, expected volume, retention, and removal in plain language.

### 4.17 Ecosystem fan-out and scale model

#### Stable event vocabulary

Core publishes a small domain vocabulary:

1. `Record_Health_Check_Set_Run__e`: Check Set run lifecycle facts.
2. `Record_Health_Check_Rule_Result__e`: finalized Rule-result facts.

All plugin-specific behavior is downstream. Notifications, observability, Cases, exports, dashboards, and future consumers do not receive dedicated core events or dedicated fields. New plugins declare which existing stream and event phases/statuses they need.

Adding a third core event type requires architectural review and all of these conditions:

- it represents a durable core-domain fact that cannot be expressed as a run or Rule evaluation;
- at least two unrelated consumers require it;
- adding it is clearer and cheaper than extending an existing schema;
- publication, security, volume, retention, and compatibility semantics are fully specified;
- it does not name or encode one plugin capability.

#### Direct subscription does not scale without a budget

Event-type count stays constant, but delivery work can still grow with fan-out. A rough capacity model is:

```text
published events per run
  = run phase events + emitted Rule events

delivered notifications
  ≈ published events × subscribers receiving each stream
```

For example, a run with STARTED + COMPLETED and 20 Rule outcomes publishes 22 events. If 10 independent subscribers receive every event, the system can perform roughly 220 deliveries. Filters, on-platform execution behavior, licensing, and the selected subscriber technology affect the exact allocation, so every release must calculate against the target org's current Salesforce entitlements and measured workload.

The platform retains events for a bounded replay window and applies publishing, delivery, concurrent-subscriber, and API allocations. Those values vary by edition, license, add-ons, and Salesforce release; keep them in deployment guidance, not hard-coded into the contract.

#### Scale tiers

| Tier                              | Recommended topology                                                                                                     | Use when                                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| A: Small ecosystem                | Each on-platform plugin subscribes directly to the shared event it needs                                                 | Few plugins, moderate run volume, allocations validated                                                |
| B: Curated on-platform ecosystem  | Direct subscribers plus strict filters, bulk processing, event-budget monitoring, and publication controls               | Several plugins or high automatic-run volume                                                           |
| C: External integration ecosystem | One Pub/Sub gateway subscription per stream, then fan out through an external broker to many consumers                   | Many external plugins, cross-org consumers, or delivery allocations make direct subscriptions wasteful |
| D: Analytics-heavy deployment     | One observability consumer persists a governed history/aggregate schema; reporting plugins consume that supported schema | Many dashboards/analytics that do not need real-time independent event delivery                        |

Tier D does not make observability mandatory for operational plugins. Notifications and exports may still consume core events directly. It prevents ten dashboard packages from each storing the same raw stream.

#### Subscription filtering

Plugins declare filters such as event phase, status, severity, Check Set, evaluator type, or source. Apply filtering as early as the supported subscriber technology permits so irrelevant notifications are not delivered or processed. Do not publish separate event types merely to simulate filters.

Examples:

- adoption analytics consumes run STARTED/COMPLETED, not Rule details;
- critical notification consumes failed Rule outcomes at Critical severity;
- performance monitoring consumes run completion plus Rule duration/reason;
- audit history consumes all required events with no sampling;
- dashboard content consumes observability aggregates rather than the raw bus.

Filters are deployment configuration owned by the plugin or integration gateway. Core must not add one checkbox or branch per consumer.

#### Optional gateway/broker pattern

For dozens of external consumers, use one durable Pub/Sub API gateway per org/stream and fan out through an external broker or integration platform. The gateway owns replay checkpoints, backpressure, consumer groups, dead-letter handling, and per-consumer routing. This reduces direct Salesforce subscriber connections and repeated deliveries while keeping the core event contract unchanged.

The gateway is optional infrastructure, not a required core plugin and not a place to redefine event semantics. Consumers still key integrations by core contract version, stable IDs, status, and reason codes.

For dozens of on-platform packages, an optional on-platform router may be considered only after direct-subscription scale tests fail. Such a router must remain generic, use a versioned registration contract, isolate each handler, handle namespaces, avoid a shared comma-separated class list, and prove that its synchronous/asynchronous limits are better than native fan-out. It must not become a hidden mandatory extensions runtime.

#### Event-volume controls

Controls are ordered from least to most lossy:

1. Plugins subscribe only to the stream they need.
2. Filter by phase/status/severity/source/Check Set.
3. Avoid duplicate cache/prerequisite events unless contractually required.
4. Bulk publication and subscriber processing.
5. Aggregate durable analytics after one ingestion.
6. Configure Set Run publication through `PublishRunEvent__c` and Rule Result publication through `PublishResultEvent__c`.
7. Sample only explicitly non-audit analytics.

Never sample compliance/audit history silently. Never suppress failed/system-error outcomes without an explicit policy. Publication controls must be observable so an administrator can distinguish “no activity” from “telemetry disabled or dropped.”

#### Capacity and operability gates

Before approving an ecosystem size or plugin combination, measure:

- peak and daily runs by source;
- average, maximum, and prerequisite Rule evaluations per run;
- run phase events enabled;
- subscribers per stream and their filters;
- projected publish and delivery allocation consumption;
- subscriber CPU, SOQL, DML, callout, and queueable usage;
- replay lag, duplicate rate, failures, and dead-letter count;
- observability storage growth and retention;
- behavior during batch/data-load spikes and plugin outages.

Use Salesforce event-usage telemetry and plugin-owned operational dashboards to alert before allocations are exhausted. The extension catalog should show a tested compatibility/capacity profile for common combinations rather than claiming an arbitrary maximum plugin count.

Platform references for implementation-time capacity planning:

- [Pub/Sub API and event allocations](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/allocations.html)
- [Event message durability and replay](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/event-message-durability.html)
- [Pub/Sub API flow control](https://developer.salesforce.com/docs/platform/pub-sub-api/references/methods/subscribe-rpc.html)
- [Salesforce event-driven design and filtered streams](https://developer.salesforce.com/blogs/2022/10/design-considerations-for-change-data-capture-and-platform-events)

### 4.18 Public check-response façade

**✅ Completed** — the bounded, user-mode façade now evaluates one Rule or Check Set for single and bulk callers, returns versioned normalized responses, and exposes an index-aligned Flow action. Scratch-org capacity and fail-fast behavior are verified (2026-07-13).

Core exposes a first-class, synchronous **check-response façade** (promoted from the previously deferred invocation adapter): a public API to evaluate a Rule or Check Set and get a structured result synchronously in the caller's transaction, distinct from the asynchronous lifecycle events, which remain for after-the-fact consumers.

- **Granularity.** Evaluate one Rule or one Check Set against a record. Rule-level granularity gives the reuse benefit of a shared rule without a junction object; the Rule keeps its required parent Check Set for authoring.
- **Bulk.** Accept a record-Id list and return one response per record, so consumers can evaluate across a list view without per-record calls.
- **Execution.** User mode, so the caller's CRUD/FLS governs field access and the response reflects exactly what the caller is authorized to see.
- **Return shape.** The normalized result model already produced for the LWC: a Rule response (status, failure severity, reason code, check title, resolved failure/fix messages, found/expected values subject to authorization, action label/URL) and a Check Set envelope (overall status, outcome counts, and the per-Rule response list).
- **Declarative access.** A Flow-invocable wrapper over the same façade, because many Salesforce admin consumers are declarative-first.
- **Stability.** The response carries a contract version and grows additive-only. The façade surface is intentionally small so it can later become a packaged `global` contract without redesign.

Consumers key on stable status/reason/severity/identity fields, never display text. Until the surface stabilizes it is published as **pre-1.0**, and consumers are told it may change.

The field-level-security and unavailable-field response policy (Section 6) defines what the façade returns when a caller cannot see a field; it is on the critical path for this contract.

### 4.19 Emission and actuation safety model

**✅ Completed** — lifecycle publication is default-off, page-load and subscriber contexts are hard-stopped before configuration lookup, publish failures cannot change health results, and rollback produces no phantom delivery (2026-07-13).

Record Health Check earns its value by being immediate: an authorized user opens a record and sees its health with no click, no configuration, and no side effect. That experience is the product and must not be traded away for telemetry or automation. This section states the one safety principle that protects it, and confirms the principle adds no metadata, no modes, and no required administrator decisions.

#### Intended core behavior

```text
Open record
→ checks run automatically
→ results display
→ nothing else happens
```

Diagnosis is automatic; treatment requires intent. The framework evaluates and displays; it does not create records, call external systems, or publish activity merely because a record was viewed.

#### Responsibility boundary

```text
Core framework:        automatic diagnosis and display
Optional rule action:  a user-initiated action link the author may add
Platform events:       optional observation/integration, disabled by default
Automatic remediation: extension responsibility, never core
```

#### The on-load publication rule

`RUN_ON_LOAD` evaluations never publish Rule Result events, regardless of whether publication is enabled anywhere else. "Default off" alone is not sufficient, because an administrator could enable a switch without understanding that a busy record page would then emit at page-view frequency. Prohibiting on-load publication by design removes the dangerous trigger-and-actuator combination instead of leaving it one checkbox away.

Publication switches (`PublishRunEvent__c`, `PublishResultEvent__c`) therefore apply only to deliberately initiated execution contexts:

- an explicit programmatic request through the public façade;
- a scheduled or batch evaluation;
- and, where a product decides to allow it, an explicit user-initiated run.

This eliminates page-view-driven fan-out completely. A `Set_Run__e` for adoption analytics, if ever wanted, remains a separately consented activity (Section 4.10), never a byproduct of viewing a record.

#### The action link is not core actuation

`ActionLabel__c`/`ActionUrl__c` present an optional, author-defined, user-initiated action link that does not depend on result-event publication. The link's destination — a record page, Flow, or documented URL — may itself perform asynchronous work or publish its own events; that is the destination's contract, not core's. What core guarantees is narrow and firm: the framework does not publish a Rule Result event merely because an action link was displayed or clicked. Showing a "Create follow-up task" link is not emission.

#### Principle

> Record Health Check automatically evaluates and displays record health. Page-load evaluations are observational and never publish result events. Rules may optionally present a user-initiated action link. Platform-event publication is disabled by default and limited to non-page-load execution contexts. Automatic remediation and subscriber behavior remain outside core and belong in explicitly installed extensions.

This safety story requires no new metadata, no new modes, no required buttons, and no extra decisions for ordinary administrators — and it makes it impossible for merely viewing a record to start an automation chain.

## 5. Contribution, conduct, and release policy

### 5.1 Contribution workflow

Contributors search existing issues, use the appropriate issue template, avoid public disclosure of security issues, create focused branches, add tests, run formatting/lint/Jest/coverage gates, and open PRs against `main`. Apex changes also require the full Apex suite and clean scratch-org validation.

Bug reports should identify Check Set and Rule developer names, expected and actual behavior, relevant sanitized configuration, org type, API version, and authorized diagnostic summaries. Never disclose tokens, session IDs, full org IDs, or customer data.

### 5.2 Review bar

- Positive and misconfiguration tests accompany behavior changes.
- Jest thresholds remain statements 85%, branches 75%, functions 90%, and lines 85% unless the repository intentionally revises them.
- New evaluator behavior updates runtime validation, deploy-time validation, reason-code docs, and tests.
- Shared parsers and comparison modules are extended rather than duplicated.
- Documentation uses active voice, avoids filler, introduces fenced blocks, and remains synchronized with code.

### 5.3 Community conduct

Participation must remain welcoming, respectful, inclusive, empathetic, and focused on the community. Harassment, sexualized conduct, trolling, personal attacks, disclosure of private information, and other unprofessional behavior are unacceptable. Maintainers may moderate contributions and must investigate reports fairly while protecting reporter privacy. The policy follows Contributor Covenant 2.1.

## 6. Decisions still requiring explicit release sign-off

The source proposals converge strongly, but these items need a recorded owner and final release decision:

Recorded V2 decisions (owner: Core maintainers; decided 2026-07-13): lifecycle events ship in V2; both event types are high-volume **Publish After Commit**; V1 carries only stable metadata identity, outcome, correlation, source, version, and aggregate counts; record/user identity and business values are excluded; only `COMPLETED` Set runs ship initially; component impressions are excluded; and both metadata publication switches default off. V2 distributes core as source with no namespace; package-version install/upgrade and cross-package `global` visibility are deferred until a package model is deliberately adopted.

- exact V2 picklist registry, labels, and defaults, verified against shipped metadata;
- whether lifecycle events ship in the initial V2 release or a later extension milestone;
- exact lifecycle event payload, publication semantics, and data-minimization policy;
- whether run lifecycle uses paired STARTED/COMPLETED events, which optional phases ship, and whether component impressions are deliberately excluded;
- default telemetry profile, per-Check-Set lifecycle gate, Record ID/user identity policy, retention expectations, and high-volume publication policy;
- field-level-security and unavailable-field response policy is defined in Section 2.11 — neutral degradation in normal mode, honest detail only under authorized diagnostics, enforced server-side; the remaining open item is verifying `USER_MODE` formula-evaluation behavior in a scratch org (on the critical path for Section 4.18);
- unlocked versus managed packaging model and required Apex visibility;
- identity and contents of the one core hero example — **decided:** `Example_Account_360_Health_Check` (see [`audits/2026-07-13-section-3-core-example-boundary-audit.md`](audits/2026-07-13-section-3-core-example-boundary-audit.md));
- examples and extensions repository names and whether migration stages temporarily use package directories in the current repository — **decided:** `RecordHealthCheck-Examples`; core sample manifests retained during transition;
- compatibility/deprecation statement for the breaking field and Apex API changes;
- ownership and private reporting channel for Code of Conduct incidents.

## 7. Source reconciliation notes

This plan's authoritative inputs are the shipped V2 metadata, the exact `field-migration-before-after.md` map, `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`. The earlier Claude, Codex, and Cursor planning drafts have been consolidated into this document and archived under `recycle-bin/`; they are superseded rationale, not parallel recommendations.

Where drafts disagreed, the implemented migration map and the locked decisions take precedence. Update this plan whenever the shipped V2 metadata differs from the migration map, so it remains a reliable product and architecture reference.

## 8. Feature-disposition register

This register prevents an idea from disappearing merely because it was not selected.

| Source feature or debate                                      | Disposition                                                                                                                                            | Consolidated location |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------- |
| Keep Rule versus rename metadata type to Check                | Keep `Record_Health_Check_Rule__mdt`                                                                                                                   | 1.2, 2                |
| Card/panel/component vocabulary                               | Adopt Card                                                                                                                                             | 1.2, 2.1              |
| Separate runtime title versus standard Label                  | Keep `CheckTitle__c`                                                                                                                                   | 1.2, 2.2              |
| Checkbox versus picklist decision rule                        | Adopt                                                                                                                                                  | 1.2                   |
| `UPPER_SNAKE_CASE` versus PascalCase stored values            | Adopt shipped uppercase contract                                                                                                                       | 1.3, 2.9              |
| Critical versus Error severity                                | Critical; reserve Error for system failure                                                                                                             | 1.2, 2.2              |
| Meaning-changing defaults                                     | No unsafe defaults                                                                                                                                     | 1.3, 2.9              |
| Exact field rename contract                                   | Adopt migration map                                                                                                                                    | 2.1–2.5               |
| Conditional-required and contradictory-field validation       | Adopt                                                                                                                                                  | 2.6                   |
| `{!Id}` versus `{!record.Id}`                                 | Adopt namespaced V2 syntax                                                                                                                             | 2.7                   |
| Namespaces for record/check/set/result                        | Adopt                                                                                                                                                  | 2.7                   |
| Typed SOQL binding versus string replacement                  | Adopt typed binding                                                                                                                                    | 2.7                   |
| Merge support in formulas/JSON/picklists                      | Explicitly unsupported                                                                                                                                 | 2.7                   |
| 2K/8K sizing tiers versus generated metadata sizes            | Resolve through shipped-size registry                                                                                                                  | 2.8                   |
| Skip versus Not Applicable                                    | **Option A adopted 2026-07-13:** one `SKIPPED` status, differentiated by stable reason code                                                            | 2.10, 6               |
| Category as outcome versus cloud/mechanism                    | Outcome in core; other facets in examples                                                                                                              | 2.2, 3.3              |
| Core hero example                                             | **`Example_Account_360_Health_Check` stays in core**                                                                                                   | 3.1, 6                |
| Test fixtures versus deployable examples                      | Keep distinct                                                                                                                                          | 3.1                   |
| Monorepo package directories before Git split                 | Adopt staged approach                                                                                                                                  | 3.2, 3.5              |
| Cloud folders versus repository per cloud                     | One examples repository, faceted catalog                                                                                                               | 3.2–3.3               |
| Duplicate examples for multiple discovery paths               | One source, generated catalog                                                                                                                          | 3.2–3.4               |
| Pack types: starter/adoption/pattern/coverage/demo            | Retain as catalog classifications                                                                                                                      | 3.3–3.4               |
| Deploy button versus unlocked/managed package                 | Support deliberate distribution choices                                                                                                                | 3.6                   |
| Git tag as package version                                    | Reject                                                                                                                                                 | 3.6                   |
| Generated compatibility catalog                               | Adopt                                                                                                                                                  | 3.7                   |
| Existing Apex check interface                                 | Supported Contract V1                                                                                                                                  | 4.1                   |
| Lifecycle platform event                                      | Primary result-consumer contract                                                                                                                       | 4.2                   |
| Run/component activity analytics                              | Add correlated `Record_Health_Check_Set_Run__e`                                                                                                        | 4.9–4.14              |
| Per-Rule outcome logging                                      | Use `Record_Health_Check_Rule_Result__e`                                                                                                               | 4.2, 4.10–4.11        |
| Who invoked versus running/effective/record owner identity    | Keep distinct                                                                                                                                          | 4.10, 4.13            |
| Component impression/page-view tracking                       | Exclude from run semantics; separate consented activity if ever needed                                                                                 | 4.10, 4.13            |
| Plugin permutations and authoring paths                       | Explicit supported/deferred taxonomy                                                                                                                   | 4.9–4.16              |
| One event type per plugin                                     | Reject; keep two shared core-domain streams                                                                                                            | 4.10, 4.17            |
| Large plugin fan-out                                          | Scale tiers, filters, optional external gateway, and event budget                                                                                      | 4.17                  |
| Set Run event opt-in                                          | Add `PublishRunEvent__c` on Check Set, default off                                                                                                     | 2.1, 4.12             |
| Rule Result event opt-in                                      | Add `PublishResultEvent__c` on Rule, default off                                                                                                       | 2.2, 4.12             |
| Emission and actuation safety (on-load never emits)           | Adopt: automatic diagnosis, off-bus action link, events off by default, remediation in extensions                                                      | 4.19                  |
| Shared diagnostic information                                 | Separate future `Record_Health_Check_Diagnostic__e`, not lifecycle payload dumping                                                                     | 4.4                   |
| Automatic system-error diagnostics                            | Minimal redacted diagnostic when diagnostic publication is enabled; detailed data remains authorized                                                   | 4.4                   |
| Synchronous sink/dispatcher/registry                          | Deferred alternative, not discarded                                                                                                                    | 4.3                   |
| One core lifecycle enablement checkbox                        | Conditional on event release                                                                                                                           | 2.1, 4.2              |
| Extension-owned retention/alerts/case rules                   | Adopt ownership boundary                                                                                                                               | 4.5, 4.8              |
| Public diagnostic event versus logger adapter                 | Defer until second implementation                                                                                                                      | 4.4                   |
| Evaluator-provider extension point                            | Defer                                                                                                                                                  | 4.7                   |
| Status/reason/message separation                              | Adopt                                                                                                                                                  | 2.9, 4.2              |
| Publish Immediately versus After Commit                       | Publish After Commit for both V1 lifecycle events (2026-07-13)                                                                                         | 4.2, 6                |
| Replay, duplicate, callback, Automated Process semantics      | Adopt as consumer requirements                                                                                                                         | 4.2                   |
| Extension manifests and generated catalog                     | Adopt                                                                                                                                                  | 4.5                   |
| Shared extension runtime/install-all                          | Reject by default                                                                                                                                      | 4.5, 4.7              |
| Observability as first proof                                  | Adopt, followed by second consumer                                                                                                                     | 4.8                   |
| Contract test kit and package-boundary tests                  | Adopt                                                                                                                                                  | 4.6                   |
| Contributor workflow and quality gates                        | Adopt                                                                                                                                                  | 5                     |
| Contributor Covenant                                          | Adopt                                                                                                                                                  | 5.3                   |
| Public check-response façade (programmatic/Flow API)          | Adopt as a first-class V2 core contract                                                                                                                | 1.1, 1.4, 4.18        |
| Junction object for reusing a Rule across Check Sets          | Defer; provide rule-level granularity through the façade                                                                                               | 2.2, 4.18             |
| Packaging model (unlocked vs managed)                         | Open release decision                                                                                                                                  | 3.6, 4.15, 6          |
| FLS/unavailable-field response policy                         | Policy decided (2.11): neutral in normal mode, honest under authorized diagnostics, enforced server-side; scratch-org `USER_MODE` verification remains | 2.11, 4.18, 6         |
| Related list, list views, declarative CMDT validation rules   | Adopt as admin-experience additions                                                                                                                    | 2.1, 2.6              |
| Sample data and sample Flexi Pages in an unpackaged directory | Adopt for the developer environment                                                                                                                    | 3                     |
| Surface skip reason and suppressed-row toggle in the LWC      | Adopt as UX additions                                                                                                                                  | 2.10                  |
| Diagnostics expands all checks (authorized auto-expand)       | Adopt: override count-only under authorized diagnostics, view-time only, never mutates stored settings                                                 | 2.11                  |
| Batch/scheduled results written to the record for reporting   | Adopt as an extension (per-record outcome counts)                                                                                                      | 4.8, 4.11             |
| LWC guided metadata builder                                   | Defer to a later iteration                                                                                                                             | —                     |
| Multi-color progress bar                                      | Defer to UI polish                                                                                                                                     | —                     |
| One log record per run (vs. per Rule) for stored history      | Adopt as observability-extension storage design: header row + JSON per-check detail + reportable rollups                                               | 4.8, 4.10, 9          |
| V1 Capture Metrics deferral                                   | Superseded by the V2 Rule Result event + observability extension; archived code retained for restoration                                               | 4.8, 9                |
| codex-plan/ and cursor-plan/ migration trees                  | Archive to `recycle-bin/`; field migration implemented and verified, pending gates in Section 9                                                        | 9                     |

## 9. V2 release-readiness gates

**🟡 Partial** — documentation, jargon, source-readback, static-analysis, source-only distribution, capacity, version, and upgrade-guide work are complete as of 2026-07-13. Production-ready status remains blocked by a human permission/diagnostics UI smoke sign-off, a restore-tested backup/rollback approval, and commit/PR/tag approval.

The V2 field migration is **complete and verified in a clean scratch org**: 41 Rule fields, 12 Check Set fields, and all 147 bundled custom metadata records deploy, with local XML, lint, Jest, and full Apex verification passing (field migration 2026-07-12; lifecycle additions and final validation 2026-07-13). The detailed field-by-field migration and jargon-cleanup plans (previously in `codex-plan/` and `cursor-plan/`) are implementation history and have been archived to `recycle-bin/`. Shipped metadata and `field-migration-before-after.md` remain the source of truth.

A complete field migration does not make V2 production-ready. These gates remain outstanding and gate the release:

- **Documentation contract** — repository-wide review and historical-versus-current terminology classification.
- **Jargon replacement** — finish the terminology cleanup; no `scalar`/`comparator` remaining in `force-app/`.
- **Manual smoke test** — `Example_Account_360_Health_Check` on an Account record page, including permission paths, since automated tests do not cover the UI.
- **Source-to-org readback** — an independent retrieve/diff artifact, not only a recorded successful deploy.
- **Release and rollback closeout** — upgrade guide (`docs/v2/installation/upgrading-to-v2.md`), backup/rollback evidence, version bump and tag, commit/PR review, and approvals.

V2 may be marked production-ready only after every gate passes, with exceptions explicitly documented and approved. Breaking-change summary for release notes: all field API renames per `field-migration-before-after.md`, no dual-read compatibility with v1.x field names, Category vocabulary replaced, `MaxQueryRows` default 200, `EmptyValueHandling` default `AS_NO_MATCH`, `EvaluationOrder` default 100, severity Error → Critical, and long-text fields truncated to 255 characters where the type changed.
