# Codex deep audit: GitHub release analysis

**Audit date:** 2026-07-14  
**Audited branch:** `v2-release`  
**Audited commit:** `f5bca457cfbc8b309c9181427b164afc86039c2f` plus the full uncommitted working tree  
**Release candidate:** Record Health Check V2 (`2.0.0`, Salesforce API `66.0`)  
**Verdict:** **Not ready for a public GitHub release**

## Executive decision

The framework has a strong foundation: the LWC test suite passes all 111 tests, the normal ESLint
run passes, all 362 Salesforce and manifest XML files parse, no prohibited `scalar` or `comparator`
wording remains under `force-app/`, and Salesforce Code Analyzer finds no High or Critical issue.
The repository also contains unusually thoughtful security, failure-state, migration, event-volume,
and rollback design work.

It should nevertheless **not be tagged or announced in its current state**. Two commands that run
in the required GitHub Actions job fail locally, the published coverage gate currently measures
0%, current V2 documentation contains broken learning paths, and the project itself records that
mandatory human release gates remain open. The release candidate is also spread across 35 modified
files, 5 deleted files, and 8 untracked top-level paths; a GitHub tag on the current commit would not
contain that work.

The shortest honest summary is: **the product looks close, but the release process and learning
experience are not yet trustworthy enough for the standard this project sets for itself.**

## What this audit covered

This was not a README-only review. The audit inventoried the repository and scanned every
release-relevant text line in:

- Apex production classes and tests, LWC JavaScript/HTML/CSS/tests, Custom Metadata, object and
  field definitions, permission sets, event definitions, reports, layouts, and integration-test
  metadata under `force-app/` and `integration-tests/`;
- every manifest, project configuration file, npm script, GitHub workflow, issue template, release
  instruction, contribution/security/community file, V2 plan, audit, and tool;
- current `docs/v2`, historical `docs/v1`, root documentation redirects, wiki material, Markdown
  references, image references, and the example-repository material present in the working tree;
- tracked, modified, deleted, and untracked files—not only `HEAD`.

Automated whole-tree checks were combined with manual review of the public entry points, install
flow, release flow, V2 gate evidence, high-risk evaluator/controller/security code, comments, and
the new SLDS theme changes. Binary image content was checked as an artifact, not treated as source
text. No org-backed deploy was repeated during this audit; existing org evidence was reviewed and
that limitation is called out below.

## Release blockers

### P0-1 — The required CI token check fails

**Evidence:** `npm run check:namespaced-tokens` exits 1 with
`{"mode":"check","legacyTokenCount":90}`. The command is mandatory in
`.github/workflows/ci.yml`. The checker includes all of `docs/`, including historical V1 pages, and
reports 89 historical/example occurrences plus one current V2 occurrence at
`docs/v2/reference/reason-codes.md` (`{!Id}`).

**Why it matters:** a pull request cannot become green, and a release that bypasses the red job
would immediately undermine the CI badge and release instructions.

**Required fix:** correct the current V2 token, then deliberately choose one of these contracts:

1. historical V1 pages are immutable and the checker excludes `docs/v1`; or
2. all displayed token examples, including historical pages, must use V2 syntax.

Document the choice in the script and add a test/fixture so versioning the docs cannot silently
break this gate again. Acceptance: the command exits 0 from a clean checkout.

### P0-2 — The required formatting check fails

**Evidence:** `npm run prettier:verify` exits 1 for:

- `force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js-meta.xml`
- `README.md`

**Why it matters:** this is the first quality gate in the local release guide and the CI workflow.

**Required fix:** format those two files and rerun the check from a clean checkout. Review the
resulting XML diff rather than applying formatting blindly to metadata.

### P0-3 — The coverage gate is a false green

**Evidence:** `npm run test:unit:coverage` exits 0 and runs all 111 tests, but its final table says
`All files | 0 | 0 | 0 | 0`. This contradicts the thresholds declared in `jest.config.js:13-20`
(75% branches, 90% functions, 85% lines/statements). The CI job relies on this command.

**Why it matters:** GitHub can show a successful coverage gate while measuring no production
JavaScript. That is worse than publishing no coverage claim because maintainers may rely on a
protection that is not active.

