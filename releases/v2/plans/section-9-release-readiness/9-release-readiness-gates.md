# Plan 9 — V2 release-readiness gates

| Field           | Value                                                                                         |
| --------------- | --------------------------------------------------------------------------------------------- |
| Release section | [`V2-RELEASE-PLAN.md §9`](../../V2-RELEASE-PLAN.md)                                           |
| Status          | 🟡 **Partial** — automated gates complete; human UI, restore, PR, and tag approvals remain    |
| Type            | Release closeout — verification, cleanup, evidence, sign-off                                  |
| Owner           | Core maintainers; release-owner approval pending                                              |
| Effort          | M–L — jargon sweep, docs review, smoke test, readback, upgrade guide, sign-off                |
| Risk            | **High** — this is the production go/no-go; a missed gate ships a breaking release unverified |
| Depends on      | Whatever ships from the other plans; the jargon gate is independent and can start now         |
| Blocks          | Marking V2 production-ready                                                                   |

## 1. Objective

Close every gate that stands between "field migration verified in a scratch org (2026-07-12)" and
"V2 is production-ready." A complete field migration does **not** make V2 production-ready (`§9`).
V2 may be marked production-ready only after every gate passes, with exceptions explicitly
documented and approved.

## 2. Gates (from `§9`)

### Gate A — Documentation contract

Repository-wide review and historical-versus-current terminology classification. Every doc either
describes current V2 behavior or is clearly marked historical. Docs and code agree (`§1.5`).

- **Action:** sweep `docs/`, `README`, and inline help; classify each terminology use as current
  vs historical; fix or annotate.
- **Done when:** no doc describes V1 field names/vocabulary as if current, except in an explicitly
  labeled migration/history section.

### Gate B — Jargon replacement (independent — can start now)

Finish the terminology cleanup: **no `scalar` or `comparator` remaining in `force-app/`** (`§9`).

- **Verified current state (2026-07-13):** `scalar` appears in **9** files and `comparator` in
  **11** files under `force-app/`, including `RecordHealthCheckComparisonEngine`,
  `RecordHealthCheckConstants` (`VALID_COMPARATORS`, `DUAL_QUERY_COMPARATORS`),
  `RecordHealthCheckValueResolver`, `RecordHealthCheckSoqlEvaluator`,
  `RecordHealthCheckCompareQueriesEvaluator`, the validators, and their tests.
- **Action:** rename to plain admin/domain language (e.g. comparator → "comparison"/"operator"
  where it means the operator; scalar → "single value"/"value"). Update class/method/variable
  names, constant names, comments, and tests together. This is a mechanical but wide change —
  do it as one focused, test-backed pass.
- **Caution:** stored picklist API values already use tokens like `GREATER_THAN_OR_EQUAL` — those
  are the _values_, not the jargon; the target is the _English words_ `scalar`/`comparator` in
  code identifiers, comments, labels, and docs.
- **This rename is itself a breaking change.** It hits `public static` members
  (`VALID_COMPARATORS`, `DUAL_QUERY_COMPARATORS`) and a class name (`RecordHealthCheckComparisonEngine`)
  that external Apex could reference. That is acceptable in a breaking V2, but every renamed
  public identifier must be listed in the `§3` breaking-change summary — not changed silently.
- **Sequence it to avoid thrash.** Gate B edits the **same** evaluator/validator classes that
  plans [2.9](../section-2-metadata-contract/2.9-reason-code-catalog.md),
  [2.11](../section-2-metadata-contract/2.11-fls-presentation-completion.md), and the
  [4.x](../section-4-extension-architecture/) work touch. Run it as an **isolated pass — first
  (before those plans start) or last (after they merge)** — never concurrently, or the wide
  rename will conflict with every other diff. Recommended: do it **first**, so downstream plans
  are written against the cleaned-up names.
- **Done when:** `grep -rli 'scalar\|comparator' force-app/` returns nothing, Apex + Jest suites
  pass, and every renamed public identifier is recorded in the breaking-change summary.

### Gate C — Manual smoke test

`Example_Account_360_Health_Check` on an Account record page, including permission paths, since
automated tests do not cover the UI (`§9`).

- **Action:** deploy to a clean org, add the LWC to an Account record page, select the hero Check
  Set, verify pass/fail/skipped/unable rendering, and verify the `Record_Health_Check_User`
  permission path (authorized vs unauthorized user, including diagnostics gating from
  [2.11](../section-2-metadata-contract/2.11-fls-presentation-completion.md)).
- **Done when:** a recorded smoke-test result (steps, screenshots/notes, date, org) exists.

### Gate D — Source-to-org readback

An independent retrieve/diff artifact, not only a recorded successful deploy (`§9`).

- **Action:** after deploy, `sf project retrieve` and diff against the source; capture the diff as
  evidence that what is in the org matches the repository.
- **Done when:** a readback/diff artifact is committed showing no unexpected drift.

### Gate E — Release and rollback closeout

- Upgrade guide **`docs/installation/upgrading-to-v2.md`** — **complete**; it covers the breaking
  field renames, no dual-read compatibility, backup prerequisites, and rollback procedure.
