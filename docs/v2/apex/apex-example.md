# Apex example

> [!NOTE]
> **In one line**
>
> Configure an Apex Rule and implement its class using one end-to-end example.
>
> **Reference**
>
> - This example covers Setup values, inputs, code, results, security, and testing.
> - For the interface contract, relationship queries, parameter parsing, compatibility, and
>   evaluator behavior, use the [Apex reference](apex-reference.md).

## Example: Account pipeline readiness

### Scenario

An account manager opens an Account before a weekly pipeline review.

> An Account is ready for pipeline review when it has at least two open Opportunities and at least
> $100,000 in total open Opportunity Amount.

The Rule passes only when both targets are met. If either target is missed, the card calls attention
to the Account without blocking save.

### What the card shows

| Card value | Shows |
| --- | --- |
| **Status** | `PASS` when both targets are met; otherwise `FAIL` |
| **Found** | Current Opportunity count and pipeline total |
| **Expected** | Both readiness targets |

### Why use Apex

| Evaluation type | Fit for this scenario |
| --- | --- |
| **Formula** | A record formula cannot aggregate the Account's child Opportunities. |
| **Query** | A Query Rule compares one resolved query value; this check must evaluate the Opportunity count and pipeline total together. |
| **Apex** | One class can calculate both aggregates, apply two configurable thresholds, and return one combined Found value. |

### What Record Health Check passes to Apex

| Input in Apex | Where it comes from |
| --- | --- |
| `context.recordId` | The Account being evaluated at runtime |
| `context.parameters` | **Apex Parameters (JSON)** (`ApexParametersJson__c`) on the `Record_Health_Check_Rule__mdt` record |

You do not put the record ID in the parameter JSON. Record Health Check supplies it automatically:

- On a Lightning record page, `context.recordId` is the ID of the open record.
- From Apex, it is the `recordId` passed to `RecordHealthCheck.runRule` or `runSet`.
- From Flow, it is the value supplied to the action's **Record ID** input.

Inside the plugin, use `context.recordId` as a bind variable so the query evaluates the intended
record:

```apex
Id accountId = context.recordId;
```

### Step 1: Understand the parameters

Use Rule parameters to update the pass criteria without changing the Apex class. This Rule uses the
following JSON parameter object:

```json
{
  "minimumOpenOpportunities": 2,
  "minimumPipeline": 100000
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on
   `Record_Health_Check_Rule__mdt`.

Record Health Check parses this JSON automatically and passes it to the class as
`context.parameters`, a map of parameter name to value. The class also defines the same values as
defaults, so blank JSON remains safe. One JSON object can contain multiple named parameters; see
[Parameter parsing patterns](apex-reference.md#4-apex-parameters-json-apexparametersjson__c) for
validation and type-conversion guidance.

### Step 2: Create the Apex class

```apex
/**
 * Checks whether an Account has enough open Opportunities and pipeline.
 * Administrators can override both thresholds with Apex Parameters (JSON).
 */