**Required fix:** determine why the Salesforce Jest wrapper is not instrumenting the files matched
by `jest.config.js:6-12`; make a deliberately untested production line reduce reported coverage;
make a below-threshold run fail; and retain the resulting coverage summary as CI evidence.

### P0-4 — Mandatory V2 approval gates remain open

**Evidence:** `releases/v2/plans/section-9-release-readiness/9-release-readiness-gates.md:154-166`
still leaves these items unchecked:

- Account-page manual smoke test, including user permission and diagnostics paths;
- backup/rollback closeout, final PR review/approval, and tag;
- explicit approval for any remaining exception.

The plan header also describes human UI, restore, PR, and tag approval as remaining.

**Why it matters:** these are the project’s own non-optional release conditions. Passing unit tests
does not prove that App Builder configuration, a real org install, permissions, rendering, and
rollback work together.

**Required fix:** complete the smoke and rollback scripts in disposable orgs, attach sanitized
evidence, review the final diff, approve any exception explicitly, and only then tag the reviewed
commit.

### P0-5 — The candidate is not a reproducible GitHub snapshot

**Evidence:** the audit began with 35 modified files, 5 deleted files, and 8 untracked paths,
including all `docs/v1/`, all `docs/v2/`, two new LWC theme files, images, wiki content, and V2
release notes. The current commit therefore does not represent the tested working tree. The branch
is `v2-release`, while `RELEASING.md` says releases are cut from `main`.

**Why it matters:** GitHub releases contain committed files. Tagging the present commit would omit
the new versioned documentation and theme files and retain old tracked content in a state unlike
the local candidate.

**Required fix:** commit the complete intended release set, confirm no required file is ignored,
merge the reviewed candidate to the documented release branch, run every gate on that exact SHA,
and tag that SHA—not a nearby working-tree state.

## High-priority findings

### P1-1 — Current V2 documentation has broken learning paths

The relative-link scan checked 1,685 Markdown links and found 176 unresolved targets. Some are
intentional template placeholders, historical material, recycled plans, or links into a separate
examples repository; those should not all be fixed identically. However, multiple failures are in
the current V2 user journey, including:

- `docs/v2/apex/plugin-reference.md` → three missing Apex example pages and `examples/index.md`;
- `docs/v2/apex/plugin-contract.md` → an incorrect relative path to
  `RecordHealthCheckRule.cls` and a missing examples index;
- `docs/v2/quick-start.md` and installation pages → missing local examples;
- `docs/v2/guides/configuration-guide.md`, `cli-commands.md`, and `llm-configuration.md` → missing
  example catalog, patterns, and Apex pages;
- `docs/spec/*` and several public reference pages → missing `guides/debug-mode.md` or metadata
  pages that were deleted/moved.

This conflicts with the checked Gate A claim that documentation is complete and makes first-time
users hit dead ends precisely when they ask for examples.

**Required fix:** define link policy by area. Current V2 pages should link either to an existing
local page or to the exact page in `RecordHealthCheck-Examples`. Historical pages should be visibly
versioned and either keep working frozen links or declare that their examples moved. Templates
should be excluded from link validation. Add a local-link checker to CI and reach zero unexplained
failures in public/current docs.

### P1-2 — The public install button deploys mutable `main`, not the release

`README.md:6,51` and `docs/v2/start/first-10-minutes.md:21` send users to `ref=main`.
`RELEASING.md:105` explicitly says the button “always installs the latest `main`,” even though the
same guide says a release is a frozen, rollback-friendly snapshot.

**Why it matters:** a person reading the V2.0.0 release can receive later, unreviewed code; support
cannot reliably reproduce what they installed; rollback instructions lose their symmetry.

**Required fix:** for a release-focused README, pin the primary deploy button to `v2.0.0` and offer
`main` only as a clearly labeled development/latest option. If the badge cannot be changed before
tag creation, make updating it an explicit release-prep step verified after publication.

### P1-3 — Static analysis passes the threshold but has a large untriaged middle

The same command used by the release workflow found 1,272 findings in 71 files: 455 Moderate, 811
Low, and 6 Info, with 97 additional findings suppressed by inline markers. No High or Critical
finding was reported, so the configured severity threshold exits 0.

