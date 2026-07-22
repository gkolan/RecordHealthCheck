# 02 · Open Pipeline Is Ready for Coaching

> [!NOTE]
> On this page, build an Apex Rule that flags only an open Opportunity carrying all three coaching risks, stale activity, no Next Step, and a Close Date outside the current quarter.
>
> **Setup reference**
>
> Use the [Apex reference](../../reference/reference-apex.md) for the complete setup fields and behavior.

## Scenario

A sales manager opens an Account before pipeline coaching.

- The manager needs to find Opportunities that have several warning signs on the same deal.
- A stale deal with no Next Step and a Close Date outside the current quarter needs focused coaching.
- The same warnings spread across different Opportunities do not identify one deal with that combined risk.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check identifies deals where all three warning signs occur together, so the manager can coach the Opportunity that needs attention instead of reconciling separate warnings.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Apply several conditions to one related record | Apex evaluates multiple warning signs on each open Opportunity. |
| Keep complex logic readable | Named Apex conditions replace an opaque metadata expression. |
| Summarize a failure for users | The result identifies why pipeline needs attention. |

## What the card shows

| Card value | Healthy | Unhealthy | No open Opportunities |
| --- | --- | --- | --- |
| **Status** | `PASS` | `FAIL` | `SKIP` |
| **Found** | `0 unhealthy` | `<N> unhealthy` | Not applicable |
| **Expected** | `0 unhealthy` | `0 unhealthy` | Not applicable |
| **Message** | No failure message | Configured Critical message | Applicability explains the skip |

## Why use Verify with Apex

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with Apex** | Best fit. The class confirms that all three warning signs belong to the same open Opportunity. |
| **Verify with a query** in three separate Rules | Would show three separate results, and each warning could come from a different Opportunity. |
| **Verify with a query** in one Rule | Could place every condition in one query, but the current-quarter date logic and user guidance would be harder to maintain. |

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

The complete class below binds `context.recordId` directly in its Opportunity query.

## Step 1: Understand the parameters

Use Rule parameters to change the stale-activity window without editing the Apex class:

```json
{
  "staleDays": 30
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON and supplies it as `context.parameters`. The class accepts
`staleDays` from `1` through `3650`; a missing or invalid value uses 30. See
[Parameter parsing patterns](../../reference/reference-apex.md#4-apex-parameters-json-apexparametersjson__c)
for validation and type-conversion guidance.

## Step 2: Create the Apex class

The complete evaluator logic is below. It reads only open Opportunities visible to the running user,
calculates the current calendar-quarter boundaries, and counts a row only when all three conditions
are true.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example RecordHealthCheckRule: flags open Opportunities that are simultaneously
 * stale, missing Next Step, and have a Close Date outside the current quarter. Administrators can change this through
 * {"staleDays": 30}
 */
public with sharing class AccountOpenOpportunityHealthCheck implements RecordHealthCheckRule {
    private static final Integer DEFAULT_STALE_DAYS = 30;
    private static final Integer MIN_STALE_DAYS = 1;
    private static final Integer MAX_STALE_DAYS = 3650;

    public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
        // Record Health Check supplies the Account ID. The administrator can
        // change staleDays in Apex Parameters (JSON) without changing this class.
        // Missing or invalid values use the documented 30-day default.
        Integer staleDays = resolveStaleDays(context.parameters);
        Date staleCutoff = Date.today().addDays(-staleDays);
        Date quarterStart = getQuarterStart(Date.today());
        Date quarterEnd = quarterStart.addMonths(3).addDays(-1);

        // WITH USER_MODE respects the running user's object, field, and record
        // access. The result never reveals an Opportunity the user cannot read.
        List<Opportunity> openOpps = [
            SELECT LastActivityDate, NextStep, CloseDate
            FROM Opportunity
            WHERE AccountId = :context.recordId AND IsClosed = FALSE
            WITH USER_MODE
        ];

        // An Opportunity is unhealthy only when all three problems occur on
        // that same record. Problems spread across different records do not fail.
        Integer unhealthyCount = 0;
        for (Opportunity opp : openOpps) {
            if (isUnhealthy(opp, staleCutoff, quarterStart, quarterEnd)) {
                unhealthyCount++;
            }
        }

        RecordHealthCheckResult result = new RecordHealthCheckResult();
        result.status = unhealthyCount == 0 ? 'PASS' : 'FAIL';
        // Return Found and Expected on pass and fail so users can see both the
        // unhealthy count and how many visible open Opportunities were checked.
        result.actualValue = unhealthyCount + ' unhealthy';
        result.expectedValue = '0 unhealthy';
        result.actualValueSource = new RecordHealthCheckValueSource.Detail(
            'Unhealthy open opportunities',
            String.valueOf(unhealthyCount),
            openOpps.size() + ' open opportunit' + (openOpps.size() == 1 ? 'y' : 'ies') + ' scanned'
        );
        result.expectedValueSource = new RecordHealthCheckValueSource.Detail('Allowed unhealthy count', '0', null);
        return result;
    }

    @TestVisible
    private static Boolean isUnhealthy(Opportunity opp, Date staleCutoff, Date quarterStart, Date quarterEnd) {
        Boolean stale = opp.LastActivityDate == null || opp.LastActivityDate < staleCutoff;
        Boolean missingNextStep = String.isBlank(opp.NextStep);
        Boolean closeNotThisQuarter =
            opp.CloseDate == null ||
            opp.CloseDate < quarterStart ||
            opp.CloseDate > quarterEnd;
        return stale && missingNextStep && closeNotThisQuarter;
    }

    @TestVisible
    private static Date getQuarterStart(Date reference) {
        Integer month = reference.month();
        Integer quarterMonth = ((Integer) Math.floor((month - 1) / 3.0) * 3) + 1;
        return Date.newInstance(reference.year(), quarterMonth, 1);
    }

    private Integer resolveStaleDays(Map<String, Object> parameters) {
        // Blank, nonnumeric, and out-of-range values use the safe default.
        if (parameters == null)
            return DEFAULT_STALE_DAYS;
        Object raw = parameters.get('staleDays');
        if (raw == null)
            return DEFAULT_STALE_DAYS;
        try {
            Integer parsed = Integer.valueOf(String.valueOf(raw));
            return parsed >= MIN_STALE_DAYS && parsed <= MAX_STALE_DAYS ? parsed : DEFAULT_STALE_DAYS;
        } catch (Exception ex) {
            return DEFAULT_STALE_DAYS;
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
| **Developer Name** | [`DeveloperName`](../../metadata/fields-rule.md#developer-name-developername) | `Open_Opportunities_Are_Healthy` |
| **Label** | [`MasterLabel`](../../metadata/fields-rule.md#label-masterlabel) | Open Opportunities Are Healthy |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-rule.md#check-title-checktitle__c) | Open Opportunities Are Healthy |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/fields-rule.md#apex-class-apexclass__c) | `AccountOpenOpportunityHealthCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/fields-rule.md#apex-parameters-json-apexparametersjson__c) | `{"staleDays": 30}` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-rule.md#applies-to-applicabilitymode__c) | When a count query matches |
| **Applies When (Count Query)** | [`ApplicabilityCountQuery__c`](../../metadata/fields-rule.md#applies-when-count-query-applicabilitycountquery__c) | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **Count Must Be** | [`ApplicabilityCountOperator__c`](../../metadata/fields-rule.md#count-must-be-applicabilitycountoperator__c) | Greater than |
| **Count Value** | [`ApplicabilityCountThreshold__c`](../../metadata/fields-rule.md#count-value-applicabilitycountthreshold__c) | `0` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-rule.md#check-description-checkdescription__c) | Checks whether any open Opportunity is stale, missing Next Step, and outside the current quarter at the same time. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-rule.md#message-when-failed-failuremessage__c) | One or more open opportunities are simultaneously stale, missing a Next Step, and have a Close Date outside the current quarter. Update Next Step, activity, or Close Date on the unhealthy Opportunities. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check open Opportunity health. Confirm the running user can read the Opportunities and fields used by this Rule. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-rule.md#fix-message-fixmessage__c) | Review the open Opportunities. For each unhealthy Opportunity, update Next Step, log current activity, or correct Close Date. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-rule.md#action-label-actionlabel__c) | `Review open opportunities` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-rule.md#evaluation-order-evaluationorder__c) | `20` |
| **Active** | [`IsActive__c`](../../metadata/fields-rule.md#active-isactive__c) | Checked |
| **Publish Result Event** | [`PublishResultEvent__c`](../../metadata/fields-rule.md#publish-result-event-publishresultevent__c) | Unchecked |

`staleDays` sets how old `LastActivityDate` must be before an Opportunity counts as stale.

The applicability fields in **Configure the Rule** are required for the documented skip behavior;
they are not repeated here. The pack metadata currently supplies the description, messages,
applicability, order, and Active. Add the recommended Fix Message and action link in Setup when the
standard Opportunities related list is available on the Account page.

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

Count-query applicability and the Apex result become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Zero unhealthy open Opportunities passes. |
| **`FAIL`** | One or more Opportunities has all three warning signs, so the card shows Needs attention with Critical severity. |
| **`SKIPPED`** | An Account with no open Opportunities is skipped by the applicability count query before the Apex class runs. |
| **Found** | Found shows the unhealthy Opportunity count, such as `0 unhealthy`. |
| **Expected** | Expected shows that the unhealthy Opportunity count must be `0`. |

`LastActivityDate = null` counts as stale, blank `NextStep` counts as missing, and null `CloseDate`
counts as outside the quarter. An Opportunity remains healthy when it has only one or two warning
signs because the class combines all three conditions with AND logic. Calling the class directly
with no open Opportunities returns `PASS`; only Framework applicability creates `SKIPPED`.

## Security and access

The class uses sharing and a user-mode Opportunity query so its result follows the running user's Salesforce access.

- Opportunity plus `AccountId`, `IsClosed`, `LastActivityDate`, `NextStep`, and `CloseDate`.

- A hidden unhealthy Opportunity does not contribute to the result and can change Needs attention to Pass or Skip.

- Missing object or field permission must show **Unable to evaluate**, not a false Pass.

- The evaluator performs no DML or callouts.

- Prove the access-limited case with the actual Permission Sets and Opportunity sharing assigned to card users.

## Step 4: Test the Rule

1. Add an open Opportunity with blank Next Step, `LastActivityDate` older than the stale window, and `CloseDate` outside the current quarter. Confirm Critical.
2. Fix or remove that Opportunity, rerun, and confirm a pass.
3. Remove all open Opportunities and confirm skip.
4. Repeat the failing case as a user who cannot see the unhealthy Opportunity. Confirm the result
   follows that user's visibility and does not expose hidden Opportunity data.

Execute Anonymous alternative:

```apex
RecordHealthCheckResult result = RecordHealthCheck.runRule(
  'Open_Opportunities_Are_Healthy', '001XXXXXXXXXXXXXXX'
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
```

### Lightning record page

1. Add **Record Health Check** to the Account record page in Lightning App Builder.
2. Select `Account_Apex_Readiness`, save, and activate the page.
3. Open the same Account, click **Run** or **Rerun**, and compare Status, Found, and Expected with
   the Execute Anonymous result.

## Failures and remedies

| Symptom | What to verify |
| --- | --- |
| Rule skips unexpectedly | Confirm an open Opportunity is visible to the running user and the applicability query still uses the Account merge token. |
| Expected unhealthy row passes | Confirm all three conditions are true on the same Opportunity and that `staleDays` is valid. |
| `APEX_EVALUATOR_ERROR` | Verify Opportunity object/field access and inspect authorized diagnostics. |
| `APEX_CLASS_NOT_FOUND` | Deploy the class and match **Apex Class** exactly. |

## Customize this Rule

Change `staleDays` in JSON without redeploying. If you change the definition of unhealthy, update
the loop conditions, tests, failure message, and required field permissions together. Remove or
change the applicability configuration if an Account with no open Opportunities should pass rather
than skip.

## Related

- [← Prev: Recent activity](01-recent-activity.md) · [Next: Strategic readiness score →](03-strategic-readiness.md)
- [Browse Apex examples](README.md)