public with sharing class AccountPipelineReadinessCheck
  implements RecordHealthCheckRule {
  public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
    // Record Health Check supplies the Account ID; it is not a JSON parameter.
    Id accountId = context.recordId;

    // Safe defaults apply when Apex Parameters (JSON) is blank or omits a key.
    Integer minimumOpenOpportunities = 2;
    Decimal minimumPipeline = 100000;

    // Override each default only when the administrator supplied that parameter.
    if (context.parameters.containsKey('minimumOpenOpportunities')) {
      minimumOpenOpportunities = Integer.valueOf(
        String.valueOf(context.parameters.get('minimumOpenOpportunities'))
      );
    }
    if (context.parameters.containsKey('minimumPipeline')) {
      minimumPipeline = Decimal.valueOf(
        String.valueOf(context.parameters.get('minimumPipeline'))
      );
    }

    // Read only records and fields available to the running user.
    // accountId is the Account being evaluated.
    AggregateResult metrics = [
      SELECT COUNT(Id) openCount, SUM(Amount) pipeline
      FROM Opportunity
      WHERE AccountId = :accountId AND IsClosed = FALSE
      WITH USER_MODE
    ];

    // Aggregate SUM returns null when no matching Opportunity has an Amount.
    Integer openCount = (Integer) metrics.get('openCount');
    Decimal pipeline = (Decimal) metrics.get('pipeline');
    if (pipeline == null) pipeline = 0;

    // Both configured requirements must be met for the Rule to pass.
    Boolean meetsRequirements = openCount >= minimumOpenOpportunities &&
      pipeline >= minimumPipeline;

    // Every determinate plugin result must return a status plus Found and Expected.
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = meetsRequirements ? 'PASS' : 'FAIL';
    result.actualValue = openCount + ' open; ' + pipeline + ' pipeline';
    result.expectedValue = 'At least ' + minimumOpenOpportunities +
      ' open; at least ' + minimumPipeline + ' pipeline';
    return result;
  }
}
```

### Step 3: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create or edit the
Rule record and set:

| Setup field | API name | Value |
| --- | --- | --- |
| **Rule Developer Name** | [`DeveloperName`](../metadata/rule-fields.md#developer-name-developername) | `Account_Pipeline_Readiness` |
| **Label** | [`MasterLabel`](../metadata/rule-fields.md#label-masterlabel) | Account pipeline readiness |
| **Check Set** | [`Record_Health_Check_Set__c`](../metadata/rule-fields.md#check-set-record_health_check_set__c) | `Account_Readiness` |
| **Check Title** | [`CheckTitle__c`](../metadata/rule-fields.md#check-title-checktitle__c) | Account pipeline readiness |
| **Evaluation Type** | [`EvaluationType__c`](../metadata/rule-fields.md#evaluation-type-evaluationtype__c) | **Apex** (`APEX`) |
| **Apex Class** | [`ApexClass__c`](../metadata/rule-fields.md#apex-class-apexclass__c) | `AccountPipelineReadinessCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../metadata/rule-fields.md#apex-parameters-json-apexparametersjson__c) | [Step 1 parameter object](#step-1-understand-the-parameters): `{"minimumOpenOpportunities": 2, "minimumPipeline": 100000}` |
### Optional configuration

These values complete the example. Change them for your business process or leave an optional field blank.

