# 03 · Strategic Account Is Ready

> [!NOTE]
> On this page, build a weighted Apex readiness score that combines four Strategic Account signals, explains the gaps, and lets an administrator control the passing threshold through Custom Metadata.
>
> **Setup reference**
>
> Use the [Apex reference](../../reference/reference-apex.md) for the complete setup fields and behavior.

## Scenario

An account director preparing a Strategic Account for an executive review currently completes four
separate reviews:

- Customer relationships.
- Open pipeline.
- Recent follow-up.
- Billing address.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check combines the four reviews into one score and points the director to the areas
> that still need attention.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Build a weighted readiness score | Apex combines several Account signals into one score. |
| Keep thresholds configurable | Apex Parameters (JSON) lets an admin tune the decision. |
| Explain a calculated outcome | The result shows the score, target, and missing readiness criteria. |

## Readiness criteria

### What contributes to readiness

| Criterion | Passes when |
| --- | --- |
| Contacts | At least one related Contact exists |
| Open pipeline | Sum of open Opportunity `Amount` is greater than zero |
| Recent activity | At least one completed Task or Event exists inside `activityDaysBack` |
| Billing complete | `BillingStreet`, `BillingCity`, and `BillingCountry` are all populated |

### How the result is decided

- **Pass:** The score meets or exceeds `minScore`.
- **Fail:** The score is below `minScore`.
- **Skip:** Account Type is not Strategic, so the scoring class does not run.

### Choose how your team measures readiness

The included configuration uses:

- **25 points** for each of the four criteria.
- **80 points** as the minimum passing score.
- **60 days** for recent activity.
- **80 points** and **30 days** when the parameter JSON is missing or invalid.

The possible scores are 0, 25, 50, 75, and 100. A minimum of 80 therefore requires all four
criteria and is effectively the same as a minimum of 100.

Before activation, choose the policy that matches your process:

- If one missing area is acceptable, change `minScore` to **75**.
- If every area is required and one combined result is preferred, keep `minScore` at **80**.
- If every area is required and users should see a separate result for each one, create four Rules
  instead of using a score.

## What the card shows

| Card value | Meets minimum | Below minimum | Not Strategic |
| --- | --- | --- | --- |
| **Status** | `PASS` | `FAIL` | `SKIP` |
| **Found** | Score plus the readiness items met | Score plus the readiness items met | Not applicable |
| **Expected** | Minimum plus any items still missing | Minimum plus the items to improve | Not applicable |
| **Message** | None | Configured Critical message | Applicability explains skip |

## Why use Verify with Apex

| Approach | What the user gets |
| --- | --- |
| **One Verify with Apex** | One readiness result with a score out of 100, the criteria met, and the criteria that still need attention. An administrator can change the passing score in **Apex Parameters (JSON)**. |
| **Four separate Query or Rules that use Verify with a formula** | Four pass-or-fail results, one for Contacts, pipeline, activity, and billing. Use this approach when every area is required or should remain visible on its own. |
| **Rules with prerequisites** | Checks can run in a required order, but their results are not added into one score. Use prerequisites when a later check should wait for an earlier check to pass. |

## What Record Health Check passes to Apex

| Input in Apex | Where it comes from |
| --- | --- |
| `context.recordId` | The Account being evaluated at run time |
| `context.parameters` | **Apex Parameters (JSON)** (`ApexParametersJson__c`) on the `Record_Health_Check_Rule__mdt` record |

Do not put the Account ID in the parameter JSON. Record Health Check supplies it automatically:

- On a Lightning record page, `context.recordId` is the ID of the open record.
- From Apex, it is the `recordId` passed to `RecordHealthCheck.runRule` or `RecordHealthCheck.runSet`.
- From Flow, it is the value supplied to the action's **Record ID** input.

Use the supplied ID as a SOQL bind variable:

```apex
Id accountId = context.recordId;
```

The complete class below passes `context.recordId` to its Account, Contact, Opportunity, Task, and
Event query methods.

## Step 1: Understand the parameters

Use Rule parameters to change the passing score and activity window without editing the class:

