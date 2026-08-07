/** Focused tests for rule dependency metadata validation. */
@IsTest
private class RHCMetadataDependencyValidatorTest {
  @IsTest
  static void reportsMissingPrerequisite() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'DeveloperName' => 'Dependent_Rule',
        'PrerequisiteRule__c' => 'Missing_Rule'
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RHCMetadataDependencyValidator.validate(
      'Set',
      new List<Record_Health_Check_Rule__mdt>{ rule },
      new Map<String, Record_Health_Check_Rule__mdt>()
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      issues.size(),
      'The missing dependency should be reported.'
    );
    Assert.areEqual(
      'INVALID_DEPENDENCY',
      issues[0].reasonCode,
      'The dependency reason code must remain stable.'
    );
  }
}
