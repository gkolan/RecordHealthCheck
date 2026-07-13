# Plan 3 — Examples repository architecture and migration

| Field           | Value                                                                               |
| --------------- | ----------------------------------------------------------------------------------- |
| Release section | [`V2-RELEASE-PLAN.md §3.1–§3.7`](../../V2-RELEASE-PLAN.md)                          |
| Status          | ✅ **Completed (initial)** — 2026-07-13; five packs in `RecordHealthCheck-Examples` |
| Type            | Repository architecture + staged content migration                                  |
| Owner           | _Unassigned — record in [`V2-RELEASE-PLAN.md §6`](../../V2-RELEASE-PLAN.md)_        |
| Effort          | L — new repository shape, catalog generation, per-pack CI, staged content moves     |
| Risk            | Medium — mis-structuring now is expensive to undo once packs and 2GP versions exist |
| Depends on      | Hero-example identity decision (`§6`); can stage in-repo before the Git split       |
| Blocks          | Nothing hard; part of the ecosystem three-repo boundary (`§1.1`)                    |

> **Design note.** This plan reflects a design review that corrected an earlier draft. The
> information architecture (flat canonical packs, metadata-driven facets, generated discovery) was
> right and is kept. The **packaging** assumptions were wrong and are corrected here: the
> repository is a **catalog of source examples**, not one giant Salesforce DX project with hundreds
> of permanent `packageDirectories`. The catalog model and the eventual 2GP packaging model are
> deliberately separated.

## 1. Objective

Move reusable examples out of core into an independently discoverable **examples library**
(`RecordHealthCheck-Examples`), so core stays independently useful with exactly **one hero
example** plus internal test fixtures (`§3.1`, `§3.2`). Each example has one canonical home,
is classified by machine-readable facets, is discovered through generated catalogs, and carries an
**honest** compatibility/removal/validation contract — without pretending to be an independently
versioned Salesforce package on day one.

## 2. Current state (verified)

- Core currently contains example Apex checks alongside engine code in
  `force-app/main/default/classes/`: `AccountHasRecentActivityCheck`,
  `AccountOpenOpportunityHealthCheck`, `AccountStrategicReadinessCheck`,
  `ApprovalInactiveApproverCheck` (each with a `*Test`).
- The `§9` smoke-test gate references `Example_Account_360_Health_Check` on an Account record page
  as the hero example candidate.
- `§8` records that prior migration trees (`codex-plan/`, `cursor-plan/`) are archived; the field
  migration is done. The examples split itself has **not** been executed.
- Commit `66e108d "Move examples library to the RecordHealthCheck-Examples repository"` references
  the destination — confirm what actually moved vs what remains before starting.

> **First action:** audit which of the four example checks above are the _hero_ (stays in core)
> vs _library_ (moves out), and which are _test fixtures_ (stay in core, not presented as
> deployable examples — `§3.1`). Do not assume; verify against the `§6` hero decision.

## 3. Target repository shape — catalog model, not one giant DX project

### 3.0 Two governing decisions

**Decision 1 — Cloud is a facet, not the physical hierarchy.** A pack may be base-platform, span
Sales and Service, or use industry-cloud objects. Filing it under one cloud folder invents an
artificial primary identity, orphans base-platform packs, tempts copy-paste duplication, and
leaves empty cloud folders implying coverage that doesn't exist (`§3.2`, `§3.3`, `§3.7`).
Therefore every facet — including cloud — is metadata in `example.yml`, never a directory.

**Decision 2 — The repository is a catalog of source examples, not one Salesforce package
project.** Do **not** maintain a root `sfdx-project.json` listing hundreds of permanent
`packageDirectories`. A giant central project file causes constant merge conflicts, conflates
source-deploy / unlocked / managed concerns, accumulates package aliases centrally, and forces one
`default` retrieval target with real operational meaning that project-wide commands honor. Instead,
`example.yml` is the **pack registry**, and CI **generates an isolated DX project on demand** for
whichever pack it validates or deploys. Actual 2GP distribution uses a **separate packaging
project**, created only for packs genuinely promoted to 2GP.

