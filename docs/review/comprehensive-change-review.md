# Comprehensive Change Review — 2026-07-04

Independent review of the full working tree (~244 changed files: Apex engine, LWC, Custom Metadata, specs, guides, and example library reorg). **No fixes were applied**; this document records findings only.

Review methods: diff inspection, targeted code reads, LWC Jest run (97 tests), automated doc link scan, Bugbot subagent, security-review subagent, cross-check against `bugs/` notes and prior `codex-documentation-review.md`.

---

## Executive summary

**The change set is largely sound.** The major features — guided remediation on FAIL rows, multi-row Found/Expected summaries, comparison provenance hardening, Setup label alignment, and the `soql/single-query` example reorg — are implemented coherently and covered by tests where exercised locally.

**Nothing appears critically broken for normal admin-authored configuration.** The highest-risk item is a **residual URL sanitization gap** (percent-encoded protocol-relative paths). The highest **user confusion** risk is **stale provenance UI documentation** that still says source notes are always behind the caret, while the LWC now attaches them inline on failing rows (and on AllRows pass rows).

| Severity | Count | Theme |
| -------- | ----- | ----- |
| Medium | 2 | URL encoding bypass; provenance docs vs LWC |
| Low | 6 | Anchor slug, deploy-time URL lint, presentation, version stamps |
| Info | 3 | Apex tests not run here; plugin contract tightening; historical changelog |

Previously reported bugs in `bugs/` (provenance NPE, backslash redirect, cross-token expansion, ComparisonDisplay validator) **appear fixed** in current source, with tests for each except the encoding bypass.

---

## What looks good

### Code — features and hardening

| Area | Verdict |
| ---- | ------- |
| **Guided remediation** | `RecordHealthCheckEngine.populateRemediationAction` resolves merge tokens, URL-encodes substituted values, sanitizes hrefs, and populates `actionLabel` / `actionUrl` / `fixInstructions` only on FAIL. LWC renders link + instructions + divider; Jest suite covers the matrix. |
| **Multi-row summaries** | `RecordHealthCheckComparatorEngine.countFailingRows` + `FoundSummaryOverride__c` / `ExpectedSummaryOverride__c` with `{!failCount}` / `{!totalCount}` tokens. Engine test `multiRowFoundSummaryIsDerivedAndOverridable` exercises the path. |
| **FAIL message precedence** | `resolveEvalResultMessage` preserves a non-blank Apex/plugin message on FAIL and falls back to `MessageWhenFailed__c` only when blank — matches plugin-contract intent. |
| **Formula “Passes when”** | `expectedValueLabel` + unquoted formula echo avoids mis-framing conditions as comparison values. LWC and Formula evaluator aligned. |
| **Apex plugin enforcement** | Dispatcher rejects PASS/FAIL without both `actualValue` and `expectedValue`. All four shipped example plugins updated; plugin-contract and plugin-reference document the requirement. |
| **Merge-token binding** | Left-to-right span substitution in `resolveMergeFields`, `resolveUrlMergeFields`, and `bindTokens`. Regression test `bindTokensDoesNotReExpandTokenTextFromFieldValues`. |
| **Provenance NPE** | `RecordHealthCheckProvenance.render` handles coercion-only `Detail` without dereferencing null `rawValueLabel`. |
| **Backslash URL bypass** | `sanitizeActionUrl` rejects `\` before accepting relative paths. Test `sanitizeActionUrlRejectsUnsafeSchemesAndLength` covers `/\\evil.example.com/path`. |
| **Metadata validator parity** | `ComparisonDisplay__c` validated at deploy time; error messages use new Setup labels (“Check Type”, “How To Interpret Query Results”, etc.). |
| **Field loading** | Remediation and summary-override merge fields added to `collectRequiredFields` so tokens resolve without spurious UNABLE_TO_EVALUATE. |

### Documentation and metadata

| Area | Verdict |
| ---- | ------- |
| **Example reorg** | `docs/examples/soql/single-query/` and `soql/compare-two-queries/` taxonomy is sensible. No remaining `docs/examples/query/` references in published docs. Spot-checked examples have correct metadata refs and deploy commands. |
| **Remediation docs** | `rule-fields.md`, `configuration-guide.md`, `llm-configuration.md`, `spec/05`, `spec/09`, `spec/11` (B37b), `action-links.md`, and CHANGELOG `[Unreleased]` describe live remediation behavior. Stale “schema only” remediation notes appear removed. |
| **Counts** | 15 Check Sets and 132 Rules in `force-app/` match doc claims. |
| **Onboarding** | README funnel, `quick-start.md`, `start/first-10-minutes.md`, `admin-quick-start.md` are coherent. |
| **Demo Check Set link** | `examples/index.md` now uses inline deploy text instead of a gitignored `docs/demo/` link. |
| **Empty example file** | `soql/single-query/07-all-rows-static-threshold.md` has full content again (was empty in an earlier commit). |

### Tests run in this review

| Suite | Result |
| ----- | ------ |
| LWC Jest (`recordHealthCheck`) | **97 passed** |
| Apex (`RecordHealthCheckEngineTest` et al.) | **Not run** — `sf` CLI could not write logs in the review environment |

---

## Issues found

### 1. Medium — Percent-encoded protocol-relative URL bypass

**Location:** `RecordHealthCheckEngine.sanitizeActionUrl` (~1295–1323)

**Problem:** The sanitizer rejects literal `//` and `\` but accepts same-org paths that *encode* those characters, e.g. `/%2f%2fevil.example.com`. Browsers decode percent-escapes before navigation, so a crafted `PrimaryActionUrl__c` (admin-authored or imported Check Set) can pass validation yet resolve off-org when rendered as the FAIL-row Fix-it `href`.

