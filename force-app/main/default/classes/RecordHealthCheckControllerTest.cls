/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckControllerTest {
  @testSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @isTest
  static void getCheckDefinitionsReturnsDefinitionResponse() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckDefinitionResponse response = RecordHealthCheckController.getCheckDefinitions(
      'Account_Data_Quality',
      accountRecord.Id,
      'test-run-1'
    );
    Test.stopTest();

    System.assertEquals('Account Data Quality', response.displayTitle);
    System.assert(
      response.checks.size() > 0,
      'Expected visible check definitions.'
    );
  }

  @isTest
  static void getCheckDefinitionsWrapsConfigErrorsForAura() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    try {
      RecordHealthCheckController.getCheckDefinitions(
        'Missing_Config',
        accountRecord.Id,
        'test-run-2'
      );
      System.assert(false, 'Expected AuraHandledException.');
    } catch (AuraHandledException ex) {
      System.assert(
        ex.getMessage().contains('CONFIG_NOT_FOUND'),
        'Expected serialized reason code in the Aura error message.'
      );
    }
  }

  @isTest
  static void evaluateCheckDoesNotThrowForMissingRule() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    RecordHealthCheckResult result = RecordHealthCheckController.evaluateCheck(
      'Account_Data_Quality',
      'Missing_Rule',
      accountRecord.Id,
      'test-run-3',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );

    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals('RULE_NOT_FOUND', result.reasonCode);
  }

  @isTest
  static void lwcPublicationRequiresUserInitiationAndMetadataOptIn() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckLifecyclePublisher.publishRuleNamesOverride = new Set<String>{
      'Missing_Rule'
    };
    RecordHealthCheckLifecyclePublisher.publishRunSettingOverride = true;
    Integer beforeDml = Limits.getDmlStatements();

    RecordHealthCheckController.evaluateCheck(
      'Account_Data_Quality',
      'Missing_Rule',
      accountRecord.Id,
      'automatic-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    System.assertEquals(
      beforeDml,
      Limits.getDmlStatements(),
      'Automatic LWC evaluation must never publish.'
    );

    RecordHealthCheckResult result = RecordHealthCheckController.evaluateCheck(
      'Account_Data_Quality',
      'Missing_Rule',
      accountRecord.Id,
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    System.assertEquals(
      beforeDml + 1,
      Limits.getDmlStatements(),
      'An opted-in user-initiated Rule must publish once.'
    );

    RecordHealthCheckController.completeRun(
      'Account_Data_Quality',
      'user-run',
      new List<RecordHealthCheckResult>{ result },
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id
    );
    System.assertEquals(
      beforeDml + 2,
      Limits.getDmlStatements(),
      'An opted-in user-initiated Set must publish once at completion.'
    );
  }

  @isTest
  static void getCheckSetAvailabilityForRecordReflectsObjectScopedMetadata() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckSetAvailability accountAvailability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
      accountRecord.Id
    );
    RecordHealthCheckSetAvailability userAvailability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
      UserInfo.getUserId()
    );
    RecordHealthCheckSetAvailability nullAvailability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
      null
    );
    Test.stopTest();

    System.assertEquals(
      true,
      accountAvailability.hasActive,
      'Packaged Account Check Sets should be visible for an Account record.'
    );
    System.assertEquals(
      false,
      userAvailability.hasActive,
      'User has no packaged Check Sets; expected false.'
    );
    System.assertEquals(
      false,
      userAvailability.hasInactive,
      'User should not report inactive Check Sets either.'
    );
    System.assertEquals(false, nullAvailability.hasActive);
    System.assertEquals(false, nullAvailability.hasInactive);
  }
}
