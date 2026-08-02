/** Focused tests for runtime rule-finding mapping. */
@IsTest
private class RecordHealthCheckConfigFindingMapperTest {
  @IsTest
  static void mapsMissingFormulaToUnableResult() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'DeveloperName' => 'Missing_Formula',
        'CheckTitle__c' => 'Missing formula',
        'EvaluationType__c' => 'FORMULA'
      }
    );
    List<RecordHealthCheckRuleValidator.Finding> findings = new List<RecordHealthCheckRuleValidator.Finding>{
      new RecordHealthCheckRuleValidator.Finding(
        RecordHealthCheckRuleValidator.FindingCode.FORMULA_MISSING,
        null
      )
    };

    Test.startTest();
    RecordHealthCheckInternalResult result = RecordHealthCheckConfigFindingMapper.firstResult(
      findings,
      rule
    );
    Test.stopTest();

    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'Invalid rules remain unable.'
    );
    Assert.areEqual(
      'INVALID_FORMULA',
      result.reasonCode,
      'Reason code must remain stable.'
    );
  }
}
