# Author Checks

You build checks declaratively in Custom Metadata. There are two record types, and one holds the
other.

- A **Check Set** (`Record_Health_Check_Set`) targets one object and carries the card's title and
  display options. One Check Set per object, per card.
- A **Rule** (`Record_Health_Check_Rule`) is one check inside a Check Set: what to evaluate, how to
  decide pass or fail, and what to tell the user when it fails.

You edit both in **Setup → Custom Metadata Types**, or deploy them from source like any other metadata.

## The four evaluation types

Every Rule sets an **Evaluation Type**, which decides how the check runs and which other fields you
fill in. There is no default — you choose one deliberately.

| Evaluation Type           | Use it to                                             | You fill in                                           |
| ------------------------- | ----------------------------------------------------- | ----------------------------------------------------- |
| **Verify with a formula** | Check a condition on the current record               | Pass Condition (a true/false formula)                 |
| **Verify with a query**   | Run one SOQL query and compare its result             | Source Query, Comparison Operator, Expected Value     |
| **Compare two queries**   | Compare the results of two SOQL queries               | Source Query and Comparison Query                     |
| **Verify with Apex**      | Run logic that the other three choices cannot express | An Apex class that implements `RecordHealthCheckRule` |

The framework validates your configuration before it runs — a field the chosen type needs but is
missing produces a clear **Unable to Check** outcome rather than a silent failure.

## A first Rule, end to end

1. Create a **Check Set** on `Account` with a card title.
2. Add a **Rule** to it: Evaluation Type **Verify with a formula**, Pass Condition
   `NOT(ISBLANK(Phone))`, Failure Severity **Warning**, Failure Message _"Add a phone number so the
   team can reach this account."_
3. Deploy, open an Account with no phone, and the card shows the failing check with your message.

Keep a first Check Set to **3–5 checks**, each with an actionable failure message. Add one Rule at a
time and confirm it before adding the next.

## Writing for the reader

- **Failure Message** says what's wrong and what to do about it.
- **Fix Message** and an optional **Fix it** action link (`Action Label` / `Action URL`) point the
  user to the fix — a record, a Flow, or a documented URL.
- Use the Salesforce field and object labels your readers already know. Write the message for the
  person who can correct the record; do not expose API values or implementation details.

## Reference

- Every Rule and Check Set field:
  [Metadata reference](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/metadata/index.md)
- Field sizes and limits (generated):
  [Field size registry](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/field-size-registry.md)
- Why a check was skipped or couldn't run:
  [Reason codes](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/reason-codes.md)

## Next

- Start from a working pattern instead → **[[Explore the Examples]]**
- Call a check from Apex or Flow → **[[Integrate]]**
