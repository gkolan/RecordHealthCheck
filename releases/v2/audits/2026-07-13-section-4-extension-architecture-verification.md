# Section 4 extension-architecture verification

## Scope

Independent review of `V2-RELEASE-PLAN.md` §4 against the working tree (2026-07-13),
focused on what Codex built and marked ✅ Completed:

| Subsection                                             | Nature                                  | Verified here                             |
| ------------------------------------------------------ | --------------------------------------- | ----------------------------------------- |
| §4.1 Apex check contract                               | Pre-existing completed                  | Spot-check                                |
| §4.2 / §4.10 / §4.12 Lifecycle events + publish fields | Built                                   | Full                                      |
| §4.18 Public check-response façade                     | Built                                   | Full                                      |
| §4.19 Emission & actuation safety                      | Built                                   | Full                                      |
| §4.3–4.9, §4.11, §4.13–4.17                            | Architecture / deferred contracts       | Out of build scope (design guidance only) |
| §4.4 Diagnostic event                                  | Explicitly deferred until two consumers | Not built (correct)                       |

Prior Codex audits under this folder (§4.2 / §4.18 / §4.19) were treated as claims to
re-check in `force-app/`, not as authority. Scratch org alias `rhc-v2-section4` is listed
Active in `sf org list` but was **unreachable** during this review (`ENOTFOUND` on the
scratch host), so PAC / two-consumer org spikes were **not re-executed**; their script and
fixture presence were inspected in-repo only.

## Method

```text
# Event / publish-field metadata
ls force-app/main/default/objects/Record_Health_Check_{Set_Run,Rule_Result}__e/fields/
rg -n "publishBehavior|eventType|defaultValue" \
  force-app/main/default/objects/Record_Health_Check_Set_Run__e/ \
  force-app/main/default/objects/Record_Health_Check_Rule_Result__e/ \
  force-app/main/default/objects/Record_Health_Check_Set__mdt/fields/PublishRunEvent__c.field-meta.xml \
  force-app/main/default/objects/Record_Health_Check_Rule__mdt/fields/PublishResultEvent__c.field-meta.xml

# Publisher, façade, Flow, tests
read RecordHealthCheckLifecyclePublisher.cls
read RecordHealthCheck.cls
read RecordHealthCheckFlowAction.cls
read RecordHealthCheckSetResult.cls
read RecordHealthCheckLifecyclePublisherTest.cls
rg -n "LifecyclePublisher|PublishResult|PublishRun|RUN_ON_LOAD" \
  force-app/main/default/classes/RecordHealthCheckController.cls

# Integration fixtures
ls integration-tests/scripts/
read integration-tests/main/default/triggers/RecordHealthCheckRuleResult{Receipt,Export}.trigger

# Org re-check attempted, failed
sf apex run --target-org rhc-v2-section4  # ENOTFOUND
```

## Findings

### §4.1 Existing Apex check contract

| Item                              | Status   | Evidence                                                               |
| --------------------------------- | -------- | ---------------------------------------------------------------------- |
| `RecordHealthCheckRule` interface | Pass     | `RecordHealthCheckRule.cls:6–7` — `evaluate(RecordHealthCheckContext)` |
| Context + result types            | Pass     | `RecordHealthCheckContext.cls`, `RecordHealthCheckResult.cls` present  |
| Cross-package `global`            | Deferred | Correctly left to §9                                                   |

### §4.2 / §4.10 / §4.12 Lifecycle events

