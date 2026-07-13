# V2 Execution Plans

This folder breaks the outstanding work in [`../V2-RELEASE-PLAN.md`](../V2-RELEASE-PLAN.md)
into self-contained, executable plan files — one per section of work that is **not yet
complete**. Each plan is written so a human or an agent can pick it up cold, verify current
state, and execute without re-reading the entire release plan.

> **Review of record.** These plans incorporate the Salesforce design audit at
> [`../audits/2026-07-13-v2-execution-plan-salesforce-design-audit.md`](../audits/2026-07-13-v2-execution-plan-salesforce-design-audit.md).
> Its release-blocker (the FLS restriction-presence flag) and every gap it raised have been folded
> into the plan files below — most visibly [2.11](section-2-metadata-contract/2.11-fls-presentation-completion.md)
> (restriction signals are diagnostics-only), [4.18](section-4-extension-architecture/4.18-public-check-response-facade.md)
> (multidimensional governor budget), [4.2](section-4-extension-architecture/4.2-lifecycle-events-and-publish-fields.md)
> (per-lifecycle-point batching + scratch-org spike), [4.19](section-4-extension-architecture/4.19-emission-and-actuation-safety.md)
> (on-load publishes nothing), and [9](section-9-release-readiness/9-release-readiness-gates.md)
> (Code Analyzer, packaging, capacity gates).

Sections already marked **✅ Completed** in the release plan (the 2.1–2.7 and 2.9 field
migration, 2.6 validators, 2.7 merge/binding, 4.1 Apex check contract) are **not** re-planned
here. They are the source of truth as shipped; touch them only if a downstream plan proves a
defect. Where a completed section has an _additive_ remainder (e.g. the `PublishRunEvent__c` /
`PublishResultEvent__c` fields noted in 2.1/2.2), that remainder is planned under the section
that actually builds it — [4.2](section-4-extension-architecture/4.2-lifecycle-events-and-publish-fields.md).

## Global constraints (apply to every plan)

These are release-level rules from `V2-RELEASE-PLAN.md §1.5`, `§5.2`, and `§9`. Every plan
inherits them; they are not repeated in full inside each file.

1. **No computer-science jargon in code, metadata, or UI.** Field labels, API names, picklist
   values, help text, runtime messages, class/method names, and docs use ordinary Salesforce
   administrator language. The release gate specifically requires **no `scalar` or `comparator`**
   remaining in `force-app/` (see the [Section 9 plan](section-9-release-readiness/9-release-readiness-gates.md));
   existing internal names like `VALID_COMPARATORS`, `RecordHealthCheckComparisonEngine`, and
   `FormulaResultType`/`scalar` return types are in scope for that cleanup.
2. **Scalable by design.** Prefer allowlisted, versioned, additive-only contracts over broad
   reflection or per-consumer branches. Two shared event streams, not one per plugin (`§4.10`,
   `§4.17`). One source of truth per fact; generate derived artifacts (catalogs, size registry).
3. **Security is not negotiable to pass tests** (`§1.5`). User-mode evaluation, CRUD/FLS,
   run caps, diagnostics authorization, and result normalization may not be weakened.
4. **Docs and code agree in the same commit** (`§1.5`). Behavior changes ship with positive
   and negative tests (`§5.2`).
5. **Stored picklist values are `UPPER_SNAKE_CASE`; labels are readable sentence case** (`§1.3`).
   Machine logic keys on stable status/reason/identity fields, never display text (`§4.16`).
6. **Apex test conventions** (apply to every plan that ships Apex): use the existing
   `RecordHealthCheckTestDataFactory` rather than hand-built records; wrap the exercised call in
   `Test.startTest()` / `Test.stopTest()`; assert with messages; **never** `@IsTest(SeeAllData=true)`.
   Permission/authorization paths (diagnostics gate, `Record_Health_Check_User`, FLS) are tested
   with `System.runAs` — note that the suite uses `System.runAs` in **zero** files today, so this
   is new test infrastructure, not a tweak. Platform-event subscribers are tested with
   `Test.getEventBus().deliver()`. Every behavior change ships **positive and negative** tests (`§5.2`).

## Per-plan header fields

