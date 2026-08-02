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
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      accountRecord.Id,
      'test-run-1'
    );
    Test.stopTest();

    Assert.areEqual(
      'Account Relationship & Risk Health Check',
      response.displayTitle,
      'The definition response should use the packaged Check Set title.'
    );
    Assert.isTrue(
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
      Assert.isTrue(false, 'Expected AuraHandledException.');
    } catch (AuraHandledException ex) {
      Assert.isTrue(
        ex.getMessage().contains('CONFIG_NOT_FOUND'),
        'Expected serialized reason code in the Aura error message.'
      );
    }
  }

  @IsTest
  static void getCheckDefinitionsRejectsBlankSelection() {
    Test.startTest();
    try {
      RecordHealthCheckController.getCheckDefinitions(' ', null, 'blank-run');
      Assert.fail('A blank Check Set selection must be rejected.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('CONFIG_NOT_FOUND'),
        'The Aura error should retain the configuration reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void getCheckDefinitionsMapsUnexpectedFailureToLoadFailed() {
    RecordHealthCheckConfigService original = RecordHealthCheckController.configService;
    RecordHealthCheckController.configService = null;

    Test.startTest();
    try {
      RecordHealthCheckController.getCheckDefinitions(
        'Any_Set',
        UserInfo.getUserId(),
        'error-run'
      );
      Assert.fail(
        'An unexpected service failure must be converted to an Aura error.'
      );
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('LOAD_FAILED'),
        'Unexpected failures should use LOAD_FAILED.'
      );
    } finally {
      RecordHealthCheckController.configService = original;
    }
    Test.stopTest();
  }

  @IsTest
  static void completeRunIgnoresAutomaticAndMissingRecordContexts() {
    Test.startTest();
    RecordHealthCheckController.completeRun(
      'Any_Set',
      'automatic',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD,
      UserInfo.getUserId(),
      null
    );
    RecordHealthCheckController.completeRun(
      'Any_Set',
      'missing-record',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      null,
      null
    );
    Test.stopTest();

    Assert.isNotNull(
      RecordHealthCheckController.configService,
      'Ignored completion calls must leave the controller service available.'
    );
  }

  @IsTest
  static void completeRunWrapsUnexpectedFailuresForAura() {
    Test.startTest();
    try {
      RecordHealthCheckController.completeRun(
        'Any_Set',
        'completion-error',
        RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
        UserInfo.getUserId(),
        'not-json'
      );
      Assert.fail('An unexpected completion failure must be converted.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('RUN_COMPLETION_FAILED'),
        'The Aura response should expose only the stable completion code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void availabilityLookupWrapsUnexpectedFailuresForAura() {
    RecordHealthCheckConfigService original = RecordHealthCheckController.configService;
    RecordHealthCheckController.configService = null;

    Test.startTest();
    try {
      RecordHealthCheckController.getCheckSetAvailabilityForRecord(
        UserInfo.getUserId()
      );
      Assert.fail('An unexpected availability failure must be converted.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('LOAD_FAILED'),
        'The Aura response should expose only the stable load code.'
      );
    } finally {
      RecordHealthCheckController.configService = original;
    }
    Test.stopTest();
  }

  @IsTest
  static void evaluateCheckDoesNotThrowForMissingRule() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Rule',
      accountRecord.Id,
      'test-run-3',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );

    Assert.areEqual('ERROR', result.evaluation.status);
    Assert.areEqual('APEX_EVALUATOR_ERROR', result.evaluation.reasonCode);
  }

  @IsTest
  static void evaluateCheckReturnsPackagedRuleAndCompletesMembership() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Controller success'
    );

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      RecordHealthCheckTestDataFactory.qualifiedRuleName(
        'Example_Profile_Phone_Available'
      ),
      accountRecord.Id,
      'controller-success',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    Assert.isNotNull(result, 'A configured Rule should return a result item.');
    Assert.areEqual(
      accountRecord.Id,
      result.evaluation.recordId,
      'The result must retain the requested record identity.'
    );
  }

  @IsTest
  static void evaluateCheckRejectsNamespaceRelativeRuleIdentity() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Controller namespace identity'
    );

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      'Example_Profile_Phone_Available',
      accountRecord.Id,
      'controller-namespace-identity',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      result.evaluation.reasonCode,
      'Every entry point must reject a Rule identity that is not its exact Qualified API Name.'
    );
    Assert.areEqual(
      accountRecord.Id,
      result.evaluation.recordId,
      'The namespace-safe evaluation must retain the requested record identity.'
    );
  }

  @IsTest
  static void lwcPublicationRequiresUserInitiationAndMetadataOptIn() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Integer beforeDml = Limits.getDmlStatements();

    RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Rule',
      accountRecord.Id,
      'automatic-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Assert.areEqual(
      beforeDml,
      Limits.getDmlStatements(),
      'Automatic LWC evaluation must never publish.'
    );

    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Rule',
      accountRecord.Id,
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    // This counts DML statements as a proxy for published events. It stays at
    // one because RecordHealthCheckPluginDispatch takes its side-effect
    // savepoint only when a custom Apex Rule actually runs, and this single
    // Rule is not one.
    Assert.areEqual(
      beforeDml,
      Limits.getDmlStatements(),
      'Per-Rule browser calls must not publish before the run completes.'
    );
    Assert.areNotEqual(
      null,
      result,
      'The user-initiated evaluation still returns its check result.'
    );

    RecordHealthCheckController.completeRun(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id,
      JSON.serialize(new List<RecordHealthCheckResultItem>{ result })
    );
    // Two DML statements: the Set completion event and the side-effect
    // savepoint for the Apex Rule that runs in this fixture. Missing_Rule is not
    // a returned Rule identity, so the publication override emits no Rule event.
    Assert.areEqual(
      beforeDml + 1,
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

    Assert.areEqual(
      true,
      accountAvailability.hasActive,
      'Packaged Account Check Sets should be visible for an Account record.'
    );
    Assert.areEqual(
      false,
      userAvailability.hasActive,
      'User has no packaged Check Sets; expected false.'
    );
    Assert.areEqual(
      false,
      userAvailability.hasInactive,
      'User should not report inactive Check Sets either.'
    );
    Assert.areEqual(false, nullAvailability.hasActive);
    Assert.areEqual(false, nullAvailability.hasInactive);
  }
}