### 3.1 Repository shape

```text
RecordHealthCheck-Examples/
├── README.md
├── package.json                     # Node tooling entry (scripts/*.mjs); NO root sfdx-project.json
├── catalog/                         # all GENERATED — carry a "DO NOT EDIT" header
│   ├── catalog.json                 # machine-readable index; source for any UI/AppExchange later
│   ├── by-cloud.md
│   ├── by-outcome.md
│   ├── by-mechanism.md
│   ├── by-complexity.md
│   ├── by-maturity.md
│   └── compatibility.md
├── docs/
│   ├── authoring-guide.md
│   ├── facet-vocabulary.yml         # MACHINE-READABLE controlled vocabulary (source of truth)
│   ├── manifest-schema.json         # JSON Schema for example.yml
│   ├── packaging-guide.md           # how a pack is promoted to unlocked/managed 2GP later
│   └── pack-template/               # copy-to-start scaffold
│       ├── example.yml
│       ├── README.md
│       ├── manifest/package.xml
│       ├── force-app/main/default/
│       └── tests/
├── packs/                           # flat; ONE canonical home per pack; stable use-case id names
│   ├── account-completeness/
│   │   ├── example.yml              # the schema-versioned pack contract (3.5)
│   │   ├── README.md                # the 10-section README (§3.4)
│   │   ├── CHANGELOG.md
│   │   ├── manifest/
│   │   │   ├── package.xml
│   │   │   └── destructiveChanges.xml
│   │   ├── force-app/main/default/
│   │   └── tests/
│   │       ├── scenarios/
│   │       └── expected-results/
│   └── case-consistency/ …
├── scripts/
│   ├── generate-catalog.mjs         # builds catalog/* from every example.yml
│   ├── validate-packs.mjs           # schema + vocabulary + duplicate-id + ownership + cycle checks
│   ├── determine-affected-packs.mjs # changed-path + dependents, for PR CI
│   ├── create-validation-project.mjs# emits an isolated .tmp DX project for one pack
│   └── validate-install-order.mjs   # topological order from declared dependencies
├── tests/
│   ├── coexistence/
│   ├── installation/
│   ├── removal/
│   └── schema/
└── .github/workflows/
    ├── validate-packs.yml
    └── generate-catalog.yml
```

The layout is identical whether packs live in this repo during staging or in the split-out
`RecordHealthCheck-Examples` repo — no pack references a repo-absolute path (`§3.5`).

### 3.2 Why flat + generated scales better than a hierarchy

| Concern                           | Flat + faceted + generated (chosen)             | Cloud-folder hierarchy (rejected)          |
| --------------------------------- | ----------------------------------------------- | ------------------------------------------ |
| Cross-cloud pack                  | One entry lists both clouds in a facet          | Must pick one cloud or duplicate           |
| Base-platform pack                | `clouds: [base-platform]`                       | No natural home                            |
| New cloud added                   | Add a vocabulary value; regenerate              | Restructure dirs; risk empty folders       |
| Discover by outcome **and** cloud | Both are generated views over one dataset       | Only the folder axis is navigable          |
| "Is coverage real?"               | Catalog shows only packs that exist + validated | Empty folders imply fake coverage (`§3.7`) |

Humans discover packs through the **generated catalog** and repository search, not by browsing
hundreds of folders. A flat `packs/` with even low-hundreds of children is manageable for that
reason. **Do not add cloud folders.** If physical sharding ever becomes necessary, shard by a
non-semantic mechanism (e.g. first character, `packs/a/…`, `packs/c/…`) — but not now; it adds
complexity without current value.

### 3.3 Pack identity and naming — stable use case, not mutable facets

The directory name is the pack's **immutable use-case identity**, never its classification:

```text
account-completeness
case-consistency
contact-readiness
owner-readiness
```

