# Cursor deep audit — GitHub V2 release readiness

| Field                  | Value                                                                                                                                                                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Date                   | 2026-07-14 (updated same day with docs/wiki polish pass)                                                                                                                                                                                         |
| Auditor                | Cursor (Composer) deep review                                                                                                                                                                                                                    |
| Branch / HEAD          | `v2-release` @ `f5bca45`                                                                                                                                                                                                                         |
| Working tree           | Dirty — large uncommitted V2 docs/LWC/wiki set                                                                                                                                                                                                   |
| Remote default         | `origin/main` at v1.2.0 (`a723eb9`); **11 commits behind** local `v2-release`                                                                                                                                                                    |
| Tags on remote         | `v1.1.0`, `v1.2.0` only — **no `v2.0.0`**                                                                                                                                                                                                        |
| Scope                  | Full `force-app/` Apex + LWC, `docs/` (+ `v1`/`v2`), **all `wiki/` pages**, README/CONTRIBUTING, CI/packaging, §9 gates, V2 shipped features vs doc coverage, prior `releases/v2/audits/`                                                        |
| Docs standards applied | Salesforce Setup / admin / developer terminology only; no CS jargon; clear without over-explaining; wiki narrative + `docs/v2` facts stay one source of truth                                                                                    |
| Related prior audits   | [`../audits/2026-07-13-section-9-release-readiness-audit.md`](../audits/2026-07-13-section-9-release-readiness-audit.md), [`../audits/2026-07-13-v2-completion-verification-audit.md`](../audits/2026-07-13-v2-completion-verification-audit.md) |
| Review later           | **§9** is the detailed documentation / wiki punch list for human review before publish                                                                                                                                                           |

---

## 1. Verdict

**Not GitHub-release-ready yet — for a polished public V2 launch.**

**Code:** Strong release-candidate quality (security posture, tests, field contract).  
**Docs / wiki:** Strong structure and tone on many pages, but **not yet polished or complete** for a learning-first public launch. See **§9** for the full page-by-page and missing-doc review.

What blocks calling it “best work out the door” today:

1. **V2 is not what GitHub installs today** — default branch + Deploy button still serve **v1.2.0**; large V2 docs/LWC/wiki work is still **uncommitted**.
2. **Learning path depends on Examples repo** — Core docs now deep-link to `RecordHealthCheck-Examples` (§9a). That repo must be **public and pushed** before Core launch; transitional sample CMDT may still sit in Core `force-app` until a cleanup PR.
3. **Public story vs transitional metadata** — Docs/wiki say Core ships **one hero Check Set**; until non-hero samples are removed from Core `force-app`, a full Deploy-button/`force-app` deploy can still land extra Sets.
4. **Docs use CS-flavored wording** in several wiki/deep pages (`façade`, `DTO`, `additive-only`, `Invocation Adapter`, token “namespace”) instead of plain Salesforce terms.
5. **V2-shipped surfaces lack some how-to docs** — Flow walkthrough, merge-token reference for `rhc*` prefixes, Permissions wiki page, Upgrade wiki page, lifecycle subscribe walkthrough (§9.C).
6. **One real runtime contract bug** — `{!rhcRun.*}` tokens are allowlisted and validated, but the run context is never populated, so those tokens hard-ERROR checks at runtime.
7. **Release-readiness Gate C / Gate E still open** — full browser smoke, rollback restore, PR, and tag remain release-owner work.

Until those close, this is a **strong release candidate / worktree**, not a public V2 release with ready-to-go wikis.

---

## 2. What was reviewed (depth)

| Area         | Coverage                                                                                                                                                                                                                  |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apex         | All **62** classes under `force-app/main/default/classes/` (~18.5k lines production + tests). No triggers. Focus: engine, façade, evaluators, validators, lifecycle publisher, tokens/merge, sample plugins, controllers. |
| LWC          | Entire `recordHealthCheck` bundle: JS modules, HTML, base + SLDS1/SLDS2 CSS, meta.xml, Jest suite (~2.5k+ test lines).                                                                                                    |
| Metadata     | Check Sets/Rules counts, picklists, permsets, platform events, manifests.                                                                                                                                                 |
| Docs         | README, CONTRIBUTING, `docs/` root stubs, `docs/v1/`, `docs/v2/`, `docs/index.html`, `_config.yml`, wiki pages + publish guide.                                                                                           |
| Ship hygiene | CI workflows, `.gitignore`, LICENSE/SECURITY/templates, packaging model, uncommitted surface, prior §9 audits.                                                                                                            |

Method: line-level reads on critical paths, repo-wide searches for jargon/TODOs/secrets, cross-check of doc claims against `force-app`, git/remote state, and reconciliation with 2026-07-13 §9 / completion audits.

---

## 3. Release-gate scorecard (today)

| Gate                                             | Status                    | Notes                                                                                                                                                                                                            |
| ------------------------------------------------ | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A — Docs contract**                            | **Fail for polish**       | Field references mostly match code, but: broken examples links, packaging narrative contradiction, jargon in wiki/deep docs, missing V2 how-tos (§9). Wiki is close in _shape_; not yet publishable as polished. |
| **B — No `scalar`/`comparator` in `force-app/`** | **Pass**                  | Zero matches in current tree.                                                                                                                                                                                    |
| **C — Manual UI smoke**                          | **Open**                  | Prior audit: Set resolves on Account page; full pass/fail/skip/unable + unauthorized + diagnostics paths not recorded.                                                                                           |
| **D — Source↔org readback**                      | **Pass (prior evidence)** | 2026-07-13 readback artifact; re-verify after final commit.                                                                                                                                                      |
| **E — Closeout / tag**                           | **Open**                  | Upgrade guide + `2.0.0` source exist; restore/PR/tag outstanding. Branch not on remote as shippable V2 on `main`.                                                                                                |
| **F — Code Analyzer**                            | **Pass (prior)**          | CI Recommended @ High; local scan recorded clean of High/Critical.                                                                                                                                               |
| **G — Packaging**                                | **Pass for chosen model** | Source-deploy, no namespace, no 2GP — intentional. Must say so clearly in release notes.                                                                                                                         |
| **H — Capacity**                                 | **Pass (prior artifact)** | Façade + event publisher evidence in prior audits.                                                                                                                                                               |
| **GitHub installability**                        | **Fail today**            | Anyone using Deploy button / clone default branch gets **v1.2.0**, not this worktree.                                                                                                                            |

