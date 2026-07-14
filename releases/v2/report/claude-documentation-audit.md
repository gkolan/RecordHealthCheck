# Documentation & Wiki Audit — V2 Release Readiness

**Prepared by:** Claude (Opus 4.8)
**Date:** 2026-07-14
**Scope reviewed:** the GitHub `wiki/` (8 content pages) and the Jekyll `docs/v2/` site (23 files),
checked against the shipped `force-app/` metadata and Apex.
**Question asked:** Are the docs complete, polished, jargon-free (Salesforce terminology only),
right-sized (not verbose, not thin), clear without bias/assumptions, and consistent with the code?

---

## Verdict

**The writing quality is excellent — genuinely wiki-ready prose. But the documentation set is
not yet complete or internally consistent enough to publish.** Three things block it:

1. An entire **examples documentation tree is missing**, yet ~28 links across the guides and the
   homepage point to it — every one 404s today.
2. A **shipped V2 feature (the SLDS Design System selector) is documented nowhere** in the user docs.
3. The wiki names one field **"Failure Message"** where Setup, the metadata, and the whole `docs/v2`
   site say **"Message When Failed."**

Everything else is polish. Fix the three above, do one dedup pass on the three large field-guides,
and this is a documentation set you can ship with confidence.

The prose itself is a model of what you asked for: plain Salesforce language, no computer-science
jargon, concise without being thin, and it consistently links to a single source of truth instead
of restating facts. The wiki in particular is very good.

---

## How this audit was done

- Read all 8 wiki content pages in full (`Home`, `Install-the-Core`, `Author-Checks`,
  `Explore-the-Examples`, `Integrate`, `Extend`, `Reference`, plus `_Sidebar`/`_Footer`).
- Sized and sampled all 23 `docs/v2/` pages; read the ones that carry field-level facts.
- Cross-checked every specific claim the wiki makes against the code: field API names **and**
  labels, the `EvaluationType__c` picklist, the `RecordHealthCheckRule` interface, the platform-event
  names, and the `RecordHealthCheck` façade signatures.
- Scanned all `docs/v2/` for CS jargon and traced internal `.md` links to their targets.

---

## What is strong (so this is balanced)

- **Jargon discipline is real.** The shipped metadata help text, the wiki, and `docs/v2` all speak
  Salesforce ("Check Set", "Rule", "record page", "Custom Metadata Type"). The only "scalar/comparator"
  usage left is in `docs/v2/installation/upgrading-to-v2.md:19`, where it is _correctly_ explaining
  the rename away from those words. "Boolean" appears throughout — that is accurate Salesforce/Apex
  terminology (formula return type, Apex type), not jargon.
- **Single source of truth is enforced.** `wiki/Reference.md` states the rule outright — "the wiki
  links to them rather than restating them — that keeps one copy of every fact" — and the wiki lives
  up to it. Generated references (field-size registry, reason codes) are linked, not copied.
- **Dormant metadata is handled honestly.** `Category__c` ships but grouping isn't built yet, and the
  docs say so plainly: "the LWC does not group rows by category yet" (`rule-fields.md:30`), "UI
  grouping planned" (`configuration-guide.md:77`). This is exactly the right treatment — keep the
  "yet".
- **Code ↔ doc coherence is high** (table below). The wiki's Apex interface, event names, façade
  call, and hero-example developer name all match the code verbatim.

---

## Blockers — fix before publishing

### D1. ~~The examples documentation tree is missing~~ — CORRECTED 2026-07-14: docs/v2 is already fine

**Correction (2026-07-14):** My original D1 was **wrong**. A re-verification showed the local
`../examples/...` links are in **`docs/v1/`** (the frozen historical v1.x docs), **not** `docs/v2/`.
The first pass grepped a path that swept in `docs/v1` and mis-attributed the hits.

**Actual current state — verified:**

- **`docs/v2/` has zero local `../examples/` links.** It already deep-links every example to the
  separate `RecordHealthCheck-Examples` repo with full GitHub URLs
  (e.g. `…/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#example-catalog`).
  This matches the V2 "core-only, deep-link the rest" boundary (§3.1).
- **Every one of those Examples-repo targets exists** in the local Examples clone at
  `/Users/gkolan/Documents/GitHub/RecordHealthCheck-Examples` — `catalog/`, `docs/install.md`,
  `docs/pattern-library/**`, `docs/examples-index.md`, and all 12 `packs/`.
