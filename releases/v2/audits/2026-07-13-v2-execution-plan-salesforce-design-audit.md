# V2 execution-plan Salesforce design audit

## Scope

Reviewed the V2 design authority and all execution plans under `releases/v2/plans/` against
Salesforce security, Apex governor-limit, Flow-invocable, custom metadata, packaging, and
platform-event design practices. The audit covers the contracts in `V2-RELEASE-PLAN.md` §§2.8–2.11,
§§4.2, 4.10, 4.14, 4.18–4.19, and the §9 release gates.

State audited: branch `v2-release`, commit `2950ac2`, 2026-07-13. This was a source/document review;
no org behavior was assumed verified.

## Method

Commands used:

```text
rg --files releases/v2
sed -n '1,240p' releases/v2/AGENTS.md
sed -n '1,320p' releases/v2/V2-RELEASE-PLAN.md
for f in releases/v2/plans/section-*/*.md; do sed -n '1,420p' "$f"; done
rg -n "containsRestrictedDetail|indistinguishable|stripInaccessible|EventBus.publish|Test.getEventBus|Limits.getQueries|permission sets|High-Volume" releases/v2
```

Platform assumptions were compared with current Salesforce developer guidance for secure Apex,
`WITH USER_MODE`, `Security.stripInaccessible`, Flow invocable methods, Apex limits, and platform
event publish behavior. Exact limit values must still be read from the target release/org during
implementation; the plans correctly avoid hard-coding edition allocations.

## Findings

| Item                                      | Status                                     | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                | Owner                    |
| ----------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| Contract boundaries and growth policy     | Pass                                       | The plans favor small, versioned, additive, allowlisted contracts; keep normalization centralized; avoid extension-specific engine branches; and defer speculative extension points (`plans/README.md:23-34`, `4.18-public-check-response-facade.md:54-64,107-116`).                                                                                                                                                                    | Architecture owner       |
| User-mode and server-side data protection | Pass with correction required below        | Explicit user-mode evaluation, diagnostics authorization, no raw exception detail in normal responses, and positive/negative permission tests are strong defaults (`2.11-fls-presentation-completion.md:23-36,103-115`).                                                                                                                                                                                                                | Security owner           |
| Unauthorized restricted-detail flag       | **Fail — security contradiction**          | Normal mode is required to make restricted and genuinely blank values indistinguishable (`2.11-fls-presentation-completion.md:24-27,144-145`), but the same plan sends `containsRestrictedDetail = true` to a normal caller (`:81-85,123-125`). The flag discloses the very fact the policy says must remain hidden.                                                                                                                    | Security owner           |
| `stripInaccessible` integration seam      | Gap                                        | Salesforce recommends `stripInaccessible` for graceful degradation, but it sanitizes SObjects; it does not by itself sanitize already-derived strings, formula outputs, aggregate values, exception text, or URLs. The plan acknowledges some non-SObject paths (`2.11-fls-presentation-completion.md:98-100`) but acceptance criteria do not require a complete source-to-response data-flow inventory.                                | Security owner           |
| Bulk façade contract                      | Gap — capacity model incomplete            | The façade caps input near 200 and forbids query/describe calls inside per-record loops (`4.18-public-check-response-facade.md:70-77,107-109`), but “queries stay flat as record count grows” (`:121-125`) is not a sufficient or always realistic scalability assertion. Cost depends on records × rules × configured query count/row limits/formulas; CPU, query rows, heap, and synchronous time are missing gates.                  | Façade owner             |
| Flow bulk shape                           | Pass with validation needed                | Dedicated invocable DTOs, list-in/list-out alignment, and no per-item SOQL are appropriate (`4.18-public-check-response-facade.md:80-96`). Validate supported annotations/types and actual bulk behavior in the release-target API version rather than treating “200” as the façade's only safety bound.                                                                                                                                | Façade owner             |
| Event fan-out and allocation awareness    | Pass with correction required below        | Default-off switches, two shared streams, payload minimization, idempotency key, at-least-once assumptions, recursion protection, and N×M fan-out awareness are sound (`4.2-lifecycle-events-and-publish-fields.md:61-75,119-131,138-148`).                                                                                                                                                                                             | Event owner              |
| “Single event list per transaction”       | Gap — lifecycle/scaling ambiguity          | The plan requires one publish list per transaction (`4.2-lifecycle-events-and-publish-fields.md:119-120`) while defining `STARTED` and terminal run phases (`:76-90`). Buffering both until completion makes `STARTED` non-live; publishing at both lifecycle points violates the stated rule. Two event types/phases also need explicit chunking behavior when the platform per-call event limit is reached.                           | Event owner              |
| Platform-event test recipe                | Gap — must be spike-verified               | The plan mandates `Test.getEventBus().deliver()` after `Test.stopTest()` and a savepoint rollback proof (`4.2-lifecycle-events-and-publish-fields.md:151-159`). These mechanics are release-sensitive and do not by themselves prove a real transaction commit boundary. Require a minimal deployable spike plus an org integration test for publish-after-commit/rollback before making this the global test convention.               | Event owner              |
| On-load safety                            | Pass with one inconsistent acceptance test | The context-first guard, default-off switches, explicit limitation of caller intent, subscriber-origin guard, and no recursive diagnostic event are strong (`4.19-emission-and-actuation-safety.md:35-79,88-102`). However, §4.19's headline test expects zero Set and Rule events (`:105-106`), while invariant 6 allows separately consented on-load Set Run analytics (`:53-55`). Choose one contract and make both documents agree. | Product + event owner    |
| CMDT and platform-event permissions       | Gap — terminology/metadata precision       | The event plan says to update “permission sets (read for admins as appropriate)” while adding CMDT fields (`4.2-lifecycle-events-and-publish-fields.md:108-110`). Separate CMDT configuration visibility, Apex class/custom permission access, and platform-event Read/Create object permissions explicitly; do not imply ordinary record-object FLS semantics apply uniformly to all three.                                            | Packaging/security owner |
| Reason-code registry                      | Pass with catalog refinement               | Stable additive string constants, null reason for ordinary pass/fail, and integration keys independent of messages are scalable (`2.9-reason-code-catalog.md:35-56,88-97`). `NO_ROWS` and `EMPTY_VALUE` currently show “configured” status and must be split into outcome-specific codes or precisely constrained mappings before freezing.                                                                                             | Contract owner           |
| Release gates                             | Gap                                        | Clean-org deploy, readback, UI smoke, permissions, documentation, and rollback evidence are good (`9-release-readiness-gates.md:55-86`). Add Salesforce Code Analyzer/security scanning, packaging-version install/upgrade validation for the chosen package model, and explicit governor/capacity evidence for façade and events.                                                                                                      | Release owner            |