---

## 4. Findings

Severity: **Blocker** (cannot ship as claimed) → **High** → **Medium** → **Low** → **Nit**.

### 4.1 Shipping & repository hygiene

#### B-SHIP-1 — V2 is not on GitHub’s default install path

- **Evidence:** `origin/main` = v1.2.0; `v2-release` is **11 commits ahead**, not reflected as the public default; tags stop at `v1.2.0`. README Deploy button uses `ref=main` (`README.md` badge + Option 1).
- **Why it hurts:** Every “try it from GitHub” path installs the **wrong product**. That is worse than a small code bug — first impressions fail before the framework runs.
- **Fix:** Commit remaining V2 work → push → merge (or replace) `main` with V2 → tag `v2.0.0` → keep Deploy button on `main` or pin to the tag after cut.

#### B-SHIP-2 — Large V2 surface is still uncommitted

- **Evidence:** Untracked/modified include `docs/v1/**`, `docs/v2/**`, `wiki/**`, SLDS CSS pair, LWC redesign, README rewrite, `releases/v2/V2-RELEASE-NEW-FUNCTIONALITY.md`.
- **Why it hurts:** Release cannot be reproduced from any commit. Contributors cloning `v2-release` still miss the Pages/wiki/LWC polish sitting only on disk.
- **Fix:** One coherent commit (or small series) that lands docs + LWC CSS imports **together**, then open the release PR.

#### B-SHIP-3 — LWC imports untracked SLDS CSS files

- **Evidence:** Working-tree `recordHealthCheck.js` imports `./recordHealthCheckSlds1.css` and `./recordHealthCheckSlds2.css`; those files are `??` untracked. Committing JS alone would break LWC compile (“module not found”).
- **Fix:** Always stage both CSS files with the JS change; dry-run deploy before merge.

#### H-SHIP-1 — Release-gate workflow references a gitignored Apex script

- **Evidence:** `.github/workflows/salesforce-validate.yml` runs `scripts/apex/validateMetadata.apex`; `.gitignore` ignores `scripts/`; file is local-only.
- **Why it hurts:** Manual/CI release gate fails on a clean checkout.
- **Fix:** Commit a tracked script (e.g. under `releases/v2/tools/` or a tracked `scripts/` carve-out) and update the workflow path.

---

### 4.2 Documentation & learning experience

#### B-DOC-1 — Missing `docs/v2/examples/` tree; ~29+ broken relative links

- **Evidence:** `docs/v2/examples` does not exist. Links from `getting-started.md`, `quick-start.md`, `configuration-guide.md`, `cli-commands.md`, `llm-configuration.md`, `plugin-reference.md`, `plugin-contract.md`, `sandbox.md`, etc. point at `../examples/...` or `examples/index.md`.
- **Why it hurts:** Onboarding’s “copy a pattern” path 404s. Readers who want to learn by example hit a dead end on the most important journey.
- **Fix:** Repoint every examples link to the public **RecordHealthCheck-Examples** repo (README already does this in places), **or** restore a thin `docs/v2/examples/` index that redirects. Add a markdown link checker to CI.

#### B-DOC-2 — GitHub Pages home promotes dead example cards

- **Evidence:** `docs/index.html` curated example CTAs (`/examples/formula/...`, `/examples/soql/...`, `/examples/apex/...`) have no matching Pages content under `docs/`.
- **Why it hurts:** First screen of the marketing/docs site advertises broken destinations.
- **Fix:** Point cards at the Examples repo (or remove until examples Pages exist).

#### B-DOC-3 — “Core ships one hero Check Set” vs 15/132 in `force-app`

- **Evidence:**
  - Claim: `README.md` Example Library (~line 92); wiki `Install-the-Core.md` (“hero example” only).
  - Reality: **15** `*Set__mdt` + **132** `*Rule__mdt` under `force-app/main/default/customMetadata/`.
  - Accurate docs: `docs/v2/installation/getting-started.md` / `sandbox.md` describe 15 sets (10 reusable + 4 teaching + 1 demo).
- **Why it hurts:** Split brain between README/wiki and install docs. Admins who believed “thin Core + external packs” get a heavy sample library. Undermines trust and the §3.1 core/examples boundary story.
- **Fix (pick one):**
  1. **Narrative honesty:** Say Core still bundles the sample Account library today; document `manifest/package-core.xml` for clean install; note Examples repo for future packs — **or**
  2. **Boundary completion:** Remove non-hero samples from Core (deferred per prior §3 audit) and make the README true.

#### H-DOC-1 — External Examples repo must be public and complete at launch

- README/wiki learning spine depends on `RecordHealthCheck-Examples` (`install.md`, catalog, pattern library, authoring guide).
- **Fix:** Gate Core public launch on that repo being public with those paths live.

#### H-DOC-2 — Same page sometimes says “external repo” and links to missing local examples

- Example: `docs/v2/quick-start.md` describes external packs then links `examples/index.md`.
- **Fix:** One canonical location string used everywhere.

#### M-DOC-1 — Internal planning docs will publish on GitHub Pages

- **Evidence:** `docs/_config.yml` `exclude:` omits `reference/` planning pages that still sit at `docs/reference/` (`product-roadmap.md`, `label-simplification-plan.md`, `record-health-check-ui-changes-2026-06.md`, `code-quality-and-hardening-guide.md`).
- **Why it hurts:** Looks unfinished; leaks maintainership notes into the public site.
- **Fix:** Exclude or move them; keep public reference only under `docs/v2/reference/`.

#### M-DOC-2 — Stale v1.2.0 upgrade paragraphs in README next to V2 breaking callout

- **Evidence:** `README.md` still explains v1.2.0 App Builder property removals after the V2 WARNING.
- **Fix:** Move v1.x upgrade notes into `docs/v1/` / CHANGELOG; keep README V2-only for first public V2 cut.

#### M-DOC-3 — Hard-coded Jest count drift

- CONTRIBUTING cites **106** tests; suite has grown (prior audits 108; tree continues to add cases).
- **Fix:** Update or say “run `npm test`” without a fixed count.

