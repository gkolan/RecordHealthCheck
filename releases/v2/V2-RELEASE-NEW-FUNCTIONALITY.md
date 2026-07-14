# Post-V2 functionality plan

A sequenced plan for the work that comes **after** V2 ships: features V1 deferred, and product
surfaces the V2 contract was designed to unlock. This is a roadmap, not a release gate.

> **Gate: do not start any item here until V2 is tagged.** V2's value is a clean, frozen
> contract (`V2-RELEASE-PLAN.md` §9). Pulling these forward reopens scope and risks the release.
> When an item starts, give it its own file under [`plans/`](plans/) and update the status column
> here.

**Authorities:** [`V2-RELEASE-PLAN.md`](V2-RELEASE-PLAN.md) (§4.3–§4.17 deferred surfaces, §6 open
decisions, §8 disposition register) and
[`docs/v2/reference/record-health-check-design-spec.md`](../../docs/v2/reference/record-health-check-design-spec.md)
(Non-Goals, Open Limitations).

## Already shipped in V2 — do not re-plan

| Once deferred                           | V2 status                                                             |
| --------------------------------------- | --------------------------------------------------------------------- |
| Programmatic / Flow Set evaluation      | ✅ `RecordHealthCheck` façade + `RecordHealthCheckFlowAction` (§4.18) |
| Result-consumer / capture-metrics path  | ✅ Opt-in lifecycle events; V1 Capture Metrics superseded (§4.2, §8)  |
| FLS / diagnostics presentation contract | ✅ Shipped and org-verified (§2.11)                                   |

## Ground rules for every item

1. Respect §4.19: page-load stays observational; actuation and automatic remediation live in
   extensions, never core.
2. Defer any extension-point **API** until two credible consumers justify it (§1.4, §4.4, §4.7).
3. One source of truth per fact — generate derived docs, don't hand-copy.
4. Prefer items that **finish metadata already shipped** over net-new surfaces.

---

## Tier 1 — Finish what V2 shipped (core, low risk, high visibility)

Each of these has its metadata or contract already in `force-app/`; only the experience is missing.
Verified against the code on 2026-07-13:

| ID     | Feature                                      | Verified gap                                                                                                                                                                                        | Effort | Acceptance                                                                                                                              |
| ------ | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| **F1** | **Group card rows by Category**              | `Category__c` ships on the Rule; the LWC has **zero** `category` references ([`recordHealthCheck.js`](../../force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js)) — no grouping today | S–M    | Rows group by outcome Category; blank → Uncategorized; presentation-only, evaluation order/status unchanged; positive + a11y Jest tests |
| **F3** | **Show skip reason + suppressed-row toggle** | `reasonCode` is already plumbed through `healthCheckModel.js`/`healthCheckPresentation.js`; only the plain-language display and the authorized collapse toggle are missing                          | S      | Skip rows read a plain-language reason; authorized toggle collapses diagnostics-expanded groups; no stored-state change                 |
| **F5** | **Run/progress polish**                      | §8 "multi-color progress bar — defer to UI polish"                                                                                                                                                  | S      | Pure presentation; only worth doing inside the same pass as F1                                                                          |

**Recommended first plan:** F1 + F3 together (one LWC pass, shared tests). This is the natural
"first thing after V2 tags." Draft it as `plans/post-v2/f1-f3-card-grouping-and-skip-ux.md` when V2 ships.

## Tier 2 — Activate a shipped-but-dormant permission (core admin tooling)

| ID     | Feature                                                | Verified gap                                                                                                                                                                                      | Effort | Acceptance                                                                                                                               |
| ------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **F2** | **Rule Tester**                                        | `Record_Health_Check_Configure` custom permission ships but is referenced **nowhere** in Apex/LWC (only `View_Details` is wired, in `RecordHealthCheckAccess.cls`). F2 is its first real consumer | M      | Admin tests a Rule against a chosen record from a Setup/admin surface; runs user-mode; honors the diagnostics gate; gated by `Configure` |
| **F4** | **Related-list / list-view admin experience for CMDT** | §8 admin-experience additions; optional declarative Validation Rules layered on the Apex validators (§2.6)                                                                                        | M      | Friendlier browsing of Rules under a Check Set; VRs are additive, never replace the Apex validators                                      |

## Tier 3 — First extension products (in `RecordHealthCheck-Extensions`, not core)

