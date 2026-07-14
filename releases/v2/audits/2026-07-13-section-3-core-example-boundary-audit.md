# Section 3 — Core / example boundary audit

## Scope

Recorded the boundary between **core** (`RecordHealthCheck`) and the **examples library**
(`RecordHealthCheck-Examples`) per `V2-RELEASE-PLAN.md` §3.1, §3.5 step 1, and plan
[`3-examples-repository-migration.md`](../plans/section-3-examples-repository/3-examples-repository-migration.md) §2.

State audited: branch working tree, 2026-07-13.

## Method

```text
ls force-app/main/default/classes/*Check*
ls manifest/package*.xml
rg -l "Example_Account_360" force-app manifest docs
rg -l "Account_Data_Quality|Account_Everyday_Use_Cases|Account_Examples_Apex" manifest/
```

## Findings

| Item                        | Status         | Evidence                                                                                                                                                                     | Disposition                                                                                                                                                                                                      |
| --------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hero example                | Pass           | `Example_Account_360_Health_Check` in `manifest/package-Example_Account_360_Health_Check.xml`; referenced in `README.md`, `docs/v2/start/first-10-minutes.md`, §9 smoke gate | **Stays in core**                                                                                                                                                                                                |
| Hero Apex dependency        | Pass           | `AccountHasRecentActivityCheck` in `package-core.xml`; used by `Example_Recent_Activity` rule in hero set                                                                    | **Stays in core** (ships with engine)                                                                                                                                                                            |
| Core example Apex (library) | Gap → pending  | `AccountStrategicReadinessCheck`, `ApprovalInactiveApproverCheck` are removed from `package-core.xml` (2026-07-14) but the `.cls` source still lives in `force-app/`         | **Ownership recorded as Examples** (`packs/apex-advanced-checks`); source removal from Core **deferred** to the org-verified fixture migration (BLK-9)                                                           |
| Core example Apex (shared)  | Pass           | `AccountOpenOpportunityHealthCheck` remains in core; referenced by library rules without duplicate source                                                                    | **Stays in core**; packs declare core dependency only                                                                                                                                                            |
| Sample Check Sets (library) | Gap → pending  | 14 non-hero sets + 123 rules still in `force-app/main/default/customMetadata/`; 14 non-hero manifests under `manifest/package-Account_*.xml`                                 | **Ownership recorded as Examples**; 7 Core test classes still resolve these by SOQL, so deletion is **deferred** until internal fixtures replace them and the Apex suite is re-verified in an org (BLK-9 / HI-1) |
| Test fixtures               | Pass           | `RecordHealthCheckTestDataFactory`, engine tests, validator tests — not packaged as deployable examples                                                                      | **Stay in core**                                                                                                                                                                                                 |
| Example documentation       | Gap → migrated | `docs/examples/` removed from core; content lives in `RecordHealthCheck-Examples/docs/pattern-library/`                                                                      | **Ecosystem link** replaces in-core catalog                                                                                                                                                                      |

## Hero and fixture policy (§6 decision recorded)

| Role        | Identity                                                       | Deploy path                                                                              |
| ----------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Hero**    | `Example_Account_360_Health_Check` (9 rules + report)          | `manifest/package-core.xml` then `manifest/package-Example_Account_360_Health_Check.xml` |
| **Fixture** | Engine/validator test classes and CMDT used only in Apex tests | Core only; not listed in examples catalog                                                |
| **Library** | All other sample Check Sets and pattern docs                   | `RecordHealthCheck-Examples/packs/*`                                                     |

## Verdict

**Boundary recorded, extraction incomplete.** Core may retain only the Hero example plus Apex that
the Hero requires. The release owner ended the transition on 2026-07-14: every other reusable Check
Set, Rule pattern, scenario, and optional example Apex class belongs only in the independent
`RecordHealthCheck-Examples` repository.

Core still contains duplicated library metadata, optional example Apex, and 14 non-Hero manifests.
Some Core tests depend on those public example names. V2 release now requires a fixture migration:
replace test dependencies with clearly named internal fixtures, keep those fixtures out of public
install paths, then remove the duplicated library records, classes, and manifests from Core.