**Evidence:** No test covers encoded `//` or `%5c`. Bugbot flagged this as the only medium code finding. Literal backslash bypass is fixed; encoded form is not.

**Risk:** Low practical likelihood (admin trust model), but contradicts the documented “last line of defense” contract for remediation URLs.

**Suggested direction (not applied):** Reject `%2f`, `%5c`, and/or URL-decode before scheme/authority checks; add a test case.

---

### 2. Medium — Provenance / source-note docs contradict shipped LWC behavior

**Problem:** Several authoritative docs still state that provenance (`actualValueDetail` / `expectedValueDetail`) is **always behind the caret** and never inline with Found/Expected chips. The LWC intentionally changed in this branch: source notes attach **directly under the visible chip** whenever that side is shown inline.

**Code behavior (`healthCheckPresentation.js`):**

- **FAIL rows (all modes):** Found/Expected inline → source notes inline when the viewer has `Record_Health_Check_View_Details` (no caret).
- **PASS rows, AllRows mode:** same inline attachment.
- **PASS rows, OnDemand / FailuresOnly:** values and notes remain behind the expander.

**Stale doc locations:**

| File | Stale text |
| ---- | ---------- |
| `docs/reference/record-health-check-design-spec.md` (~259) | “Provenance is always behind the caret, never inline with the chips.” |
| `docs/spec/05-result-contract-and-reason-codes.md` (~38–39) | “Always behind the caret.” / “provenance as de-emphasized lines beneath when expanded” |
| `docs/spec/09-lwc-behavior.md` (~94, ~136–138) | Implies caret expansion is required to see provenance; does not describe inline attachment on FAIL / AllRows |

**Why it matters:** Admins and implementers relying on the spec will mis-predict what entitled users see on failing checks. The CHANGELOG `[1.1.0]` entry (“source notes now attach directly to the matching Found/Expected value”) matches code but was not fully propagated to spec tables.

**Tests:** LWC test `OnDemand: a failing row shows values inline with source notes attached` encodes the new behavior.

---

### 3. Low — Broken fragment anchor in `rule-fields.md`

**Location:** `docs/metadata/rule-fields.md` line 49

**Link:** `../examples/index.md#seeing-found-expected`

**Problem:** The target section exists as `### Seeing Found / Expected` in `examples/index.md` (line 114), but GitHub-style slug generation yields `#seeing-found--expected` (double hyphen), not `#seeing-found-expected`. The link may not jump to the section on GitHub Pages / many Markdown renderers.

---

### 4. Low — No deploy-time lint for `PrimaryActionUrl__c`

**Location:** `RecordHealthCheckMetadataValidator` — no validation of remediation URL shape at deploy time.

**Problem:** Unsafe URLs are still dropped at runtime by `sanitizeActionUrl`, so this is a feedback gap, not an exploit path. Admins only discover a bad URL after running a failing check (link absent; optional `detailMessage` breadcrumb with debug).

**Note:** Acceptable as residual risk per security review; worth documenting as intentional or adding a WARNING-level deploy hint.

---

### 5. Low — `bugs/` folder reads as open issues

**Location:** `bugs/README.md` and `bugs/01`–`04`

**Problem:** Each file says “Fixed locally” in its body, but the index table has no status column and no top-level note that all four items are resolved in the current tree. New readers may treat them as active defects.

**Suggested direction:** Add a one-line banner to `bugs/README.md` or relocate to `docs/review/audits/` for historical findings.

---

### 6. Low — Stale version / test-count stamps

| Location | Issue |
| -------- | ----- |
| `docs/guides/llm-configuration.md` line 3 | `Version: 2026-06-23` — predates remediation, multi-row summaries, and Setup label renames now documented in the same file |
| `CHANGELOG.md` `[1.1.0]` | References “90-test LWC suite”; current suite is **97** tests |

Cosmetic only; does not affect runtime.

---

### 7. Low — `CHANGELOG [1.1.0]` historical wording

`[1.1.0]` lists “metadata-only category and remediation fields for future grouped display and guided fixes.” `[Unreleased]` now implements remediation UI. Not wrong historically, but readers scanning only the latest release section may briefly think remediation is still schema-only until they read `[Unreleased]`.

---

## Security review summary

