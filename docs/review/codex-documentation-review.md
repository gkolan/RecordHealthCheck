# Documentation review — Codex changes (2026-07-04)

Independent review of the large documentation refactor (README, Quick Start, example reorg, guides, specs, and `bugs/` notes). Cross-checked against the Apex/LWC source and Custom Metadata in `force-app/`.

## Executive summary

**Most of the refactor is sound.** The Quick Start, simplified README, example taxonomy (`soql/single-query`, `soql/compare-two-queries`), and admin-facing start docs are coherent and accurate. Check Set / Rule counts (15 sets, 132 rules) match the repo.

**There are a few concrete problems that should be fixed before treating the docs as authoritative:**

1. One example file is **empty** (content loss).
2. **Remediation UI** shipped in code and CHANGELOG `[Unreleased]`, but several docs still say it is “schema only” / not rendered — including text that contradicts itself in the same file.
3. A **broken link** to gitignored demo content.
4. A **broken anchor** in `rule-fields.md`.
5. Spec/LWC contract docs are **missing remediation** where other sections already document it.

The `bugs/` write-ups are accurate; the listed Apex issues appear fixed in the current codebase.

---

## What looks good

### Quick Start and onboarding

| Document | Verdict |
| -------- | ------- |
| `docs/quick-start.md` | Clear starting path; links and “copy one pattern” section match real examples. |
| `docs/start/first-10-minutes.md` | Accurate for `Account_Data_Quality` (4 rules: Billing City, Industry, Phone, Website). CLI manifests are correct. |
| `docs/installation/admin-quick-start.md` | Plain-English model is helpful; troubleshooting table matches common failures. |
| `README.md` | Good “Start Here” funnel without losing links to the full catalog. |
| `docs/installation/sandbox.md` | Appropriate for non-CLI admins; deploy-button flow and permission steps are correct. |

### Example library reorg

Moving `docs/examples/query/` → `docs/examples/soql/single-query/` and `docs/examples/compare-two-queries/` → `docs/examples/soql/compare-two-queries/` is a sensible taxonomy. Spot-checked examples (`01-single-required-field`, `01-child-count-minimum-one`, `06-any-row-formula-threshold`, apex `01-recent-activity`) — relative paths, metadata references, and deploy commands are correct.

`docs/examples/index.md` rule counts per Check Set match metadata (verified programmatically).

### Spec and reference accuracy (selected)

- `docs/metadata/check-set.md` — comparison display, 25-rule cap, concurrency: matches code.
- `docs/spec/12-limitations-and-roadmap.md` — remediation **limitation** row (valid URL required) is correct for current behavior.
- `docs/installation/getting-started.md` — 10 + 4 + 1 Check Set breakdown and 88 + 35 + 9 rule math is correct.
- `bugs/README.md` — scope and “non-issues” notes are reasonable; individual bug files match code paths.

### `bugs/` folder

Useful audit trail. Status notes (“Fixed locally”) align with the codebase for all four reported issues:

- Provenance NPE — guarded in `RecordHealthCheckProvenance.render`
- `/\` URL bypass — rejected in `sanitizeActionUrl`
- Cross-token merge expansion — left-to-right binding in formula/SOQL evaluators
- `ComparisonDisplay__c` validator gap — covered in `RecordHealthCheckMetadataValidator`

---

## Issues that need changes

### 1. Critical — empty example file

**File:** `docs/examples/soql/single-query/07-all-rows-static-threshold.md`

**Problem:** The file is **0 bytes**. It is linked from `docs/examples/index.md` as “Every row passes” but renders a blank page.

**Evidence:** `git show 7e85118:docs/examples/query/07-all-rows-static-threshold.md` had ~89 lines (rule `Ex_Q_AllOppsPositiveAmt`, `AllRowsPass` pattern). Content was lost before the `soql/` move (already empty at commit `47344c1`).

**Recommended fix:** Restore content from `7e85118`, updating paths to the new `soql/single-query/` layout and current Setup labels (same treatment as sibling examples `05` and `06`).

---

### 2. High — remediation docs contradict code and themselves

**Problem:** Guided remediation (`FixInstructions__c`, `PrimaryActionLabel__c`, `PrimaryActionUrl__c`) **is implemented** on FAIL rows, but multiple docs still say it is schema-only or not rendered.

**Code evidence:**

- `RecordHealthCheckEngine` populates `actionLabel`, `actionUrl`, `fixInstructions` on FAIL
- `healthCheckPresentation.js` / `recordHealthCheck.html` render the action block
- LWC tests: `describe("annotateCheck — guided remediation", …)`
- CHANGELOG `[Unreleased]` documents the feature
- Sample rule `Example_Every_Contact_Has_Email` ships remediation fields

**Stale locations (remediation portion only — Category is still metadata-only and those notes are correct):**

| File | Stale text |
| ---- | ---------- |
| `docs/metadata/rule-fields.md` | Note at line ~42: “LWC does not render them yet” — **contradicts** the table rows immediately below that describe FAIL-row rendering |
| `docs/guides/configuration-guide.md` | §4: “schema-only until the LWC renders remediation guidance” |
| `docs/guides/llm-configuration.md` | §4.3 table: “schema only — not rendered on card yet” on all three remediation fields |
| `docs/spec/11-defaults-and-resolved-issues.md` | B37: “fix-instruction rendering are not implemented yet” |
| `docs/reference/record-health-check-design-spec.md` | B37 and limitations table: lumps Category + remediation as “not rendered on the card yet” |

**Already correct (do not regress):**

- `docs/spec/12-limitations-and-roadmap.md` — remediation limitation row describes live behavior
- Field table body in `rule-fields.md` (lines 46–48) — accurate when the schema-only note is removed

**Recommended fix:**

1. Remove or rewrite the schema-only notes for remediation in the files above.
2. Split B37 into **B37a Category** (still not rendered) and **B37b Remediation** (implemented in `[Unreleased]` / current branch).
3. Update `docs/spec/05-result-contract-and-reason-codes.md` and `docs/spec/09-lwc-behavior.md` to document `actionLabel`, `actionUrl`, `fixInstructions` on FAIL rows (sanitization, merge tokens, non-FAIL suppression).
4. Update `docs/guides/llm-configuration.md` version stamp and remediation table rows; add a one-line rule that unsafe URLs are dropped but instructions may still show.

---

### 3. Medium — broken demo link

**File:** `docs/examples/index.md` (Sample Check Set table)

**Problem:** Links to `../demo/unified-health-check.md` for `Example_Account_360_Health_Check`, but:

- `docs/demo/` is listed in `.gitignore` (intentionally unpublished)
- No substitute doc exists in the published tree

**Recommended fix (pick one):**

- **A.** Publish a short `docs/installation/account-360-demo.md` (or similar) with deploy notes and what the 9 rules demonstrate; point the table there.
- **B.** Remove the link and replace with inline text: “Demo Check Set — deploy `manifest/package-Example_Account_360_Health_Check.xml`.”
- **C.** Stop gitignoring `docs/demo/unified-health-check.md` if it is meant to ship.

Option B is the smallest fix; A is better for admins evaluating the demo set.

---

### 4. Medium — broken anchor in rule-fields

**File:** `docs/metadata/rule-fields.md` (~line 52)

**Problem:** Link target `../examples/index.md#seeing-found--expected-on-a-failing-check` does not exist. `examples/index.md` has no such section.

