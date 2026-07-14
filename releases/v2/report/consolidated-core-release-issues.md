# Consolidated V2 Release Issues — Core (`RecordHealthCheck`)

**Consolidates:** the four deep-audit reports in [`releases/v2/report/`](.) —
Claude release audit, Claude documentation audit, Codex audit, and Cursor audit — into a single
core-only punch list. Examples-repo issues are tracked separately in the
`RecordHealthCheck-Examples` repo (`docs/consolidated-release-issues.md`); they are **not** in
scope for this document.

**Date consolidated:** 2026-07-14
**Branch:** `v2-release` @ `f5bca45` (working tree dirty)
**Verdict across all four audits:** **Not GitHub-release-ready yet.** The framework code is
release-candidate quality (security, tests, field contract); the blockers are packaging/publishing
hygiene, uncommitted work, red CI gates, one runtime contract bug, and documentation completeness —
not defects in the framework.

> **Docs vs wiki decision (from prior chat):** track and ship documentation as in-repo **`docs/`
> pages, not the GitHub wiki**, so it version-controls and reviews cleanly. Findings the source
> audits raised against `wiki/` pages are folded into the **Documentation** section below and
> re-scoped as `docs/` work. Treat `wiki/` as superseded.

Each item lists which source audits raised it (C-Rel = Claude release, C-Doc = Claude docs,
Codex, Cursor) so nothing is lost in the merge.

---

## How to read this

