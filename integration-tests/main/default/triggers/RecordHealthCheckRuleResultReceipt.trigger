/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Scratch-org-only consumer used to verify publish-after-commit behavior. */
trigger RecordHealthCheckRuleResultReceipt on Record_Health_Check_Rule_Result__e(
  after insert
) {
  // code-analyzer-suppress-next-line AvoidLogicInTrigger: This scratch-org-only fixture is already a single-purpose, bulkified event-to-receipt adapter; a handler would add indirection without reusable behavior.
  List<Task> receipts = new List<Task>();
  for (Record_Health_Check_Rule_Result__e eventRecord : Trigger.New) {
    receipts.add(
      new Task(
        Subject = 'RHC Rule Result Receipt',
        Description = eventRecord.EventId__c,
        Status = 'Not Started',
        Priority = 'Normal'
      )
    );
  }
  Database.insert(receipts, AccessLevel.USER_MODE);
}