#### L-DOC-1 — Wiki install CLI omits `--source-dir force-app`

- `wiki/Install-the-Core.md` runs `sf project deploy start --target-org <alias>` without `--source-dir force-app` (README Option 2 includes it). Risky for first-time installers.
- **Fix:** Match README’s exact command.

#### L-DOC-2 — `cli-commands.md` says “all ten set manifests” while `manifest/` has more set packages

- **Fix:** Drop fixed count or generate it.

---

### What docs got right (do not lose this)

- V2 Rule/Set field docs match metadata (41 Rule + 12 Set; picklist values align).
- Permission set and custom permission names match shipped metadata (details need a consolidated Permissions page — see §9).
- API **66.0** is consistent across project + badge + most meta (FormulaEval “v63+” called out separately — good).
- Upgrade guide for V2 breaking fields exists and is rightly called out as `[!IMPORTANT]`.
- Jargon gate: `scalar`/`comparator` gone from `force-app`; V2 docs use them only in intentional migration history (`upgrading-to-v2.md`).
- Wiki structure + `[[WikiLinks]]` are coherent; publishing guide is actionable; most wiki pages are well-sized (low cognitive load).
- `Author-Checks.md` is a model of the tone you want: crisp Evaluation Type table, no CS jargon, clear first Rule walkthrough.
- Design: wiki narrative links to `docs/v2` for generated facts (field-size registry, reason codes) instead of copying — keep that.

**Deep documentation / wiki review continues in §9** (page-by-page, jargon, missing V2 pages, reviewer checklist).

---

### 4.3 Apex / runtime

#### H-APEX-1 — `{!rhcRun.*}` allowlisted but never wired → runtime ERROR

- **Evidence:**
  - `RecordHealthCheckTokenRegistry` includes namespace `rhcRun` + `RUN_PROPERTIES`.
  - `RecordHealthCheckMergeContext` has a `run` field, but production code never populates it (only tests exercise run tokens).
  - Template resolve path treats null run as unavailable → throws → engine catches as evaluation ERROR.
- **Why it hurts:** Config-time validation can **accept** a token that will **always** blow up at run time. That is a public-contract bug, not a nit.
- **Fix:** Populate run context on evaluate/runSet paths (`withRun` / set `context.run`), **or** remove `rhcRun` from the allowlist until supported. Prefer wiring if docs already teach it.

#### M-APEX-1 — Reason codes are only partially centralized

- `RecordHealthCheckReasonCodes` holds a small subset; dozens of codes remain string literals across ConfigService / MetadataValidator / Engine / SoqlEvaluator.
- **Why it hurts:** Docs ↔ code drift; typos create “unknown” codes quietly.
- **Fix:** Promote every emitted code to constants; generate or assert docs from that list.

#### M-APEX-2 — Public result `contractVersion` is still `"0.1"` on a 2.0.0 product

- **Evidence:** `RecordHealthCheckResult.CONTRACT_VERSION = '0.1'`; lifecycle events use `'1.0'` + `CORE_VERSION '2.0.0'`.
- **Why it hurts:** Looks unfinished to Flow/Apex integrators reading the DTO.
- **Fix:** Bump result contract intentionally (e.g. `1.0`) and update pinned tests / docs.

#### M-APEX-3 — `validateAsJson()` is `@AuraEnabled` without a permission gate

- **Evidence:** `RecordHealthCheckMetadataValidator.cls` ~125–128 — serializes full validation of all Sets/Rules (including query/class/formula surfaces).
- **Why it hurts:** Config disclosure to any user who can invoke Aura/LWC apex. Admin tooling should require Admin / Configure.
- **Fix:** Gate with existing access helper / custom permission, or remove `@AuraEnabled` and keep Apex/CI-only.

#### M-APEX-4 — `runSet` can approach SOQL governor ceiling in one transaction

- Façade allows up to 15 evaluations per call; each may cost multiple queries (Apex plugins more). LWC is safer (per-check transactions). Flow/`RecordHealthCheck.runSet` is the risk path.
- **Fix:** Document hard guidance + add mid-loop `Limits.getQueries()` short-circuit returning clean `GOVERNOR_LIMIT_RISK` results.

#### M-APEX-5 — Logger unit tests assert `true`

- `RecordHealthCheckLoggerTest` uses tautological asserts; `render` behavior is under-proven.
- **Fix:** Make render testable; assert line shape/levels.

#### L-APEX-1 — Dead / misleading API surface

- Deprecated unused `hasActiveCheckSetForObject`; test-only `stringList`; `AdminDetail.fieldNames` always empty; unused params in `applyEmptyValueHandling`.
- **Fix:** Remove or finish populating before public citation.

#### L-APEX-2 — Duplicated relationship traversal (four copies)

- Soql / Formula / Template / ValueResolver — prior comments already warn about drift.
- **Fix:** One shared helper.

#### L-APEX-3 — Sample plugin builds SOQL identifiers from JSON parameters without describe validation

- `ApprovalInactiveApproverCheck` concatenates object/field names from parameters (values bound; identifiers not validated). Low risk under `USER_MODE` + trusted CMDT authors; high “copy-paste into worse contexts” risk as a **reference** plugin.
- **Fix:** Validate API names via describe cache; call out the pattern in plugin docs.

#### N-APEX — Comment hygiene

- Garbled FormulaEval comment in `RecordHealthCheckEngine` (“100-call / The platform…”).
- Copy-paste comment in compare-queries evaluator claiming “SOQL evaluator also sets…”.
- Self-assignment no-op `settings.maxNames = settings.maxNames` in Approval plugin.
- Edge: `displayLabel` can throw on empty word segments from consecutive spaces.

---

### 4.4 LWC / UI

Overall: **mature, well-modularized, strong Jest coverage**. No XSS via template interpolation, no empty catches, no TODOs/FIXMEs found in the active bundle.

#### H-LWC-1 — Fix-it `href` has no client-side scheme guard

- **Evidence:** `healthCheckPresentation.js` passes `actionUrl` through; HTML binds `href={check.actionUrl}`. Apex sanitizes; LWC trusts that alone.
- **Why it hurts:** Public/reference component; forks may weaken Apex. Defense-in-depth is expected.
- **Fix:** Accept only paths starting with `/` or `https:`; drop link (keep instructions) otherwise. Add Jest cases for rejected schemes.

