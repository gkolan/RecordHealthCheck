@IsTest
public class RHCObservabilityTestDataFactory {
  public static Account incompleteAccount(String label) {
    Account accountRecord = new Account(Name = label);
    insert accountRecord;
    return accountRecord;
  }

  public static Record_Health_Check_Rule_Result__e failedRuleEvent(
    String eventId,
    String runId,
    Id recordId
  ) {
    return new Record_Health_Check_Rule_Result__e(
      ContractVersion__c = '2.0',
      EventId__c = eventId,
      RunId__c = runId,
      CheckSetQualifiedApiName__c = 'Example_Account_Profile_Readiness',
      RuleQualifiedApiName__c = 'Example_Profile_Phone_Available',
      RecordId__c = String.valueOf(recordId),
      Status__c = 'FAIL',
      Severity__c = 'WARNING',
      ReasonCode__c = 'VALUE_MISSING',
      OccurredAt__c = System.now(),
      Source__c = 'USER_INITIATED',
      FrameworkVersion__c = '2.0.0'
    );
  }
}
