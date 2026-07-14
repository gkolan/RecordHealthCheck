# Deep Audit — GitHub Release Readiness Analysis

**Prepared by:** Claude (Opus 4.8) deep-audit pass
**Date:** 2026-07-14
**Branch reviewed:** `v2-release` (working tree, uncommitted)
**Question asked:** In its current state, is this project ready to publish as a GitHub release?

---

## Verdict

**Not yet — but the product code is in excellent shape. The blockers are packaging and
publishing hygiene, not defects in the framework.**

The Apex and Lightning code is well-written, secure, tested, and free of the jargon the V2
plan bans. What stops a release today is that **the V2 change is only half-committed**: the
component imports two CSS files that were never added to git, and the README and docs
homepage already link to an entire documentation tree that isn't committed either. Anyone
who follows your own install instructions from a clean clone would hit a compile failure and
a wall of 404s.

Fix the four blockers below and this is a release you can be proud of.

---

## How this audit was done (scope and honesty about depth)

| Area                                                                                                                                              | Method                                                                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| LWC production layer (`recordHealthCheck.js`, `healthCheckRunner.js`, `healthCheckModel.js`, `healthCheckPresentation.js`, both SLDS CSS modules) | Read line by line                                                                                                                                |
| Security & entry-point Apex (`RecordHealthCheckController`, `RecordHealthCheckAccess`, `RecordHealthCheck` façade)                                | Read line by line                                                                                                                                |
| Dynamic-SOQL security path (`RecordHealthCheckSoqlEvaluator`, `RecordHealthCheckSoqlTemplate`, `RecordHealthCheckEngine` query methods)           | Read the relevant regions                                                                                                                        |
| All 60 shipped Apex classes (~18,500 lines)                                                                                                       | Pattern-scanned for TODO/FIXME, CS jargon, `System.debug`, empty catch blocks, `without sharing`, hardcoded IDs, injection surface, suppressions |
| Tooling gates                                                                                                                                     | Ran `npm run lint`, `npm run prettier:verify`, `npm run test:unit`                                                                               |
| Docs & repo hygiene                                                                                                                               | Mapped tracked vs. untracked vs. deleted; traced internal links; checked version/API consistency                                                 |

**What I did not do:** individually read all ~18,500 lines of Apex. The security-critical and
public-surface classes were read fully; the remainder were scanned with targeted checks. If
you want a guaranteed every-line Apex pass, run `/code-review ultra` on the branch or ask for
a dedicated follow-up — I don't want to claim coverage I didn't perform.

---

## Blockers — must fix before release

### B1. The component imports two CSS files that are not committed to git

`force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js:7-8` imports
`./recordHealthCheckSlds1.css` and `./recordHealthCheckSlds2.css`, and `:46` registers them
as `static stylesheets = [slds1Styles, slds2Styles]`. Both files are **untracked** (`??` in
`git status`) and have **never been committed** (`git log` on them is empty).

**Impact:** A fresh `git clone` + `sf project deploy start -d force-app` fails to compile the
LWC because the two imported modules don't exist in the repo. This breaks **both** install
paths you advertise in the README — the "Deploy to Salesforce" button and Option 2 (CLI).
This is the single most important issue in the audit. (Local tests pass only because the
files exist on your machine.)

**Fix:** `git add` both CSS modules and commit them together with the modified
`recordHealthCheck.css`.

### B2. The README and docs homepage link to an entire doc tree that isn't committed

A documentation reorganization into versioned `docs/v1/` and `docs/v2/` folders is in flight
but uncommitted:

- `docs/v1/` and `docs/v2/` are **untracked** (41 markdown files total).
- 5 old docs are **deleted** in the working tree but still in HEAD: `docs/guides/llm-configuration.md`,
  `docs/guides/action-links.md`, `docs/metadata/rule-fields.md`, `docs/metadata/check-set.md`,
  `docs/apex/plugin-contract.md`.
- The committed README links into the uncommitted tree: `README.md:45, 68, 84-88`
  (e.g. `docs/v2/installation/upgrading-to-v2.md`, `docs/v2/guides/action-links.md`).