- So there is **no local examples-tree gap in docs/v2.** The links will resolve **once the Examples
  repo is committed and pushed to `main`** on GitHub (it currently has content but no commits and no
  remote — see the status note the assistant provided).

**Residual (lower severity):** `docs/v1/` (frozen v1.x history) still contains its old local
`../examples/...` links (llm-configuration 9, getting-started 5, configuration-guide 6, plugin-reference 6,
plus others). If `docs/v1/` is published as-is those links 404, because there is no `docs/v1/examples/`
tree. Decide whether to (a) leave v1 as a frozen artifact and accept the dead example links, or
(b) repoint them to the Examples repo like v2. This is a v1-history question, not a v2-release
blocker.

**Net:** the "largest single gap" framing in the first draft was incorrect. The real dependency is
D2 — the Examples repo (and docs/v2) still need to be committed and pushed.

### D2. The whole doc set is uncommitted and links to `main`, which doesn't have it yet

`wiki/`, `docs/v1/`, and `docs/v2/` are all untracked (see the release audit, findings B1–B3). Every
wiki "Reference" link is an absolute
`https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/...` URL, and the README/homepage link
into `docs/v2/` too. Until `docs/v2/` is committed to `main` and the release is merged/tagged, those
links resolve to nothing.

**Impact:** Publishing the wiki before `docs/v2` lands on `main` gives readers a wall of 404s from
the Reference and Integrate pages.

**Fix:** Commit `docs/v1/`, `docs/v2/`, and `wiki/` together with the branch merge, then click through
the wiki Reference and Integrate links once on `main`.

---

## High — fix before or immediately after publishing

### D3. The SLDS "Design System" feature is documented nowhere in the user docs

V2 ships a **"Design System"** App Builder property with values **SLDS 2 / SLDS 1**
(`recordHealthCheck.js-meta.xml:23-28`) and a full theming layer. It appears in **none** of:
the wiki (`Install-the-Core` step 3 walks through component settings but omits it),
`docs/v2` (`getting-started`, `quick-start`, `configuration-guide`, `metadata/check-set` — none
mention it), the README, or the CHANGELOG.

**Impact:** An admin placing the component sees a "Design System" picker with two SLDS options and no
guidance on what they do or when to switch. This is the clearest "docs don't reflect the
functionality" gap.

**Fix (new documentation needed):**

- A short section — either a new `docs/v2/guides/design-system.md` or a subsection of the
  configuration/getting-started guide — explaining: SLDS 2 is the default (Cosmos theme), SLDS 1
  preserves legacy styling, the setting is per-placement, and it does **not** change the org theme.
  (The `js-meta.xml` description at line 28 is good raw copy.)
- One sentence in `wiki/Install-the-Core.md` step 3.
- A CHANGELOG entry and a README "What You Get" bullet.

### D4. The wiki calls a field "Failure Message"; Setup, the metadata, and docs/v2 call it "Message When Failed"

`wiki/Author-Checks.md:32` ("… Failure Message _\"Add a phone number…\"_") and `:41`
("**Failure Message** says what's wrong…") name a field that does not exist by that label. The field
is `FailureMessage__c` with label **"Message When Failed"** — which is what an admin sees in Setup and
what the entire `docs/v2` site uses (`rule-fields.md:32`, `getting-started.md:149`,
`configuration-guide.md:262,327`).

**Impact:** An admin following the wiki searches Setup for "Failure Message" and doesn't find it.

**Fix:** Change both wiki references to "Message When Failed". While there, consider aligning the
wiki's "Expected Value" (Author-Checks table) with the actual field label "Expected Value Comes From"
(`ExpectedValueSource__c`) — the wiki's simplification is defensible for a conceptual table, but the
field help text uses the precise label.

---

## Medium — worth doing for polish and lower cognitive load

### D5. The wiki sends end-users into internal maintainer documents

`wiki/Extend.md` links "Extension architecture (§4)" to `releases/v2/V2-RELEASE-PLAN.md`, and its
"Next" link goes to `releases/v2/V2-RELEASE-NEW-FUNCTIONALITY.md`. `wiki/Reference.md` also links the
"V2 release plan". Those are **maintainer planning documents** — the roadmap file even opens with
"Gate: do not start any item here until V2 is tagged." Pointing readers there raises cognitive load
and exposes unfinished-roadmap language as if it were product documentation.

**Fix:** Link the extension model to the design-spec's extension section (a user-facing page) instead
of the release plan; drop or replace the roadmap link with a short "what's coming" line you control.

