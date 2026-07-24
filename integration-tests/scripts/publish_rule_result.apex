EventBus.publish(
  new Record_Health_Check_Rule_Result__e(
    ContractVersion__c = '1.0',
    EventId__c = 'RHC_POSITIVE_COMMIT',
    RunId__c = 'rollback-spike-positive',
    CheckSetDeveloperName__c = 'Spike_Set',
    RuleDeveloperName__c = 'Spike_Rule',
    Status__c = 'PASS',
    OccurredAt__c = System.now(),
    Source__c = 'FACADE',
    CoreVersion__c = '2.0.0'
  )
);