#### M-LWC-1 — “Needs Setup” banner uses red `error` icon variant

- **Evidence:** `recordHealthCheck.html` hardcodes `variant="error"` even when `errorBannerIcon` is setup gear.
- **Why it hurts:** First-run/config state looks like a hard failure — poor onboarding psychology.
- **Fix:** Bind variant to setup vs true error (warning/neutral for setup).

#### M-LWC-2 — Summary-pill tooltips not exposed to screen readers

- Rule names living only in CSS `::after` / `data-tooltip` are not reliably announced; pills lack `aria-label` with the full “Passed: A, B, C” text.
- **Fix:** Mirror tooltip text into `aria-label` when present.

#### M-LWC-3 — User-facing “check” vs “rule” mixed

- Counts say “Checks”; notices say “active rules” / “inactive rules omitted”.
- **Fix:** One noun in UI copy (prefer “check”), keep “Rule” for Setup/metadata docs.

#### L-LWC — Smaller polish

- Empty Check Set + diagnostics still hints “check console” without logging.
- Inconsistent SLDS token fallback hex values across CSS.
- “Rerun” vs “Re-run” spelling split.
- Redundant double `normalizeResult`.
- Internal “§2.11 / V2-RELEASE-PLAN” comments in shipped JS (trim for public source).

---

### 4.5 Packaging, examples boundary, CI hygiene

| Item                                       | Status                                                                              |
| ------------------------------------------ | ----------------------------------------------------------------------------------- |
| Source-only / no 2GP                       | Intentional for V2 — say so in release notes                                        |
| §3.1 core vs Examples                      | **Incomplete** — samples still in Core; README claims otherwise                     |
| Plugin classes claimed “moved” in §3 audit | Still present in Core (transition reality) — correct the audit language             |
| Secrets in repo                            | **Clean** (only `${{ secrets.* }}` refs)                                            |
| LICENSE / SECURITY / CoC / issue templates | **Present**                                                                         |
| `.gitignore` for local Examples checkout   | **Good**                                                                            |
| `Record_Health_Check_Configure`            | Shipped but unused in runtime (reserved for future Rule Tester) — document or defer |

---

## 5. Positive inventory (why this _will_ look excellent once ships)

Do not bury the strength of the work already done:

- Clear admin language in most user-facing surfaces; jargon gate **passed** in `force-app`.
- Security-minded Apex: sharing, user mode, SOQL template defenses, remediation URL sanitization, FormulaEval budget.
- Public façade + Flow action + lifecycle events with capacity and emission-safety evidence already written.
- LWC architecture (runner / model / presentation) is maintainable; Jest suite is exceptionally thorough for Salesforce open source.
- V2 field migration is clean in source (no lingering v1 Rule/Set field API names).
- Upgrade guide, field-size registry, reason-code docs, architecture map exist under `docs/v2/`.
- Prior §9 automated gates (B/D/F/G/H) already have committed audit evidence from 2026-07-13.

The gap is **finish the last mile of honesty, wiring, and ship mechanics** — not rewrite the framework.

---

## 6. Priority action list (recommended order)

### Must close before tagging `v2.0.0` / flipping `main`

1. **Commit** remaining V2 docs + wiki + LWC (including both SLDS CSS files) as a coherent unit; verify `sf project deploy` dry-run + Jest.
2. **Push / merge** so GitHub default + Deploy button serve V2; cut tag only after reviews.
3. **Confirm Examples repo is public + pushed**; keep Core free of a local `examples/` doc tree (see §9a). Remaining: remove transitional non-hero sample CMDT from Core `force-app`.
4. **Reconcile Core packaging** with hero-only story (delete leftover sample Sets/manifests or keep them gitignored from Deploy).
5. **Docs jargon pass** — replace `façade` / `DTO` / `additive-only` / `Invocation Adapter` / misuse of token “namespace” / loose “consumer” (§9.D).
6. **Wire or reject `rhcRun` tokens** (H-APEX-1); document whatever ships in the merge-token reference.
7. **Gate `validateAsJson`** (M-APEX-3).
8. **Client-side `actionUrl` scheme guard** + setup-banner icon variant + summary pill `aria-label` (H/M LWC).
9. **Complete Gate C** browser evidence and **Gate E** restore + approvals.
10. **Fix release-gate workflow** path to a tracked validate script.
11. **Stop publishing** maintainer planning docs on Pages; scrub README v1.2.0 archaeology.
12. **Add missing wiki/docs pages** for V2 (§9.C): Permissions, Upgrade, merge tokens, Flow how-to, lifecycle enable+subscribe (at least thin pages with links).

### Should close in the same release window (high polish)

13. Align result `contractVersion` with 2.0.0 messaging (and docs that say `0.1`).
14. Centralize reason-code constants; keep `docs/v2/reference/reason-codes.md` as generated or asserted truth.
15. Document / guard `runSet` SOQL budget in programmatic API doc.
16. Unify check/rule UI copy; wiki CLI command parity with README.
17. Trim `show-diagnostics.md` density; fix “only” permset claim in getting-started (§9).
18. Comment cleanup (garbled FormulaEval note, copy-paste comments, self-assignment no-op).
19. Dead API surface removal / `fieldNames` population decision.
20. Harden Approval sample plugin identifier validation.
21. Replace logger `assert(true)` tests.

### Nice-to-have soon after tag

22. Deduplicate field-path traversal helpers.
23. Normalize CSS token fallbacks; Rerun spelling.
24. Finish §3.1 sample relocation so README’s “one hero set” becomes true.
25. Markdown/link CI + optional Pages build check.
26. Publish wiki via `README-PUBLISHING.md` after Core `main` has V2 docs URLs that resolve.

---

## 7. “Would a Salesforce admin learn this easily?” — honest answer

