/** Focused tests for Check Set metadata validation. */
@IsTest
private class RHCMetadataSetValidatorTest {
  @IsTest
  static void reportsMissingRequiredFields() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Invalid_Set',
        'ObjectApiName__c' => null,
        'CardTitle__c' => null,
        'CardRunMode__c' => 'RUN_ON_LOAD',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataSetValidator.validate(
      checkSet
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      issues.size(),
      'Both required fields should be reported.'
    );
  }
}
