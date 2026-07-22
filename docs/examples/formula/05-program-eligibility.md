# 05 · Account Meets the Small-business Program Minimum

> [!NOTE]
> **On this page**
>
> Learn how to show the current employee count beside the required minimum so users know what needs to change.
>
> **Setup reference**
>
> Use the [Formula reference](reference.md) for the complete setup fields and behavior.

## Scenario

A territory planner is reviewing Accounts for a small-business program whose confirmed minimum is 10 employees.

- For each Account, the planner currently compares Number of Employees with the program minimum.
- Overlooking a low or missing value could place an ineligible Account in the program.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check shows the recorded employee count beside the program minimum, so the planner can understand the eligibility result without calculating it separately.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Compare a number with a threshold | Employee count is evaluated against the program limit. |
| Make **Found** and **Expected** meaningful | Users see the current count and required maximum. |
| Write an eligibility message | The result explains the decision without exposing formula syntax. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. Number of Employees is on the Account, and the minimum is a value the administrator enters in the Rule. |
| **Verify with a query** | Is not needed because the employee count is already stored on the Account. |
| **Verify with Apex** | Would require an Apex class without providing a better result. |

## Why not use a Validation Rule

- An Account below the program minimum is still a valid Account.

- Program eligibility should be reviewed when needed instead of blocking unrelated Account updates.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-rule.md#developer-name-developername) | `Employee_Count_Meets_Minimum` |
| **Label** | [`MasterLabel`](../../metadata/fields-rule.md#label-masterlabel) | Employee Count Meets Minimum |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-rule.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-rule.md#check-title-checktitle__c) | Employee Count Meets Minimum |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-rule.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-rule.md#pass-condition-passconditionformula__c) | `BLANKVALUE(NumberOfEmployees, 0) >= 10` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../../metadata/fields-rule.md#display-found-formula-displayfoundformula__c) | `BLANKVALUE(NumberOfEmployees, 0)` |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../../metadata/fields-rule.md#display-expected-formula-displayexpectedformula__c) | `10` |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/fields-rule.md#formula-result-type-formularesulttype__c) | Number |

This scenario uses a confirmed minimum of 10 employees. When adapting the Rule, replace `10` in the
Pass Condition and Expected Formula with the minimum approved for your program.

Keep the display formulas consistent with the Pass Condition. The engine does not compare Found to Expected; only Pass Condition decides the status. Mirror each side of the comparison: Found is the left side, Expected the right side.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-rule.md#check-description-checkdescription__c) | Compares Number of Employees with a minimum of 10 and displays both values. |
| **Category** | [`Category__c`](../../metadata/fields-rule.md#category-category__c) | Data Quality |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-rule.md#message-when-failed-failuremessage__c) | `{!record.Name}` is below the staffing minimum. Compare Found and Expected, then update Employees. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare employee count. Confirm the user can read Number of Employees. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-rule.md#fix-message-fixmessage__c) | Review Found and enter an employee count of at least 10. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-rule.md#action-label-actionlabel__c) | `Edit employee count` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-rule.md#evaluation-order-evaluationorder__c) | `80` |
| **Active** | [`IsActive__c`](../../metadata/fields-rule.md#active-isactive__c) | Checked |
| **Publish Result Event** | [`PublishResultEvent__c`](../../metadata/fields-rule.md#publish-result-event-publishresultevent__c) | Unchecked |

Query and Apex fields do not apply. Do not add **Display: Found Text** or **Display: Expected Text**;
those fields belong to Query results, while this Verify with a formula uses display formulas.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | `Account Data Quality` |
| **Card Subtitle** | Add one short sentence explaining what the card reviews. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | Every check |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish Run Event** | Unchecked |
| **Active** | Checked |

## What the user sees

The card shows one status each time the Rule runs. Supporting details appear only when they apply:

- **Needs attention:** An Account with fewer than 10 employees fails and can show Found and Expected values for the current count and minimum.

- **Pass:** Ten or more employees passes.

This Check Set uses **Every check** for **Found/Expected Display** because the employee count and
program minimum are useful during both passing and failing eligibility reviews.

- **Found and Expected:** The display formulas affect only what the card shows; they never change the pass or fail result.

- **Display fallback:** If a display formula cannot be evaluated, the card uses its standard display instead.

## Security and access

Record Health Check reads Number of Employees with the running user's Salesforce access. This field supplies both the eligibility decision and the Found value.

- If the user cannot read Number of Employees, the card may show **Unable to evaluate**. A display-formula problem does not change Pass or Needs attention; the card falls back to its standard text.

Before activation, confirm the result and Found / Expected display with the Permission Sets assigned to program planners.

## Test the Rule

1. Set Employees below 10. Confirm Warning and Found / Expected when display is configured.
2. Set Employees to 10 or more, rerun, and confirm a pass.
3. Clear both display formulas and confirm the row uses Pass Condition text only.
4. Repeat the failing test as a user without access to Number of Employees and confirm **Unable to evaluate**.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Rule runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Branch handoff](04-branch-handoff.md)
- [Browse the pattern library](../README.md)