| Journey                                          | Today                                                                                             |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| Install something from GitHub Deploy button      | Gets **v1.2.0**, not this V2 worktree                                                             |
| Deploy from a committed `v2-release` `force-app` | Engine installs; need permset + App Builder                                                       |
| Follow “first Check Set”                         | Hero set works, but org also quietly receives **14 other sample sets** if full `force-app` deploy |
| Learn by copying examples from docs              | **Broken** (missing examples docs tree / Pages cards)                                             |
| Learn from README → Examples repo                | Good _if_ that repo is public; Core README story is half-true                                     |
| Author with V2 field docs                        | Strong — field reference matches metadata                                                         |
| Extend with Apex plugin docs                     | Good content quality, but walkthrough links 404                                                   |
| Integrate via Apex / Flow                        | Solid tables exist; jargon-heavy “façade”; no step-by-step Flow guide (§9.C)                      |
| Learn permissions / diagnostics                  | Accurate but scattered — no wiki Permissions page                                                 |
| Upgrade from v1.x                                | Deep guide exists; no short wiki entry; easy to miss                                              |

**Bottom line:** Install of the engine can succeed. **Learning and trust** are where the release currently fails the bar you set (“go to great lengths to make it easy”). The wiki is half a step from excellent — fix honesty, jargon, and the missing V2 how-tos in §9.

---

## 8. Final recommendation

| Question                                                 | Answer                                                                                                                                                 |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Is the core framework _code quality_ near release-grade? | **Yes** — with a short punch list (especially `rhcRun`, `validateAsJson`, LWC URL/a11y polish).                                                        |
| Are docs + wiki _complete and polished_ for learning?    | **No** — good bones; blockers in §9 (links, packaging story, jargon, missing how-tos).                                                                 |
| Is the project _GitHub public V2 release_ ready today?   | **No.**                                                                                                                                                |
| Biggest reputation risk if tagged now?                   | Shipping v1 via Deploy button / broken learning links / packaging story that disagrees with what lands in the org / “façade” wiki language.            |
| Smallest high-ROI polish set?                            | Ship mechanics + examples links + packaging honesty + jargon pass + Permissions/Upgrade wiki stubs + `rhcRun` + setup banner + actionUrl client guard. |

Treat this document as the go/no-go checklist. When every **Blocker**, the §9 docs/wiki P0–P2 items, and the remaining Gate C/E items are closed, re-run a short verification pass (link check, jargon grep, deploy dry-run, Jest/Apex smoke, wiki publish dry-run) and only then call V2 GitHub-ready with ready-to-go wikis.

---

## 9. Documentation & Wiki polish readiness (review this section in detail)

**Purpose:** Human review checklist for “complete, polished, Salesforce-language-only docs and publish-ready wikis,” including pages that V2 shipped features still need. Standards applied in this review:

| Standard           | What “good” looks like                                                                                                                                                                         |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Terminology        | Setup labels, Custom Metadata Types, Lightning App Builder, Permission Sets, Platform Events, Invocable Actions, SOQL, Apex, Flow, user mode / running user’s field access — **not** CS jargon |
| Length             | Enough to act; not a lecture. One idea per section; link out for depth                                                                                                                         |
| Assumptions        | State prerequisites (sandbox, permset, deploy rights). Do not assume the reader already knows Core vs Examples vs Extensions                                                                   |
| Code ↔ docs        | Claimed behavior matches `force-app`. Wiki does not invent a thinner install than the CLI it shows                                                                                             |
| One fact, one home | Wiki tells the story; `docs/v2` holds field registries, schemas, long guides                                                                                                                   |

### 9.A Wiki — page-by-page review

#### `Home.md` — landing

|                |                                                                                                                                              |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Strengths      | Strong opening promise; three-repo table; clear “pick your path”; safety at a glance                                                         |
| Fix            | Replace “programmatic façade” / “consume … façade” with plain language (Apex entry point / Flow action; “use Core’s events and entry point”) |
| Fix            | “One working hero example” conflicts with a full `force-app` deploy (15 Sets). Align with Install page decision (§9.A Install)               |
| Cognitive load | Good — keep this length                                                                                                                      |

#### `Install-the-Core.md` — first ten minutes

|                |                                                                                                                                                                                                                                                                                              |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strengths      | Outcome table; clear App Builder steps; “nothing else happens” loop                                                                                                                                                                                                                          |
| **Blocker**    | CLI shows `sf project deploy start --target-org …` then claims only the hero Set installs. That command (default package dir) deploys **all** Check Sets in `force-app`. Either use manifests (`package-core.xml` + hero package) **or** say a source deploy installs the sample library too |
| Fix            | Prefer `--source-dir force-app` or manifests for clarity (README Option 2 uses `--source-dir force-app`)                                                                                                                                                                                     |
| Fix            | App Builder step: picker shows **DeveloperName** (`Example_Account_360_Health_Check`), not the Master Label “Example - Account 360 Health Check” — use DeveloperName in the numbered step                                                                                                    |
| Missing        | Clean install vs full sample library callout (one short subsection — see proposed wiki addition below)                                                                                                                                                                                       |
| Cognitive load | Good                                                                                                                                                                                                                                                                                         |

#### `Author-Checks.md` — model page

|           |                                                                                                                                                          |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strengths | Best wiki page for your bar: four Evaluation Types, no jargon, first Rule end-to-end, “3–5 checks” guidance                                              |
| Polish    | “Machine behavior keys on stable stored values” is slightly abstract; optional: “Use Setup labels for people; the product keys on the stored API values” |
| Keep      | Do not expand — length is right                                                                                                                          |

#### `Explore-the-Examples.md`

|                |                                                                                                            |
| -------------- | ---------------------------------------------------------------------------------------------------------- |
| Strengths      | Clear Core vs Examples-repo packs; “pick one pack”                                                         |
| Fix            | Same “Core ships **one** hero” claim — true only for clean/core+hero install story; reconcile with Install |
| Gate           | Depends on public `RecordHealthCheck-Examples` with live catalog paths                                     |
| Cognitive load | Good                                                                                                       |

#### `Integrate.md`

|                |                                                                                                                                                                                                      |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strengths      | Apex vs Flow vs events split; page-load never publishes; code sample is useful                                                                                                                       |
| **Jargon**     | “synchronous façade”, “additive-only”, “Consumers key on…”, repeated “façade”                                                                                                                        |
| Prefer         | Title the section “Run checks from Apex”; say “versioned; new fields can be added without breaking existing callers”; “Callers key on status / reason code / severity / names — not on display text” |
| Missing        | Link to a short Flow _how-to_ (not only the deep programmatic doc’s tables)                                                                                                                          |
| Cognitive load | Moderate — okay after jargon rewrite                                                                                                                                                                 |