Dedicated security pass found **no medium-or-higher exploitable issues** beyond the encoding bypass above. SOQL binding, merge-token expansion, permission gating, and XSS surface (text bindings in LWC) were judged sound.

**Admin-trust behaviors (not vulnerabilities):**

- Admins can author `https://` external playbooks (by design).
- Merge tokens in URLs can incorporate user-editable field values into destinations for viewers who click Fix-it.
- `ApprovalInactiveApproverCheck` builds SOQL from admin JSON settings (`ApexSettingsJson__c`), not end-user input.

---

## Previously reported bugs (`bugs/`) — status

| # | Issue | Status in current tree |
| - | ----- | ---------------------- |
| 01 | Provenance `render` NPE on coercion-only Detail | **Fixed** — guarded `else` branch |
| 02 | `/\host` open redirect | **Fixed** — `contains('\\')` rejection + test |
| 03 | Cross-token merge re-expansion | **Fixed** — span-based binding + test |
| 04 | `ComparisonDisplay__c` deploy-time gap | **Fixed** — validator + test |

**New residual:** encoded `//` / `\` in URLs (issue #1 above) — not in original `bugs/` set.

---

## Plugin / breaking-change note for consumers

Custom `RecordHealthCheckRule` implementations that return PASS or FAIL **must** now set both `actualValue` and `expectedValue`. Otherwise the dispatcher returns `ERROR` / `APEX_EVALUATOR_ERROR`. This is documented in `docs/apex/plugin-contract.md` and enforced in `RecordHealthCheckApexEvaluatorDispatcher` (~204–218). Shipped examples were updated; third-party plugins in consumer orgs may need a one-time change.

---

## Documentation items resolved since earlier review

An earlier pass (`docs/review/codex-documentation-review.md`, same date) flagged several items that **no longer apply** to the current tree:

| Earlier finding | Current status |
| --------------- | -------------- |
| Empty `07-all-rows-static-threshold.md` | **Restored** (~90 lines) |
| Broken `docs/demo/unified-health-check.md` link | **Fixed** — inline manifest reference |
| Remediation “schema only” across guides/specs | **Mostly reconciled** — see `rule-fields.md`, `spec/11` B37b, `action-links.md` |
| `spec/05` / `spec/09` missing remediation contract | **Present** — `actionLabel`, `actionUrl`, `fixInstructions` documented |

Remaining doc gaps are primarily **provenance placement** (issue #2) and the **anchor slug** (issue #3).

---

## Internal consistency checks

| Claim | Verified |
| ----- | -------- |
| 15 Account Check Sets | Yes |
| 132 Rules | Yes |
| Project API 66.0 | Matches `sfdx-project.json` |
| Old `examples/query/` paths in docs | None found |
| Category UI not implemented | Consistent across docs and code |
| Remediation UI implemented | Code + LWC tests + most docs |
| Setup label renames in validator errors | Aligned with `rule-fields.md` |
| LWC test count in CHANGELOG `[1.1.0]` | Stale (90 vs 97) |

---

## Suggested fix order (for a follow-up pass)

1. **URL sanitization** — close encoded `//` / `%5c` bypass; add regression test.
2. **Provenance docs** — update `design-spec`, `spec/05`, and `spec/09` to describe inline source notes on FAIL (and AllRows pass) vs caret-gated notes on OnDemand pass rows.
3. **Anchor** — change `rule-fields.md` link to `#seeing-found--expected` or add an explicit HTML anchor in `examples/index.md`.
4. **Housekeeping** — `bugs/README` status banner; bump `llm-configuration.md` version; update CHANGELOG test count when cutting release.
5. **Optional** — deploy-time WARNING for obviously unsafe `PrimaryActionUrl__c` patterns.

---

## Files and areas reviewed

**Apex:** `RecordHealthCheckEngine`, `RecordHealthCheckFormulaEvaluator`, `RecordHealthCheckSoqlEvaluator`, `RecordHealthCheckComparatorEngine`, `RecordHealthCheckApexEvaluatorDispatcher`, `RecordHealthCheckProvenance`, `RecordHealthCheckMetadataValidator`, `RecordHealthCheckResult`, example plugin classes and tests.

**LWC:** `healthCheckPresentation.js`, `recordHealthCheck.html`, `recordHealthCheck.css`, `recordHealthCheck.test.js`.

**Docs (representative):** `README.md`, `CHANGELOG.md`, `docs/quick-start.md`, `docs/start/first-10-minutes.md`, `docs/examples/index.md` and SOQL/formula/apex examples, `docs/metadata/rule-fields.md`, `docs/guides/*`, `docs/spec/05`, `09`, `11`, `12`, `docs/reference/record-health-check-design-spec.md`, `bugs/*`.

**Not reviewed exhaustively:** Every Custom Metadata record diff (132 rules), every spec section, CI workflow, permission-set XML, or App Builder meta beyond spot checks.

---

*Reviewer: comprehensive pass against `recordHealthCheck` working tree, 2026-07-04. No code or doc fixes were applied.*