The lifecycle events and façade exist to be consumed here. **The Extensions repository does not
exist yet** — standing it up is the first task; keep every item below out of core.

| ID     | Feature                                                    | Refs        | Gate                                                                                                              |
| ------ | ---------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------- |
| **E1** | **Observability / history extension**                      | §4.8, §4.11 | First real Rule/Set-run consumer; retention, reports, permissions all extension-owned. Retires V1 Capture Metrics |
| **E2** | **Second material consumer** (notify / Case / Task / SIEM) | §4.8, §4.11 | Required before deeper lifecycle fields freeze; must never alter evaluation results                               |
| **E3** | **Scheduled assessment pack**                              | §4.11, F7   | Schedulable/batch calls the façade; optional history via E1                                                       |
| **E4** | **Per-record outcome rollups for reporting**               | §8          | Extension writes counts/last-status; never from page-load                                                         |
| **E5** | **Example packs → unlocked/managed 2GP**                   | §3.6, §4.15 | Source-first packaging done; 2GP promotion per pack; `global` surfaces wait for a real package model              |

## Tier 4 — Product space from V1 non-goals (bigger bets, need a product decision)

Deliberate V1 non-goals, not bugs. Open only with an explicit decision to reverse the non-goal.

| ID      | Feature                                                          | Where it belongs                                                                                   |
| ------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| **F6**  | Result history on the record page                                | Extension storage (E1) + optional thin core read API — core never grows a mandatory history object |
| **F7**  | Background / scheduled monitoring                                | Extension invocation adapter on the façade; wire `Source__c` `SCHEDULED`/`BATCH`                   |
| **F8**  | Auto re-run after inline edit/save                               | Core LWC, opt-in only; never couples to on-load publication                                        |
| **F9**  | Non–record-page surfaces (Home, utility, Experience Cloud, REST) | Callers of the façade — never fork the engine                                                      |
| **F10** | Label / message translation (i18n)                               | Core, later — Custom Labels for UI strings; revisit reason-code inference for non-English orgs     |

## Tier 5 — New contract surfaces (additive, only after two consumers)

Gated behind real demand per §4.7. Building these speculatively is the anti-pattern the design warns against.

| ID         | Feature                                                                                                            | Gate                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| **C1**     | Wire remaining `Source__c` values (`USER_INITIATED`/`SCHEDULED`/`BATCH`/`FLOW`)                                    | Today Flow tags as `FACADE`; optional user **Rerun** may publish under §4.19 deliberate-context rules |
| **C2**     | Additional Set Run phases (`STARTED`/`CANCELLED`/`FAILED_TO_START`)                                                | Beyond the shipped `COMPLETED`-only payload; decide live-vs-buffered carefully                        |
| **C4**     | Global emergency publish kill switch                                                                               | Org-level override of publish checkboxes without rewriting stored metadata                            |
| **C5**     | Richer lifecycle identity fields (`RecordId__c`, user identity, `DurationMs__c`, parent IDs)                       | Only under explicit privacy/telemetry-profile decisions (§4.13, §6)                                   |
| **C8**     | Packaged `global` façade / check contract                                                                          | When an unlocked/managed package model is chosen; smallest surface only                               |
| **C9**     | Effective publication state in admin diagnostics                                                                   | Distinguish "no activity" from "publication disabled"                                                 |
| **E6–E12** | Diagnostic event, logger adapter, sync sink, evaluator provider, presentation/remediation plugins, Pub/Sub gateway | Each needs its own second-consumer proof (§4.3, §4.4, §4.7, §4.9, §4.17)                              |

## Suggested order

```text
V2 tags ──▶ Tier 1 (F1+F3) ──▶ Tier 2 (F2 Rule Tester) ──▶ Tier 3 (E1 → E2 → E3/E4)
                                                              │
                              privacy sign-off ──▶ Tier 5 lifecycle enrichment (C1, C2, C4)
                              two consumers ─────▶ Tier 5 new extension points (E6–E12)
                              package model ─────▶ E5 2GP, C8 global contract
```

## Still non-goals (do not fold in without reversing the decision)

Blocking record saves · replacing Validation Rules / Duplicate Rules / Flow as the save-time
engine · automatic remediation inside core · one core event type per plugin · treating page-load
evaluation as telemetry (§4.19).