#### `Extend.md`

|                |                                                                                                                                                                                              |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strengths      | Safety model is excellent; “never require a change to Core”                                                                                                                                  |
| **Jargon**     | Result/Run **Consumer**, **Invocation Adapter**, “Consumes” column, “façade”, “best-effort consumer”                                                                                         |
| Prefer         | Result **subscriber** / Run **subscriber**; “Scheduled, batch, or REST caller of `RecordHealthCheck`”; “uses” instead of “consumes”                                                          |
| Link risk      | Points at `releases/v2/V2-RELEASE-PLAN.md` and `V2-RELEASE-NEW-FUNCTIONALITY.md` on `blob/main` — those must exist on public `main` after merge, or link to Pages / unlisted maintainer docs |
| Cognitive load | Good once jargon cleaned                                                                                                                                                                     |

#### `Reference.md`

|           |                                                                           |
| --------- | ------------------------------------------------------------------------- |
| Strengths | Correct hub: link, don’t restate                                          |
| Fix       | “façade” / “consumer rules” wording                                       |
| Verify    | “53 fields” still matches generated field-size registry at publish time   |
| Missing   | Entries for proposed Permissions / Upgrade / merge-token pages once added |

#### `_Sidebar.md` / `_Footer.md` / `README-PUBLISHING.md`

|        |                                                                                                     |
| ------ | --------------------------------------------------------------------------------------------------- |
| Status | Sound. After adding Permissions + Upgrade pages, update `_Sidebar.md` under Get started / Reference |

---

### 9.B `docs/v2` coverage map vs V2 shipped functionality

Shipped in V2 (from plan + `force-app`), scored for documentation:

| V2 capability                                   | Primary docs                                         | Wiki                       | Score                                 | Notes for reviewer                                                                            |
| ----------------------------------------------- | ---------------------------------------------------- | -------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------- |
| Record-page card + outcomes                     | Getting started, admin quick start, first-10-minutes | Home, Install, Author      | **Good**                              | Keep; minor check/rule noun consistency with UI                                               |
| Four Evaluation Types                           | Configuration guide §2, Author Checks                | Author                     | **Good**                              |                                                                                               |
| Check Set / Rule field contract                 | `metadata/check-set.md`, `rule-fields.md`            | Reference links            | **Good**                              | Matches code                                                                                  |
| Publish Run / Result Event fields               | Check set §6, rule fields, lifecycle-events          | Integrate (thin)           | **Good reference / thin how-to**      | Need enable→subscribe walkthrough                                                             |
| Programmatic `RecordHealthCheck.run` / `runSet` | `apex/programmatic-api.md`                           | Integrate                  | **Good tables / jargon**              | Caps, user mode documented                                                                    |
| Flow invocable **Run Record Health Check**      | Same file — inputs/outputs table                     | Integrate one sentence     | **Thin**                              | No Setup → Flow Builder steps                                                                 |
| Lifecycle Platform Events schemas               | `reference/lifecycle-events.md`                      | Integrate table            | **Good**                              | Payload omissions documented well                                                             |
| FLS / Show Diagnostics / View Details           | `guides/show-diagnostics.md`                         | Reference link only        | **Good but dense**                    | Trim overlapping permission tables                                                            |
| Reason codes                                    | `reference/reason-codes.md`                          | Author / Reference         | **Good**                              | Keep generated/asserted                                                                       |
| Apex `RecordHealthCheckRule` plugins            | plugin-contract + plugin-reference                   | Integrate                  | **Good body / broken example links**  |                                                                                               |
| Merge tokens `{!record…}`                       | configuration-guide §11                              | —                          | **Thin**                              | Only `record.` shown; code also allowlists `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun`         |
| Clean vs full install                           | getting-started, first-10-minutes                    | **Missing**                | **Gap on wiki**                       |                                                                                               |
| Upgrading v1→V2                                 | `upgrading-to-v2.md`                                 | Reference link only        | **Deep good / wiki thin**             | Need short wiki page                                                                          |
| Example pattern library                         | Examples `docs/pattern-library/`                     | Explore + Core deep links  | **Good (moved)**                      | Core no longer hosts examples docs                                                            |
| Permission Sets + custom permissions            | Scattered §1b + show-diagnostics                     | **No dedicated wiki page** | **Scattered**                         |                                                                                               |
| Source-only install model (no 2GP)              | Partial / release notes                              | Home ecosystem             | **Should be explicit**                | One sentence in Install or README                                                             |
| `Record_Health_Check_Configure` dormant         | Mentioned in getting-started / plan                  | —                          | **Say “reserved”**                    | Avoid “what does this do?” confusion                                                          |
| Category field on Rule (no LWC grouping yet)    | In rule fields                                       | —                          | **Document non-goal / deferred**      | Category ships; card does **not** group yet (post-V2 F1) — say so so admins don’t hunt for UI |
| Skip reason plain-language UI                   | reason codes exist; F3 deferred                      | —                          | **Don’t promise UI that isn’t there** |                                                                                               |

---

### 9.C Proposed **new** documentation (missed or too thin for V2)

Use this as a backlog. Prefer **short wiki narrative + deep `docs/v2` page** where facts grow over time.

#### New wiki pages (recommended before public wiki publish)

1. **`Permissions-and-Access.md`** (sidebar: Get started)  
   Audience: admins. Outline (keep short):
   - `Record_Health_Check_User` — who needs it; Apex classes / events it grants
   - `Record_Health_Check_Admin` — what extra it unlocks
   - Custom permission `Record_Health_Check_View_Details` → Show Diagnostics / restricted detail
   - Custom permission `Record_Health_Check_Configure` → **reserved for future admin tooling** (not used by the card today)
   - Least privilege: who gets User vs Admin
   - Link to Show Diagnostics guide

2. **`Upgrading-from-v1.md`** (sidebar: Get started or Reference)  
   Audience: orgs on v1.x. Outline:
   - Breaking rename; no dual-read of old field API names
   - Back up Custom Metadata before deploy
   - Re-select Check Set on each Lightning record page
   - Publish switches default off — leave off until deliberate
   - Link only to `docs/v2/installation/upgrading-to-v2.md` for the full map