| Item                                     | Status                          | Evidence                                                                                                                                                                                                                                                                    |
| ---------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Two high-volume events                   | Pass                            | `Record_Health_Check_Set_Run__e`, `Record_Health_Check_Rule_Result__e` — `eventType=HighVolume`                                                                                                                                                                             |
| Publish After Commit                     | Pass                            | Both object-meta: `publishBehavior=PublishAfterCommit`                                                                                                                                                                                                                      |
| Opt-in fields default false              | Pass                            | `PublishRunEvent__c` / `PublishResultEvent__c` `defaultValue=false`; help text states page-load never publishes                                                                                                                                                             |
| Independent switches                     | Pass                            | Publisher queries Set checkbox and Rule checkbox separately (`LifecyclePublisher.cls:29–41`, `:75–87`)                                                                                                                                                                      |
| Minimal V1 payload per plan + §6         | Pass                            | Set Run: 15 fields (identity, phase, source, version, counts). Rule Result: 12 fields (identity, status/severity/reason, source, version, restricted-detail flag). No record/user/business values                                                                           |
| Only `COMPLETED` Set phase               | Pass (intentional)              | Hard-coded `Phase__c = 'COMPLETED'` (`LifecyclePublisher.cls:47`); matches §6 recorded decision                                                                                                                                                                             |
| Count reconciliation                     | Pass with note                  | Set envelope counts from `RecordHealthCheckSetResult.add/finish`; publisher copies those counts. `EligibleRuleCount__c` and `EvaluatedRuleCount__c` are both set to `response.results.size()` (`:52–53`) — equal on the façade path, not independently measured eligibility |
| Bulk + failure isolation                 | Pass                            | Chunk size 100; `inspect` logs WARN and does not throw (`:133–185`); unit tests for chunking and partial failure                                                                                                                                                            |
| Publisher seam                           | Pass                            | Only façade calls publisher (`RecordHealthCheck.cls:53–58`, `:94–104`, `:211–217`); controller has zero publisher references                                                                                                                                                |
| Layouts                                  | Pass                            | Set layout §6 Lifecycle Events; Rule layout §8 Lifecycle Events                                                                                                                                                                                                             |
| Permission sets                          | Pass with note                  | Admin + User grant Create/Read on both event objects. Field-level permissions for the publish checkboxes are not in the permission sets (Setup CMDT authorship remains admin-Setup)                                                                                         |
| Two materially different consumers       | Pass (fixture) / org not re-run | `RecordHealthCheckRuleResultReceipt` (Task) and `RecordHealthCheckRuleResultExport` (`RHC_Event_Export__c`) under `integration-tests/`. Scripts `publish_rule_result.apex` / `rollback_rule_result.apex` present. **No Set Run subscriber** in fixtures                     |
| Conceptual §4.2/§4.10 field completeness | Pass as V1 minimal              | Missing design-target fields (EvaluationId, ParentEvaluationId, RecordId, user identity, DurationMs, STARTED/CANCELLED/FAILED_TO_START, etc.) align with plan “ship minimal first” and §6 minimization — not treated as defects                                             |

### §4.18 Public check-response façade

| Item                                              | Status      | Evidence                                                                                                                      |
| ------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Rule evaluation                                   | Pass        | `RecordHealthCheck.run(...)` single + `runId` overload                                                                        |
| Check Set evaluation                              | Pass        | `runSet(configName, recordId[, runId])`                                                                                       |
| Bulk, order-preserving                            | Pass        | List overloads for Rule and Set; Flow returns index-aligned list                                                              |
| User mode                                         | Pass        | Delegates to engine (`RecordHealthCheck.cls:188–193`); no separate system-mode path in façade                                 |
| Contract version pre-1.0                          | Pass        | `RecordHealthCheckResult.CONTRACT_VERSION = '0.1'`                                                                            |
| Flow-invocable wrapper                            | Pass        | `RecordHealthCheckFlowAction` — dedicated `@InvocableVariable` DTOs, one `@InvocableMethod`, plain-language labels            |
| Fail-fast governor envelope                       | Pass        | `MAX_RECORDS_PER_CALL = 200`, `MAX_EVALUATIONS_PER_CALL = 15`; Flow preflight rejects over-budget aggregate before evaluating |
| Normalized Set envelope                           | Pass        | `RecordHealthCheckSetResult` with overall status + outcome counts + per-Rule list                                             |
| Surface remains `public` (not premature `global`) | Pass        | Appropriate until §9 packaging decision                                                                                       |
| Flow source stamp                                 | Gap (minor) | Flow calls façade, which always publishes as `SOURCE_FACADE`. `SOURCE_FLOW` constant exists but is unused                     |