Do **not** encode facets like cloud in the name (`sales-account-completeness`). If that pack later
also supports Service, a facet-encoded name becomes a lie, and renaming it breaks the catalog,
docs, release automation, and any external reference. Cloud lives in YAML instead. Only include a
product term in the identifier when the product is **intrinsic** because the pack uses
product-specific objects/capabilities — e.g. `financial-account-eligibility` is reasonable if it
genuinely depends on Financial Services Cloud metadata.

> **Rule: names identify the use case; facets classify it.** The `id` in `example.yml` must match
> the directory name and is immutable once published.

### 3.4 Facets are a machine-readable controlled vocabulary

At scale the risk is drift (`FSC` vs `Financial Services Cloud` vs `fin-services`). Prevent it:

- `docs/facet-vocabulary.yml` is the **source of truth** for every facet's allowed values:
  `clouds`, `outcomes`, `mechanisms`, `scopes`, `complexity`, `maturity`
  (Experimental/Preview/Supported/Community/Deprecated per `§4.5`).
- `clouds` is **multi-valued**; `base-platform` is a first-class value.
- `scripts/validate-packs.mjs` rejects any `example.yml` whose facet values fall outside the
  vocabulary — this is what keeps a many-pack, many-cloud catalog coherent.
- Outcome values stay neutral and jargon-free (`§3.3`): improve completeness, verify consistency,
  detect stale records, enforce eligibility, monitor readiness. Never label people by role/skill.
- The human-readable vocabulary page is **generated** from the YAML; Markdown is never authoritative.

### 3.5 The `example.yml` contract (schema-versioned public contract)

`example.yml` carries most of the pack's responsibility, so treat it as a versioned public
contract, validated against `docs/manifest-schema.json`:

```yaml
schemaVersion: 1

id: account-completeness # immutable; matches directory name
title: Account Completeness
summary: >
  Identifies accounts missing information required for downstream
  sales and service processes.

maturity: preview

ownership:
  maintainer: record-health-check-community

facets:
  clouds: [sales, service]
  outcomes: [improve-completeness]
  mechanisms: [formula, query]
  scopes: [single-record, related-records]
  complexity: beginner

compatibility:
  core:
    minimumVersion: 1.2.0
    maximumTestedVersion: 1.4.0 # distinct from "maximum supported"
  salesforce:
    minimumApiVersion: 64.0
    editions: [developer, enterprise, unlimited]
    requiredFeatures: []
    requiredObjects: [Account]

dependencies:
  core:
    package: record-health-check
    version: ">=1.2.0 <2.0.0"
  packs: [] # foundation deps are rare (3.10)

distribution:
  supported: [source] # initial repo is SOURCE-ONLY (3.7)
  default: source
  namespacePolicy: none # intent only; not achievable inside one root DX project

installation:
  manifest: manifest/package.xml
  estimatedMinutes: 5

removal:
  method: destructive-changes
  manifest: manifest/destructiveChanges.xml
  status: tested # tested | documented | partial | not-supported (3.8)
  lastValidated: 2026-07-13
  limitations:
    - Remove the component from Lightning record pages before deletion.

validation:
  status: passed
  method: scratch-org
  lastValidated: 2026-07-13
  orgShape: config/base-project-scratch-def.json
  scenarios: [pass, fail, skipped, unable-to-evaluate]

components: # ownership for collision detection (3.9)
  owns:
    - CustomMetadata:Health_Check.account_completeness
    - CustomMetadata:Health_Check_Set.account_health
  modifiesSharedComponents: []

documentation:
  readme: README.md
  changelog: CHANGELOG.md
```

Key contract properties: `schemaVersion`; immutable `id`; structured compatibility with
`maximumTestedVersion` **separate** from any "maximum supported" claim; separate core and pack
dependencies; **honest** distribution claims; explicit removal status; validation date + method;
required objects/features; and declared component ownership.

### 3.6 Discovery is generated (one source, many paths)

`scripts/generate-catalog.mjs` reads every `example.yml` and emits `catalog/catalog.json` (the
machine source) plus the `by-*.md` views and `compatibility.md`. Every generated file carries a
header:

