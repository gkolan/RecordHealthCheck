/** Scratch-org-only consumer used to verify publish-after-commit behavior. */
trigger RecordHealthCheckRuleResultReceipt on Record_Health_Check_Rule_Result__e(
  after insert
) {
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
  insert receipts;
}