### §4.19 Emission and actuation safety

| Item                                         | Status                         | Evidence                                                                                                                                                                                              |
| -------------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `canPublish` hard-stops on-load / subscriber | Pass                           | `source != RUN_ON_LOAD && source != SUBSCRIBER && subscriberContextOverride != true` **before** CMDT lookup (`LifecyclePublisher.cls:118–123`)                                                        |
| Page-load emits neither stream               | Pass                           | (1) Controller never calls publisher; (2) unit test `onLoadPublishesNeitherStreamEvenWhenSwitchesAreOn` forces switches on and asserts zero DML                                                       |
| Default off                                  | Pass                           | Field defaults + unit test `defaultOffAndSubscriberGuardPublishNothing`                                                                                                                               |
| Deliberate context only                      | Pass                           | Production publish path is façade-only with `SOURCE_FACADE`                                                                                                                                           |
| Result unchanged on publish failure          | Pass                           | Publish after finalization; `inspect` does not mutate results; façade test + publisher tests assert status unchanged                                                                                  |
| Action link ≠ actuation                      | Pass                           | LWC/action presentation has no publisher path                                                                                                                                                         |
| Subscriber recursion guard                   | Pass with note                 | Test override works; `SOURCE_SUBSCRIBER` is rejected in `canPublish` but **no unit test stamps that source string**, and **no production API** auto-sets subscriber context for extension subscribers |
| PAC rollback                                 | Pass (script) / org not re-run | In-repo `rollback_rule_result.apex` + receipt trigger; Codex audit claimed Task only for committed marker. This review could not reconfirm in org                                                     |

## Outstanding work

1. **Stamp or document Flow source.** Either pass `SOURCE_FLOW` from `RecordHealthCheckFlowAction` or document that Flow is a façade subtype under `FACADE`.
2. **Extension subscriber recursion.** Expose a documented way for package subscribers to mark subscriber context (today only `@TestVisible subscriberContextOverride`), or require extensions to own the guard in their contracts and drop the unused `SOURCE_SUBSCRIBER` production path expectation.
3. **`EligibleRuleCount` vs `EvaluatedRuleCount`.** Prefer distinct semantics when truncation/applicability differs; today both equal `results.size()`.
4. **Set Run second-consumer proof.** Add a Set Run fixture consumer before freezing broader run analytics, or narrow the §4.8 claim to Rule Result only.
5. **Re-run scratch org spikes** when `rhc-v2-section4` (or a replacement) is reachable — PAC + two-consumer queries + façade capacity script.
6. **§4.3 sink / §4.4 diagnostic event / §4.5–4.17 packaging ecosystem** remain design-only; no further build verification needed until those plans open.

## Codex audit cross-check

| Codex artifact                                            | Independent verdict                                                                            |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `2026-07-13-section-4.2-lifecycle-events-verification.md` | **Holds** for source/metadata; org claim not re-run                                            |
| `2026-07-13-section-4.18-facade-verification.md`          | **Holds** for source; Flow→`FACADE` nuance omitted there                                       |
| `2026-07-13-section-4.19-emission-safety-verification.md` | **Holds** for source invariants; subscriber-production wiring is weaker than the prose implies |

Plan statuses ✅ Completed for 4.2 / 4.18 / 4.19 are **warranted** for the V1 shipping scope.

## Verdict

**Pass** for the built Section 4 contracts (§4.1 spot-check, §4.2/4.10/4.12, §4.18, §4.19) against the V1 minimal design and §6 recorded decisions.

Residual items above are polish / follow-on documentation or additive schema work — **not** release blockers for marking those subsections complete. Org-side PAC/capacity claims remain “verified by Codex on 2026-07-13; not re-executed in this audit.”