The Moderate group includes 139 missing-brace findings, 137 `if` missing-brace findings, 32 long
parameter lists, 32 cyclomatic-complexity findings, 29 cognitive-complexity findings, 18 oversized
methods/classes, 10 unsupported SLDS 2 styling hooks, 8 tests without detected assertions, 8
inline ESLint disables, and individual unused-variable, empty-block, hard-coded-ID, and trigger
logic findings.

**Required fix:** do not mechanically rewrite all 455 before release. Triage them in three groups:

1. correctness/security or dead-code findings—fix now;
2. SLDS 2 compatibility findings in the newly themed component—verify visually and fix now;
3. complexity/style debt—record narrowly scoped follow-up issues with an owner and rationale.

Audit all 97 suppressions and require a plain-language reason next to each. Configure Code Analyzer
to use `eslint.config.js`; its run warned that the repository config was found but not applied.

### P1-4 — Apex verification was not reproduced against the final candidate

The local suite covers the LWC only. Apex behavior is supported by extensive test classes and past
scratch-org audit artifacts, but this working tree has uncommitted release changes and the current
audit did not deploy them to a clean org. The Salesforce release workflow is manual
(`workflow_dispatch`), not part of every pull request.

**Required fix:** after the candidate is committed, run a clean scratch-org deploy with
`RunLocalTests`, metadata validation, user/admin permission checks, and source readback. Record the
job URL/SHA and actual Apex coverage. A prior run against a different tree is supporting evidence,
not final-release evidence.

### P1-5 — The release guide contains stale or misleading verification text

- `RELEASING.md:38` promises 106 Jest tests; the suite now has 111.
- The documented `npm test -- --runInBand` form does not actually forward `runInBand` through npm
  as intended; npm warns that the option is an unknown npm configuration value.
- `docs/v2/installation/upgrading-to-v2.md:41` uses the same confusing form.
- The release guide tells users to verify artifacts after publication instead of requiring an
  installation rehearsal of the exact tag before announcing it.

**Required fix:** remove hard-coded test counts or generate them; document the correct wrapper
syntax; and add an explicit draft-release/tag rehearsal followed by sandbox installation and
permission assignment before announcement.

## Medium-priority quality and presentation findings

### P2-1 — The public README mixes V1 upgrade detail into the V2 first impression

`README.md:44-49` gives the V2 warning and then immediately devotes two dense paragraphs to the old
v1.2.0 component migration. That history is useful, but it interrupts a new user’s installation
path and makes the current instructions look less settled.

Move old-version specifics to the versioned V1 or upgrade guide. Keep the README focused on: what
the framework does, safe sandbox install, first successful check, current V2 docs, and support.

### P2-2 — Examples are described as both bundled and external without a crisp boundary

The README says “Sample Account Check Sets for learning,” then says core ships one hero Check Set,
while the repository currently contains many `Account_*` and other custom-metadata records.
Documentation links also alternate between missing local `docs/v2/examples` pages and the external
examples repository.

Publish one plain-language table that states exactly what a core deployment installs, what is a
test/coverage fixture, what lives only in the examples repository, and what order optional packs
require. Generate the table from metadata if possible so it cannot drift.

### P2-3 — Code comments are generally valuable but need a focused cleanup pass

The production code contains helpful explanations around security, missing values, stop behavior,
and failure normalization. The main cleanup need is not deleting comments; it is keeping only
comments that explain a Salesforce behavior or safety decision. Static analysis identifies inline
disable comments in `healthCheckRunner.js` and the Jest file, while the workflows contain a long
historical “P0-03” explanation that reads like audit history rather than durable operating
guidance.

Before release, verify every suppression explains why the rule is safe to ignore, remove comments
that merely repeat the next statement, and move historical incident narrative into an audit or
commit message. Avoid unexplained acronyms in user-facing and contributor-facing guidance.

### P2-4 — The style split needs release-grade visual evidence

The candidate introduces `recordHealthCheckSlds1.css`, `recordHealthCheckSlds2.css`, and a design
theme property. Unit tests verify selection and fallback, but Code Analyzer flags unsupported SLDS
2 hooks in the existing component CSS, and no current screenshot set proves both themes across
pass/fail/warning/skipped/unable, long text, keyboard focus, narrow layout, and high-contrast use.

