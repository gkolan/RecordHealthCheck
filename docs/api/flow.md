# Use Record Health Check from Flow

> [!NOTE]
> On this page, configure the packaged Flow actions, branch on every returned status, and keep bulk Flow work within the Record Health Check request limits.

Flow Builder exposes **Run Record Health Check Set** and **Run Record Health Check Rule** in the
**Record Health Check** action category. Both actions use the same request contract as Apex.

## Build the Flow

1. Create or open a Flow that has a record ID.
2. Add an **Action** element.
3. Select **Run Record Health Check Set**.
4. Set **Check Set Qualified API Name** to the Custom Metadata `QualifiedApiName`.
5. Set **Record ID** to the current record ID.
6. Set **Event Publication** explicitly to `NONE`, `ACTIONABLE`, or `ALL`. Use `NONE` when the Flow must not publish lifecycle events; a blank value is rejected.
7. Add a Decision element with separate paths for `PASS`, `FAIL`, `SKIPPED`,
   `UNABLE_TO_EVALUATE`, and `ERROR`.
8. Connect the Action fault path for invalid requests and transaction failures.

Use **Run Record Health Check Rule** when the Flow intentionally needs one Rule instead of the
complete Check Set.

## Understand the outputs

| Action | Main outputs |
| --- | --- |
| Check Set | Contract Version, Status, Passed Count, Failed Count, Skipped Count, Unable Count, System Error Count, Result JSON |
| Rule | Contract Version, Status, Reason Code, Result JSON |

`FAIL` is a returned result. It does not use the fault connector. Invalid names, invalid
publication values, oversized requests, and unhandled platform failures can use the fault path.

## Use Flow collections safely

The actions group requests that have the same qualified metadata name and publication mode, then
evaluate the record IDs together. This design avoids one evaluation call per Flow row.

Keep the Flow interview within both public limits. The record limit applies to the incoming action
collection. The planned-evaluation limit applies after each Check Set expands into active Rules.
Split larger populations into separate transactions with scheduled paths, Queueable Apex, or Batch
Apex.

## Test the Flow

Test at least one record for every status path and one invalid metadata name for the fault path.
Run the test with the same effective access as the deployed Flow. Confirm that a later Flow fault
rolls back transactional work and prevents Publish After Commit lifecycle events.

## Related

- [Apex API](apex-api.md)
- [Queueable Apex](queueable.md)
- [Subscribe with a platform event-triggered Flow](../platform-events/README.md)
- [Flow actions integration reference](../integration/flow-actions.md)
