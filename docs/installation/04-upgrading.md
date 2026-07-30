# Upgrading Record Health Check

> [!NOTE]
> On this page, move an existing Record Health Check installation to the current contract without losing configuration, access, Lightning behavior, integrations, or a tested rollback path.

Use this guide to migrate existing Record Health Check configuration and integrations to the current release.
Because the current release renames metadata fields and other public identifiers, test the complete upgrade in a
sandbox or scratch org made from a current production backup before changing production.

## Before the upgrade

1. Export all `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` records and retain the deployed v1.x source or package artifact.
2. Record the current application version, permission assignments, Account record-page activation, and any Apex or Flow integrations.
3. Search custom Apex, Flow, scripts, and CI configuration for the old field names in the [field-migration reference](#field-migration-reference).
4. Back up any Custom Metadata values that exceed 255 characters where the current target field is Text.
5. Validate the change in a non-production org with the same features and permissions as production.

## What changes

- Every field rename is listed in the [field-migration reference](#field-migration-reference). The current release does not read v1.x field API names.
- Category values use the current list of terms, and Severity `Error` is now `Critical`.
- `MaxQueryRows__c` defaults to `200`, `EmptyValueHandling__c` to `AS_NO_MATCH`, and `EvaluationOrder__c` to `100`.
- Values moving from Long Text Area to Text are limited to 255 characters; review them before deployment.
- Apex identifiers using “comparator” or “scalar” were renamed to operator/single-value wording. `VALID_COMPARATORS`, `DUAL_QUERY_COMPARATORS`, and `VALID_APPLICABILITY_COMPARATORS` are now the corresponding `...OPERATORS` properties. `scalarFromRow` and `scalarList` are now `singleValueFromRow` and `singleValueList`.
- Reason code `INVALID_COMPARATOR` is now `INVALID_OPERATOR`.
- The public synchronous response contract is stable at `1.0` on `RecordHealthCheckResult` /
  `RecordHealthCheckSetResult` and grows additively. The independent lifecycle event contract is
  also `1.0`, is optional by default, and
  Publish After Commit. See [Apex API](../reference/reference-apex-api.md), [Flow actions](../integration/flow-actions.md), and
  [Platform events](../integration/lifecycle-events.md).

## Upgrade procedure

1. Convert Custom Metadata source to the current field APIs and values before deployment. Convert and validate every record before running the destructive-change manifest.
2. Deploy the current source and run all local Apex tests.
3. Run `scripts/apex/validateMetadata.apex` and resolve every invalid Rule or Check Set.
4. Assign `Record_Health_Check_User` to viewers and `Record_Health_Check_Admin` only to administrators. Assign the diagnostics-detail Custom Permission only where justified.
5. Open each Lightning record page containing Record Health Check. Re-select the intended Check Set if the old component placement used removed properties, then save and activate the page.
6. Verify `Example_Account_Relationship_Risk` on an Account for authorized, unauthorized, diagnostics-enabled, and diagnostics-disabled paths.
7. Enable `PublishRunEvent__c` or `PublishResultEvent__c` only after reviewing event allocations and installed subscribers. Both remain false by default, and page-load evaluations never publish. `PublishErrorLogEvent__c` defaults to true; uncheck it on a Check Set only when its automatic ERROR log events are not wanted.

## Field migration reference

Use this map while converting exported Custom Metadata. **Earlier release** contains the previous API and
Setup label; **Current release** contains the field to deploy. A field whose API name is unchanged may still have
a new label, restricted value set, size, or default.

### Before and after at a glance

These representative rows show how to read the complete tables below. The value on the left is what an exported
v1.x record contains; the value on the right is what the migrated v2 record must contain.

| Metadata type | Before (v1.x) | After (v2) |
| --- | --- | --- |
| Rule | `CheckName__c` (Check Name) | `CheckTitle__c` (Check Title) |
| Rule | `CheckMethod__c` (Check Type) | `EvaluationType__c` (Evaluation Type) |
| Rule | `PrimaryActionLabel__c` (Action Button Label) | `ActionLabel__c` (Action Label) |
| Check Set | `PanelHeading__c` (Panel Title) | `CardTitle__c` (Card Title) |
| Check Set | `ComparisonDisplay__c` (Found/Expected Display) | `FoundExpectedDisplay__c` (Found/Expected Display) |

For current descriptions, allowed values, defaults, and dependencies, use the
[Rule fields](../metadata/fields-check-rule.md) and [Check Set fields](../metadata/fields-check-set.md) references.

### Complete Rule field map

| Earlier API | Earlier label | Current API | Current Setup label | Current type |
| --- | --- | --- | --- | --- |
| `CheckName__c` | Check Name (shown to users) | `CheckTitle__c` | Check Title | Text(255) |
| `CheckMethod__c` | Check Type | `EvaluationType__c` | Evaluation Type | Picklist (4) |
| `Category__c` | Category | `Category__c` | Category | Picklist |
| `IsActive__c` | Active | `IsActive__c` | Active | Checkbox |
| `RunOrder__c` | Run Order (lower runs first) | `EvaluationOrder__c` | Evaluation Order | Number(4,0) |
| `Severity__c` | Failure Severity | `FailureSeverity__c` | Failure Severity | Picklist (3) |
| `Tooltip__c` | Description (hover tooltip) | `CheckDescription__c` | Check Description | Text(255) |
| `Record_Health_Check_Set__c` | Check Set | `Record_Health_Check_Set__c` | Check Set | Metadata Relationship |
| `RunThisCheckWhen__c` | Applies To | `ApplicabilityMode__c` | Applies To | Picklist (3) |
| `RunWhenFormula__c` | Applies When Formula Is True | `ApplicabilityFormula__c` | Applies When (Formula) | Long Text Area |
| `RunWhenCountQuery__c` | Applies When Count Query Matches | `ApplicabilityCountQuery__c` | Applies When (Count Query) | Long Text Area |
| `CountOperator__c` | Count Must Be | `ApplicabilityCountOperator__c` | Count Must Be | Picklist (6) |
| `CountThreshold__c` | Count Value | `ApplicabilityCountThreshold__c` | Count Value | Number(4,0) |
| `RequiresCheck__c` | Prerequisite Check (Developer Name) | `PrerequisiteRule__c` | Prerequisite Rule | Text(255) |
| `PassFailFormula__c` | Pass Condition (Formula) | `PassConditionFormula__c` | Pass Condition | Long Text Area |
| `DataQuery__c` | Primary Query (SOQL) | `SourceQuery__c` | Source Query | Long Text Area |
| `FieldToRead__c` | Primary Query Field/Alias | `SourceQueryField__c` | Source Query Field | Text(255) |
| `Operator__c` | Comparison Operator | `ComparisonOperator__c` | Comparison Operator | Picklist (15) |
| `WhenMultipleRows__c` | How To Interpret Query Results | `QueryResultHandling__c` | How To Read Query Results | Picklist (4) |
| `WhenValueIsEmpty__c` | If Query Field Value Is Empty | `EmptyValueHandling__c` | If Field Value Is Empty | Picklist (3) |
| `WhenZeroRows__c` | If Query Finds No Records | `NoRowsResult__c` | If Query Finds No Records | Picklist (4) |
| `MaxRows__c` | Max Rows (safety cap, max 2000) | `MaxQueryRows__c` | Max Query Rows (1-2000) | Number(4,0) |
| `ValueToTest__c` | Value To Test (list checks only) | `FindInListFormula__c` | Value to find in the list (formula) | Long Text Area |
| `CompareAgainst__c` | Expected Value Comes From | `ExpectedValueSource__c` | Expected Value Comes From | Picklist (3) |
| `FixedValue__c` | Expected Value (Fixed) | `ExpectedFixedValue__c` | Expected Value (Fixed) | Text(255) |
| `RecordFormulaValue__c` | Expected Formula (on this record) | `ExpectedRecordFormula__c` | Expected Value (Formula) | Long Text Area |
| `CompareToQuery__c` | Second Query | `ComparisonQuery__c` | Comparison Query | Long Text Area |
| `CompareToField__c` | Second Query Field/Alias | `ComparisonQueryField__c` | Comparison Query Field | Text(255) |
| `ApexClass__c` | Apex Class Name | `ApexClass__c` | Apex Class | Text(255) |
| `ApexSettingsJson__c` | Apex Settings (JSON) | `ApexParametersJson__c` | Apex Parameters (JSON) | Long Text Area |
| `ScalarFormulaReturnType__c` | Advanced: Formula Result Type | `FormulaResultType__c` | Formula Result Type | Picklist (6) |
| `MessageWhenFailed__c` | Message When Check Fails | `FailureMessage__c` | Message When Failed | Long Text Area |
| `MessageWhenCannotRun__c` | Message When Check Cannot Run | `UnableToEvaluateMessage__c` | Message When Unable To Evaluate | Long Text Area |
| `FoundValueFormula__c` | Advanced: Found Value (Formula) | `DisplayFoundFormula__c` | Display: Found Formula | Long Text Area |
| `ExpectedValueFormula__c` | Advanced: Expected Value (Formula) | `DisplayExpectedFormula__c` | Display: Expected Formula | Long Text Area |
| `FoundSummaryOverride__c` | Advanced: Found Summary (Text) | `DisplayFoundText__c` | Display: Found Text | Text(255) |
| `ExpectedSummaryOverride__c` | Advanced: Expected Summary (Text) | `DisplayExpectedText__c` | Display: Expected Text | Text(255) |
| `PrimaryActionLabel__c` | Action Button Label | `ActionLabel__c` | Action Label | Text(80) |
| `PrimaryActionUrl__c` | Action Button URL | `ActionUrl__c` | Action URL | Long Text Area |
| `FixInstructions__c` | Fix Instructions | `FixMessage__c` | Fix Message | Long Text Area |
| Not applicable | Added in the current release | `PublishResultEvent__c` | Publish Result Event | Checkbox |

### Complete Check Set field map

| Earlier API | Earlier label | Current API | Current Setup label | Current type |
| --- | --- | --- | --- | --- |
| `IsActive__c` | Active | `IsActive__c` | Active | Checkbox |
| `ObjectApiName__c` | Record Object API Name | `ObjectApiName__c` | Object | Text(80) |
| `PanelHeading__c` | Panel Title | `CardTitle__c` | Card Title | Text(255) |
| `PanelSubheading__c` | Panel Subtitle | `CardSubtitle__c` | Card Subtitle | Text(255) |
| `RunChecksWhen__c` | Start Checks | `CardRunMode__c` | When Checks Run | Picklist (2) |
| `StopOnSystemError__c` | Stop After System Error | `StopOnSystemError__c` | Stop after a system error | Checkbox |
| `RowAppearance__c` | How checks appear | `CardRevealMode__c` | Reveal Mode | Picklist (2) |
| `ComparisonDisplay__c` | Found/Expected Display | `FoundExpectedDisplay__c` | Found/Expected Display | Picklist (3) |
| `PassedChecksDisplay__c` | Passed Checks | `PassedChecksDisplay__c` | Passed Checks | Picklist (2) |
| `SkippedChecksDisplay__c` | Skipped Checks | `SkippedChecksDisplay__c` | Skipped Checks | Picklist (2) |
| `DebugMode__c` | Show Troubleshooting Details | `ShowDiagnostics__c` | Show Diagnostics | Checkbox |
| Not applicable | Added in the current release | `PublishRunEvent__c` | Publish Run Event | Checkbox |
| Not applicable | Added in the current release | `PublishErrorLogEvent__c` | Publish Error Log Event | Checkbox |

### Migration decisions that require review

- **Evaluation Type:** convert old values to `FORMULA`, `QUERY`, `COMPARE_TWO_QUERIES`, or `APEX`.
- **Category and Failure Severity:** use the current restricted values; `Error` severity becomes `CRITICAL`.
- **Text capacities:** review values moving to Text(255) or Text(80) before deployment.
- **Defaults:** explicitly review `MaxQueryRows__c = 200`, `EmptyValueHandling__c = AS_NO_MATCH`,
  and `EvaluationOrder__c = 100` instead of assuming the previous behavior.
- **Lifecycle events:** both publication fields default to unchecked. Enable them only after the
  subscriber, Platform Event allocation, replay, duplicate handling, and data access have been reviewed.
- **Error events:** `PublishErrorLogEvent__c` defaults to checked. Uncheck it to opt an individual
  Check Set out without changing Salesforce debug-log output.
- **Validation:** run `scripts/apex/validateMetadata.apex` after conversion and resolve every finding
  before destructive changes or production deployment.

## Verification

Run the local gates and a clean-org validation:

```text
npm run prettier:verify
npm run lint
npm run check:namespaced-tokens
npm test
sf project deploy start --manifest manifest/package.xml --test-level RunLocalTests --target-org <validation-org> --wait 30
sf apex run --file scripts/apex/validateMetadata.apex --target-org <validation-org>
```

Retrieve the deployed metadata into an empty directory and compare it with the release source. Review expected org-normalized XML separately from unexpected differences.

## Rollback

Rollback is a restore operation, not a dual-read mode. If a release gate fails:

1. Disable lifecycle publication switches and any newly added extensions.
2. Restore the retained v1.x source/package and the exported v1.x custom metadata records.
3. Restore the previous Lightning record-page activation and permission assignments.
4. Re-run the v1.x test and smoke suites.
5. Preserve failed deployment, validation, and subscriber logs for root-cause analysis.

Run the upgrade's destructive changes in production only after the backup has been restore-tested and the release owner has approved the rollback evidence.

## Next steps

- [Create your first Rule](03-create-your-first-rule.md): verify the upgraded installation and first Rule
- [Metadata reference](../metadata/README.md): review current field APIs and values
- [Lifecycle events](../integration/lifecycle-events.md): validate optional publication and subscribers
- [Reason Codes](../reference/reference-reason-codes.md): update downstream status handling