Add a small visual test matrix and screenshots from a real org. Confirm that the default shown in
App Builder matches the documentation and that unsupported values have a clear administrator
fallback.

### P2-5 — Documentation duplication needs ownership rules, not another rewrite

The working tree now has root redirect/stub pages, `docs/v1`, `docs/v2`, wiki content, specs,
reviews, demos, slides, templates, release plans, and an external examples repository. Some
duplication is deliberate, but the 176 broken links and stale test count show that facts are
already drifting.

Declare one source of truth for each repeated fact: install steps, field contract, reason codes,
example catalog, supported API version, test commands, and release gates. Make old root paths tiny
redirect/index pages, mark archival reviews clearly, and generate tables where the repository
already has generator tools. Keep the main learning path free of internal planning language.

## Documentation and wiki review addendum

### V2 Core versus Examples boundary clarification

The release owner confirmed that the transition described in V2 plan §3 is over:
`RecordHealthCheck` is a **Core-only** repository. It owns the framework and the single Hero Check
Set `Example_Account_360_Health_Check`. Every other reusable Check Set, Rule pattern, industry
scenario, and optional example Apex class belongs in the independent
`RecordHealthCheck-Examples` repository and must be listed or deep-linked from Core.

The independent repository at `/Users/gkolan/Documents/GitHub/RecordHealthCheck-Examples` now has a
refreshed 12-pack catalog and passes pack-schema and install-order validation. Its detailed
publication review is `docs/release-readiness.md` in that repository.

This clarification creates a new Core release blocker. Core still physically contains four migrated
library Check Sets (`Account_Data_Quality`, `Account_Everyday_Use_Cases`,
`Account_Relationships`, and `Account_Examples_Apex`), their Rules, optional example Apex classes,
and 14 non-Hero Check Set manifests. Core tests reference some of those public example names. Before
release, replace those test dependencies with clearly named internal fixtures, then remove the
library metadata, optional example classes, and non-Hero manifests from Core. Internal fixtures may
remain only when they are not documented or deployable as examples.

The Core README, current installation guides, Admin Quick Start, sandbox walkthrough, and GitHub
documentation issue link were updated to install the Hero from Core and direct all other examples
to `RecordHealthCheck-Examples`.

### Examples repository documentation pass

Every one of the 12 pack teaching guides in `RecordHealthCheck-Examples` now has an explicit
**Before you begin** section. Deployable packs state that Core V2 must already be installed, identify
the Salesforce records involved, call out record and field access where query results can change,
and require both a passing and failing test. Documentation-only packs state that they are design
examples—not deployable metadata—and require Object Manager confirmation, business-owner review,
sandbox creation, and tests for both expected results. This protects readers from copying assumed
CPQ, Revenue Cloud, Financial Services Cloud, Advanced Approvals, or grantmaking API names into an
org where the data model differs.

The maintained pattern library contains 35 Formula, Query, Compare Two Queries, and Apex pages.
Each page is now checked for a plain-language purpose, appropriate-use guidance, Setup-label
configuration, Evaluation Type, and a test procedure. Compatibility pages under `examples/` point
to the maintained pattern library instead of carrying a second editable copy. The obsolete example
template that instructed readers to deploy Core from the Examples repository was replaced with a
pointer to the repository-owned template.

A new `npm run validate-docs` gate checks all pack guides, maintained pattern pages, and relative
Markdown links. It is also part of `npm run validate`. At the time of this audit, documentation
validation covers 12 pack guides, 35 pattern pages, and 129 Markdown files with no missing required
sections or broken relative links. `npm run validate`, `npm run check-catalog`, and
`npm run install-order` all pass. The six product-specific packs remain intentionally
documentation-only until their object and field API names can be verified in suitable licensed
Salesforce orgs; the guides now say this before the reader reaches an example.

### Changes completed in the working tree

The publishable wiki now includes two missing V2 entry points:

- `wiki/What-Is-New-in-V2.md` explains administrator and builder changes, the upgrade warning,
  current limits, and next steps without repeating the full changelog.
- `wiki/Troubleshooting.md` starts from the message a user sees, explains permission and field-access
  checks, includes the metadata-validator command, and states what information is safe to include in
  an issue.