### D6. Three large field-guides overlap — confirm each has one distinct job

`docs/v2/guides/configuration-guide.md` (3,672 words), `docs/v2/guides/llm-configuration.md`
(4,548 words), and `docs/v2/metadata/rule-fields.md` (2,222 words) each enumerate the same Rule
fields for different audiences (human setup / LLM-prompt authoring / field reference). Some overlap is
expected, but the wiki's own "one copy of every fact" rule should hold here too.

**Fix / for your review:** Do one dedup pass. Field _semantics_ (what a field means, its limits)
should be stated once in `rule-fields.md` / the field-size registry and **linked** from the two
guides, which should keep only their audience-specific framing. Flagging for review rather than
prescribing — you know which of the three is canonical.

### D7. The design spec is 9,609 words in one page

That's fine for a canonical behavior contract, and the wiki/guides correctly link to it rather than
restate it. No action needed beyond making sure nothing else re-explains its contents (see D6). Noted
so it's a conscious choice, not an oversight.

---

## Low / polish

- **D8.** `wiki/Install-the-Core.md` troubleshooting could add one line pointing to the Show
  Diagnostics overlay (currently only surfaced from `Reference.md`).
- **D9.** The wiki and README both carry a v1.x upgrade aside; make sure the historical v1.2.0 note
  lives in one place (the release audit flags the README copy).

---

## Missing-documentation checklist (driven by V2 new functionality)

This is the "what might be missing because V2 added it" list you asked for.

| V2 surface                                           | User doc exists?                                           | Action                                                                           |
| ---------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **SLDS Design System selector**                      | ❌ Nowhere                                                 | **New doc + Install/Config/README/CHANGELOG mentions (D3)**                      |
| Examples doc set (deep-linked)                       | ✅ docs/v2 links to the Examples repo; targets exist       | Push the Examples repo to `main` (D1 corrected). docs/v1 residual links optional |
| Programmatic façade (`RecordHealthCheck`)            | ✅ `apex/programmatic-api.md`                              | Verify only                                                                      |
| Flow action (`RecordHealthCheckFlowAction`)          | ✅ In programmatic-api + wiki Integrate                    | Verify only                                                                      |
| Lifecycle events (2 platform events)                 | ✅ `reference/lifecycle-events.md` + wiki Integrate/Extend | Verify only                                                                      |
| Apex check contract (`RecordHealthCheckRule`)        | ✅ `apex/plugin-contract.md` + `plugin-reference.md`       | Verify only                                                                      |
| Show Diagnostics overlay + `View_Details` permission | ✅ `guides/show-diagnostics.md`                            | Verify only                                                                      |
| V1 → V2 field renames / breaking changes             | ✅ `installation/upgrading-to-v2.md`                       | Verify only                                                                      |
| Category field (grouping deferred)                   | ✅ Documented as "not yet"                                 | Keep the "yet" note                                                              |
| Reason codes / field-size registry (generated)       | ✅ `reference/`                                            | Verify generation is current                                                     |

The five "❌/verify" items in bold are the real work; the rest of the V2 surface is already covered
by an appropriately-scoped page.

---

## Code ↔ documentation coherence — verification results

| Claim checked                                                                                           | Source of truth                                                        | Result                                                                                                  |
| ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `EvaluationType` = four values (Formula / Query / Compare two queries / Apex) and their field phrasings | `EvaluationType__c` (FORMULA, QUERY, COMPARE_TWO_QUERIES, APEX)        | ✅ Match — wiki mirrors the field help text                                                             |
| Rule & Check Set field labels used in prose                                                             | `*.field-meta.xml` `<label>`                                           | ✅ Match **except** "Failure Message" → "Message When Failed" (D4)                                      |
| `RecordHealthCheckRule` interface signature                                                             | `RecordHealthCheckRule.cls`                                            | ✅ Exact match (`evaluate(RecordHealthCheckContext)`)                                                   |
| Platform-event names                                                                                    | `Record_Health_Check_Rule_Result__e`, `Record_Health_Check_Set_Run__e` | ✅ Both exist                                                                                           |
| `RecordHealthCheck.runSet(name, id)` + hero example dev name                                            | `RecordHealthCheck.cls:63,70`; `Example_Account_360_Health_Check`      | ✅ Match                                                                                                |
| SLDS "Design System" property                                                                           | `recordHealthCheck.js-meta.xml:23-28`                                  | ❌ In code, absent from all user docs (D3)                                                              |
| docs/v2 example links → Examples repo                                                                   | full GitHub URLs; targets exist in the Examples clone                  | ✅ Correct (resolve once Examples is pushed to `main`). docs/v1 still has old local links (D1 residual) |