| Setup field | API name | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../metadata/rule-fields.md#check-description-checkdescription__c) | Checks open Opportunity count and pipeline against configurable targets. |
| **Failure Severity** | [`FailureSeverity__c`](../metadata/rule-fields.md#failure-severity-failureseverity__c) | **Warning** (`WARNING`) |
| **Message When Failed** | [`FailureMessage__c`](../metadata/rule-fields.md#message-when-failed-failuremessage__c) | `{!record.Name}` is not ready for the pipeline review owned by `{!record.Owner.Name}`. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../metadata/rule-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to evaluate this readiness check. |
| **Applies To** | [`ApplicabilityMode__c`](../metadata/rule-fields.md#applies-to-applicabilitymode__c) | **All records** (`ALL_RECORDS`) |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../metadata/rule-fields.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../metadata/rule-fields.md#fix-message-fixmessage__c) | Review open Opportunities and pipeline amount. |
| **Action Label** | [`ActionLabel__c`](../metadata/rule-fields.md#action-label-actionlabel__c) | `Review Account` |
| **Action URL** | [`ActionUrl__c`](../metadata/rule-fields.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../metadata/rule-fields.md#evaluation-order-evaluationorder__c) | `100` |
| **Active** | [`IsActive__c`](../metadata/rule-fields.md#active-isactive__c) | Checked |
| **Found/Expected Display** (Check Set) | [`FoundExpectedDisplay__c`](../metadata/check-set.md#foundexpected-display-foundexpecteddisplay__c) | **On demand** (`ON_DEMAND`) |
| **Publish Result Event** | [`PublishResultEvent__c`](../metadata/rule-fields.md#publish-result-event-publishresultevent__c) | Unchecked |

Messages and action links can resolve current-record and parent values. See
[Merge tokens](../guides/action-links.md#merge-tokens), [Rule fields](../metadata/rule-fields.md),
and [Check Set fields](../metadata/check-set.md).

### Step 4: Test the Rule

#### Option 1: Execute Anonymous

Run this from **Developer Console → Debug → Open Execute Anonymous Window**.

```apex
// Replace this placeholder with the 15- or 18-character ID of an Account you can access.
// Account IDs begin with 001.
Id accountId = '001XXXXXXXXXXXXXXX';

// Use the Rule record's Developer Name from Step 3.
RecordHealthCheckResult result = RecordHealthCheck.runRule(
  'Account_Pipeline_Readiness',
  accountId
);

// Review status, Found, Expected, message, and any reason code in the debug log.
System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
```

Confirm that `status`, `actualValue`, and `expectedValue` match the selected Account's open
Opportunity data.

#### Option 2: Lightning component

1. Add **Record Health Check** to the Account Lightning record page in Lightning App Builder.
2. Select the active Check Set that contains `Account_Pipeline_Readiness`.
3. Save and activate the page, then open an Account.
4. Click **Run** or **Rerun** and confirm the row shows the same Found, Expected, and status values.

For component permissions and run modes, see
[Lightning component runs](../lwc/runs-and-events.md#prerequisites-and-quick-start).

## Context (`RecordHealthCheckContext`)

| Field | Type | What it holds |
| ----- | ---- | ------------- |
| `recordId` | `Id` | Record on the Lightning page: **use this in SOQL** |
| `objectApiName` | `String` | API name (for example `Account`) |
| `record` | `SObject` | **Partial** record; see [Apex reference](apex-reference.md#2-reading-fields-on-the-current-record) |
| `parameters` | `Map<String, Object>` | Parsed **Apex Parameters (JSON)**; empty map when blank |
| `ruleDeveloperName` | `String` | Rule `DeveloperName` being evaluated |

## Result (`RecordHealthCheckResult`)

| Field | Plugin sets | Notes |
| --- | --- | --- |
| `status` | Yes | Use `PASS` or `FAIL` for a completed check. |
| `actualValue` | Required for `PASS` / `FAIL` | **Found:** what the plugin observed. A blank value is rejected with `APEX_EVALUATOR_ERROR`. |
| `expectedValue` | Required for `PASS` / `FAIL` | **Expected:** what the Rule required. A blank value is rejected with `APEX_EVALUATOR_ERROR`. |
| `actualValueSource` | Optional | Diagnostic origin for Found; shown as `actualValueDetail` only in authorized browser diagnostics. |
| `expectedValueSource` | Optional | Diagnostic origin for Expected; shown as `expectedValueDetail` only in authorized browser diagnostics. |
| `message` | Optional | On `FAIL`, a non-blank value overrides the Rule's configured failure message. |

The diagnostic source fields never appear on the card. See
[Show Diagnostics](../guides/show-diagnostics.md#what-you-see-in-the-browser-console) for the
conditions that reveal them.

Evaluator sets `label`, `severity`, `durationMs`, etc. Details: [Apex reference](apex-reference.md#6-returning-recordhealthcheckresult).

## Security

- **Query with `WITH USER_MODE`.** This enforces the running user's object, field, record-sharing, and
  restriction-rule access. Without it, the plugin can read data the user is not permitted to see
  and expose that data through the health-check result or diagnostics.
- **Declare the plugin `public with sharing`.** This makes record-level sharing behavior explicit.
  Omitting a sharing declaration makes behavior depend on the calling context; using `without
  sharing` can evaluate records outside the user's sharing access.
- **Keep evaluation side-effect free.** A Rule may run more than once, so performing DML or callouts
  inside `evaluate` can repeat changes, slow the card, or return `APEX_EVALUATOR_ERROR` when the
  operation fails.
  - For an immediate action, call Record Health Check from Apex or Flow, inspect the result, and
    perform the action outside the plugin.
  - For decoupled notifications, analytics, or integrations, use
    [lifecycle platform events](../reference/lifecycle-events.md). Review their delivery and data
    constraints before enabling a subscriber.

## Failures and remedies

| Result | What to investigate |
| --- | --- |
| `APEX_CLASS_NOT_FOUND` | Compare `ApexClass__c` with the deployed class name. For managed code, verify whether the resolvable name requires a namespace. Also confirm that the class implements `RecordHealthCheckRule`. |
| `APEX_EVALUATOR_ERROR` | Use [Show Diagnostics](../guides/show-diagnostics.md) to inspect the authorized browser-console detail. It distinguishes an exception from an invalid status or missing Found/Expected value. |

## Related

- [Apex reference](apex-reference.md)
- [Examples index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md)
- [Configuration guide: Apex Rules](../guides/configuration-guide.md#9-apex-rules)
- [Reason codes](../reference/reason-codes.md)
- [V2 documentation standard](../api-documentation-standard.md)