The wiki navigation, Home, Author Checks, Examples, Integrate, Extend, Reference, and footer pages
were revised to prefer Salesforce terms. Examples include **public Apex class** instead of “façade,”
**platform event subscriber** instead of “consumer,” and direct statements about record updates
instead of “side effects.” The V2 documentation index links to the new wiki pages. Broken local
example links in the Configuration Guide now point to specific locations in
`RecordHealthCheck-Examples`.

### Documentation decisions that still need owner review

| Decision                                                           | Why review is needed                                                                             | Recommended answer                                                                                |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| Which GitHub release tag the Deploy button should use              | `main` can change after V2 is announced.                                                         | Point public V2 install paths to `v2.0.0`; label `main` as development/latest source.             |
| Whether the LLM guide belongs in the main administrator navigation | It is 500+ lines, uses AI-product terminology, and can distract from supported Salesforce setup. | Keep it as an optional builder appendix, outside the primary administrator path.                  |
| Whether historical V1 links must remain live                       | Token and link checks currently treat V1 pages as current, causing false release failures.       | Mark V1 as archived, exclude it from V2 syntax gates, and keep links working when practical.      |
| Whether the wiki or `docs/v2` owns troubleshooting                 | Copying full procedures into both will drift.                                                    | Wiki owns symptom-first navigation; `docs/v2` owns diagnostics, reason codes, and field behavior. |
| How Core and Examples divide sample metadata                       | Core contains more example-looking metadata than “one hero example” suggests.                    | Publish a generated inventory naming the Core example, test fixtures, and optional packs.         |
| Whether `Record_Health_Check_Configure` belongs in user docs       | It ships but has no active product behavior.                                                     | Mention it only in limitations/release notes until a Setup tool uses it.                          |

### New documentation still recommended before release

1. **Exact deployment contents.** Generate a page showing every class, component, permission set,
   Custom Metadata Type, platform event, report, and example installed by `manifest/package.xml` and
   by a full `force-app` deployment.
2. **Permission and access matrix.** Cover End User, Check Author, Troubleshooting Administrator,
   Apex/Flow Caller, and Platform Event Subscriber: permission set, custom permission, record access,
   object access, field access, and available actions.
3. **V2 release installation proof.** Record the exact SHA and tag used for clean sandbox deploy,
   permission assignment, App Builder setup, Apex tests, metadata validation, upgrade, and rollback.
4. **Platform event subscriber example.** Show one Flow or Apex trigger with duplicate-event safety,
   after-commit behavior, replay guidance, missing record identity, and safe error handling. Keep it
   in the Extensions repository if it is not part of Core.
5. **Apex and Flow error examples.** Show request exceptions, `UNABLE_TO_EVALUATE`, system errors,
   unknown future reason codes, and the 15-evaluation request limit without comparing message text.
6. **Known limitations for administrators.** Extract no automatic rerun after save, no built-in
   history, no Category grouping, the 25-Rule card limit, 5 simultaneous card requests, page-load
   event behavior, and field-access effects from the design specification.
7. **Supported-version statement.** State minimum Salesforce/API requirements, tested browsers and
   form factors, source-deployment model, and whether Salesforce mobile and Experience Cloud are
   supported, untested, or out of scope.

### Clarity and terminology cleanup still required

The wiki narrative is substantially cleaner, but deep technical references still mix Salesforce
terms with internal engineering language. Review these current V2 pages sentence by sentence:

- `record-health-check-design-spec.md`: replace reader-facing “façade,” “DTO,” “wire boundary,”
  “sink,” and “contract” where **public Apex class**, **response**, **Apex response**, **logging
  class**, or **documented behavior** is accurate.
- `configuration-guide.md`: move implementation flow and edge cases out of the administrator path
  into the design specification; keep this guide task-based.
- `programmatic-api.md`: retitle it **Apex API and Flow**, define `runId` as a shared run identifier,
  and explain version fields once instead of repeating “contract” language.
- `lifecycle-events.md`: prefer official Platform Events terms; replace “payload,” “consumer,” and
  “best effort” with exact field, subscriber, and publishing behavior statements.
