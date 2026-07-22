# 01 · Open Opportunities Have Contact Roles

> [!NOTE]
> **On this page**
>
> Learn how to confirm that every open Opportunity has at least one Contact Role before forecast review.
>
> **Setup reference**
>
> Use the [Compare-two-queries reference](reference.md) for the complete setup fields and behavior.

## Scenario

A seller opens an Account before forecast review.

- Every open Opportunity must identify at least one Contact Role so the team knows who is involved in the buying decision.
- A deal without a buyer, evaluator, or stakeholder leaves the forecast without customer relationship context.
- Opening every Opportunity separately makes missing Contact Roles easy to overlook.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check compares the number of open Opportunities with Contact Roles with the total number of open Opportunities. The seller sees the covered and total counts on the Account, so missing Contact Roles can be found without opening every Opportunity.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Produce two related-record counts | One query counts open Opportunities; the other counts covered Opportunities. |
| Compare coverage with demand | The Rule checks whether Contact Role coverage keeps pace with pipeline. |
| Interpret **Found** and **Expected** | Users can see both sides of the coverage decision. |

## Why use Compare two queries

| Evaluation Type | Why it fits |
| --- | --- |
| **Compare two queries** | Best fit. One query counts open Opportunities with Contact Roles. The other counts all open Opportunities. Matching counts mean every open Opportunity has a Contact Role. |
| **Verify with a query** | Verify with a query can return one count, but this check needs both counts. |
| **Verify with a formula** | An Account formula cannot review its related Opportunities and Contact Roles. |

## Why not use a Validation Rule or Report

- **Validation Rule:** Opportunity Contact Roles are child records. A Validation Rule cannot reliably require a Contact Role when an Opportunity is saved.

- **Report:** A report can find gaps across the pipeline. It does not place the answer directly on the Account being prepared for forecast review.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-rule.md#developer-name-developername) | `Open_Opportunities_Have_Contact_Roles` |
| **Label** | [`MasterLabel`](../../metadata/fields-rule.md#label-masterlabel) | Open Opportunities Have Contact Roles |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-rule.md#check-set-record_health_check_set__c) | `Account_Record_Alignment` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-rule.md#check-title-checktitle__c) | Open Opportunities Have Contact Roles |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-rule.md#evaluation-type-evaluationtype__c) | Compare two queries |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-rule.md#source-query-sourcequery__c) | `SELECT COUNT_DISTINCT(OpportunityId) coveredCount FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-rule.md#source-query-field-sourcequeryfield__c) | `coveredCount` |
| **Comparison Query** | [`ComparisonQuery__c`](../../metadata/fields-rule.md#comparison-query-comparisonquery__c) | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-rule.md#how-to-read-query-results-queryresulthandling__c) | One row or aggregate |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-rule.md#comparison-operator-comparisonoperator__c) | Equals |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-rule.md#applies-to-applicabilitymode__c) | When a count query matches |
| **Applies When (Count Query)** | [`ApplicabilityCountQuery__c`](../../metadata/fields-rule.md#applies-when-count-query-applicabilitycountquery__c) | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |

## Optional configuration

These values improve presentation. Change them for your process, or leave an optional field blank.

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-rule.md#failure-severity-failureseverity__c) | Info |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-rule.md#message-when-failed-failuremessage__c) | One or more open Opportunities have no Contact Roles. Add the appropriate stakeholders before the forecast review. |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-rule.md#check-description-checkdescription__c) | Checks that every open Opportunity has at least one Contact Role. |
| **Category** | [`Category__c`](../../metadata/fields-rule.md#category-category__c) | Buying Committee Coverage |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare the query results. Confirm the user can read every object and field named in both queries. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-rule.md#fix-message-fixmessage__c) | Review open Opportunities and add the missing Contact Roles. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-rule.md#action-label-actionlabel__c) | `Review opportunities` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-rule.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../metadata/fields-rule.md#active-isactive__c) | Checked only after confirming this example matches your business process |
| **Publish Result Event** | [`PublishResultEvent__c`](../../metadata/fields-rule.md#publish-result-event-publishresultevent__c) | Unchecked |

Comparison display text, event publishing, and prerequisite behavior are optional. Expected-value, value-to-find, Formula-result, and Apex fields do not apply to Compare two queries.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Record_Alignment` |
| **Object** | `Account` |
| **Card Title** | `Account Record Alignment` |
| **Card Subtitle** | Add one short sentence explaining what the card reviews. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish Run Event** | Unchecked |
| **Active** | Checked |

## What the user sees

The card shows one status each time the Rule runs. Supporting details appear only when they apply:

- **Pass:** Every open Opportunity has at least one Contact Role. Found and Expected show the same count.

- **Needs attention:** Found is lower than Expected. The difference is the number of open Opportunities without a Contact Role.

- **Skip:** The Account has no open Opportunities.

## Security and access

Record Health Check runs both coverage counts with the running user's Salesforce access.

- Open Opportunities and their Opportunity Contact Roles.

- Hidden Opportunities or Contact Roles can lower either side of the comparison. Equal visible counts describe the user's view, not records the user cannot access.

- Missing Opportunity or OpportunityContactRole permission can show **Unable to evaluate**.

- Compare the result for a seller and a manager whose Opportunity visibility differs.

## Test the Rule

1. Create two open Opportunities and add a Contact Role to only one. Run the check and confirm Info with Found `1` and Expected `2`.
2. Add a Contact Role to the second Opportunity, rerun, and confirm a pass.
3. Close all Opportunities and confirm the Rule is skipped.
4. Repeat the incomplete-coverage test as a user with restricted Opportunity Contact Role access and confirm the visible counts follow that user's sharing access.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Case review capacity](../query/07-high-priority-case-capacity.md) · [Next: Product continuity →](02-open-pipeline-product-continuity.md)
- [Browse the pattern library](../README.md)