---

## Prioritized action list

1. [x] **D1** — CORRECTED: docs/v2 already deep-links to the Examples repo and the targets exist.
       Remaining: push the Examples repo to `main` (see D2). Optionally repoint the frozen docs/v1
       local example links.
2. [ ] **D3** — Write the SLDS Design System documentation; add the Install/Config/README/CHANGELOG mentions.
3. [ ] **D4** — Fix "Failure Message" → "Message When Failed" in `wiki/Author-Checks.md:32,41`; consider the "Expected Value" alignment.
4. [ ] **D5** — Repoint the wiki's extension links away from `releases/v2/` maintainer docs.
5. [ ] **D6** — Dedup pass across configuration-guide / llm-configuration / rule-fields; link semantics, don't restate.
6. [ ] **D2** — Commit `wiki/` + `docs/v1/` + `docs/v2/` with the branch merge; click-test the wiki Reference/Integrate links on `main`.
7. [ ] Regenerate the field-size registry and reason-code reference and confirm they match current metadata before publishing.

---

## Examples repository status (added 2026-07-14)

You asked me to work on the examples in the separate `RecordHealthCheck-Examples` repo. Here's the
verified state and why the work turned out to be mostly _delivery_, not _content_.

**Where it lives.** A real clone exists at
`/Users/gkolan/Documents/GitHub/RecordHealthCheck-Examples` (its own `.git`). The folder of the same
name _inside_ core is a separate, incomplete stub and is correctly gitignored — ignore it; the
sibling clone is the real repo.

**Content is in good shape — better than the core wiki in one respect:**

- Uses the correct field label **"Message When Failed"** in 40 files; **zero** uses of the wrong
  "Failure Message" (the core wiki has the wrong label — see D4).
- **No** stale pre-V2 field API names (`ComparisonDisplay__c`, `DebugMode__c`, `RowAppearance__c`,
  `INVALID_COMPARATOR`, etc.) — fully migrated to V2.
- CS jargon: effectively none (a lone "scalar" was already gone when I went to fix it — the docs are
  being actively edited).
- The repo's own `scripts/validate-packs.mjs` passes: **12/12 packs validated.**
- Scope: 12 packs, ~30 pattern-library examples (apex/formula/soql), a generated `catalog/`, an
  install guide, and an examples index — all present and matching the URLs core deep-links to.

**The real blocker is that it is not published yet.**

- The clone has **no commits** (`master` is empty) and **no git remote** configured.
- So every core → Examples deep link (docs/v2, README, homepage body, wiki) will **404 until the
  Examples repo is committed and pushed to `main`** on GitHub.
- Publishing needs your GitHub authentication and an outward-facing `git push` — that's your action,
  not something I do for you. Sequence: `git remote add origin …` → commit → `git push -u origin main`.

**Two live-edit cautions I hit:**

1. The docs (both core `docs/` and the Examples repo) changed **between my tool calls** more than
   once. Something/someone is editing them live. I did **not** make edits into that moving target to
   avoid racing your changes.
2. The earlier "D1 = ~28 broken links" finding was a casualty of that plus a grep that swept
   `docs/v1`. Corrected above.

**One real core-side item this surfaced (for your review, not yet fixed):** the docs **site nav** in
`docs/_layouts/base.html:30-40` still points at the **old flat paths** (`/installation/`, `/examples/`,
`/guides/`, `/reference/`) while the homepage body points at `/v2/…`. The nav's `/examples/` link
(line 33) has no target and would 404; the others are inconsistent with the `/v2/` migration. This is
part of the flat-vs-versioned docs migration that's mid-flight — worth finishing as one deliberate
pass rather than patching one link.

---

## Bottom line

Both the wiki prose and the Examples repo are in good shape — the Examples content is actually clean
and V2-accurate. The remaining work is **delivery and consistency, not writing**: publish the
Examples repo (commit + push, your auth), finish the flat-vs-`/v2/` docs-site nav migration, document
the SLDS Design System feature (D3), fix the one wiki label (D4), and commit the whole doc set with
the branch merge. Do those and the docs and examples ship as the polished, jargon-free, low-cognitive-load
set you're aiming for.

_Correction note: this report's original D1 (“examples tree missing / ~28 broken links”) was
inaccurate and has been struck through above. The accurate picture is in this section and the
corrected D1._