- `llm-configuration.md`: correct broken example links, update stale field names and headings, and
  separate copyable prompts from supported product documentation.
- `architecture-map.md`: label it as a contributor reference so administrators do not mistake code
  layout for required product knowledge.

Do not remove exact API values, class names, method names, reason codes, SOQL, Apex, Flow, Custom
Metadata, Lightning App Builder, platform event, sharing, object access, or field access. These are
Salesforce terms or required product identifiers. Define them at first use and keep administrator
pages focused on the task being completed.

## Checks that passed

| Check                                   | Result         | Evidence                                                             |
| --------------------------------------- | -------------- | -------------------------------------------------------------------- |
| LWC unit tests                          | Pass           | 1 suite; 111/111 tests                                               |
| Standard ESLint                         | Pass           | `npm run lint` exits 0                                               |
| Salesforce/manifest XML syntax          | Pass           | 362 XML files parsed                                                 |
| V2 jargon gate in shipped metadata/code | Pass           | no whole-word `scalar` or `comparator` under `force-app/`            |
| Code Analyzer release threshold         | Pass with debt | no High/Critical; 455 Moderate findings require triage               |
| Namespaced-token gate                   | **Fail**       | 90 legacy tokens                                                     |
| Prettier gate                           | **Fail**       | 2 files                                                              |
| LWC coverage gate                       | **Invalid**    | command exits 0 while reporting 0%                                   |
| Current/public Markdown links           | **Fail**       | current V2 broken targets are present within 176 whole-tree failures |
| Final org smoke/rollback/approval       | **Open**       | unchecked Gate C/E/exception items                                   |

## Recommended release sequence

1. Freeze the intended file set. Commit the versioned docs, images, theme files, release notes,
   deletions/redirects, and all other intended V2 content on the release branch.
2. Fix the three automated-gate defects: token scope/content, formatting, and real coverage
   instrumentation. Make CI green on the frozen SHA.
3. Repair every current V2/public broken link and clarify the core-versus-examples boundary. Add a
   link check that excludes only documented archives/templates.
4. Triage Moderate Analyzer findings, prioritize correctness and SLDS 2 compatibility, audit the
   97 suppressions, and make Code Analyzer consume the repository ESLint configuration.
5. Deploy the exact SHA to a clean org. Run all Apex tests and metadata validation; assign User and
   Admin permission sets; exercise App Builder, both themes, permission denial, diagnostics,
   representative Formula/SOQL/compare-query/Apex checks, guided links, events, and error states.
6. Perform the documented upgrade and rollback with exported V1 metadata. Retrieve source back and
   confirm no unexpected drift.
7. Update release notes and `RELEASING.md`, pin the public deploy link to the release tag, obtain PR
   and release-owner approval, merge to the documented release branch, and tag the exact reviewed
   SHA.
8. Install from the tag into a fresh sandbox once more, verify the release page and links, then
   announce.

## Go/no-go acceptance checklist

- [ ] `git status --short` is empty on the exact candidate SHA.
- [ ] `npm ci`, formatting, lint, namespaced tokens, real coverage, and XML checks all pass.
- [ ] LWC coverage is non-zero, meets thresholds, and a forced regression proves the gate fails.
- [ ] Current/public documentation has zero unexplained broken local links.
- [ ] Code Analyzer applies `eslint.config.js`; every High/Critical is zero and each Moderate or
      suppression is fixed or recorded with a plain-language reason.
- [ ] Clean-org deploy, Apex tests/coverage, metadata validation, permission paths, and UI matrix
      pass against the candidate SHA.
- [ ] Upgrade, backup, rollback, and source-readback evidence match the candidate SHA.
- [ ] Release notes list all breaking changes and clearly separate core from optional examples.
- [ ] Public install links point to the frozen release tag.
- [ ] Required human review and release-owner approval are recorded.

## Final assessment

**No-go today.** The framework’s implementation quality is promising and the test depth around the
LWC is a real strength, but public-release quality includes reproducibility, honest gates, working
learning paths, and a proven install/rollback experience. Fixing the P0 items is mandatory. The P1
items should also close before a V2.0.0 announcement; the P2 items are the polish that will make the
project feel as careful to Salesforce administrators as its underlying engineering already is.