## Outstanding work

1. Update Plan 2.11 so the normal public/LWC response contains neither restricted detail nor a
   restriction-presence flag. If operational consumers need the flag, expose it only through the
   authorized diagnostics contract. Add a complete inventory test covering every response field
   derived from SObjects, formulas, queries, messages, URLs, and exceptions.
2. Update Plan 4.18 with a transaction budget: maximum records, maximum active rules, maximum
   configured query work, query rows, CPU, heap, and response size. Define fail-fast validation
   and recommend Batch/Queueable processing when the synchronous envelope is exceeded. Replace
   “flat query count” with bounded growth and explicit ceilings.
3. Update Plan 4.2 to define publication batches per lifecycle point and event type, including
   chunk size, partial `SaveResult` handling, idempotent retry policy, and what happens when the
   transaction or hourly allocation budget is exhausted. Decide whether `STARTED` provides true
   real-time value; omit it if both phases are intentionally emitted only after completion.
4. Run a small scratch-org spike for publish-after-commit behavior and platform-event test
   delivery. Record which assertions are possible in Apex tests and which require an org-level
   integration test.
5. Reconcile §4.19: either on-load emits nothing at all, or it may emit a separately consented,
   minimal Set Run event. The acceptance test and prose must express the same rule.
6. Add §9 gates for Code Analyzer, package installation/upgrade (after packaging model decision),
   dependency/version compatibility, and documented capacity test evidence.

Acceptance is achieved when the matching plan files contain these decisions and tests, with a
named owner, and the contradictory statements no longer exist.

## Verdict

**Not ready to execute unchanged.** The overall architecture is directionally strong and notably
better than a reflection-heavy or per-extension design. It follows many Salesforce best practices,
especially user-mode access, additive contracts, bulk interfaces, event payload minimization, and
default-off automation. The restricted-detail flag is a release-blocking security contradiction.
The façade needs a multidimensional governor-limit budget, and the event plan needs precise
lifecycle batching and release-verified test mechanics before it can be called scalable.
