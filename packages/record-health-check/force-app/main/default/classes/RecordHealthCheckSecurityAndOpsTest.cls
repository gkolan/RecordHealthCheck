/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckSecurityAndOpsTest {
  @IsTest
  static void structuredLogValuesCannotForgeNewLines() {
    Assert.areEqual(
      'ticket forged value',
      RecordHealthCheckLogger.normalizeIdentifier('ticket\nforged\tvalue', 120)
    );
    Assert.areEqual(
      '12345',
      RecordHealthCheckLogger.normalizeIdentifier('123456789', 5)
    );
  }

  @IsTest
  static void fieldPlanningIgnoresLiteralsAndInvalidMessageTokens() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'CONTAINS(Website, "example.com") && NOT(ISBLANK(Parent.Name))',
        'FailureMessage__c' => 'Bad token stays blank: {!record.Parent.Missing__c}'
      }
    );

    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(rule, Account.SObjectType);

    Assert.isTrue(fields.contains('Website'));
    Assert.isTrue(fields.contains('Parent.Name'));
    Assert.isTrue(!fields.contains('example.com'));
    Assert.isTrue(!fields.contains('Parent.Missing__c'));
  }

  @IsTest
  static void sharedValidatorCoversObjectsPluginsAndJson() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Assert.isTrue(
      RecordHealthCheckConfigValidator.isValidObjectApiName('Account')
    );
    Assert.isTrue(
      !RecordHealthCheckConfigValidator.isValidObjectApiName('Nope__c')
    );
    Assert.isTrue(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'AccountHasRecentActivityCheck'
      )
    );
    Assert.isTrue(
      !RecordHealthCheckConfigValidator.isValidApexPlugin('String')
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'Class_That_Does_Not_Exist'
      ),
      'An unresolved Apex class must not be accepted as a Rule plugin.'
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'RecordHealthCheckConstants'
      ),
      'A constructible class that does not implement the Rule contract must be rejected.'
    );
    Assert.isTrue(
      RecordHealthCheckConfigValidator.isJsonObject('{"daysBack":90}')
    );
    Assert.isTrue(!RecordHealthCheckConfigValidator.isJsonObject('[1,2,3]'));

    Assert.areEqual(
      'CUSTOM',
      RecordHealthCheckConstants.toLwcSeverity('CUSTOM'),
      'Unknown severity values must pass through for forward compatibility.'
    );
    Assert.areEqual(
      'Apex',
      RecordHealthCheckConstants.toLwcEvaluatorType('APEX'),
      'The Apex evaluator must use the public LWC spelling.'
    );
    Assert.areEqual(
      'CompareTwoQueries',
      RecordHealthCheckConstants.toLwcEvaluatorType('COMPARE_TWO_QUERIES'),
      'The query-comparison evaluator must use the public LWC spelling.'
    );
    Assert.areEqual(
      'FUTURE_TYPE',
      RecordHealthCheckConstants.toLwcEvaluatorType('FUTURE_TYPE'),
      'Unknown evaluator values must pass through for forward compatibility.'
    );
  }

  @IsTest
  static void detailsPermissionUsesFeatureManagement() {
    User userWithoutPermission = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'rhcno'
    );

    Test.startTest();
    Boolean canViewDetails;
    System.runAs(userWithoutPermission) {
      canViewDetails = RecordHealthCheckAccess.canViewDetails();
    }
    Test.stopTest();

    Assert.isFalse(
      canViewDetails,
      'A minimum-access user without the diagnostics permission must be denied.'
    );
  }

  @IsTest
  static void sharedMappingsCoverEveryNamedValue() {
    Test.startTest();
    String failuresOnly = RecordHealthCheckConstants.toLwcComparisonDisplay(
      'FAILURES_ONLY'
    );
    String allRows = RecordHealthCheckConstants.toLwcComparisonDisplay(
      'ALL_ROWS'
    );
    String info = RecordHealthCheckConstants.toLwcSeverity('INFO');
    String critical = RecordHealthCheckConstants.toLwcSeverity('CRITICAL');
    String formula = RecordHealthCheckConstants.toLwcEvaluatorType('FORMULA');
    String query = RecordHealthCheckConstants.toLwcEvaluatorType('QUERY');
    Test.stopTest();

    Assert.areEqual(
      'FailuresOnly',
      failuresOnly,
      'Failures-only mapping should match the LWC contract.'
    );
    Assert.areEqual(
      'AllRows',
      allRows,
      'All-rows mapping should match the LWC contract.'
    );
    Assert.areEqual(
      'Info',
      info,
      'Info severity should match the LWC contract.'
    );
    Assert.areEqual(
      'Error',
      critical,
      'Critical severity should map to the LWC error variant.'
    );
    Assert.areEqual(
      'Formula',
      formula,
      'Formula evaluator should match the LWC contract.'
    );
    Assert.areEqual(
      'Query',
      query,
      'Query evaluator should match the LWC contract.'
    );
  }

  @IsTest
  static void sharedMappingsRejectUnknownValues() {
    assertUnknownMode('trigger');
    assertUnknownMode('reveal');
    assertUnknownMode('display');
    assertUnknownMode('comparison');
  }

  private static void assertUnknownMode(String mapping) {
    try {
      if (mapping == 'trigger') {
        RecordHealthCheckConstants.toLwcTriggerMode('UNKNOWN');
      } else if (mapping == 'reveal') {
        RecordHealthCheckConstants.toLwcRevealMode('UNKNOWN');
      } else if (mapping == 'display') {
        RecordHealthCheckConstants.toLwcDisplayMode('UNKNOWN');
      } else {
        RecordHealthCheckConstants.toLwcComparisonDisplay('UNKNOWN');
      }
      Assert.fail('An unknown ' + mapping + ' mode must be rejected.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(error.getMessage().contains('Unknown'));
    }
  }

  @IsTest
  static void templateValidationReturnsNullWhenRuleMissing() {
    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      null
    );
    Test.stopTest();

    Assert.isNull(issue, 'A missing Rule has no template to validate.');
  }

  @IsTest
  static void pluginValidationRethrowsConstructorSideEffects() {
    Test.startTest();
    try {
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'RecordHealthCheckConstructorMutationRule'
      );
      Assert.fail('A plugin constructor mutation must abort validation.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.isNotNull(
        error.getMessage(),
        'The prohibited constructor mutation should retain diagnostic detail.'
      );
    }
    Test.stopTest();
  }
}
