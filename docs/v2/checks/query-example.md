# Query example

> [!NOTE]
> **In one line**
>
> Configure a Query Rule that compares one SOQL result with a required value.
>
> **Reference**
>
> - This example shows one aggregate Query Rule.
> - For row modes, operators, empty values, limits, and additional Rule options, use the
>   [Query reference](query-reference.md).

## Example: Account has a Contact

### Scenario

> An Account is ready for outreach when it has at least one Contact.

### Why use a Query Rule

| Evaluation type | Fit |
| --- | --- |
| **Formula** | A record formula cannot count child Contacts. |
| **Query** | One aggregate SOQL value is compared with one fixed threshold. |
| **Apex** | Adds code to a comparison already supported by Query Rules. |

### Step 1: Configure the Rule

| Setup field | API name | Value |
| --- | --- | --- |
| **Rule Developer Name** | [`DeveloperName`](../metadata/rule-fields.md#developer-name-developername) | `Account_Has_Contact` |
| **Label** | [`MasterLabel`](../metadata/rule-fields.md#label-masterlabel) | Account has a Contact |
| **Check Set** | [`Record_Health_Check_Set__c`](../metadata/rule-fields.md#check-set-record_health_check_set__c) | `Account_Readiness` |
| **Check Title** | [`CheckTitle__c`](../metadata/rule-fields.md#check-title-checktitle__c) | Account has a Contact |
| **Evaluation Type** | [`EvaluationType__c`](../metadata/rule-fields.md#evaluation-type-evaluationtype__c) | **Query** (`QUERY`) |
| **Source Query** | [`SourceQuery__c`](../metadata/rule-fields.md#source-query-sourcequery__c) | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../metadata/rule-fields.md#how-to-read-query-results-queryresulthandling__c) | **One row or aggregate** (`ONE_RESULT`) |
| **Comparison Operator** | [`ComparisonOperator__c`](../metadata/rule-fields.md#comparison-operator-comparisonoperator__c) | **Greater than or equal** (`GREATER_THAN_OR_EQUAL`) |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../metadata/rule-fields.md#expected-value-comes-from-expectedvaluesource__c) | **Fixed value** (`FIXED_VALUE`) |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../metadata/rule-fields.md#expected-value-fixed-expectedfixedvalue__c) | `1` |

### Optional configuration

These values complete the example. Change them for your business process or leave an optional field blank.

| Setup field | API name | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../metadata/rule-fields.md#check-description-checkdescription__c) | Checks whether the Account has at least one Contact. |
| **Failure Severity** | [`FailureSeverity__c`](../metadata/rule-fields.md#failure-severity-failureseverity__c) | **Warning** (`WARNING`) |
| **Message When Failed** | [`FailureMessage__c`](../metadata/rule-fields.md#message-when-failed-failuremessage__c) | `{!record.Name}` has no Contact for owner `{!record.Owner.Name}`. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../metadata/rule-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to evaluate this readiness check. |
| **Applies To** | [`ApplicabilityMode__c`](../metadata/rule-fields.md#applies-to-applicabilitymode__c) | **All records** (`ALL_RECORDS`) |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../metadata/rule-fields.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../metadata/rule-fields.md#fix-message-fixmessage__c) | Add a Contact before outreach begins. |
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

1. Run the Rule on an Account without Contacts and confirm `FAIL`, Found `0`, Expected `1`.
2. Add a Contact, rerun the Rule, and confirm `PASS`, Found `1`, Expected `1`.

## Related

- [Query reference](query-reference.md)
- [Rule fields](../metadata/rule-fields.md#5-query-sources-query--compare_two_queries)
