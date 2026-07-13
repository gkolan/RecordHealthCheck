/** Scratch-org-only export consumer used to validate the shared V1 event schema. */
trigger RecordHealthCheckRuleResultExport on Record_Health_Check_Rule_Result__e(
  after insert
) {
  List<RHC_Event_Export__c> exports = new List<RHC_Event_Export__c>();
  for (Record_Health_Check_Rule_Result__e eventRecord : Trigger.New) {
    Map<String, Object> payload = new Map<String, Object>{
      'contractVersion' => eventRecord.ContractVersion__c,
      'eventId' => eventRecord.EventId__c,
      'runId' => eventRecord.RunId__c,
      'checkSet' => eventRecord.CheckSetDeveloperName__c,
      'rule' => eventRecord.RuleDeveloperName__c,
      'status' => eventRecord.Status__c,
      'reasonCode' => eventRecord.ReasonCode__c,
      'source' => eventRecord.Source__c
    };
    exports.add(
      new RHC_Event_Export__c(
        EventId__c = eventRecord.EventId__c,
        Payload__c = JSON.serialize(payload)
      )
    );
  }
  insert exports;
}
