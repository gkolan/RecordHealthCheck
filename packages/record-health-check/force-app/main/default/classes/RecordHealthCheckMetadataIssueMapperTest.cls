/** Focused tests for shared-finding metadata issue mapping. */
@IsTest
private class RecordHealthCheckMetadataIssueMapperTest {
  @IsTest
  static void mapsFormulaFindingToOriginalContract() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{ 'DeveloperName' => 'Missing_Formula' }
    );
    List<RecordHealthCheckRuleValidator.Finding> findings = new List<RecordHealthCheckRuleValidator.Finding>{
      new RecordHealthCheckRuleValidator.Finding(
        RecordHealthCheckRuleValidator.FindingCode.FORMULA_MISSING,
        null
      )
    };

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataIssueMapper.toIssues(
      findings,
      rule
    );
    Test.stopTest();

    Assert.areEqual(1, issues.size(), 'One finding should produce one issue.');
    Assert.areEqual(
      'INVALID_FORMULA',
      issues[0].reasonCode,
      'The established reason code must remain stable.'
    );
  }
}