**Recommended fix:** Either add a short “Seeing Found / Expected” subsection to `examples/index.md` (could point to `formula/08-found-expected-values.md` and a failing Query example), or change the link to `../reference/record-health-check-design-spec.md#comparison-display-contract` only.

---

### 5. Low — spec gaps for shipped behavior

| Gap | Recommendation |
| --- | -------------- |
| `docs/spec/05-result-contract-and-reason-codes.md` — no `actionLabel` / `actionUrl` / `fixInstructions` in result table | Add rows with FAIL-only visibility and URL sanitization contract |
| `docs/spec/09-lwc-behavior.md` — Rows section omits remediation block | Add bullet under Rows: action link + fix instructions on FAIL; link dropped when URL sanitization fails |
| `docs/spec/11` B37 | Split category vs remediation (see §2) |
| `docs/guides/llm-configuration.md` — `Version: 2026-06-23` | Bump when remediation guidance is corrected |

---

### 6. Low — `bugs/` folder presentation

Not wrong, but readers may think issues are open because files live under `bugs/`. Consider:

- Renaming to `docs/review/` or `docs/audits/` for resolved findings, **or**
- Adding a line to `bugs/README.md`: “All items below were fixed in the branch that introduced remediation / comparison display; kept for audit history.”

---

## Internal consistency check

| Claim | Verified |
| ----- | -------- |
| 15 Account Check Sets | Yes (`Record_Health_Check_Set__mdt` count) |
| 132 Rules | Yes |
| Sample 10 sets / 88 rules | Yes (sum of non-example sets) |
| Teaching 4 sets / 35 rules | Yes |
| Demo 1 set / 9 rules | Yes |
| `Account_Data_Quality` = 4 rules | Yes |
| Formula checks need org API v63+ | Documented consistently |
| Project API 66.0 | Matches `sfdx-project.json` |
| Old `examples/query/` paths | No remaining references in `docs/` |
| Category UI not implemented | Consistent across docs and code |

---

## Suggested edit order

1. Restore `07-all-rows-static-threshold.md` (unblocks catalog completeness).
2. Reconcile remediation documentation across `rule-fields`, `configuration-guide`, `llm-configuration`, `spec/11`, and `design-spec` (highest user confusion risk).
3. Fix demo link and `seeing-found` anchor.
4. Extend `spec/05` and `spec/09` for remediation contract.
5. Optional: clarify `bugs/` as historical.

---

## Files reviewed

- `README.md`, `CHANGELOG.md`
- `docs/quick-start.md`, `docs/start/first-10-minutes.md`, `docs/installation/admin-quick-start.md`, `docs/installation/getting-started.md`, `docs/installation/sandbox.md`
- `docs/examples/index.md` and representative examples (formula, soql, apex)
- `docs/guides/configuration-guide.md`, `docs/guides/llm-configuration.md`
- `docs/metadata/rule-fields.md`, `docs/metadata/check-set.md`
- `docs/spec/05`, `09`, `11`, `12`; `docs/reference/record-health-check-design-spec.md` (selected sections)
- `docs/index.html` (structure and counts)
- `bugs/*.md`
- Apex/LWC: `RecordHealthCheckEngine`, `RecordHealthCheckProvenance`, `RecordHealthCheckFormulaEvaluator`, `RecordHealthCheckSoqlEvaluator`, `RecordHealthCheckMetadataValidator`, `healthCheckPresentation.js`, `recordHealthCheck.html`

---

*Reviewer: documentation pass against `recordHealthCheck` working tree, 2026-07-04.*
