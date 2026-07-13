# V2 Findings — Emission Safety, Diagnostics Display, and FLS Presentation

## Purpose

This document captures the findings and outstanding work surfaced while reviewing the
three proposed platform events and the diagnostics/FLS display behavior. It is a working
backlog meant to be fed into a **plan-mode** session: the design decisions already live in
`V2-RELEASE-PLAN.md` (§2.11, §4.19, §6, §8); this file records **what is decided, what is
built, what is not, and the concrete work and acceptance criteria that remain.**

Do not restate design rationale here — reference the plan. Keep this action-oriented.

## Status at a glance

| #   | Finding                                                    | Design in plan                       | Code state                                                                 | Outstanding                                                                       |
| --- | ---------------------------------------------------------- | ------------------------------------ | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| 1   | Diagnostics auto-expands all checks                        | §2.11                                | **Implemented + tested**                                                   | Optional suppressed-row toggle (deferred)                                         |
| 2   | FLS presentation (neutral normal mode, honest diagnostics) | §2.11, §6                            | **Partial** — `WITH USER_MODE` + `isAccessible()` already enforce non-leak | Reason code, suppressed-detail flag, diagnostics detail, scratch-org verification |
| 3   | Emission & actuation safety model                          | §4.19, §2.1–§2.2, §4.2, §4.10, §4.12 | **Design only** — no events, no publish fields exist                       | Build events + enforce safety invariants when built                               |
| 4   | Stable reason-code catalog                                 | §2.9, §4.2                           | **Absent** — `reasonCode` is a free string                                 | Define an enumerated, tested reason-code registry                                 |

## Finding 1 — Diagnostics auto-expand (DONE)

**Design:** `V2-RELEASE-PLAN.md` §2.11 (Diagnostics expands every check).

**Implemented this session:**

- `recordHealthCheck.js`: `_isHiddenSkipped` / `_isHiddenSuccess` return `false` when
  `this.showDiagnostics` is set, so count-only (`Hide`) rows expand.
- The flag is authorized server-side — `RecordHealthCheckConfigService` sets
  `showDiagnostics = ShowDiagnostics__c && RecordHealthCheckAccess.canViewDebugDetails()` —
  so normal users are unaffected. View-time only; stored display picklists are untouched.
- Two Jest tests added; full component suite passes (108/108).

**Outstanding (optional, deferred):**

- The "surface skip reason and suppressed-row toggle in the LWC" idea (§2.10 disposition)
  would let an authorized admin collapse individual expanded groups. Not required; log as a
  UX nicety only if a real need appears.

## Finding 2 — FLS presentation: partial, needs completion

**Design:** `V2-RELEASE-PLAN.md` §2.11 (Field-level-security presentation), §6 (open item),
§4.18 (façade user mode).

**What already exists (verified in code):**

- `RecordHealthCheckEngine` loads the base record and runs queries `WITH USER_MODE`
  (`RecordHealthCheckEngine.cls` ~L398, ~L859–873) and gates fields via `isAccessible()`
  (~L1099, L1116, L1170). `RecordHealthCheckSoqlTemplate` enforces `WITH USER_MODE`
  injection and forbids `SYSTEM_MODE` templates.
- Net effect: an inaccessible field already yields no value to the caller — **normal-mode
  non-leakage is largely satisfied at the SOQL layer.** The LWC renders null values as blank.

**Gaps to close (the §2.11 promises that are not yet implemented):**

1. **Stable `FIELD_NOT_ACCESSIBLE` reason code** distinguishing "field not accessible" from
   other Unable-to-Evaluate causes. Today `RecordHealthCheckResult.reasonCode` is a free
   string (see Finding 4).
2. **Suppressed-detail flag** on the response (the plan's `ContainsRestrictedDetail`-style
   signal) so a consumer/UI can tell "genuinely blank" from "withheld by FLS" — but only the
   _flag_, never the value, crosses to the browser in normal mode.
3. **Diagnostics-gated honest detail.** When `showDiagnostics` is authorized, the overlay
   should name the inaccessible field (e.g. via `adminDetailMessage`) and carry the reason
   code. This detail must be **produced server-side only when the caller passes the
   diagnostics gate** — do not ship field names to the browser and hide them.
4. **Confirm the normal-mode invariant** end to end: no field API name, no "access"/
   "permission" wording, no restriction-only glyph reaches an unauthorized user through the
   LWC _or_ the façade response.

**Acceptance / verification:**