- The committed homepage `docs/index.html` links **20+ pages** under `/v1/` and `/v2/`
  (e.g. `/v2/quick-start.html`, `/v2/guides/action-links.html`).

**Impact:** Commit the README/homepage without the doc trees and every one of those links
404s on github.com and on the GitHub Pages site. Right now the change is simply incomplete —
nothing is committed, so the site still serves the old flat docs.

**Fix:** Commit `docs/v1/`, `docs/v2/`, the 5 deletions, `README.md`, and `docs/index.html`
**in one commit** so the link graph is never internally broken.

### B3. Install links point at `main`, but V2 exists only on `v2-release`

The README badges, "Deploy to Salesforce" button, and CI link all use `ref=main`
(`README.md:4-6, 51`). The V2 work is 11 commits ahead of `main` on `v2-release`, and there
is **no `v2.0.0` tag** (`git tag` shows only `v1.1.0`, `v1.2.0`).

**Impact:** Until `v2-release` is merged to `main` and tagged, the Deploy button installs
**v1.2.0** while the README and docs describe **V2** — new users get code and documentation
that don't match.

**Fix:** As part of releasing, merge `v2-release` → `main`, tag `v2.0.0`, and confirm the
Deploy button pulls the intended ref.

### B4. A shipped, user-facing feature (Design System / SLDS toggle) is entirely undocumented

The component now exposes a **"Design System"** App Builder property
(`recordHealthCheck.js-meta.xml:23-28`, values `SLDS 2` / `SLDS 1`) backed by a real theming
layer (`themeClass` getter at `recordHealthCheck.js:56-63` plus the two SLDS CSS modules). It
appears in **none** of the user-facing docs:

- Not in `CHANGELOG.md` (the `[2.0.0]` section lists renames but not this feature).
- Not in `README.md` ("What You Get" doesn't mention it).
- Not anywhere under `docs/v2/`.

**Impact:** Admins will see a new picker in Lightning App Builder with no explanation of what
SLDS 1 vs. SLDS 2 does or when to change it. This is exactly the "docs don't reflect the
functionality" gap you wanted flagged.

**Fix:** Add a short CHANGELOG entry, a "What You Get" bullet, and a paragraph in the
configuration/getting-started docs. The `js-meta.xml` description is good raw material.

---

## High-value polish — fix before or immediately after release

### P1. `prettier:verify` fails — your own CI gate is red

`npm run prettier:verify` (the check your README tells contributors to run) reports two files:

- `README.md:83` — a stray trailing blank line.
- `recordHealthCheck.js-meta.xml:16-29` — indentation on the two `<targetConfig>` property blocks.

**Fix:** `npm run prettier` rewrites both. (Your Husky pre-commit hook would catch these on
commit, but the gate is currently failing on the working tree.)

### P2. README mixes a V2 release with stale v1.2.0 migration prose

`README.md:45` correctly points V2 upgraders at the V2 guide, but `:47-49` immediately follows
with a full **v1.2.0** upgrade paragraph ("v1.2.0 removes the old Lightning component
properties…"). On a V2 release README this reads as clutter and competes with the V2 upgrade
callout right above it.

**Fix:** Move the v1.2.0 migration notes into the historical `docs/v1/` set or CHANGELOG
history; keep the top of the README focused on V2.

---

## Minor / editorial

- **M1 — Residual CS jargon in docs.** `docs/v2/installation/upgrading-to-v2.md:19` uses
  "comparator"/"scalar", which is **acceptable here** because it's explaining the rename _away_
  from those terms. But `docs/v1/` carries the vocabulary broadly (`docs/v1/guides/llm-configuration.md`,
  `docs/v1/metadata/rule-fields.md`). Decide deliberately: if `docs/v1/` is published as
  "historical reference," it will show admins the very jargon your V2 plan bans. Publishing it
  verbatim is defensible; just make it a conscious choice.
- **M2 — Comment drift.** `recordHealthCheck.js:30` still references `recordHealthCheck.css`
  for the tooltip dwell timing; now that styles are split across three CSS files, confirm the
  pointer is still accurate (trivial).
- **M3 — Redundant work.** `healthCheckRunner.js:258` stores `normalizeResult(result, check)`,
  then `_drain` re-normalizes the same buffered value at `:271`. It's idempotent and harmless —
  optional cleanup only.
- **M4 — Working tree is one large uncommitted changeset** (35 modified, 8 untracked, 5 deleted
  tracked files). None of this is a defect, but the release can't be called "done" until it's a
  coherent set of commits. Recommend committing in logical groups (code, docs, config) so the
  history reads cleanly.

---

## What is genuinely strong (so this is balanced)

These are the things that _do_ make the work look excellent:

**Security posture — this is the best part of the codebase.**

- Every shipped class is `with sharing` (no `without sharing` anywhere).
- Admin-authored SOQL runs `WITH USER_MODE` (FLS/CRUD enforced for the running user), the
  template **blocks** `WITH SYSTEM_MODE`, escapes single quotes, uses bind variables, and
  enforces an outer row cap (`RecordHealthCheckSoqlTemplate`, `RecordHealthCheckEngine:879-894`,
  `RecordHealthCheckSoqlEvaluator:478-509`).
- The one `code-analyzer` suppression (`RecordHealthCheckEngine:893`) is inline-justified and
  correct: names come from Schema describe, `recordId` is a bind, query is user-mode.
- The controller normalizes and length-caps every inbound identifier, never leaks internal
  error detail to the client, and logs unexpected failures as `LOAD_FAILED` rather than
  falsely claiming a config is missing (`RecordHealthCheckController.cls:47-93`).

**Code hygiene.** No `TODO`/`FIXME`/`HACK`, no stray `System.debug` (logging is centralized in
`RecordHealthCheckLogger`), no empty catch blocks, no hardcoded record IDs, no
`@SuppressWarnings`. The shipped `force-app/` is clean of the §9 jargon gate terms
(`scalar`/`comparator`).

**LWC quality.** 111 Jest tests pass; ESLint is clean; the runner has careful token/staleness
guards for concurrent evaluation, record swaps, and component teardown; there's real
accessibility work (folded `aria-label`s, reduced-motion handling) and genuinely helpful,
plain-language "why" comments throughout.

**Comment voice.** Comments consistently explain intent in Salesforce-admin vocabulary ("Check
Set," "Rule," "record page") rather than CS abstractions — which is exactly the tone you asked
for.

---

## Prioritized release checklist

1. [ ] **B1** — Commit `recordHealthCheckSlds1.css` and `recordHealthCheckSlds2.css` (+ modified `recordHealthCheck.css`).
2. [ ] **B2** — Commit `docs/v1/`, `docs/v2/`, the 5 doc deletions, `README.md`, and `docs/index.html` together; then click through the README and homepage links to confirm none 404.
3. [ ] **B4** — Document the Design System / SLDS toggle in CHANGELOG, README, and `docs/v2/`.
4. [ ] **P1** — Run `npm run prettier` so `prettier:verify` passes.
5. [ ] **P2 / M1** — Trim stale v1.2.0 prose from the README; decide the v1-docs jargon policy.
6. [ ] **B3** — Merge `v2-release` → `main`, tag `v2.0.0`, verify the Deploy button ref.
7. [ ] Re-run `npm run lint && npm run prettier:verify && npm test`, plus an Apex validation
       deploy / org test run (Apex tests need an org and were not executed in this audit).
8. [ ] Optional: a dedicated every-line Apex pass (`/code-review ultra`) if you want line-level
       sign-off on all ~18,500 Apex lines.

---

## Bottom line

The framework itself is release-quality: secure, tested, cleanly written, and admin-friendly
in its language. The reason it isn't shippable _today_ is that the V2 changeset is only
partially committed — two imported stylesheets and the entire documentation tree the README
points to are still sitting untracked in your working directory. Commit the full set as
coherent commits, document the one new feature, green the prettier gate, and merge-and-tag —
then this is exactly the polished, easy-to-learn release you're aiming for.
