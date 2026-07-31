/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckControllerTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @IsTest
  static void getCheckDefinitionsReturnsDefinitionResponse() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
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

  @IsTest
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

  @IsTest
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

  @IsTest
  static void lwcPublicationRequiresUserInitiationAndMetadataOptIn() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckLifecyclePublisher.publishRuleNamesOverride = new Set<String>{
      'Missing_Rule'
    };
    RecordHealthCheckLifecyclePublisher.publishRunSettingOverride = true;
    Integer beforeDml = Limits.getDmlStatements();

    RecordHealthCheckController.evaluateCheck(
      'Example_Account_Relationship_Risk',
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
      'Example_Account_Relationship_Risk',
      'Missing_Rule',
      accountRecord.Id,
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    // This counts DML statements as a proxy for published events. It stays at
    // one because RecordHealthCheckPluginDispatch takes its side-effect
    // savepoint once per transaction and only when a custom Apex Rule actually
    // runs, which no Rule in this test does.
    System.assertEquals(
      beforeDml + 1,
      Limits.getDmlStatements(),
      'An opted-in user-initiated Rule must publish once.'
    );
    System.assertNotEquals(
      null,
      result,
      'The user-initiated evaluation still returns its check result.'
    );

    RecordHealthCheckController.completeRun(
      'Example_Account_Relationship_Risk',
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id
    );
    // Three DML statements, not two: the Rule event, the Set completion event,
    // and the single side-effect savepoint RecordHealthCheckPluginDispatch
    // takes the first time a custom Apex Rule runs in the transaction. Running
    // the whole Set reaches the Apex Rule, which the single-Rule case above
    // does not. That savepoint is what makes the no-side-effect guarantee real
    // rather than dependent on nobody up the stack catching the violation.
    System.assertEquals(
      beforeDml + 3,
      Limits.getDmlStatements(),
      'An opted-in user-initiated Set must publish once at completion.'
    );
  }

  @IsTest
  static void getCheckSetAvailabilityForRecordReflectsObjectScopedMetadata() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
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
