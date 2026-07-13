# V2 completion-verification audit

## Scope

Independent verification of the "✅ Completed" claims in
[`../V2-RELEASE-PLAN.md`](../V2-RELEASE-PLAN.md) against the shipped `force-app/` metadata, plus a
Salesforce best-practices pass. Covers the field migration (§2.1–2.5), value contract (§2.9),
size registry (§2.8), lifecycle events (§4.2), public façade (§4.18), the §1.5/§9 jargon gate,
and the §9 release-readiness gates. Does **not** re-audit design decisions already recorded in the
per-section verification files listed in [`../plans/README.md`](../plans/README.md).

## Method

- **Branch / commit:** `v2-release` @ `2950ac2`.
- **Date:** 2026-07-13.
- **Org:** none reachable at audit start — the four prior scratch orgs (`rhc-v2-verify`,
  `rhc-v2-migration`, `rhc-v2-section4`, `rhc-namespaced-verify`) all expired `2026-07-13`; DevHub
  `gkSfdcDevHub` is connected. A fresh org (`rhc-v2-audit`, `test-6qb4wucj79bw@example.com`) was
  created during this audit, source-deployed clean, and used to run the full Apex suite.
- Commands run (reproducible):
  - Field counts: `ls force-app/main/default/objects/Record_Health_Check_{Rule,Set}__mdt/fields/ | wc -l`
  - Jargon gate: `grep -rniE "scalar|comparator" force-app/`
  - V1-name regression: `grep -rnoE "PanelHeading__c|CheckName__c|RunOrder__c|CheckMethod__c|MessageWhenFailed__c|DataQuery__c|PassFailFormula__c|Tooltip__c|DebugMode__c" force-app/`
  - Picklist hygiene: inspected `EvaluationType__c.field-meta.xml` for `<restricted>` + value casing.
  - API version drift: `grep -h apiVersion force-app/main/default/classes/*.cls-meta.xml | sort | uniq -c`
  - Local tests: `npm test`.

## Findings

| Item                                           | Status                  | Evidence                                                                                                                                                                                                                                                                                                                                                                              | Owner         |
| ---------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| §2.1 Set fields (12)                           | Pass                    | 12 field files in `Record_Health_Check_Set__mdt/fields/`, incl. `PublishRunEvent__c`                                                                                                                                                                                                                                                                                                  | Core          |
| §2.2 Rule fields (41)                          | Pass                    | 41 field files, incl. `PublishResultEvent__c`; names match migration map                                                                                                                                                                                                                                                                                                              | Core          |
| §2.1–2.5 breaking migration is clean (no shim) | Pass                    | **0** lingering V1 Rule/Set field names in `force-app/`. All 172 `Severity__c` hits are the event-payload field, not the renamed Rule field                                                                                                                                                                                                                                           | Core          |
| §2.9 restricted picklists / `UPPER_SNAKE_CASE` | Pass                    | `EvaluationType__c`: `<restricted>true`, values `FORMULA/QUERY/COMPARE_TWO_QUERIES/APEX`, no `<default>true`                                                                                                                                                                                                                                                                          | Core          |
| §2.8 size registry                             | Pass                    | `docs/reference/field-size-registry.md` present, 53 fields                                                                                                                                                                                                                                                                                                                            | Core          |
| §4.2 lifecycle events                          | Pass                    | `Record_Health_Check_Rule_Result__e` (12 fields) + `Record_Health_Check_Set_Run__e` (15 fields) match documented schema                                                                                                                                                                                                                                                               | Core          |
| §4.18 façade                                   | Pass                    | `RecordHealthCheck.run()`/`runSet()` overloaded single + bulk; `RecordHealthCheckFlowAction` `@InvocableMethod`/`@InvocableVariable`; `USER_MODE` in 7 classes                                                                                                                                                                                                                        | Core          |
| §1.5 / §9 jargon gate                          | Pass                    | **0** `scalar`/`comparator` matches in `force-app/`                                                                                                                                                                                                                                                                                                                                   | Core          |
| Local test suite                               | Pass                    | `npm test` → **108/108 Jest passing**                                                                                                                                                                                                                                                                                                                                                 | Core          |
| Clean-org deploy + Apex suite                  | Pass                    | Source deployed clean to fresh `rhc-v2-audit`; `RunLocalTests` → **183/183 Apex passing, 94% org-wide coverage**                                                                                                                                                                                                                                                                      | Core          |
| Source-to-org readback (§9)                    | Pass                    | [`2026-07-13-source-to-org-readback.md`](2026-07-13-source-to-org-readback.md) verdict Pass (415 files, 147/147 CMDT)                                                                                                                                                                                                                                                                 | Core          |
| Apex API version consistency                   | **Fixed in this audit** | Was 13 classes on `65.0` (incl. new `RecordHealthCheckFlowAction`, `...LifecyclePublisher`, `...ReasonCodes`, `...SetResult`, merge/token classes) vs project `sourceApiVersion 66.0`. Bumped all 13 to `66.0`; distribution now uniform                                                                                                                                              | Core          |
| §2.11 FLS `USER_MODE` org verification         | Advanced                | Automated half done — the FLS/`USER_MODE` Apex tests pass in the fresh `rhc-v2-audit` org (part of the 183/183 run). No separate human step remains for §2.11 beyond the shared Gate C browser sign-off                                                                                                                                                                               | Release owner |
| §9 Gate C — manual UI smoke test               | In progress             | On 2026-07-13 the LWC was added to a desktop Account record page in `rhc-v2-audit`, configured with `Example_Account_360_Health_Check`, saved, and activated as the org default. The live page resolves the Set and displays the expected 9-check Run state. The required result-state and permission/diagnostics-path evidence has **not** yet been recorded, so Gate C remains open | Release owner |
| §9 Gate E — release closeout                   | Gap                     | The upgrade guide and `2.0.0` source version already exist. Remaining work is a restore test using the retained v1.x artifact and exported metadata, rollback approval, final commit/PR review and approval, then creation of the V2 tag                                                                                                                                              | Release owner |

