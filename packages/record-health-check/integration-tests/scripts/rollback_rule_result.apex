Savepoint beforePublish = Database.setSavepoint();
EventBus.publish(
  new Record_Health_Check_Rule_Result__e(
    ContractVersion__c = '1.0',
    EventId__c = 'RHC_ROLLED_BACK',
    RunId__c = 'rollback-spike-negative',
    CheckSetQualifiedApiName__c = 'Spike_Set',
    RuleQualifiedApiName__c = 'Spike_Rule',
    Status__c = 'PASS',
    OccurredAt__c = System.now(),
    Source__c = 'FACADE',
    FrameworkVersion__c = '2.0.0'
  )
);
Database.rollback(beforePublish);
