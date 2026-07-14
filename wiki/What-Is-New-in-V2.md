# What Is New in V2

V2 keeps the Lightning record-page experience and adds supported ways to run the same checks from
Apex and Flow. It also standardizes Custom Metadata field names, result reasons, and optional
platform events.

## Before you upgrade

V2 changes Custom Metadata field API names and does not read the earlier names. Test in a sandbox,
export your Check Set and Rule records, and follow the
[V2 upgrade and rollback guide](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/installation/upgrading-to-v2.md).

## Changes for Salesforce administrators

- App Builder uses a **Check Set** picklist for the record page.
- Setup labels use consistent Salesforce terms for Evaluation Type, comparison, display, and
  applicability settings.
- **Critical** replaces the earlier Error failure severity. **System Error** remains a separate
  result for an unexpected technical failure.
- Passed and skipped checks can be shown or summarized. **Found/Expected Display** controls when
  comparison values appear.
- **Show Diagnostics** and the `Record_Health_Check_View_Details` custom permission protect
  troubleshooting details.
- Failed checks can show a **Fix it** link and **Fix Message** without updating the record.

## Changes for builders

- Use `RecordHealthCheck.run` or `runSet` from Apex.
- Use the Flow action **Run Record Health Check** without writing Apex.
- Optional platform events report completed Check Set runs and Rule results after commit.
- Reason codes identify why a Rule was skipped, could not run, or returned a system error.
- Custom Apex checks continue to implement `RecordHealthCheckRule`.

## Important limits

- A record-page card runs at most 25 active Rules and no more than 5 Apex requests at once.
- An Apex or Flow request accepts at most 200 record IDs and plans at most 15 Rule evaluations.
- Opening a record page never publishes lifecycle platform events.
- The card does not save result history or rerun automatically after a record edit.

## Next

- New installation → **[[Install the Core]]**
- Existing V1 installation → use the
  [upgrade guide](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/installation/upgrading-to-v2.md)
- Build a Check Set → **[[Author Checks]]**
- Run checks from Apex or Flow → **[[Integrate]]**