Each plan's header table carries **Owner**, **Effort**, and **Risk** in addition to Status and
dependencies. Owner is `Unassigned` until recorded in `V2-RELEASE-PLAN.md §6` (the release plan
explicitly wants a recorded owner per open item). Effort is a rough T-shirt size (S/M/L); Risk is
a one-line blast-radius note so a scheduler can sequence safely.

## Plan index and dependency order

| Order | Plan                                                                                                                 | Release §                 | Status                 | Depends on                           |
| ----- | -------------------------------------------------------------------------------------------------------------------- | ------------------------- | ---------------------- | ------------------------------------ |
| 1     | [2.10 Skip and Not-Applicable semantics](section-2-metadata-contract/2.10-skip-and-not-applicable-semantics.md)      | 2.10, 6                   | ✅ Completed           | —                                    |
| 2     | [2.9 Reason-code catalog](section-2-metadata-contract/2.9-reason-code-catalog.md)                                    | 2.9, 4.2                  | ✅ Completed           | 2.10                                 |
| 3     | [2.11 FLS presentation completion](section-2-metadata-contract/2.11-fls-presentation-completion.md)                  | 2.11, 6                   | ✅ Completed           | 2.9                                  |
| 4     | [4.18 Public check-response façade](section-4-extension-architecture/4.18-public-check-response-facade.md)           | 4.18                      | ✅ Completed           | 2.9, 2.11                            |
| 5     | [4.2 Lifecycle events + publish fields](section-4-extension-architecture/4.2-lifecycle-events-and-publish-fields.md) | 4.2, 4.10, 4.12, 2.1, 2.2 | ✅ Completed           | 2.9, 2.10, 6 sign-off                |
| 6     | [4.19 Emission & actuation safety](section-4-extension-architecture/4.19-emission-and-actuation-safety.md)           | 4.19                      | ✅ Completed           | 4.2                                  |
| 7     | [2.8 Field size registry](section-2-metadata-contract/2.8-field-size-registry.md)                                    | 2.8                       | ✅ Completed           | —                                    |
| 8     | [3 Examples repository migration](section-3-examples-repository/3-examples-repository-migration.md)                  | 3.1–3.7                   | ✅ Completed (initial) | hero-example decision (6)            |
| 9     | [9 Release-readiness gates](section-9-release-readiness/9-release-readiness-gates.md)                                | 9                         | 🟡 Partial             | all above where they land in-release |

**Critical path** for the FLS/façade contract (`§6`) was **2.10 → 2.9 → 2.11 → 4.18**. Sections
2.8–2.11, 4.2, 4.18, and 4.19 are verified complete for the V1 shipping scope; §2.11's
scratch-org Apex/FLS `USER_MODE` verification passed as part of the 183/183 run on `rhc-v2-audit`
(2026-07-13, commit `bda2469`). §4.3–4.17 stay intentionally deferred/design-only. Section 9 is
the closeout.

### Verification rollup (2026-07-13)

| Area                               | Status                                                                                                                                                   |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| §4.1, §4.2/4.10/4.12, §4.18, §4.19 | **Pass** — [`audits/2026-07-13-section-4-extension-architecture-verification.md`](../audits/2026-07-13-section-4-extension-architecture-verification.md) |
| §2.8                               | **Verified complete** — 53-field registry, 2,000-character URL limit                                                                                     |
| §2.9                               | **Verified complete**                                                                                                                                    |
| §2.10                              | **Verified complete** (Option A)                                                                                                                         |
| §2.11                              | **Verified complete** — implementation + local tests verified; org FLS/`USER_MODE` check passed in `rhc-v2-audit` (183/183, commit `bda2469`)            |

## Open release decisions referenced by these plans

These are owned in `V2-RELEASE-PLAN.md §6` and must have a recorded owner + decision before the
dependent plan can freeze its contract. Each plan lists the specific decisions it is blocked on.

- Skip vs Not-Applicable (`§2.10`) → **resolved:** Option A, one `SKIPPED` status with reason codes.
- Do lifecycle events ship in V2 / Publish After Commit (`§4.2`, `§6`) → **resolved:** ship in V2; high-volume Publish After Commit.
- Unlocked vs managed packaging model + required `global` visibility (`§4.15`, `§6`) → blocks
  packed `global` finalization and 3.6 distribution (§4.18 same-namespace surface is complete).
- Identity of the one core hero example (`§6`) → **resolved:** `Example_Account_360_Health_Check` in core.