```json
{
  "minScore": 80,
  "activityDaysBack": 60
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON and supplies both named values in `context.parameters`.
`minScore` accepts `1`–`100`, and `activityDaysBack` accepts `1`–`3650`; missing or invalid values
use 80 and 30. See
[Parameter parsing patterns](../../reference/reference-apex.md#4-apex-parameters-json-apexparametersjson__c)
for validation and type-conversion guidance.

## Implementation summary

The class queries the
three Account billing fields, counts visible Contacts, sums visible open Opportunity Amount, and
counts visible completed Tasks plus Events inside the window. Each true criterion adds 25 points.
It returns `PASS` when `score >= minScore`. Found shows the score and the items that earned points;
Expected shows the minimum and the items that still need attention.

Applicability evaluates `ISPICKVAL(Type, "Strategic")` before Apex runs. An open Opportunity with
blank Amount earns no pipeline points; any missing billing component loses all billing points; one
Contact or one qualifying activity is sufficient for its respective criterion.

## Step 2: Create the Apex class

This is the complete class deployed by the pack. Comments explain the Record Health Check inputs, administrator settings, user access, pass logic, and returned values.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example RecordHealthCheckRule that calculates one readiness score for
 * Strategic Accounts. This class, its test, and its Rule metadata are included
 * in packs/apex-advanced-checks/manifest/package.xml. Install Record Health
 * Check first, and then deploy that pack manifest.
 * Apex Parameters (JSON): {"minScore": 80, "activityDaysBack": 60}
 */
public with sharing class AccountStrategicReadinessCheck implements RecordHealthCheckRule {
  private static final Integer DEFAULT_MIN_SCORE = 80;
  private static final Integer DEFAULT_ACTIVITY_DAYS = 30;
  private static final Integer MIN_SCORE = 1;
  private static final Integer MAX_SCORE = 100;
  private static final Integer MIN_ACTIVITY_DAYS = 1;
  private static final Integer MAX_ACTIVITY_DAYS = 3650;
  private static final Integer POINTS_PER_CRITERION = 25;

  public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
    // Record Health Check supplies the Account ID. Administrators control only
    // the minimum score and activity window through Apex Parameters (JSON).
    // Invalid values use the documented defaults instead of stopping the Rule.
    Integer minScore = resolveInt(
      context.parameters,
      'minScore',
      DEFAULT_MIN_SCORE,
      MIN_SCORE,
      MAX_SCORE
    );
    Integer activityDays = resolveInt(
      context.parameters,
      'activityDaysBack',
      DEFAULT_ACTIVITY_DAYS,
      MIN_ACTIVITY_DAYS,
      MAX_ACTIVITY_DAYS
    );

    // Read the billing fields with the running user's Salesforce access.
    Account acct = [
      SELECT BillingStreet, BillingCity, BillingCountry
      FROM Account
      WHERE Id = :context.recordId
      WITH USER_MODE
    ];

    // Each business requirement is worth 25 points. Keep the names of met and
    // missing requirements so Found and Expected help users diagnose the score.
    Integer score = 0;
    List<String> metCriteria = new List<String>();
    List<String> missingCriteria = new List<String>();
    if (hasContacts(context.recordId)) {
      score += POINTS_PER_CRITERION;
      metCriteria.add('Contact');
    } else {
      missingCriteria.add('Contact');
    }
    if (hasOpenPipeline(context.recordId)) {
      score += POINTS_PER_CRITERION;
      metCriteria.add('open pipeline');
    } else {
      missingCriteria.add('open pipeline');
    }
    if (hasRecentActivity(context.recordId, activityDays)) {
      score += POINTS_PER_CRITERION;
      metCriteria.add('recent activity');
    } else {
      missingCriteria.add('recent activity');
    }
    if (billingComplete(acct)) {
      score += POINTS_PER_CRITERION;
      metCriteria.add('billing address');
    } else {
      missingCriteria.add('billing address');
    }

    RecordHealthCheckResult result = new RecordHealthCheckResult();
    // The Rule passes when the score meets the administrator's selected minimum.
    result.status = score >= minScore ? 'PASS' : 'FAIL';
    // Return useful Found and Expected values on both pass and fail. The Check
    // Set controls whether users see them immediately or open them on demand.
    result.actualValue =
      score +
      '/100; met: ' +
      (metCriteria.isEmpty() ? 'none' : String.join(metCriteria, ', '));
    result.expectedValue =
      minScore +
      '+; improve: ' +
      (missingCriteria.isEmpty()
        ? 'all criteria met'
        : String.join(missingCriteria, ', '));
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      'Strategic readiness score',
      String.valueOf(score),
      'sum of met criteria'
    );
    result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
      'Minimum required score',
      String.valueOf(minScore),
      null
    );
    return result;
  }

  private static Boolean hasContacts(Id accountId) {
    // A visible Contact earns the Contact-coverage points.
    return [
        SELECT COUNT()
        FROM Contact
        WHERE AccountId = :accountId
        WITH USER_MODE
      ] > 0;
  }

  private static Boolean hasOpenPipeline(Id accountId) {
    // SUM can be null when no visible open Opportunity has Amount. Null or zero
    // does not earn pipeline points.
    AggregateResult ar = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE AccountId = :accountId AND IsClosed = FALSE
      WITH USER_MODE
    ];
    Decimal total = (Decimal) ar.get('total');
    return total != null && total > 0;
  }

  private static Boolean hasRecentActivity(Id accountId, Integer daysBack) {
    // A completed Task or an Event inside the selected window earns the recent
    // activity points. Both queries respect the running user's access.
    Date cutoff = Date.today().addDays(-daysBack);
    Integer tasks = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId = :accountId AND IsClosed = TRUE AND ActivityDate >= :cutoff
      WITH USER_MODE
    ];
    Integer events = [
      SELECT COUNT()
      FROM Event
      WHERE WhatId = :accountId AND ActivityDate >= :cutoff
      WITH USER_MODE
    ];
    return tasks + events > 0;
  }

  private static Boolean billingComplete(Account acct) {
    // All three billing fields are required to earn the address points.
    return String.isNotBlank(acct.BillingStreet) &&
      String.isNotBlank(acct.BillingCity) &&
      String.isNotBlank(acct.BillingCountry);
  }

  private static Integer resolveInt(
    Map<String, Object> parameters,
    String key,
    Integer defaultValue,
    Integer min,
    Integer max
  ) {
    // Blank, nonnumeric, and out-of-range JSON values use the documented default.
    if (parameters == null) {
      return defaultValue;
    }
    Object raw = parameters.get(key);
    if (raw == null) {
      return defaultValue;
    }
    try {
      Integer parsed = Integer.valueOf(String.valueOf(raw));
      return parsed >= min && parsed <= max ? parsed : defaultValue;
    } catch (Exception ex) {
      return defaultValue;
    }
  }
}
```