3. **Install page subsection (or short callouts):** **Clean install vs sample library**
   - Core-only: `manifest/package-core.xml`
   - Core + hero: also `package-Example_Account_360_Health_Check.xml`
   - Full source: all sample Sets (list count, not every name)

#### New or expanded `docs/v2` pages

4. **`docs/v2/reference/merge-tokens.md`** (or expand configuration-guide §11 into a true reference)  
   Audience: admins + Apex authors. Must list **code truth** from `RecordHealthCheckTokenRegistry`:
   - Prefixes: `record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun`
   - Allowed properties per prefix
   - Which message / query surfaces accept which prefixes
   - Map reason codes (`UNSUPPORTED_TOKEN_NAMESPACE`, `UNKNOWN_TOKEN_PROPERTY`, …) to cause
   - **Important:** until H-APEX-1 is fixed, **`rhcRun` must be documented as unsupported or removed from the allowlist and docs** — do not teach a token that always fails

5. **Flow how-to** — expand `programmatic-api.md` or add `docs/v2/guides/flow-run-health-check.md`  
   Audience: declarative builders. Outline:
   - Create a record-triggered or screen Flow (say which makes sense)
   - Add Invocable Action **Run Record Health Check**
   - Inputs: Check Set API Name, optional Rule API Name, Record ID
   - Branch on Status / counts
   - When Result JSON is needed
   - Note: enabled publish switches use source value `FACADE` today

6. **Lifecycle events — enable and subscribe** (short guide; lifecycle-events.md stays schema source)  
   Outline:
   - Turn on Publish Run Event / Publish Result Event on metadata
   - Only deliberate Apex/Flow runs publish
   - Build a Platform Event–triggered Flow or Apex trigger subscriber
   - Correlate with Run ID; what is _not_ on the payload (no record Id / messages)
   - Failure to publish does not change check results

7. **Optional one-pager: `docs/v2/guides/what-v2-does-not-do-yet.md`** (or a short FAQ on Home)  
   Prevents false expectations from Category field, Configure permission, Extensions repo “in progress,” list-view Rule Tester (F2), card grouping (F1). Prefer linking from Home/Extend rather than a long roadmap dump.

#### Do **not** invent duplicate pages for

Skip/Unable semantics (reason-codes + admin quick start), Empty Value Handling / No Rows Result (rule-fields), App Builder (only Check Set picker — already covered), design-spec non-goals (link, don’t re-narrate).

---

### 9.D Terminology & jargon sweep (replace before publish)

| Avoid / rewrite                      | Prefer (Salesforce-facing)                                                                          | Where found                                                                                                                               |
| ------------------------------------ | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| façade / facade                      | `RecordHealthCheck` Apex entry point; Flow action **Run Record Health Check**; “programmatic entry” | Wiki Home/Integrate/Extend/Reference; docs README, programmatic-api, lifecycle-events, architecture-map, design-spec, configuration-guide |
| DTO                                  | “values the Lightning component expects on the wire” / “wire format”                                | check-set.md, architecture-map, design-spec                                                                                               |
| additive-only / additive (as jargon) | “new fields or codes can be added without breaking existing callers”                                | Integrate.md, reason-codes.md, programmatic-api.md                                                                                        |
| consumer / consume (events)          | subscriber / subscribe; “use”                                                                       | Home, Integrate, Extend, Reference                                                                                                        |
| Invocation Adapter                   | Scheduled, batch, or REST caller of the Apex entry point                                            | Extend.md                                                                                                                                 |
| allowlist / allowlisted              | approved list / approved prefixes                                                                   | reason-codes.md                                                                                                                           |
| token “namespace”                    | token **prefix** (`record.`, `rhcRule.`, …)                                                         | README, architecture-map, reason codes — keep “namespace” only for packaging namespace                                                    |
| Evaluator (as user term)             | Evaluation Type / evaluation path                                                                   | configuration-guide mental model — fine for deep guide; avoid on wiki                                                                     |
| contractVersion unexplained          | “response version on the result” + current value                                                    | programmatic-api — explain once in plain words                                                                                            |
| telemetry                            | avoid; use “usage / history in an extension”                                                        | if present in linked plans                                                                                                                |

**Leave as-is:** `scalar` / `comparator` only inside upgrading-to-v2 rename history. Stored picklist `UPPER_SNAKE_CASE` is fine for metadata authors. Event source constant `FACADE` is an API value — document the value, don’t use “façade” as the prose name for the whole product surface.

**Also fix factual wording drift:**

- `getting-started.md`: User permset is **not** only `RecordHealthCheckController` + `RecordHealthCheck` — also `RecordHealthCheckFlowAction` + platform event object create/read.
- `cli-commands.md`: “ten set manifests” → match actual manifest count (15 Check Set packages + core).
- User permset description still mentions “metrics log object” (V1 Capture Metrics) — update metadata label/description to lifecycle-events language.

---

### 9.E Cognitive load / duplication

| Item                                           | Finding                                                                                       | Recommendation                                                      |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Wiki page length                               | Generally right                                                                               | Keep Author / Install as models                                     |
| `show-diagnostics.md`                          | Four overlapping permission/visibility tables; phrase “comparison diagnostic details” repeats | Merge tables; one short “who sees what” matrix                      |
| `getting-started.md` (~191 lines)              | Valuable but heavy first-run                                                                  | Keep; ensure First 10 Minutes + wiki Install stay the short path    |
| “Page-load never publishes”                    | Repeated across many pages intentionally                                                      | Keep once on Home + Integrate + lifecycle deep doc; else cross-link |
| `configuration-guide.md`                       | Encyclopedic by design                                                                        | OK; fix broken examples links so promises don’t 404                 |
| Design spec + V2 release plan linked from wiki | Very long for wiki audiences                                                                  | Keep behind Reference; never paste into wiki                        |

---

### 9.F Priority order for **docs/wiki only** (reviewer checklist)

**P0 — must before polished public wiki / pages**

