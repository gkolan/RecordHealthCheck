# `tools/` — V2 release tooling

Reusable, committed scripts and utilities for the V2 release: migration, artifact generation,
and verification. This is the home for any script an agent or human writes that should be
**re-runnable**, not a throwaway.

## What belongs here

- Migration/transform scripts (e.g. the existing `apply_v2_field_contract.py`,
  `migrate_namespaced_tokens.py`, `build_field_decision_review.py`).
- Generators for derived, single-source-of-truth artifacts — e.g. the field size registry
  generator called for in [`../plans/section-2-metadata-contract/2.8-field-size-registry.md`](../plans/section-2-metadata-contract/2.8-field-size-registry.md),
  or a `COMPATIBILITY.md` generator.
- Verification helpers (readback/diff, jargon sweeps, contract-value checks).
- Examples repository bootstrap (Section 3): `bootstrap_examples_repo.mjs`, `setup_examples_infrastructure.mjs`,
  `write_pack_contracts.mjs`, and `examples-repo-scripts/` (copied into `RecordHealthCheck-Examples/scripts/`).

## What does NOT belong here

- One-off temporary files or scratch output — use your session scratchpad, not the repo.
- Generated **output** artifacts themselves — those belong next to what they document (a size
  registry under `docs/reference/`, an audit under `../audits/`). `tools/` holds the _generator_,
  the output lives where it is consumed.

## Conventions

- Prefer Python 3 or POSIX shell; no external network dependencies unless documented.
- Each script has a top-of-file docstring: what it does, how to run it, inputs, outputs, and
  whether it mutates the repo.
- Scripts are idempotent where possible (safe to re-run).
- Do not commit `__pycache__/` or other build noise (it is already present locally; leave it out
  of commits).

## Source readback comparison

`compare_source_readback.py <source-dir> <retrieved-dir>` compares a Salesforce DX source tree
with an isolated Metadata API retrieve. It normalizes documented platform serialization changes
without modifying either tree and exits nonzero for missing or substantively different files.