- **Severity:** Blocker (cannot ship as claimed) → High → Medium → Low/Nit.
- **Status column** in each table is for you to drive to done.
- Where audits disagreed, the reconciled/verified state is stated inline (notably the "broken
  examples links" finding — see D-1).

---

## 1. Release blockers — must close before tagging `v2.0.0`

### BLK-1 — LWC imports two SLDS CSS files that are not committed

- **Sources:** C-Rel (B1), Cursor (B-SHIP-3)
- **Evidence:** `force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js:7-8` imports
  `./recordHealthCheckSlds1.css` and `./recordHealthCheckSlds2.css` and registers them at `:46` as
  `static stylesheets`. Both files are untracked and never committed.
- **Impact:** A fresh clone + `sf project deploy start -d force-app` fails to compile the LWC
  ("module not found"). Breaks **both** advertised install paths. Local tests pass only because the
  files exist on disk.
- **Fix:** `git add` both CSS modules and commit them with the modified `recordHealthCheck.css`;
  dry-run a deploy before merge.

### BLK-2 — The V2 changeset is uncommitted; no reproducible release snapshot

- **Sources:** C-Rel (B2, M4), Codex (P0-5), Cursor (B-SHIP-2)
- **Evidence:** ~35 modified, ~8 untracked, 5 deleted-tracked paths, including all `docs/v1/`,
  all `docs/v2/`, the SLDS CSS pair, the LWC redesign, README rewrite, and
  `releases/v2/V2-RELEASE-NEW-FUNCTIONALITY.md`. Tagging the current commit would omit all of it.
- **Fix:** Commit the complete intended release set as coherent commits (code / docs / config),
  confirm nothing intended is gitignored, then open the release PR. Run every gate on that exact SHA.

### BLK-3 — GitHub installs v1.2.0, not V2 (default branch + Deploy button + no tag)

- **Sources:** C-Rel (B3), C-Doc (D2), Codex (P1-2), Cursor (B-SHIP-1)
- **Evidence:** `origin/main` = v1.2.0 (`a723eb9`), `v2-release` is **11 commits ahead**; tags stop
  at `v1.2.0` (no `v2.0.0`). README badge/Deploy button + `docs/v2/start/first-10-minutes.md:21`
  use `ref=main`. `RELEASING.md:105` states the button "always installs the latest `main`."
- **Impact:** Every "try it from GitHub" path installs the wrong product; rollback symmetry lost.
- **Fix:** Merge `v2-release` → `main`, tag `v2.0.0`, and pin the primary Deploy button to the tag
  (offer `main` only as a clearly labeled "latest/dev" option). Verify after publication.

### BLK-4 — CI gate `check:namespaced-tokens` fails (90 legacy tokens)

- **Sources:** Codex (P0-1)
- **Evidence:** `npm run check:namespaced-tokens` exits 1 (`legacyTokenCount:90`). The checker
  scans all of `docs/` including historical V1 pages: 89 historical/example hits **plus one current
  V2 hit** at `docs/v2/reference/reason-codes.md` (`{!Id}`).
- **Fix:** Correct the current V2 token, then decide the policy: (a) exclude `docs/v1` as an immutable
  archive, or (b) require V2 syntax everywhere. Encode the choice in the script and add a fixture so
  versioning docs can't silently re-break the gate. Acceptance: exits 0 from a clean checkout.

### BLK-5 — CI gate `prettier:verify` fails

- **Sources:** C-Rel (P1), Codex (P0-2)
- **Evidence:** `npm run prettier:verify` exits 1 on `README.md` (stray trailing blank line) and
  `recordHealthCheck.js-meta.xml` (`<targetConfig>` indentation).
- **Fix:** `npm run prettier`; review the metadata XML diff before accepting.

### BLK-6 — Coverage gate is a false green (reports 0%)

- **Sources:** Codex (P0-3)
- **Evidence:** `npm run test:unit:coverage` exits 0, runs all 111 tests, but prints
  `All files | 0 | 0 | 0 | 0`, contradicting the thresholds in `jest.config.js:13-20`. CI relies on
  this command.
- **Fix:** Fix instrumentation so the files matched by `jest.config.js:6-12` are measured; prove a
  deliberately untested line lowers coverage and a below-threshold run fails; retain the summary as
  CI evidence.

### BLK-7 — `{!rhcRun.*}` merge tokens are allowlisted but never wired → runtime ERROR

- **Sources:** Cursor (H-APEX-1); also flagged in Cursor §9.C/§9.G merge-token docs
- **Evidence:** `RecordHealthCheckTokenRegistry` allowlists the `rhcRun` prefix + `RUN_PROPERTIES`;
  `RecordHealthCheckMergeContext` has a `run` field that production code never populates (only tests
  do). The template resolve path treats a null run as unavailable → throws → engine records an
  evaluation ERROR.
- **Impact:** Config-time validation **accepts** a token that **always** fails at runtime — a public
  contract bug.
- **Fix:** Either populate run context on the evaluate/`runSet` paths, **or** remove `rhcRun` from
  the allowlist until supported. Whatever ships must match the merge-token docs (DOC-8).

### BLK-8 — SLDS "Design System" feature is documented nowhere

- **Sources:** C-Rel (B4), C-Doc (D3)
- **Evidence:** V2 ships a "Design System" App Builder property (values **SLDS 2 / SLDS 1**,
  `recordHealthCheck.js-meta.xml:23-28`) with a real theming layer (`themeClass` getter
  `recordHealthCheck.js:56-63` + the two CSS modules). It appears in no user doc, README, or
  CHANGELOG.
- **Fix:** New `docs/v2/guides/design-system.md` (or a config-guide subsection) explaining: SLDS 2 is
  the default (Cosmos theme), SLDS 1 preserves legacy styling, the setting is per-placement and does
  **not** change the org theme (the `js-meta.xml:28` description is good raw copy). Add a CHANGELOG
  entry, a README "What You Get" bullet, and one line in the install/getting-started guide.

### BLK-9 — "Core ships one hero Check Set" contradicts what `force-app` deploys

- **Sources:** Codex (P2-2, boundary addendum), Cursor (B-DOC-3, §9.A, §9.G)
- **Evidence:** README/wiki say Core ships **one** hero Check Set; `force-app/main/default/customMetadata/`
  holds **15** `*Set__mdt` + **132** `*Rule__mdt`. A full `force-app` / Deploy-button deploy lands 14
  extra sample Sets. Core tests also reference some public example names.
- **Fix (pick one, then make docs true):**
  1. **Boundary completion:** replace test dependencies on public example names with clearly-named
     internal fixtures, then remove the non-hero library CMDT, optional example Apex, and non-hero
     manifests from Core (the four migrated libraries: `Account_Data_Quality`,
     `Account_Everyday_Use_Cases`, `Account_Relationships`, `Account_Examples_Apex`); **or**
  2. **Narrative honesty:** document that Core currently bundles the sample Account library, ship a
     `manifest/package-core.xml` for a clean install, and correct the "one hero" claim.
- **Note:** Prior §3 audit language claiming these were "moved" is inaccurate while they remain in
  Core — correct that audit wording too (Cursor §4.5).

### BLK-10 — Release-gate workflow calls a gitignored Apex script

- **Sources:** Cursor (H-SHIP-1)
- **Evidence:** `.github/workflows/salesforce-validate.yml` runs
  `scripts/apex/validateMetadata.apex`, but `.gitignore` ignores `scripts/` — the file is local-only,
  so the gate fails on a clean checkout.
- **Fix:** Commit a tracked validate script (e.g. under `releases/v2/tools/` or a tracked `scripts/`
  carve-out) and update the workflow path.

### BLK-11 — Mandatory human release gates (C / E) still open

- **Sources:** Codex (P0-4), Cursor (Gate C/E)
- **Evidence:** `releases/v2/plans/section-9-release-readiness/9-release-readiness-gates.md:154-166`
  leaves unchecked: Account-page manual smoke (permission + diagnostics paths), backup/rollback
  closeout, final PR review/approval, tag, and explicit exception approval.
- **Fix:** Run the smoke + rollback scripts in disposable orgs, attach sanitized evidence, review the
  final diff, approve exceptions explicitly, then tag the reviewed SHA.

| ID     | Blocker                                 | Sources              | Status |
| ------ | --------------------------------------- | -------------------- | ------ |
| BLK-1  | Untracked SLDS CSS imports              | C-Rel, Cursor        | ☐      |
| BLK-2  | Uncommitted V2 changeset                | C-Rel, Codex, Cursor | ☐      |
| BLK-3  | GitHub installs v1.2.0 / no tag         | all four             | ☐      |
| BLK-4  | `check:namespaced-tokens` fails         | Codex                | ☐      |
| BLK-5  | `prettier:verify` fails                 | C-Rel, Codex         | ☐      |
| BLK-6  | Coverage false green (0%)               | Codex                | ☐      |
| BLK-7  | `rhcRun` tokens error at runtime        | Cursor               | ☐      |
| BLK-8  | Design System feature undocumented      | C-Rel, C-Doc         | ☐      |
| BLK-9  | "One hero set" vs 15 sets in Core       | Codex, Cursor        | ☐      |
| BLK-10 | Workflow calls gitignored script        | Cursor               | ☐      |
| BLK-11 | Manual smoke / rollback / PR / tag open | Codex, Cursor        | ☐      |

---

## 2. High — close before or immediately after tagging

### HI-1 — Apex verification not reproduced against the final candidate

- **Sources:** Codex (P1-4), Cursor (Gate C)
- The local suite covers the LWC only; Apex rests on prior scratch-org artifacts against a different
  tree. **Fix:** after committing, run a clean scratch-org deploy with `RunLocalTests` + metadata
  validation + user/admin permission checks + source readback; record the job URL/SHA and real Apex
  coverage.

### HI-2 — `validateAsJson()` is `@AuraEnabled` with no permission gate

- **Sources:** Cursor (M-APEX-3)
- `RecordHealthCheckMetadataValidator.cls` (~125-128) serializes full validation of all Sets/Rules
  (query/class/formula surfaces) to any user who can invoke Aura/LWC Apex. **Fix:** gate with the
  existing access helper / a custom permission, or drop `@AuraEnabled` and keep it Apex/CI-only.

### HI-3 — Fix-it `actionUrl` has no client-side scheme guard (defense-in-depth)

- **Sources:** Cursor (H-LWC-1)
- `healthCheckPresentation.js` passes `actionUrl` straight to `href` in the HTML; Apex sanitizes but
  the LWC trusts that alone. **Fix:** accept only paths starting with `/` or `https:`; otherwise drop
  the link and keep the instructions. Add Jest cases for rejected schemes.

### HI-4 — Code Analyzer passes the threshold but has a large untriaged middle

- **Sources:** Codex (P1-3)
- 1,272 findings / 71 files (455 Moderate, 811 Low, 6 Info) + 97 inline suppressions; no High/Critical
  so it exits 0. **Fix:** triage Moderate in three buckets — (1) correctness/security/dead-code: fix
  now; (2) SLDS 2 compatibility hooks in the newly themed CSS: verify visually + fix now; (3)
  complexity/style debt: file scoped follow-ups with owners. Audit all 97 suppressions for a
  plain-language reason each; configure Analyzer to consume `eslint.config.js` (it warned the config
  was found but not applied).

### HI-5 — Release guide has stale/misleading verification text

- **Sources:** Codex (P1-5), Cursor (M-DOC-3)
- `RELEASING.md:38` promises 106 Jest tests (suite is now 111); CONTRIBUTING cites 106 too. The
  `npm test -- --runInBand` form doesn't forward `runInBand` (npm warns unknown config);
  `docs/v2/installation/upgrading-to-v2.md:41` repeats it. **Fix:** generate or drop hard-coded test
  counts; document the correct wrapper syntax; add a draft-tag install rehearsal before announcement.

| ID   | High item                              | Sources       | Status |
| ---- | -------------------------------------- | ------------- | ------ |
| HI-1 | Apex re-verify on final SHA            | Codex, Cursor | ☐      |
| HI-2 | Gate `validateAsJson`                  | Cursor        | ☐      |
| HI-3 | Client-side `actionUrl` guard          | Cursor        | ☐      |
| HI-4 | Triage 455 Moderate + 97 suppressions  | Codex         | ☐      |
| HI-5 | Stale test counts / `runInBand` syntax | Codex, Cursor | ☐      |

---

## 3. Documentation (in-repo `docs/`, per the wiki→docs decision)

> All `wiki/` findings below are re-scoped as `docs/` work. If any wiki is kept at all, it should be
> a thin pointer into `docs/`; the source of truth lives in `docs/v2/`.

### DOC-1 — Broken examples links (reconciled state)

- **Sources:** Codex (P1-1), Cursor (B-DOC-1/B-DOC-2), C-Doc (D1, **corrected**)
- **Reconciled truth:** C-Doc's re-verification found `docs/v2/` already deep-links every example to
  the `RecordHealthCheck-Examples` repo with full GitHub URLs, and the targets exist in the Examples
  clone — so there is **no local examples-tree gap in `docs/v2`**. The residual broken `../examples/`
  links live in **`docs/v1/`** (frozen v1 history) and in a few current-page/Pages surfaces Codex/Cursor
  still caught. **Actions:**
  1. Decide `docs/v1` policy: leave frozen (accept dead example links) or repoint to the Examples repo.
  2. Fix `docs/index.html` example CTA cards (`/examples/formula|soql|apex/...`) — point to the
     Examples repo or remove until live.
  3. Fix any remaining current-page relative-example links Codex flagged
     (`plugin-reference.md`, `plugin-contract.md`, `quick-start.md`, `configuration-guide.md`,
     `cli-commands.md`, `llm-configuration.md`).
  4. Add a Markdown link checker to CI that excludes only documented archives/templates.

### DOC-2 — Docs-site nav still points at old flat paths

- **Sources:** C-Doc (Examples addendum)
- `docs/_layouts/base.html:30-40` links `/installation/`, `/examples/`, `/guides/`, `/reference/`
  while the homepage body uses `/v2/…`; the nav `/examples/` link (line 33) has no target and 404s.
  **Fix:** finish the flat→`/v2/` nav migration as one deliberate pass.

### DOC-3 — Internal maintainer/planning docs leak onto GitHub Pages

- **Sources:** C-Doc (D5), Cursor (M-DOC-1)
- `docs/_config.yml` `exclude:` misses planning pages still under `docs/reference/`
  (`product-roadmap.md`, `label-simplification-plan.md`, `record-health-check-ui-changes-2026-06.md`,
  `code-quality-and-hardening-guide.md`). Docs also link the extension model to
  `releases/v2/V2-RELEASE-PLAN.md` / `V2-RELEASE-NEW-FUNCTIONALITY.md` ("do not start until V2 is
  tagged"). **Fix:** exclude/move planning pages; link the extension model to the user-facing
  design-spec section, not the release plan.

### DOC-4 — Field label mismatch: "Failure Message" vs "Message When Failed"

- **Sources:** C-Doc (D4)
- Docs prose (originally `wiki/Author-Checks.md:32,41`) names "Failure Message"; the field is
  `FailureMessage__c` with label **"Message When Failed"** (as in Setup and every `docs/v2` page).
  **Fix:** standardize on "Message When Failed"; also consider aligning "Expected Value" with the real
  label "Expected Value Comes From" (`ExpectedValueSource__c`).

### DOC-5 — README mixes stale v1.2.0 migration prose into the V2 first impression

- **Sources:** C-Rel (P2), Codex (P2-1), Cursor (M-DOC-2)
- `README.md:44-49` follows the V2 warning with two dense v1.2.0 App Builder migration paragraphs.
  **Fix:** move v1.x specifics to `docs/v1/` / CHANGELOG; keep the README V2-focused.

### DOC-6 — CS jargon in docs (Salesforce-language gate)

- **Sources:** Cursor (§9.D), Codex (clarity/terminology), C-Doc (M1)
- Replace, in prose (not API values): `façade`→"`RecordHealthCheck` Apex entry point / Flow action";
  `DTO`→"wire format the Lightning component expects"; `additive-only`→"new fields/codes can be added
  without breaking callers"; `consumer/consume`→"subscriber/subscribe/use"; `Invocation Adapter`→
  "scheduled, batch, or REST caller"; token `namespace`→token **prefix**. Pages: design-spec,
  configuration-guide, programmatic-api, lifecycle-events, architecture-map, README. **Leave**
  `scalar`/`comparator` only inside `upgrading-to-v2.md` rename history; keep the `FACADE` event-source
  **value** documented as a value, not prose.
- Also fix factual drift Cursor caught: getting-started permset is **not** only
  `RecordHealthCheckController` + `RecordHealthCheck` (also `RecordHealthCheckFlowAction` + platform
  event object access); `cli-commands.md` "ten set manifests" → real count; permset description still
  says "metrics log object" (V1) → update to lifecycle-events language.

### DOC-7 — Three large field-guides overlap

- **Sources:** C-Doc (D6)
- `configuration-guide.md` (~3,672w), `llm-configuration.md` (~4,548w), `metadata/rule-fields.md`
  (~2,222w) each re-enumerate Rule fields. **Fix:** one dedup pass — field semantics stated once in
  `rule-fields.md` / field-size registry and **linked**; guides keep only audience-specific framing.

### DOC-8 — Missing/thin V2 how-to docs

- **Sources:** Cursor (§9.C), Codex (new-docs list), C-Doc (missing-doc checklist)
- Add (as `docs/v2` pages; drop the wiki equivalents):
  - **Permissions & access** — `Record_Health_Check_User` vs `_Admin`, `View_Details` custom
    permission, `Record_Health_Check_Configure` documented as **reserved/not yet used**.
  - **Upgrading from v1** — short page linking the deep `upgrading-to-v2.md`.
  - **Merge-token reference** — align with `RecordHealthCheckTokenRegistry` prefixes
    (`record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun`); document `rhcRun` as **unsupported** until
    BLK-7 is resolved.
  - **Flow how-to** — Setup → Flow Builder steps for the "Run Record Health Check" invocable action.
  - **Lifecycle events: enable + subscribe** — turn on publish switches, build a platform-event
    subscriber, correlate by Run ID, note payload omissions.
  - **Known limitations / "what V2 doesn't do yet"** — no auto-rerun on save, no built-in history, no
    Category grouping, 25-Rule card limit, 5 simultaneous requests, page-load never publishes.
  - **Supported-version statement** — min Salesforce/API, tested browsers/form factors, source-deploy
    model, mobile/Experience Cloud support status.
- **Trim (density):** `show-diagnostics.md` overlapping permission tables → one "who sees what" matrix.

| ID    | Doc item                                  | Sources              | Status |
| ----- | ----------------------------------------- | -------------------- | ------ |
| DOC-1 | Broken examples links (reconciled)        | Codex, Cursor, C-Doc | ☐      |
| DOC-2 | Flat vs `/v2/` nav migration              | C-Doc                | ☐      |
| DOC-3 | Planning docs leak to Pages / bad links   | C-Doc, Cursor        | ☐      |
| DOC-4 | "Message When Failed" label               | C-Doc                | ☐      |
| DOC-5 | Strip v1.2.0 prose from README            | all                  | ☐      |
| DOC-6 | Jargon + factual drift pass               | Cursor, Codex, C-Doc | ☐      |
| DOC-7 | Dedup three field-guides                  | C-Doc                | ☐      |
| DOC-8 | Missing V2 how-tos + limitations/versions | Cursor, Codex, C-Doc | ☐      |

---

## 4. Medium — Apex / runtime polish

- **MED-A1 — Result `contractVersion` is `'0.1'` on a 2.0.0 product** (Cursor M-APEX-2). Lifecycle
  events use `'1.0'` + core `'2.0.0'`. Bump intentionally and update pinned tests/docs.
- **MED-A2 — Reason codes only partially centralized** (Cursor M-APEX-1). Many codes are string
  literals across ConfigService / MetadataValidator / Engine / SoqlEvaluator. Promote to constants;
  generate or assert `docs/v2/reference/reason-codes.md` from them.
- **MED-A3 — `runSet` can approach the SOQL governor ceiling in one transaction** (Cursor M-APEX-4).
  Up to 15 evaluations/call, each possibly multiple queries. Document guidance + add a mid-loop
  `Limits.getQueries()` short-circuit returning a clean `GOVERNOR_LIMIT_RISK` result.
- **MED-A4 — Logger unit tests assert `true`** (Cursor M-APEX-5). Make `render` testable; assert line
  shape/levels.

## 5. Medium — LWC / UI polish

- **MED-L1 — "Needs Setup" banner uses the red `error` icon variant** (Cursor M-LWC-1). First-run/config
  state looks like a hard failure. Bind the variant to setup-vs-error.
- **MED-L2 — Summary-pill tooltips aren't exposed to screen readers** (Cursor M-LWC-2). Rule names live
  only in CSS `::after`/`data-tooltip`. Mirror into `aria-label`.
- **MED-L3 — "check" vs "rule" UI copy is mixed** (Cursor M-LWC-3, C-Rel M2 comment drift). Counts say
  "Checks"; notices say "rules". Pick one noun for UI (prefer "check"); keep "Rule" for Setup/metadata.

## 6. Low / Nit — code hygiene

- **Comment hygiene** (Cursor N-APEX, C-Rel M2): garbled FormulaEval comment in
  `RecordHealthCheckEngine`; copy-paste comment in the compare-queries evaluator; self-assignment
  no-op `settings.maxNames = settings.maxNames` in the Approval plugin; internal "§2.11 /
  V2-RELEASE-PLAN" comments in shipped JS — trim for public source.
- **Redundant `normalizeResult`** (C-Rel M3, Cursor L-LWC): `healthCheckRunner.js:258` normalizes,
  then `_drain` re-normalizes at `:271`. Idempotent; optional cleanup.
- **Dead / misleading API surface** (Cursor L-APEX-1): deprecated unused `hasActiveCheckSetForObject`,
  test-only `stringList`, always-empty `AdminDetail.fieldNames`, unused params in
  `applyEmptyValueHandling`. Remove or finish before public citation.
- **Duplicated relationship traversal, four copies** (Cursor L-APEX-2): Soql / Formula / Template /
  ValueResolver. Extract one shared helper.
- **Approval sample plugin builds SOQL identifiers from JSON params without describe validation**
  (Cursor L-APEX-3): low runtime risk (USER_MODE + trusted CMDT) but high copy-paste risk as a
  reference plugin. Validate API names via describe cache; call out the pattern in plugin docs.
- **CSS token fallbacks inconsistent; "Rerun" vs "Re-run" split; empty-Check-Set diagnostics hints
  "check console" with no logging** (Cursor L-LWC). Normalize.

---

## 7. Reconciled release sequence (core)

1. **Freeze the set:** commit all intended V2 code + docs + config as coherent commits (BLK-1, BLK-2).
2. **Green the automated gates on that SHA:** namespaced tokens (BLK-4), prettier (BLK-5), real
   coverage instrumentation (BLK-6), plus lint/XML.
3. **Fix the runtime contract:** wire or remove `rhcRun` (BLK-7); gate `validateAsJson` (HI-2);
   add the `actionUrl` scheme guard (HI-3).
4. **Resolve the Core/Examples boundary + packaging honesty** (BLK-9): remove non-hero samples or
   correct the narrative + ship `package-core.xml`; fix the gitignored validate script (BLK-10).
5. **Document the gaps:** Design System (BLK-8), missing V2 how-tos + limitations (DOC-8), jargon +
   factual pass (DOC-6), broken links + nav + Pages exclusions (DOC-1/2/3), labels (DOC-4), README
   trim (DOC-5), dedup (DOC-7). Add a Markdown link checker to CI.
6. **Prove it on an org:** clean scratch-org deploy of the exact SHA with `RunLocalTests`, metadata
   validation, both permission paths, both SLDS themes, diagnostics, and the full outcome matrix
   (HI-1); complete Gate C smoke + Gate E rollback/backup evidence (BLK-11).
7. **Ship mechanics:** update `RELEASING.md`/CONTRIBUTING (HI-5), merge `v2-release` → `main`, tag
   `v2.0.0`, pin the Deploy button to the tag (BLK-3), reinstall from the tag into a fresh sandbox,
   verify links, then announce.
8. **Fast-follow polish:** Sections 4–6 (contractVersion, reason-code constants, governor guard,
   a11y/copy, comment + dead-code cleanup).

---

## 8. What is genuinely strong (all four audits agree)

- **Security posture:** every class `with sharing`; admin SOQL runs `WITH USER_MODE`, blocks
  `SYSTEM_MODE`, escapes quotes, binds variables, enforces a row cap; the single Code Analyzer
  suppression is inline-justified; the controller length-caps identifiers and never leaks internal
  error detail.
- **Code hygiene:** no TODO/FIXME/HACK, no stray `System.debug`, no empty catches, no hardcoded IDs,
  `scalar`/`comparator` gate passes in `force-app`.
- **LWC quality:** 111 Jest tests pass, ESLint clean, careful token/staleness guards, real
  accessibility work, plain-language "why" comments.
- **Docs bones:** admin-vocabulary tone, single-source-of-truth discipline, honest "not yet" notes on
  deferred features (Category grouping), accurate field/interface/event/façade-signature coherence.

The gap is the **last mile of ship hygiene, one runtime wiring bug, and documentation completeness —
not a framework rewrite.**
