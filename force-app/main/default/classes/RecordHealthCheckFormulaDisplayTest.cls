@IsTest
private class RecordHealthCheckFormulaDisplayTest {
  @IsTest
  static void preservesVerdictWhenDisplayFormulaIsInvalid() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'PassConditionFormula__c' => 'AnnualRevenue > 0',
        'DisplayFoundFormula__c' => 'Missing_Field__c',
        'FormulaResultType__c' => 'TEXT'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = 'PASS';

    Test.startTest();
    RecordHealthCheckFormulaDisplay.apply(
      rule,
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'AnnualRevenue' => 100 }
      ),
      result,
      new RecordHealthCheckFormulaEvaluator(),
      new RecordHealthCheckRunContext('formula-display-test', 'TEST')
    );
    Test.stopTest();

    Assert.areEqual(
      'PASS',
      result.status,
      'Display-only failures must not change the business verdict.'
    );
    Assert.isNull(
      result.actualValue,
      'An invalid Found formula must not produce a misleading value.'
    );
    Assert.areEqual(
      'AnnualRevenue > 0',
      result.expectedValue,
      'The pass condition should remain the Expected fallback.'
    );
  }

  @IsTest
  static void usesPassConditionWhenDisplayFormulasAreBlank() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'PassConditionFormula__c' => 'TRUE',
        'DisplayFoundFormula__c' => null,
        'DisplayExpectedFormula__c' => null
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckFormulaDisplay.apply(
      rule,
      RecordHealthCheckTestDataFactory.account(null),
      result,
      new RecordHealthCheckFormulaEvaluator(),
      null
    );
    Test.stopTest();

    Assert.areEqual(
      'TRUE',
      result.expectedValue,
      'A Formula check without display formulas should expose its condition.'
    );
    Assert.areEqual(
      RecordHealthCheckInternalResult.PASSES_WHEN_LABEL,
      result.expectedValueLabel,
      'The fallback must be labelled as a condition rather than a value.'
    );
  }
}