```text
DO NOT EDIT. Generated from packs/*/example.yml.
```

A hand-edited catalog view is a bug; CI checks for catalog drift (3.11). This is how "multiple
clouds / different permutations" are served without duplicating a pack: the same pack appears under
every facet value it declares, from one definition.

### 3.7 Packaging model — source-first, generated projects, 2GP later

- **No root `sfdx-project.json`.** `example.yml` is the registry. To validate or deploy a pack,
  `scripts/create-validation-project.mjs` writes an isolated project such as:

  ```text
  .tmp/validation/account-completeness/
  ├── sfdx-project.json      # single packageDirectory, default:true, empty namespace
  └── force-app/
  ```

  This gives one isolated validation unit, no giant central package list, no accidental deploy of
  unrelated packs, trivial changed-path CI, and freedom to split a pack into its own repo later.

- **Namespace is a project-level property, not a per-pack manifest fact.** `example.yml` may
  _describe_ intended namespace/distribution policy, but that YAML does not make arbitrary
  per-pack namespaces achievable inside one root DX project. Namespace and packaging ownership need
  deliberate Dev Hub + packaging-project design.
- **Initial repository is source-only.** Restrict `distribution.supported` to `[source]` at first.
  Promote selected mature packs to unlocked or managed 2GP later through **separate packaging
  pipelines** (documented in `docs/packaging-guide.md`). Do not make every example pretend to
  support all three distribution models. When a pack is genuinely released via 2GP, record its
  `04t` version and declare the released **core** dependency in that pack's dedicated packaging
  project. A Git tag is not an installable version (`§3.6`).

### 3.8 Removal is documented honestly — destructive changes ≠ uninstall

A `destructiveChanges.xml` only instructs the Metadata API to delete named components. It is **not**
package-uninstall semantics and does not prove deletion is safe. Removal can fail or cause damage
when another pack or a Flow/permission set/layout/validation rule references the metadata, when the
pack modified a shared container, or when post-install records still depend on it.

Use precise language: **every pack must have an isolated deployment manifest and a documented
removal procedure; CI validates removal where the metadata and target-org configuration permit.**
Represent the real guarantee in `example.yml` `removal.status`:

| Status          | Meaning                                                    |
| --------------- | ---------------------------------------------------------- |
| `tested`        | Removal validated in CI/scratch org                        |
| `documented`    | Steps written; not automatically validated                 |
| `partial`       | Removes cleanly except for documented residue/manual steps |
| `not-supported` | Safe automated removal is not currently possible           |

Never equate a `destructiveChanges.xml` with "removable."

### 3.9 Metadata ownership and collision validation (required)

The biggest scale risk is two packs shipping or editing the **same** component — a permission set,
FlexiPage, custom metadata record, custom label, Apex test helper, app, or tab. Enforce ownership:

- Each pack declares `components.owns` (complete components it fully owns) and
  `modifiesSharedComponents` (deliberate contributions to a shared mutable component).
- `scripts/validate-packs.mjs` derives most components from the source tree and **rejects
  duplicate ownership** across packs and unauthorized shared-component edits.

> **Rule:** a pack may own **complete** metadata components, but it may **not** contribute partial
> edits to a shared mutable component unless the contribution mechanism is explicitly supported.
> This matters most for permission sets and Lightning pages.

### 3.10 Shared building blocks: foundation packs are rare exceptions

Foundation packs are **not** part of the default template and **not** a normal reuse mechanism — a
user should install `account-completeness` without first learning a `foundation-*` ecosystem.
Default dependency order:

1. Depend on Record Health Check **core**.
2. Keep metadata-only pack content **self-contained**.
3. Deliberately **duplicate** tiny example-specific assets when needed.
4. Introduce a shared foundation **only after ≥3 real packs** require the same nontrivial component.
5. Never create a foundation to eliminate five lines of repetition.

