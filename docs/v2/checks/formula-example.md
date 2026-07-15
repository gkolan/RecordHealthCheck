# Formula example

> [!NOTE]
> **In one line**
>
> Configure a Formula Rule that evaluates current-record and parent values without SOQL or Apex.
>
> **Reference**
>
> - This example shows the fields needed for one Formula Rule.
> - You can also configure titles, severity, messages, applicability, dependencies, display
>   behavior, action links, and event publication. See
>   [Additional Rule configuration](formula-reference.md#additional-rule-configuration).

## Example: Portfolio account readiness

### Scenario

> An Account is ready when it has a contact channel, a billing country, and revenue of at least 10%
> of its top-level portfolio Account's revenue.

### Why use a Formula Rule

| Evaluation type | Fit |
| --- | --- |
| **Formula** | All inputs are on the Account or its parent relationships; no child aggregation is required. |
| **Query** | Adds SOQL even though the required values are already reachable by formula. |
| **Apex** | Adds code without adding capability for this decision. |

### Step 1: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API name | Value |
| --- | --- | --- |
| **Rule Developer Name** | [`DeveloperName`](../metadata/rule-fields.md#developer-name-developername) | `Portfolio_Account_Readiness` |
| **Label** | [`MasterLabel`](../metadata/rule-fields.md#label-masterlabel) | Portfolio account readiness |
| **Check Set** | [`Record_Health_Check_Set__c`](../metadata/rule-fields.md#check-set-record_health_check_set__c) | `Account_Readiness` |
| **Check Title** | [`CheckTitle__c`](../metadata/rule-fields.md#check-title-checktitle__c) | Portfolio account readiness |
| **Evaluation Type** | [`EvaluationType__c`](../metadata/rule-fields.md#evaluation-type-evaluationtype__c) | **Formula** (`FORMULA`) |
| **Pass Condition** | [`PassConditionFormula__c`](../metadata/rule-fields.md#pass-condition-passconditionformula__c) | <pre class="table-code"><code>AND(&#10;  OR(&#10;    NOT(ISBLANK(Phone)),&#10;    NOT(ISBLANK(Website))&#10;  ),&#10;  NOT(ISBLANK(BillingCountry)),&#10;  AnnualRevenue >= Parent.Parent.AnnualRevenue * 0.10&#10;)</code></pre> |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../metadata/rule-fields.md#display-found-formula-displayfoundformula__c) | `AnnualRevenue` |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../metadata/rule-fields.md#display-expected-formula-displayexpectedformula__c) | `Parent.Parent.AnnualRevenue * 0.10` |
| **Formula Result Type** | [`FormulaResultType__c`](../metadata/rule-fields.md#formula-result-type-formularesulttype__c) | **Number** (`NUMBER`) |
### Optional configuration

These values complete the example. Change them for your business process or leave an optional field blank.

| Setup field | API name | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../metadata/rule-fields.md#check-description-checkdescription__c) | Checks contact details, billing country, and portfolio-relative revenue. |
| **Failure Severity** | [`FailureSeverity__c`](../metadata/rule-fields.md#failure-severity-failureseverity__c) | **Warning** (`WARNING`) |
| **Message When Failed** | [`FailureMessage__c`](../metadata/rule-fields.md#message-when-failed-failuremessage__c) | `{!record.Name}` is below the readiness target for `{!record.Parent.Parent.Name}`. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../metadata/rule-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to evaluate this readiness check. |
| **Applies To** | [`ApplicabilityMode__c`](../metadata/rule-fields.md#applies-to-applicabilitymode__c) | **All records** (`ALL_RECORDS`) |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../metadata/rule-fields.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../metadata/rule-fields.md#fix-message-fixmessage__c) | Review the Account fields and portfolio revenue target. |
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

1. Add **Record Health Check** to an Account record page and select the Rule's active Check Set.
2. Open an Account with two populated parent levels.
3. Click **Run** or **Rerun**.
4. Confirm **Found** is the Account revenue, **Expected** is 10% of the top-level Account revenue,
   and status is `PASS` only when every condition is true.

## Related

- [Formula reference](formula-reference.md)
- [Rule fields](../metadata/rule-fields.md#4-check-fields-on-this-record-formula)
