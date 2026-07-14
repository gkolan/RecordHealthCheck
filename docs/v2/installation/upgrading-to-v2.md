# Upgrading to Record Health Check V2

V2 is a breaking metadata-contract release. Test the upgrade in a sandbox or scratch org made from a current production backup before changing production.

## Before the upgrade

1. Export all `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` records and retain the deployed v1.x source or package artifact.
2. Record the current application version, permission assignments, Account record-page activation, and any Apex or Flow integrations.
3. Search custom Apex, Flow, scripts, and CI configuration for the old field names in [`field-migration-before-after.md`](../../../releases/v2/field-migration-before-after.md).
4. Back up any custom metadata values that exceed 255 characters where the V2 target field is Text.
5. Validate the change in a non-production org with the same features and permissions as production.

## Breaking contract changes

- Every field rename is listed in [`field-migration-before-after.md`](../../../releases/v2/field-migration-before-after.md). V2 does not read v1.x field API names.
- Category values use the V2 vocabulary, and Severity `Error` is now `Critical`.
- `MaxQueryRows__c` defaults to `200`, `EmptyValueHandling__c` to `AS_NO_MATCH`, and `EvaluationOrder__c` to `100`.
- Values moving from Long Text Area to Text are limited to 255 characters; review them before deployment.
- Apex identifiers using “comparator” or “scalar” were renamed to operator/single-value wording. `VALID_COMPARATORS`, `DUAL_QUERY_COMPARATORS`, and `VALID_APPLICABILITY_COMPARATORS` are now the corresponding `...OPERATORS` properties. `scalarFromRow` and `scalarList` are now `singleValueFromRow` and `singleValueList`.
- Reason code `INVALID_COMPARATOR` is now `INVALID_OPERATOR`.
- The public synchronous response contract is pre-1.0 (`0.1`) on `RecordHealthCheckResult` / `RecordHealthCheckSetResult` and grows additively. Lifecycle event contract `1.0` is opt-in and Publish After Commit. See [Programmatic API and Flow](../apex/programmatic-api.md) and [Lifecycle events](../reference/lifecycle-events.md).

## Upgrade procedure

1. Convert custom metadata source to the V2 field APIs and values before deployment. Do not deploy the destructive-change manifest until every record has been converted and validated.
2. Deploy V2 source and run all local Apex tests.
3. Run `scripts/apex/validateMetadata.apex` and resolve every invalid Rule or Check Set.
4. Assign `Record_Health_Check_User` to viewers and `Record_Health_Check_Admin` only to administrators. Assign the diagnostics-detail custom permission only where justified.
5. Open each Lightning record page containing Record Health Check. Re-select the intended Check Set if the old component placement used removed properties, then save and activate the page.
6. Verify `Example_Account_360_Health_Check` on an Account for authorized, unauthorized, diagnostics-enabled, and diagnostics-disabled paths.
7. Enable `PublishRunEvent__c` or `PublishResultEvent__c` only after reviewing event allocations and installed subscribers. Both remain false by default, and page-load evaluations never publish.

## Verification

Run the local gates and a clean-org validation:

```text
npm run prettier:verify
npm run lint
npm run check:namespaced-tokens
npm test
sf project deploy start --manifest manifest/package-core.xml --test-level RunLocalTests --target-org <validation-org> --wait 30
sf project deploy start --manifest manifest/package-Example_Account_360_Health_Check.xml --target-org <validation-org> --wait 30
sf apex run --file scripts/apex/validateMetadata.apex --target-org <validation-org>
```

Retrieve the deployed metadata into an empty directory and compare it with the release source. Review expected org-normalized XML separately from unexpected drift.

## Rollback

Rollback is a restore operation, not a dual-read mode. If a release gate fails:

1. Disable lifecycle publication switches and any V2 extensions.
2. Restore the retained v1.x source/package and the exported v1.x custom metadata records.
3. Restore the previous Lightning record-page activation and permission assignments.
4. Re-run the v1.x test and smoke suites.
5. Preserve failed V2 deployment, validation, and subscriber logs for root-cause analysis.

Do not run the V2 destructive changes in production until the backup has been restore-tested and the release owner has approved the rollback evidence.