- [ ] Repair every `docs/v2` → missing `examples/` link; fix Pages `index.html` example CTAs
- [ ] Fix Install-the-Core honesty (CLI + what actually installs + DeveloperName in App Builder)
- [ ] Fix getting-started permset “only” claim; fix “ten manifests” count
- [ ] Confirm Examples repo public with paths wiki/README cite
- [ ] Commit wiki + docs/v2 so wiki `blob/main` links resolve after merge

**P1 — terminology & trust**

- [ ] Jargon pass (`façade`, DTO, additive-only, Invocation Adapter, consumer, token prefix)
- [ ] Align README / wiki / getting-started on Core sample story
- [ ] Document Category / Configure as present-but-not-yet-UI (or deferred)
- [ ] Exclude or hide internal planning `docs/reference/` pages from Pages

**P2 — missing V2 learning surfaces**

- [ ] Wiki: Permissions-and-Access
- [ ] Wiki: Upgrading-from-v1
- [ ] docs: merge-token reference aligned with TokenRegistry (+ `rhcRun` decision)
- [ ] docs: Flow how-to
- [ ] docs: lifecycle enable + subscribe how-to
- [ ] Update `_Sidebar.md` + Reference.md links

**P3 — polish**

- [ ] Trim show-diagnostics density
- [ ] README: drop v1.2.0 archaeology from the top of Install
- [ ] CONTRIBUTING: drop stale Jest count
- [ ] Publish wiki per `wiki/README-PUBLISHING.md`
- [ ] Spot-check all wiki → GitHub blob links on `main` after merge

---

### 9.G Docs ↔ code hand-in-hand gaps (explicit)

These are places documentation quality depends on a small code/product decision — document only after the decision:

| Topic                             | Code state                       | Doc implication                                                     |
| --------------------------------- | -------------------------------- | ------------------------------------------------------------------- |
| `{!rhcRun.*}`                     | Allowlisted; never populated     | Do not document as working; fix or remove first                     |
| Result `contractVersion` `0.1`    | Shipped                          | Either bump in code or explain plainly why `0.1` on product `2.0.0` |
| “One hero Check Set”              | 15 Sets in `force-app`           | Docs must follow packaging reality (or packaging must follow docs)  |
| `Record_Health_Check_Configure`   | Unused in runtime                | Document as reserved                                                |
| Category grouping                 | Field exists; LWC does not group | Document deferred UX; don’t imply grouping                          |
| Examples in Core vs Examples repo | Boundary incomplete              | Narrative must not claim the unfinished end-state                   |

---

---

## 9a. Examples ownership (decision applied 2026-07-14)

**Authority:** `V2-RELEASE-PLAN.md` §3 / boundary audit — Core stays independently useful with **one
hero Check Set**; all other examples live in **`RecordHealthCheck-Examples`**.

### What was corrected in this pass

| Surface                                          | Change                                                                                                                                                                        |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Core `docs/v2/**`                                | Broken `../examples/` links retargeted to Examples `docs/pattern-library/` and pack index / install URLs                                                                      |
| Core `docs/index.html`                           | Example teasers and builder CTAs deep-link to Examples GitHub paths (no local `/examples/` Pages tree)                                                                        |
| Core install guides                              | Recommend Core + hero manifests; optional packs from Examples only                                                                                                            |
| Wiki `Install-the-Core` / `Explore-the-Examples` | Hero-only Core install; full pack table with deep links; pattern library vs packs explained                                                                                   |
| Examples repo                                    | Added `docs/core-and-examples-boundary.md`; README Related + tree note; `examples/` files are path aliases → `docs/pattern-library`                                           |
| README Example Library                           | Boundary link + pack index                                                                                                                                                    |
| Examples content polish (follow-up)              | All 35 pattern-library pages retargeted to packs/Setup; **Evaluation Type** terminology; 51 pack Rule configs regenerated from CMDT; docs-only pack banners; template updated |

### Still open (not finished in this pass)

| Item                                                                                                     | Owner                  | Notes                                                                                                                |
| -------------------------------------------------------------------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Non-hero sample CMDT / manifests still present under Core `force-app` / `manifest/package-Account_*.xml` | Core follow-up PR      | Documented as **transitional**; remove when §3.1 cleanup lands so Deploy button cannot dump 14 extra Sets            |
| Examples GitHub remote still may be private / unpushed (`No commits yet on master` locally)              | Release owner          | Public launch of Core learning path depends on this repo being pushed and public                                     |
| Coverage teaching Sets (`Account_Formula_Coverage`, etc.)                                                | Examples               | Not yet first-class packs — either migrate as packs or keep as Core-only transitional and finish removal with a plan |
| `project-homepage.html` (gitignored / local)                                                             | Ignore or update later | Still has V1 `docs/examples/` links; not shipped via Pages if excluded                                               |

### Doc/wiki review impact

Previous **B-DOC-1 / B-DOC-2** (missing Core `docs/v2/examples/`) are **resolved by design**: Core must
**not** recreate that tree. Learning content is owned by Examples. Re-check links after Examples is
on `main` and public.

---

## 10. Appendix — evidence quick reference

```text
# Branch / install path
git status -sb                    # dirty V2 docs/LWC/wiki
git rev-list --left-right --count origin/main...HEAD   # 0  11
# CMDT volume
find force-app/.../customMetadata -name '*Set__mdt*' | wc -l   # 15
find force-app/.../customMetadata -name '*Rule__mdt*' | wc -l  # 132
# Jargon gate
rg -i 'scalar|comparator' force-app    # empty
# Examples docs missing
ls docs/v2/examples                    # no such directory
# Wiki jargon sample
rg -n 'façade|facade|Invocation Adapter|additive-only' wiki
# Token prefixes in code
RecordHealthCheckTokenRegistry: record, rhcRule, rhcSet, rhcResult, rhcRun
# Result contract
RecordHealthCheckResult.CONTRACT_VERSION = '0.1'
# Unguarded Aura method
RecordHealthCheckMetadataValidator.validateAsJson @AuraEnabled
# Gitignored release script
.gitignore: scripts/ → salesforce-validate.yml still calls it
```

Prior automated gate evidence remains valid for what it covered on 2026-07-13. This report adds ship/docs/learning gaps, contract/polish findings, and **§9** as the detailed documentation / wiki readiness review for human sign-off before publishing polished wikis.
