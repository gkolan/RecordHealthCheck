# `audits/` — V2 audits and review reports

One file per audit. An audit is a point-in-time review of the codebase or metadata against a
contract or gate — the evidence that a `§9` release gate or a design promise actually holds. Use
it for security reviews, FLS presentation audits, jargon sweeps, source-to-org readback diffs,
capacity/event-volume analyses, permission audits, and value-contract verifications.

The existing [`../emission-display-fls-findings.md`](../emission-display-fls-findings.md) is an
audit-style document; new audits of this kind belong here.

## File naming

`YYYY-MM-DD-<topic>-audit.md` — e.g. `2026-07-14-jargon-sweep-audit.md`,
`2026-07-15-fls-presentation-audit.md`, `2026-07-16-source-to-org-readback.md`.

## Required contents

1. **Scope** — what was audited, against which contract/gate (cite the `V2-RELEASE-PLAN.md`
   section, e.g. §2.11, §4.19, §9 Gate B/D).
2. **Method** — how it was checked (commands run, files inspected, org used, date). An audit must
   be **reproducible** — record the exact `grep`/`sf` commands or scripts (put reusable ones in
   [`../tools/`](../tools/)).
3. **Findings** — a table: item, status (pass / gap / fail), evidence (`file:line`, counts,
   diff), and owner. Distinguish "verified in code" from "assumed."
4. **Outstanding work** — concrete, action-oriented, with acceptance criteria. Reference the
   matching [`../plans/`](../plans/) file rather than restating design rationale.
5. **Verdict** — does the audited gate/contract pass? If not, what blocks it.

## Rules

- Audits **cite evidence** — `file:line`, counts, or command output — never vibes.
- Reference the design in `V2-RELEASE-PLAN.md` and the execution steps in `plans/`; do **not**
  restate design rationale (keep audits action-oriented, like the findings doc).
- Record the date and the state audited (branch, org, commit) so a later reader knows what was
  true when.
- Route any defect an audit finds into a [`../bugs/`](../bugs/) file; route outstanding build
  work into the relevant [`../plans/`](../plans/) file.
- Sanitized only — no customer data, tokens, session IDs, or full org IDs.
