# V2 release workspace — instructions for Claude

This directory (`releases/v2/`) is the coordination workspace for the Record Health Check V2
release. When you work here, follow this layout and these rules. The design authority is
[`V2-RELEASE-PLAN.md`](V2-RELEASE-PLAN.md); the execution breakdown is in [`plans/`](plans/).

## Folder layout — put work in the right place

| Folder               | What goes there                                                                             | Read first                             |
| -------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------- |
| [`plans/`](plans/)   | One execution plan per outstanding section. Update the matching plan when work lands.       | [`plans/README.md`](plans/README.md)   |
| [`tools/`](tools/)   | Reusable, committed scripts: migration, artifact generators, verification helpers.          | [`tools/README.md`](tools/README.md)   |
| [`bugs/`](bugs/)     | One file per bug: repro, root cause, fix, verification. `YYYY-MM-DD-<slug>.md`.             | [`bugs/README.md`](bugs/README.md)     |
| [`audits/`](audits/) | One file per audit/review: scope, method, findings, verdict. `YYYY-MM-DD-<topic>-audit.md`. | [`audits/README.md`](audits/README.md) |

**Routing when you start a task:** writing a re-runnable script → `tools/`. Investigating a
defect → a `bugs/` file. Reviewing code/metadata against a gate or contract → an `audits/` file.
Building a section → follow and update its `plans/` file. Never scatter these at the `releases/v2/`
root; the four subfolders are the homes. Read the target folder's `README.md` before adding to it —
it defines the required file structure and naming.

**Do not** put temporary/scratch files in the repo — use your session scratchpad. Only durable,
committed artifacts belong here. `tools/` holds generators; generated **output** lives where it is
consumed (docs, `audits/`), not in `tools/`.

## Non-negotiable rules (from `V2-RELEASE-PLAN.md §1.5`, `§5.2`, `§9`)

1. **No computer-science jargon** in code, metadata, labels, help text, runtime messages, or docs
   — use plain Salesforce admin language. The `§9` gate specifically requires **no `scalar` or
   `comparator`** in `force-app/`.
2. **Scalable, additive-only contracts** — allowlisted and versioned over broad reflection; two
   shared event streams, not one per plugin; one source of truth per fact (generate derived docs).
3. **Security may not be weakened to pass a test** — user-mode evaluation, CRUD/FLS, run caps,
   diagnostics authorization, result normalization stay intact.
4. **Behavior changes ship with positive and negative tests**; docs and code agree in the same
   commit.
5. **Stored picklist values are `UPPER_SNAKE_CASE`; labels are readable sentence case.** Machine
   logic keys on stable status/reason/identity, never display text.

## Working style here

- Verify current state in `force-app/` before trusting a status in the plan — cite `file:line`.
- Reference design by section (e.g. "per §2.11") instead of restating rationale.
- When a plan's work lands, update that plan's status and the [`plans/README.md`](plans/README.md)
  index table.
- Commits in this repo omit AI co-author trailers.