- Source version bump — **complete** (`2.0.0`). The release tag remains outstanding.
- Backup/rollback evidence — **open**: restore the retained v1.x artifact and exported metadata in
  a disposable org, record the result, and obtain release-owner rollback approval.
- Commit/PR review and approvals — **open**: commit the final release diff, open/review the PR, and
  create the V2 tag only after all gates are approved.

### Gate F — Static analysis and security scan (from the 2026-07-13 design audit)

- **Action:** run **Salesforce Code Analyzer** (PMD/Graph Engine, including the security ruleset)
  over `force-app/`; triage findings, especially SOQL-injection, CRUD/FLS, and sharing rules on the
  new façade ([4.18](../section-4-extension-architecture/4.18-public-check-response-facade.md)) and
  FLS ([2.11](../section-2-metadata-contract/2.11-fls-presentation-completion.md)) code paths.
- **Done when:** the scan runs in CI, and every finding is fixed or has a recorded, justified
  suppression (the repo already uses `code-analyzer-suppress` comments — each must have a reason).

### Gate G — Packaging install/upgrade and dependency compatibility (from the audit)

- **Action:** after the `§6`/`§4.15` packaging-model decision, validate the chosen model
  end-to-end: fresh **install**, **upgrade** from the minimum supported version, permission
  assignment, and (where supported) **uninstall** — plus dependency/version compatibility between
  core and any example/extension packages.
- **Done when:** a recorded install/upgrade run exists for the chosen model; if V2 ships
  source-only, state that explicitly and defer package-version validation with a recorded note.

### Gate H — Capacity and governor evidence (from the audit)

- **Action:** record measured capacity evidence, not assertions — the
  [4.18](../section-4-extension-architecture/4.18-public-check-response-facade.md) façade at its
  documented worst case (records × rules × query work: SOQL, query rows, CPU, heap, response size)
  and, if events ship, the [4.2](../section-4-extension-architecture/4.2-lifecycle-events-and-publish-fields.md)
  publisher (per-transaction event count, chunking, allocation headroom) plus the step-0
  publish-after-commit spike.
- **Done when:** capacity artifacts are committed under [`../../audits/`](../../audits/) with the
  org, date, and worst-case parameters recorded.

## 3. Breaking-change summary (for release notes, from `§9`)

All items must be in the upgrade guide and release notes:

- All field API renames per `field-migration-before-after.md`.
- **No** dual-read compatibility with v1.x field names.
- Category vocabulary replaced.
- `MaxQueryRows` default **200**.
- `EmptyValueHandling` default **`AS_NO_MATCH`**.
- `EvaluationOrder` default **100**.
- Severity **Error → Critical**.
- Long-text fields truncated to **255** characters where the type changed.

## 4. Dependency on other plans

If these land in the same V2 release, their own acceptance criteria roll up into this closeout:

- [2.8 size registry](../section-2-metadata-contract/2.8-field-size-registry.md) — reconciled and
  generated.
- [2.9 reason codes](../section-2-metadata-contract/2.9-reason-code-catalog.md) /
  [2.10 skip semantics](../section-2-metadata-contract/2.10-skip-and-not-applicable-semantics.md) /
  [2.11 FLS](../section-2-metadata-contract/2.11-fls-presentation-completion.md) — decisions
  recorded in `§6`, code + tests landed.
- [4.18 façade](../section-4-extension-architecture/4.18-public-check-response-facade.md) — if the
  façade ships in V2, its parity + bulk tests are part of the readback/smoke evidence.
- [4.2](../section-4-extension-architecture/4.2-lifecycle-events-and-publish-fields.md) /
  [4.19](../section-4-extension-architecture/4.19-emission-and-actuation-safety.md) — only if the
  `§6` "events ship in V2?" decision is yes; otherwise explicitly deferred and noted.

## 5. Acceptance criteria

- [x] Gate A: documentation classified/fixed; no stale-as-current V1 terminology.
- [x] Gate B: zero `scalar`/`comparator` in `force-app/`; suites green; API-name changes noted.
- [ ] Gate C: recorded manual smoke test on an Account record page incl. permission + diagnostics
      paths.
- [x] Gate D: committed source-to-org readback/diff artifact.
- [ ] Gate E: `docs/installation/upgrading-to-v2.md` written; backup/rollback evidence; version
      bump + tag; PR reviewed + approved.
- [x] Gate F: Salesforce Code Analyzer (incl. security ruleset) runs in CI; findings fixed or
      justified-suppressed.
- [x] Gate G: install/upgrade validated for the chosen packaging model (or source-only deferral
      recorded); dependency/version compatibility checked.
- [x] Gate H: committed capacity evidence for the façade (and events, if shipped) plus the
      publish-after-commit spike.
- [x] Breaking-change summary present in release notes and upgrade guide.
- [ ] Any unmet gate is explicitly documented and approved as an exception (`§9`).

## 6. Constraints

- Security, CRUD/FLS, run caps, concurrency limits, diagnostics authorization, and result
  normalization may not be weakened to pass a gate (`§1.5`).
- Follow the commit/PR process and quality gates in `§5`.
