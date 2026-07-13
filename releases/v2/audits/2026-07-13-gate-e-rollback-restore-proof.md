# Gate E — rollback restore proof

## Scope

§9 Gate E release-closeout item: prove the retained v1.x artifact is restorable in a disposable
org ("Restore the retained v1.x artifact and exported metadata in a disposable org, record
success"). This audit records the **technical** restore proof; the rollback **approval** remains a
release-owner sign-off.

## Method

- **Date:** 2026-07-13. **Branch:** `v2-release` @ `bda2469`.
- **Retained artifact:** git tag `v1.2.0` (`dcf76f3`), checked out via `git worktree`.
- **Disposable org:** scratch org `rhc-v2-rollback` (`test-69kfi7njt531@example.com`), created off
  `gkSfdcDevHub`, 1-day duration.
- Salesforce CLI run **unsandboxed** with `SF_DISABLE_LOG_FILE=true SFDX_DISABLE_DNS_CHECK=true`
  (see root `CLAUDE.md` — the sandbox otherwise causes a false `ENOTFOUND`).
- Steps:
  1. `git worktree add --detach <wt> v1.2.0`; copied `force-app/` to a project-local, ignored
     staging dir (`sf` rejects source paths that resolve outside the project root).
  2. `sf project deploy start --target-org rhc-v2-rollback --source-dir .rollback-v1/force-app`.
  3. Queried `FieldDefinition` (Tooling API) for v1-only vs v2-only field API names.
  4. Removed the worktree and staging dir.

## Findings

| Item                                   | Status | Evidence                                                                                                                                                                                                               |
| -------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| v1.2.0 artifact deploys to a clean org | Pass   | `sf project deploy start` succeeded; a re-run reports `NothingToDeploy` (idempotent)                                                                                                                                   |
| Org holds the v1 schema after restore  | Pass   | `FieldDefinition` on `Record_Health_Check_Rule__mdt` returns `ApexSettingsJson__c`, `CheckName__c`, `RunOrder__c` (v1 names) and **none** of `ApexParametersJson__c`, `CheckTitle__c`, `EvaluationOrder__c` (v2 names) |
| Restore is reproducible                | Pass   | Method above is scripted from a tag; no manual metadata edits                                                                                                                                                          |

## Outstanding work

- **Rollback approval** — a release owner reviews this proof and signs off that v1.2.0 is the
  accepted rollback target. (Human; not automatable.)
- A production rollback would also restore exported CMDT **records**; this proof covers the
  metadata schema/artifact. Record data export/restore is part of the operational runbook.

## Verdict

Pass (technical). The retained v1.2.0 artifact restores cleanly to a disposable org and yields the
v1 schema, so the rollback path is proven executable. Gate E's remaining blockers are the
human rollback **approval**, PR review/approval, and the release **tag** — plus the still-uncommitted
`docs/v1`–`docs/v2` restructuring, which must land before a tag is cut.