A foundation dependency must clear a high bar: stable public contract, independent semantic
versioning, independent tests, clear ownership, proven multi-pack usage, no circular dependencies,
and no dependence on example-specific metadata. Reaching into another pack's `force-app/` or
copying core classes across the boundary is always forbidden (`§4.7`).

### 3.11 Permutations — worked archetypes

All packs live flat in `packs/`, differing only by declared facets and manifest requirements — no
structural special-casing. Names are stable use-case ids; classification is YAML.

| Pack archetype                | `clouds` facet         | `mechanisms`  | deps                     | Manifest requirements          | Validation org         |
| ----------------------------- | ---------------------- | ------------- | ------------------------ | ------------------------------ | ---------------------- |
| Metadata-only, base platform  | `[base-platform]`      | Formula/Query | none                     | `compatibility.core`           | Developer Edition      |
| Standard-object, single cloud | `[sales]`              | Query/Compare | none                     | `compatibility`                | Developer Edition      |
| Cross-cloud                   | `[sales, service]`     | Query         | none                     | `compatibility`                | Developer Edition      |
| Industry-cloud                | `[financial-services]` | Query/Apex    | none                     | `requiredFeatures`, `editions` | FSC-provisioned org    |
| Apex custom check             | `[base-platform]`      | Apex          | core Apex-check contract | `compatibility`                | Developer Edition      |
| Foundation-dependent (rare)   | any                    | any           | `dependencies.packs`     | dependency version range       | install-order resolved |

Permutation-safety rules:

- A cross-cloud pack lists **all** clouds in the multi-valued facet — it is never duplicated.
- A cloud-dependent pack declares `requiredFeatures`/`editions`; CI routes it to the right org, and
  where none is automatable it publishes its validation method + date (`§3.7`) — never fakes a green.
- Reuse is a **declared** `dependencies.packs` entry on a foundation pack; never a copy (`§4.7`).
- Adding a new cloud is a **vocabulary + regenerate** operation (3.4/3.6), not a restructure.

## 4. Classification (`§3.3`) — faceted, not folders

Classify across separate facets, not one folder hierarchy: product/cloud; business outcome;
evaluation mechanism; scope/dependencies; complexity; maturity/support status. Outcome routes use
**neutral** language and never label people by presumed role or skill level (`§3.3`). The facet
values are drawn from `docs/facet-vocabulary.yml` (3.4).

## 5. Required pack README (`§3.4`)

`example.yml` (3.5) is the machine contract; the README is the human contract and explains, in
order: (1) what it checks; (2) what the user sees; (3) when it is useful; (4) prerequisites;
(5) installed components; (6) evaluation mechanics; (7) deploy + validation steps; (8) adaptation
guidance; (9) removal steps (matching the honest `removal.status`); (10) technical references.

## 6. Migration sequence (`§3.5`) — execute in order

1. **Record the current core/example boundary and dependencies** (the §2 audit).
2. **Define the hero example and fixture policy.** Resolve the `§6` hero identity; declare which
   fixtures stay in core and are _not_ deployable examples.
3. **Establish the catalog tooling first:** `facet-vocabulary.yml`, `manifest-schema.json`,
   `generate-catalog.mjs`, `validate-packs.mjs`, and the pack template.
4. **Move low-dependency, metadata-only examples first**, each with a schema-valid `example.yml`.
5. **Move Apex and feature-dependent packs after isolation tests exist.**
6. **Replace core docs with ecosystem links and outcome-based discovery.**
7. **Prove the paths:** core-only, each pack alone, multiple packs together, upgrade, and removal.
8. **Open contribution paths only after templates and CI enforce the quality bar** (`§3.7`, `§5`).

## 7. Install/distribution experience (`§3.6`)

Initial delivery is **source/manifest deploy** per pack. The adopter path stays simple: install
core + hero example → assign `Record_Health_Check_User` → add the component to a record page and
pick a Check Set → optionally deploy example packs → independently, optionally install extensions.
Unlocked/managed 2GP is a later, per-pack promotion through a dedicated packaging pipeline
(`docs/packaging-guide.md`), not a day-one claim.