## Outstanding work

1. **§9 Gate C** — complete and record the manual browser smoke test per
   [`../plans/section-9-release-readiness/9-release-readiness-gates.md`](../plans/section-9-release-readiness/9-release-readiness-gates.md).
   The page setup and hero-Set resolution are complete in `rhc-v2-audit`; the outstanding evidence
   is pass/fail/skipped/unable rendering plus authorized, unauthorized, diagnostics-enabled, and
   diagnostics-disabled paths.
2. **§9 Gate E** — restore-test the rollback artifact and exported metadata, obtain rollback
   approval, commit the final release diff, obtain PR review/approval, and only then create the V2
   tag (same plan). The upgrade guide and source version bump are already complete.

## Release-readiness closeout (post-audit, 2026-07-13)

A pre-commit inspection found the decisive blocker the completion audit above had missed: the
entire Section 4 feature set (façade, lifecycle publisher, reason codes, set-result DTO, publish
fields) plus the release workspace existed **only in the working tree** — `HEAD` (`2950ac2`) did
not contain them — and an untracked `RecordHealthCheck-Examples/` checkout sat inside core, not
git-ignored, one `git add -A` away from a §3.1 boundary violation. A tag cut then would have
shipped V1-plus-field-migration with none of Section 4.

Executable closeout completed:

| Step                                         | Result                                                                                                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Core/examples boundary                       | `/RecordHealthCheck-Examples/` added to `.gitignore`; `git check-ignore` confirms it can no longer be committed. Commit `aff016f`                                                                       |
| Commit V2 product + docs + integration-tests | Commit `5d4d65d` (91 files incl. 6 new Section 4 classes); pre-commit prettier/eslint/Jest hook passed                                                                                                  |
| Commit V2 release workspace                  | Commit `41f3b17` (50 files: plans, audits, tools)                                                                                                                                                       |
| Working tree                                 | Clean (only the ignored examples checkout remains)                                                                                                                                                      |
| Committed artifact == org                    | `sf project deploy start` reports **Nothing to deploy** against `rhc-v2-audit` — committed source is byte-identical to the org that passed tests (source-to-org readback holds for the committed state) |
| Post-commit verification                     | **183/183 Apex @ 94% org-wide**, **108/108 Jest** on the committed artifact                                                                                                                             |

## Outstanding work — human/approval only

The two remaining gates are now genuinely blocked on a person, not on executable work:

1. **§9 Gate C** — a human runs `Example_Account_360_Health_Check` on the activated Account page in
   `rhc-v2-audit` and records pass/fail/skipped/unable rendering plus authorized, unauthorized,
   diagnostics-enabled, and diagnostics-disabled paths. Automated FLS/`USER_MODE` coverage passes;
   only the browser sign-off remains.
2. **§9 Gate E** — restore-test the retained v1.x artifact in a disposable org and obtain rollback
   approval; obtain PR review/approval for commits `aff016f`/`5d4d65d`/`41f3b17`; then create the
   `2.0.0` tag. These are executable on request, but each carries a required human approval and
   the restore test needs the retained v1.x export, so they are intentionally left for the release
   owner.

## Verdict

The completed claims are **accurate**, and the release's executable blockers are now **cleared**:
the V2 feature set is committed on `v2-release` (`41f3b17`), the core/examples boundary is
protected, and the committed artifact deploys clean and passes 183/183 Apex + 108/108 Jest with no
source-to-org drift. What remains is **not code** — it is the Gate C browser sign-off and the
Gate E restore test + approvals + tag. **V2 is release-_candidate_ ready; it must not be tagged
production-ready until those two human gates close.**