<!-- END GENERATED APEX CLASS -->

## Context and result contract

Record Health Check calls:

```apex
RecordHealthCheckResult evaluate(RecordHealthCheckContext context)
```

The context contains:

| Context field | Type | What it contains |
| --- | --- | --- |
| `recordId` | `Id` | Record being evaluated; use this value in SOQL |
| `objectApiName` | `String` | API name of the evaluated object, such as `Account` |
| `record` | `SObject` | Partial current record; do not assume every field was loaded |
| `parameters` | `Map<String, Object>` | Parsed **Apex Parameters (JSON)**; an empty map when JSON is blank |
| `ruleDeveloperName` | `String` | Developer Name of the Rule being evaluated |

For a completed check, the class must return all three required values:

| Result field | What the class must return |
| --- | --- |
| `status` | `PASS` or `FAIL` |
| `actualValue` | Nonblank **Found** value describing what the class observed |
| `expectedValue` | Nonblank **Expected** value describing the passing requirement |
| `message` | Optional; on `FAIL`, a nonblank class message replaces **Message When Failed** from the Rule |
| `actualValueSource` / `expectedValueSource` | Optional diagnostic detail; never displayed as the card's Found or Expected value |

Do not return `SKIP` from the class to represent applicability; configure **Applies To** on the
Rule so Record Health Check skips before Apex runs. The framework supplies the label, severity,
duration, and other card details. An invalid status, blank Found value, blank Expected value, or
unhandled exception produces `APEX_EVALUATOR_ERROR`, not a pass. See
[Returning `RecordHealthCheckResult`](../../reference/reference-apex.md#6-returning-recordhealthcheckresult).


## Step 3: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-rule.md#developer-name-developername) | `Strategic_Account_Is_Ready` |
| **Label** | [`MasterLabel`](../../metadata/fields-rule.md#label-masterlabel) | Strategic Account Is Ready |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-rule.md#check-title-checktitle__c) | Strategic Account Is Ready |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/fields-rule.md#apex-class-apexclass__c) | `AccountStrategicReadinessCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/fields-rule.md#apex-parameters-json-apexparametersjson__c) | `{"minScore": 80, "activityDaysBack": 60}` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-rule.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../metadata/fields-rule.md#applies-when-formula-applicabilityformula__c) | `ISPICKVAL(Type, "Strategic")` |

Confirm the `Strategic` Type picklist API value in your org. Skip comes from applicability: the class always returns PASS or FAIL when it runs.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-rule.md#check-description-checkdescription__c) | Scores Contact coverage, open pipeline, recent activity, and billing-address completeness for Strategic Accounts. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-rule.md#message-when-failed-failuremessage__c) | This strategic account is not ready: readiness score is below the required minimum. Improve the readiness checks or lower `minScore` in Apex Parameters (JSON). |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to calculate strategic readiness. Confirm the running user can read the Account and related records used by this Rule. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-rule.md#fix-message-fixmessage__c) | Review the missing readiness items shown in Found: Contact, open pipeline, recent activity, or billing address. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-rule.md#action-label-actionlabel__c) | Leave blank: one portable link cannot correct all four readiness areas. |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-rule.md#action-url-actionurl__c) | Leave blank; use an org-specific readiness report or playbook only after verifying it. |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-rule.md#evaluation-order-evaluationorder__c) | `30` |
| **Active** | [`IsActive__c`](../../metadata/fields-rule.md#active-isactive__c) | Checked |
| **Publish Result Event** | [`PublishResultEvent__c`](../../metadata/fields-rule.md#publish-result-event-publishresultevent__c) | Unchecked |

`minScore` and `activityDaysBack` change the passing score and activity window without changing the class.

The applicability fields in **Configure the Rule** are required for the documented skip behavior.
The pack supplies description, failure settings, applicability, order, and Active. The remaining
rows document recommended choices. Do not add an Account view link merely to fill the action fields;
it does not help a user understand which readiness item is missing.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Apex_Readiness` |
| **Object** | `Account` |
| **Card Title** | `Account Readiness` |
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

The Apex class turns the weighted score and configured threshold into these user-facing values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A Strategic Account at or above `minScore` passes. |
| **`FAIL`** | A score below `minScore` shows Needs attention with Critical severity. |
| **`SKIPPED`** | A non-Strategic Account is skipped by Formula applicability before the Apex class runs. |
| **Found** | Found shows the score and criteria met, such as `75/100; met: Contact, open pipeline, billing address`. |
| **Expected** | Expected shows the passing threshold and gaps, such as `80+; improve: recent activity`. |

Scores move in 25-point increments, so a minimum of 80 effectively requires 100. Use 75 when
meeting three of the four criteria should pass.

## Security and access

The readiness score follows the running user's Salesforce access.

- Account billing fields plus visible Contacts, open Opportunities, Tasks, and Events.

- A user who cannot see a qualifying related record may receive a lower score than an administrator for the same Account.

- A lower user-mode score is not proof that the related record does not exist. Do not remove `WITH USER_MODE` to force equal scores.

- The class reads data only and performs no DML or callouts.

- Compare the score for the intended user and an administrator, then confirm the difference matches the approved sharing model.

## Step 4: Test the Rule

1. Set Type to Strategic on an Account with no Contacts, no open pipeline Amount, no recent activity, and incomplete billing (score **0**). Confirm Critical (`0` vs `80+`).
2. Add only Contacts (score **25**). Confirm still Critical while `minScore` is 80.
3. Meet all four criteria (score **100**), or lower `minScore` in JSON until the current score passes, then confirm a pass.
4. Change Type away from Strategic and confirm skip (class does not run).
5. Repeat with restricted related-record access and confirm the score reflects only visible evidence.

### Execute Anonymous

Run this from **Developer Console → Debug → Open Execute Anonymous Window** after replacing the
placeholder with an Account ID you can access:

```apex
Id accountId = '001XXXXXXXXXXXXXXX';
RecordHealthCheckResult result = RecordHealthCheck.runRule(
  'Strategic_Account_Is_Ready',
  accountId
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
```

Confirm `status`, `actualValue`, and `expectedValue` match the same Account on the card.

### Lightning record page

1. Add **Record Health Check** to the Account record page in Lightning App Builder.
2. Select `Account_Apex_Readiness`, save, and activate the page.
3. Open an Account, click **Run** or **Rerun**, and compare the result with Execute Anonymous.

## Failures, remedies, and customization

| Symptom | What to verify |
| --- | --- |
| Rule always skips | Confirm the Type value is exactly `Strategic`, or adapt the applicability formula. |
| Score is unexpectedly low | Check all four criteria, blank Amount, activity window, and running-user visibility. |
| `APEX_EVALUATOR_ERROR` | Verify object/field access and inspect authorized diagnostics. |

Use JSON to change the minimum or window. Changing criteria or weights requires matching class,
test, threshold, and documentation updates.

## Related

- [← Prev: Open Opportunity health](02-open-opportunity-health.md) · [Next: Inactive approvers →](04-inactive-approver.md)
- [Browse Apex examples](README.md)