## 8. CI — layered, not changed-path alone (`§3.7`)

Changed-path CI is for PR speed, but it cannot be the sole safeguard: a core change, a Salesforce
seasonal release, a catalog-generator change, or a shared-schema change can affect packs whose
directories were untouched.

- **Pull-request validation:** changed packs + packs depending on them; `example.yml` schema;
  facet-vocabulary conformance; catalog-drift check; duplicate-`id` check; metadata-ownership
  collisions (3.9); dependency-cycle check.
- **Scheduled validation (nightly/weekly):** all base-platform packs; coexistence groups;
  installation and removal tests; latest supported Salesforce release; latest core release.
- **Release validation:** full catalog regeneration; full dependency graph; compatibility checks;
  security + secrets scan; documentation-link checks; a representative multi-pack installation.

Cloud-specific packs need a correctly provisioned validation org; where automation is unavailable,
publish the validation method + date rather than faking coverage (`§3.7`). Route defects:
engine/LWC/schema → core; pack → examples; integration → extensions.

## 9. Constraints / best practices

- **Separate the catalog model from the packaging model** — no giant root DX project; generate
  isolated projects on demand; 2GP only for genuinely promoted packs.
- **No hidden runtime dependency** (`§3.1`, `§1.1`): no example may require a core source edit,
  engine branch, copied core class, or hidden dependency.
- **One source of truth per example**; generate every catalog/compatibility artifact (`§3.2`).
- **Stable use-case names; facets classify** (3.3). **Immutable `id`.**
- **Honest claims** for compatibility, distribution, removal, and validation (3.5, 3.8).
- **Foundations are rare** (3.10). **Ownership collisions are enforced** (3.9).
- **Neutral, outcome-oriented, jargon-free** language; no CS jargon in code, metadata, or UI.

## 10. Acceptance criteria

- [x] Core/example boundary audit committed; hero example + fixture policy decided (`§6`).
- [x] Repository uses the **flat, faceted, catalog** shape (3.1): **no root `sfdx-project.json`**,
      **no cloud folders**; every facet is `example.yml` metadata.
- [x] `docs/facet-vocabulary.yml` + `docs/manifest-schema.json` exist; `validate-packs.mjs` rejects
      out-of-vocabulary facets, duplicate `id`s, ownership collisions, and dependency cycles.
- [x] `scripts/create-validation-project.mjs` generates an isolated DX project per pack; CI never
      deploys unrelated packs.
- [x] At least one pack fully migrated (schema-valid `example.yml`, 10-section README, manifest,
      `destructiveChanges.xml`); plus one **cross-cloud** (`account-everyday-readiness`) and one **industry-cloud** (`grantmaking-application-readiness`) pack proving
      the permutation model (3.11).
- [x] `catalog/*` and `compatibility.md` are **generated** with the DO-NOT-EDIT header; catalog
      drift fails CI.
- [x] Every pack declares an **honest** `removal.status` and `compatibility.maximumTestedVersion`;
      distribution is source-only initially.
- [x] Foundation sharing (if any) clears the 3.10 bar via declared `dependencies.packs`; no pack
      copies core or peer-pack source.
- [x] CI runs the PR validation layer; scheduled/release layers documented — cloud-dependent NPC pack publishes validation method + date.
- [ ] All five paths proven: core-only, each pack alone, multiple together, upgrade, removal (deferred to §9 scratch-org proof).
- [x] Core retains exactly one hero example; test fixtures stay in core and are not deployable
      examples.

## 11. Open decisions (from `§6`)

- ~~Identity of the one core hero example.~~ **Resolved:** `Example_Account_360_Health_Check` in core.
- ~~Examples repository name confirmation~~ **Resolved:** `RecordHealthCheck-Examples`.
- Which packs (if any) are promoted to unlocked/managed 2GP, and when — a **separate** packaging
  pipeline decision, not a repository-shape decision.
