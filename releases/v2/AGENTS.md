# V2 release workspace — instructions for Codex (and other AGENTS.md-aware agents)

This directory (`releases/v2/`) is the coordination workspace for the Record Health Check V2
release. Any agent working here must follow this layout and these rules. The design authority is
[`V2-RELEASE-PLAN.md`](V2-RELEASE-PLAN.md); the execution breakdown is in [`plans/`](plans/).

## Folder layout — put work in the right place

| Folder               | What goes there                                                                             | Read first         |
| -------------------- | ------------------------------------------------------------------------------------------- | ------------------ |
| [`plans/`](plans/)   | One execution plan per outstanding section. Update the matching plan when work lands.       | `plans/README.md`  |
| [`tools/`](tools/)   | Reusable, committed scripts: migration, artifact generators, verification helpers.          | `tools/README.md`  |
| [`bugs/`](bugs/)     | One file per bug: repro, root cause, fix, verification. `YYYY-MM-DD-<slug>.md`.             | `bugs/README.md`   |
| [`audits/`](audits/) | One file per audit/review: scope, method, findings, verdict. `YYYY-MM-DD-<topic>-audit.md`. | `audits/README.md` |

### Routing rule

When you begin a task, decide where its output lives before you start:

- Writing a re-runnable script or generator → `tools/`.
- Investigating or fixing a defect → a `bugs/` file.
- Reviewing code/metadata against a gate or contract → an `audits/` file.
- Building out a plan section → follow and update its `plans/` file.

Do not scatter these files at the `releases/v2/` root — the four subfolders are their homes.
Always read the target folder's `README.md` first; it defines the required file structure and
naming. `tools/` holds the _generator_; generated **output** lives where it is consumed (under
`docs/` or `audits/`), not in `tools/`.

Temporary or scratch files must not be committed to the repository. Only durable artifacts belong
here.

## Non-negotiable rules (from `V2-RELEASE-PLAN.md §1.5`, `§5.2`, `§9`)

1. No computer-science jargon in code, metadata, labels, help text, runtime messages, or docs —
   use plain Salesforce administrator language. The `§9` release gate requires **no `scalar` or
   `comparator`** remaining in `force-app/`.
2. Prefer scalable, additive-only, versioned, allowlisted contracts over broad reflection or
   per-consumer branches. Keep one source of truth per fact and generate derived documents.
3. Do not weaken security to pass tests: user-mode evaluation, CRUD/FLS, run caps, diagnostics
   authorization, and result normalization stay intact.
4. Behavior changes ship with positive and negative tests; documentation and code must agree in
   the same commit.
5. Stored picklist values are `UPPER_SNAKE_CASE`; labels are readable sentence case. Machine logic
   keys on stable status/reason/identity fields, never on display text.

## Working style

- Verify the current state in `force-app/` before trusting a status written in a plan; cite
  `file:line`.
- Reference design by section number (e.g. "per §4.19") instead of restating rationale.
- When a plan's work lands, update that plan's status and the `plans/README.md` index table.
- Commits in this repository omit AI co-author trailers.
