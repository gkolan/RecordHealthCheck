/** Focused tests for Check Set definition loading helpers. */
@IsTest
private class RecordHealthCheckDefinitionLoaderTest {
  @IsTest
  static void selectsOnlyFrameworkMaximumRules() {
    List<Record_Health_Check_Rule__mdt> rules = new List<Record_Health_Check_Rule__mdt>();
    for (Integer index = 0; index < 30; index++) {
      rules.add(
        RecordHealthCheckTestDataFactory.rule(
          new Map<String, Object>{ 'DeveloperName' => 'Rule_' + index }
        )
      );
    }

    Test.startTest();
    List<Record_Health_Check_Rule__mdt> selected = RecordHealthCheckDefinitionLoader.selectRulesForRun(
      rules
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS,
      selected.size(),
      'The run must remain capped at the framework maximum.'
    );
  }

  @IsTest
  static void validatesRequiredCardTitleAndInactiveOnlySets() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_COUNT_ONLY',
        'CardRunMode__c' => 'RUN_ON_LOAD',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'CardTitle__c' => null,
        'FoundExpectedDisplay__c' => 'ON_DEMAND'
      }
    );
    Id accountId =
      Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .getKeyPrefix() + '000000000000';

    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        'Missing_Title',
        accountId
      );
      Assert.fail('A blank Card Title must be rejected.');
    } catch (RecordHealthCheckConfigService.ConfigException error) {
      Assert.isTrue(error.getMessage().contains('Card Title'));
    }

    if (RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      try {
        RecordHealthCheckDefinitionLoader.validateActiveRulesForDefinition(
          new List<Record_Health_Check_Rule__mdt>(),
          'Example_Account_Relationship_Risk'
        );
        Assert.fail('An inactive-only Set must be rejected.');
      } catch (RecordHealthCheckConfigService.ConfigException error) {
        Assert.isTrue(error.getMessage().contains('inactive'));
      }
    }
  }
}
