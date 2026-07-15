# Compare two queries example

> [!NOTE]
> **In one line**
>
> Configure a Rule that compares two independent SOQL results without writing Apex.
>
> **Reference**
>
> - This example compares two aggregate counts.
> - For single-value and list modes, operators, empty values, limits, and additional Rule options,
>   use the [Compare two queries reference](compare-two-queries-reference.md).

## Example: Balanced customer coverage

### Scenario

> An Account has balanced coverage when its Contact count equals its open Opportunity count.

### Why compare two queries

| Evaluation type | Fit |
| --- | --- |
| **Formula** | Cannot aggregate either child collection. |
| **Query** | A single-query comparison does not make both independent SOQL sources explicit. |
| **Compare two queries** | Resolves both aggregate values and compares them directly without Apex. |
| **Apex** | Adds code to a supported metadata comparison. |

### Step 1: Configure the Rule

| Setup field | API name | Value |
| --- | --- | --- |
| **Rule Developer Name** | [`DeveloperName`](../metadata/rule-fields.md#developer-name-developername) | `Balanced_Customer_Coverage` |
| **Label** | [`MasterLabel`](../metadata/rule-fields.md#label-masterlabel) | Balanced customer coverage |
| **Check Set** | [`Record_Health_Check_Set__c`](../metadata/rule-fields.md#check-set-record_health_check_set__c) | `Account_Readiness` |
| **Check Title** | [`CheckTitle__c`](../metadata/rule-fields.md#check-title-checktitle__c) | Balanced customer coverage |
| **Evaluation Type** | [`EvaluationType__c`](../metadata/rule-fields.md#evaluation-type-evaluationtype__c) | **Compare two queries** (`COMPARE_TWO_QUERIES`) |
| **Source Query** | [`SourceQuery__c`](../metadata/rule-fields.md#source-query-sourcequery__c) | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| **Comparison Query** | [`ComparisonQuery__c`](../metadata/rule-fields.md#comparison-query-comparisonquery__c) | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../metadata/rule-fields.md#how-to-read-query-results-queryresulthandling__c) | **One row or aggregate** (`ONE_RESULT`) |
| **Comparison Operator** | [`ComparisonOperator__c`](../metadata/rule-fields.md#comparison-operator-comparisonoperator__c) | **Equals** (`EQUALS`) |
### Optional configuration

These values complete the example. Change them for your business process or leave an optional field blank.

| Setup field | API name | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../metadata/rule-fields.md#check-description-checkdescription__c) | Compares Contact coverage with the open Opportunity count. |
| **Failure Severity** | [`FailureSeverity__c`](../metadata/rule-fields.md#failure-severity-failureseverity__c) | **Warning** (`WARNING`) |
| **Message When Failed** | [`FailureMessage__c`](../metadata/rule-fields.md#message-when-failed-failuremessage__c) | `{!record.Name}` has unbalanced coverage for manager `{!record.Owner.Manager.Name}`. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../metadata/rule-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to evaluate this readiness check. |
| **Applies To** | [`ApplicabilityMode__c`](../metadata/rule-fields.md#applies-to-applicabilitymode__c) | **All records** (`ALL_RECORDS`) |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../metadata/rule-fields.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../metadata/rule-fields.md#fix-message-fixmessage__c) | Review Contact and open Opportunity coverage. |
| **Action Label** | [`ActionLabel__c`](../metadata/rule-fields.md#action-label-actionlabel__c) | `Review Account` |
| **Action URL** | [`ActionUrl__c`](../metadata/rule-fields.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../metadata/rule-fields.md#evaluation-order-evaluationorder__c) | `100` |
| **Active** | [`IsActive__c`](../metadata/rule-fields.md#active-isactive__c) | Checked |
| **Found/Expected Display** (Check Set) | [`FoundExpectedDisplay__c`](../metadata/check-set.md#foundexpected-display-foundexpecteddisplay__c) | **On demand** (`ON_DEMAND`) |
| **Publish Result Event** | [`PublishResultEvent__c`](../metadata/rule-fields.md#publish-result-event-publishresultevent__c) | Unchecked |

Messages and action links can resolve current-record and parent values. See
[Merge tokens](../guides/action-links.md#merge-tokens), [Rule fields](../metadata/rule-fields.md),
and [Check Set fields](../metadata/check-set.md).

### Step 2: Test the Rule

1. Run the Rule on an Account whose Contact and open Opportunity counts differ; confirm `FAIL`.
2. Make the counts equal, rerun the Rule, and confirm `PASS`.
3. Confirm Found shows the Contact count and Expected shows the open Opportunity count.

## Related

- [Compare two queries reference](compare-two-queries-reference.md)
- [Rule fields](../metadata/rule-fields.md#5-query-sources-query--compare_two_queries)
