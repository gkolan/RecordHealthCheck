# 01 · Account Is Ready for Customer Follow-up

> [!NOTE]
> **On this page**
>
> Learn how to show recent completed Tasks and Events in one Account result and let an administrator choose the activity window.
>
> **Setup reference**
>
> Use the [Apex reference](reference.md) for the complete setup fields and behavior.

## Scenario

An account manager opens an Account before a customer call and wants to know whether anyone has completed follow-up recently.

- The answer should include completed Tasks and logged Events without making the manager interpret two separate card rows.
- Customer follow-up may be recorded as either type of activity.
- Opening and comparing both activity lists takes attention away from preparing for the conversation.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check combines completed Tasks and logged Events into one answer, so the account manager can see whether recent follow-up exists before the customer call.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Choose Apex for multi-object logic | The Rule evaluates completed Tasks and Events together. |
| Accept administrator-controlled parameters | JSON configures the recent-activity window without changing Apex. |
| Return a clear Framework result | The class supplies status, **Found**, **Expected**, and user guidance. |

## What the card shows

| Card value | Activity found | No activity found |
| --- | --- | --- |
| **Status** | `PASS` | `FAIL` |
| **Found** | `<N> completed tasks; <N> events` | `0 completed tasks; 0 events` |
| **Expected** | `at least 1 completed task or event in the last <N> days` | Same |
| **Message** | No failure message | The Rule's configured Warning message |

Found keeps the Task and Event counts separate so the result begins the diagnosis. Expected shows
the date window the class actually used. With diagnostics enabled, the source detail also identifies
the configured look-back window.

## Why use Verify with Apex

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with Apex** | Best fit. One class can review completed Tasks and Events, apply the administrator's date window, and return one status. |
| **Verify with a formula** using Last Activity Date | Can read the Account's Last Activity Date but cannot apply separate Task and Event filters. |
| **Verify with a query** in two separate Rules | Would show separate Task and Event results instead of one recent-activity status. |
| **Compare two queries** | Can compare the Task and Event counts but cannot pass when either count is greater than zero. |

## What Record Health Check passes to Apex

| Input in Apex | Where it comes from |
| --- | --- |
| `context.recordId` | The Account being evaluated at run time |
| `context.parameters` | **Apex Parameters (JSON)** (`ApexParametersJson__c`) on the `Record_Health_Check_Rule__mdt` record |

Do not put the Account ID in the parameter JSON. Record Health Check supplies it automatically:

- On a Lightning record page, `context.recordId` is the ID of the open record.
- From Apex, it is the `recordId` passed to `RecordHealthCheck.runRule` or `RecordHealthCheck.runSet`.
- From Flow, it is the value supplied to the action's **Record ID** input.

Inside the class, use `context.recordId` as a bind variable so the query evaluates the intended
record:

```apex
Id accountId = context.recordId;
```

The complete class below binds `context.recordId` directly in its Task and Event queries, which is
equivalent to assigning the value to `accountId` first.

## Step 1: Understand the parameters

Use Rule parameters to change the activity window without editing the Apex class. This Rule uses:

```json
{
  "daysBack": 90
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON automatically and passes it to the class as
`context.parameters`, a map of parameter names to values. The class uses 30 days when `daysBack`
is absent, null, nonnumeric, or outside `1`–`3650`; the shipped Rule explicitly uses 90 days. See
[Parameter parsing patterns](reference.md#4-apex-parameters-json-apexparametersjson__c)
for validation and type-conversion guidance.

## Step 2: Create the Apex class

Deploy this complete class after Record Health Check. It respects the running user's Salesforce
access when it counts Tasks and Events, combines those counts, and returns Status, Found, and
Expected.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example implementation of RecordHealthCheckRule using the Apex evaluator.
 * Checks whether an Account has at least one completed Task or logged Event
 * within a configurable look-back window. The number of days is read from
 * ApexParametersJson__c so an administrator can change it without editing code
 * ApexParametersJson__c: {"daysBack": 90}
 * Failure message, severity, and label all come from the CMT record — this
 * class determines PASS/FAIL and returns comparison values for the UI.
 */
public with sharing class AccountHasRecentActivityCheck implements RecordHealthCheckRule {
  private static final Integer DEFAULT_DAYS_BACK = 30;
  private static final Integer MIN_DAYS_BACK = 1;
  private static final Integer MAX_DAYS_BACK = 3650;

  public RecordHealthCheckResult evaluate(RecordHealthCheckContext context) {
    Integer daysBack = resolveDaysBack(context.parameters);
    Date cutoff = Date.today().addDays(-daysBack);

    Integer taskCount = [
      SELECT COUNT()
      FROM Task
      WHERE
        WhatId = :context.recordId
        AND IsClosed = TRUE
        AND ActivityDate >= :cutoff
      WITH USER_MODE
    ];

    Integer eventCount = [
      SELECT COUNT()
      FROM Event
      WHERE WhatId = :context.recordId AND ActivityDate >= :cutoff
      WITH USER_MODE
    ];

    Integer activityCount = taskCount + eventCount;

    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = activityCount > 0 ? 'PASS' : 'FAIL';
    // Keep the two counts separate so Found helps an administrator understand
    // whether the class saw completed Tasks, Events, or neither.
    result.actualValue =
      taskCount +
      ' completed task' +
      (taskCount == 1 ? '' : 's') +
      '; ' +
      eventCount +
      ' event' +
      (eventCount == 1 ? '' : 's');
    // Include the effective window so an invalid JSON value that uses the
    // 30-day default is visible in the result instead of being easy to miss.
    result.expectedValue =
      'at least 1 completed task or event in the last ' + daysBack + ' days';
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      'Completed tasks + events',
      String.valueOf(activityCount),
      'last ' + daysBack + ' days'
    );
    result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
      'Required recent activity',
      '1',
      'within ' + daysBack + ' days'
    );
    return result;
  }

  private Integer resolveDaysBack(Map<String, Object> parameters) {
    if (parameters == null)
      return DEFAULT_DAYS_BACK;
    Object raw = parameters.get('daysBack');
    if (raw == null)
      return DEFAULT_DAYS_BACK;
    try {
      Integer parsed = Integer.valueOf(String.valueOf(raw));
      return parsed >= MIN_DAYS_BACK &&
        parsed <= MAX_DAYS_BACK
        ? parsed
        : DEFAULT_DAYS_BACK;
    } catch (Exception ex) {
      return DEFAULT_DAYS_BACK;
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
[Returning `RecordHealthCheckResult`](reference.md#6-returning-recordhealthcheckresult).


## Step 3: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-rule.md#developer-name-developername) | `Has_Recent_Activity` |
| **Label** | [`MasterLabel`](../../metadata/fields-rule.md#label-masterlabel) | Has Recent Activity |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-rule.md#check-title-checktitle__c) | Has Recent Activity |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/fields-rule.md#apex-class-apexclass__c) | `AccountHasRecentActivityCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/fields-rule.md#apex-parameters-json-apexparametersjson__c) | `{"daysBack": 90}` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-rule.md#check-description-checkdescription__c) | Checks for a completed Task or Event related to the Account inside the selected number of days. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-rule.md#message-when-failed-failuremessage__c) | `{!record.Name}` has no completed tasks or logged events in the last 90 days. Log a completed Task or Event inside the look-back window. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check recent activity. Confirm the running user can read Tasks and Events. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-rule.md#fix-message-fixmessage__c) | Review the Account activity timeline. If no completed Task or Event falls inside the 90-day window, log the activity and rerun the check. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-rule.md#action-label-actionlabel__c) | `Log account activity` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-rule.md#action-url-actionurl__c) | `/lightning/o/Task/new?defaultFieldValues=WhatId={!record.Id}` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-rule.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../metadata/fields-rule.md#active-isactive__c) | Checked |
| **Publish Result Event** | [`PublishResultEvent__c`](../../metadata/fields-rule.md#publish-result-event-publishresultevent__c) | Unchecked |

Change `daysBack` to change the window without redeploying the class.

The pack metadata currently supplies severity, failure message, applicability, order, and Active.
The other rows above are recommended choices for a complete, useful card and may be added in Setup.

The action link opens a new Task with the Account already selected. It does not prove why an
existing Task or Event was excluded. For diagnosis, first use Found and the 90-day window shown on
this page, then check the Account activity timeline for these four requirements:

1. The activity is related to this Account.
2. A Task has a closed status; Events do not use the Task status check.
3. Activity Date is inside the selected window.
4. The person running the check can read the activity.

If your administrators maintain an activity report filtered by Account ID, a report action link is
better for diagnosis:

```text
/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}
```

Replace the report ID with one from the target org. Do not publish the placeholder as a working
link. The prefilled Task link is the safer portable default because it does not depend on an
org-specific report or an assumed Activity related-list API name.

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

Formula, Query, and Compare two queries fields do not apply because this is the Verify with Apex Evaluation Type.

## What the user sees

The card shows one status each time the Rule runs. Supporting details appear only when they apply:

- **Pass:** A completed Task or Event with `ActivityDate` on or after the cutoff passes.

- **Needs attention:** No matching rows produce counts of zero and a normal `FAIL`, not an evaluation error.

- **Found and Expected:** The class supplies separate Task and Event counts plus the date window. The Rule supplies the label, severity, and failure message.

- **Parameter fallback:** Invalid `daysBack` values use 30 days. Expected shows the effective 30-day window so an administrator can spot a mistyped value.

## Security and access

The class uses sharing and user-mode queries so its result follows the running user's Salesforce access.

- Task and Event plus `WhatId`, `IsClosed`, and `ActivityDate`.

- Record sharing and restriction rules decide which activities contribute to the counts. Two users can legitimately see different results for the same Account.

- Insufficient object or field access must show **Unable to evaluate**. It is not proof that no activity exists.

- Keep `evaluate` free of DML and callouts because the card may run the Rule more than once.

- Run the Rule with the Permission Sets and activity visibility assigned to the intended users.

## Step 4: Test the Rule

1. Remove or push outside the window every completed Task and logged Event. Confirm Warning.
2. Add either back inside the window, rerun, and confirm a pass.
3. Edit `daysBack` in Apex Parameters (JSON) and confirm the window changes without a class redeploy.
4. Run as a user who cannot see a qualifying Task or Event. Confirm the result follows that user's
   visibility, then restore access and confirm the activity contributes again.

You can also test without the card from **Developer Console → Debug → Open Execute Anonymous
Window** (replace the placeholder with an Account ID):

```apex
Id accountId = '001XXXXXXXXXXXXXXX';
RecordHealthCheckResult result = RecordHealthCheck.runRule(
  'Has_Recent_Activity',
  accountId
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
```

### Lightning record page

1. Add **Record Health Check** to the Account record page in Lightning App Builder.
2. Select `Account_Apex_Readiness`, save, and activate the page.
3. Open the same Account, click **Run** or **Rerun**, and compare Status, Found, and Expected with
   the Execute Anonymous result.

## Failures and remedies

| Symptom or reason | What to verify |
| --- | --- |
| `APEX_CLASS_NOT_FOUND` | Deploy `AccountHasRecentActivityCheck`, confirm the class name in **Apex Class**, and confirm it implements `RecordHealthCheckRule`. |
| `APEX_EVALUATOR_ERROR` | Confirm the running user can read Task/Event and the queried fields; inspect authorized diagnostics for the underlying exception. |
| A known Task does not count | Confirm it is closed, its `WhatId` is this Account, its `ActivityDate` is inside the effective window, and the running user can see it. |
| The window appears to be 30 days | Correct a missing, nonnumeric, or out-of-range `daysBack`; those values use the 30-day default. |

## Customize this Rule

Change `daysBack` in JSON to change the window without deploying code. Change the Task or Event
filters only when your definition of activity differs, and update the class tests and explanatory
copy at the same time. If `LastActivityDate` alone answers the business question, replace this Apex
Rule with a simpler Verify with a formula.

## Related

- [Next: Combine per-row conditions on a child object →](02-open-opportunity-health.md)
- [Browse the pattern library](../README.md)