- Scratch-org verification of `USER_MODE` **formula-evaluation** behavior — the §6 open item
  on the §4.18 critical path. Confirm a formula check referencing a field the running user
  cannot see resolves to Unable-to-Evaluate with `FIELD_NOT_ACCESSIBLE`, not a leak or a raw
  exception.
- Apex tests: an inaccessible display field returns a blank value + suppressed flag in normal
  mode, and the field name + reason only under an authorized-diagnostics caller.
- Façade (§4.18) and LWC must return the **same** policy for the same input.

**Dependencies:** Finding 4 (reason-code catalog) should land first or together.

## Finding 3 — Emission & actuation safety: design only, not built

**Design:** `V2-RELEASE-PLAN.md` §4.19 (safety model), §2.1/§2.2 (additive `PublishRunEvent__c`
/ `PublishResultEvent__c`), §4.2 / §4.10 / §4.12 (event contracts and switches).

**Current state (verified):** none of it exists in `force-app/main`.

- No `Record_Health_Check_Set_Run__e`, `Record_Health_Check_Rule_Result__e`, or
  `Record_Health_Check_Diagnostic__e` objects.
- No `PublishRunEvent__c` / `PublishResultEvent__c` fields.
- The only platform event in the repo is the archived, deferred
  `force-app/deferred/capture-metrics/objects/Record_Health_Check_Metric__e` (V1 capture-metrics,
  superseded per §8).

**Invariants to enforce whenever emission is actually built (from §4.19):**

1. `RUN_ON_LOAD` evaluations **never** publish Rule Result events, regardless of switch state.
2. Publication switches gate only **deliberately initiated** contexts: public façade,
   scheduled/batch, or an explicit user-initiated run.
3. Both publish fields **default `false`**; installing/upgrading core publishes nothing.
4. **Recursion guard** in core: stamp run origin; refuse/guard republication for runs that
   originate inside an event-subscriber execution context.
5. **Publish-after-commit vs immediate** — resolve the §6 open decision; lean after-commit for
   anything that can drive record creation (phantom-event risk on rollback).
6. Payload minimization + identity/data-classification defaults per §4.13; on-load adoption
   analytics (`Set_Run__e` only) is a separately consented, minimal-profile option, never a
   byproduct of viewing a record.

**Open decisions carried from §6:**

- Whether lifecycle events ship in the initial V2 release or a later extension milestone.
- Exact payload, publication semantics, and data-minimization policy.
- Paired `STARTED`/`COMPLETED` vs. which optional phases ship; component impressions excluded.
- Default telemetry profile, per-Check-Set gate, Record ID / user identity policy, retention.

**Note:** this is future work. Until it is scheduled, the §4.19 rules are a **design constraint
to honor**, not current behavior. Nothing emits today.

## Finding 4 — Reason-code catalog is missing

**Design:** `V2-RELEASE-PLAN.md` §2.9 ("reason code explains why; display messages are never
integration keys"), §4.2 (`ReasonCode__c` as a stable machine-readable reason).

**Current state:** `RecordHealthCheckResult.reasonCode` is a single free-text `String`. There
is no enumerated, documented, tested set of reason codes.

**Work:**

- Define a stable reason-code registry (at minimum: the Unable-to-Evaluate family including
  `FIELD_NOT_ACCESSIBLE`, `INVALID_FORMULA`, applicability/prerequisite skips, and the
  system-error family). Align with the §2.10 skip/not-applicable decision.
- Enforce it in the engine and cover it with tests; document it so plugins key on codes, not
  labels. This underpins Finding 2 (FLS reason) and any future emission (Finding 3).

## Suggested sequencing for plan mode

1. **Reason-code catalog (Finding 4)** — small, unblocks the rest.
2. **FLS completion (Finding 2)** — reason code + suppressed flag + diagnostics detail +
   scratch-org `USER_MODE` verification; closes the §6 façade-critical-path item.
3. **Emission (Finding 3)** — larger; only after the §6 event decisions are signed off. Build
   events + switches with the §4.19 invariants enforced and tested from day one.

Diagnostics auto-expand (Finding 1) is already complete and needs no further plan work.

## Provenance

Findings compiled from the working session that added §2.11 and §4.19 to
`V2-RELEASE-PLAN.md`. Code state verified against `force-app/` on branch `v2-release`. All
current changes (plan edits, the diagnostics auto-expand implementation, and its tests) are in
the working tree and not yet committed.
