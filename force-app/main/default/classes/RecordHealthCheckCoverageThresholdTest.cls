/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckCoverageThresholdTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @IsTest
  static void setResultCoversEveryStatusAndRollupPriority() {
    RecordHealthCheckSetResult emptyResult = new RecordHealthCheckSetResult();
    emptyResult.finish();
    System.assertEquals('SKIPPED', emptyResult.status);

    RecordHealthCheckSetResult result = new RecordHealthCheckSetResult();
    result.add(resultWithStatus('PASS'));
    result.finish();
    System.assertEquals('PASS', result.status);

    result.add(resultWithStatus('SKIPPED'));
    System.assertEquals(1, result.skippedCount);
    result.add(resultWithStatus('FAIL'));
    result.finish();
    System.assertEquals('FAIL', result.status);

    result.add(resultWithStatus('UNABLE_TO_EVALUATE'));
    result.add(resultWithStatus(null));
    result.finish();
    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals(2, result.unableCount);

    result.add(resultWithStatus('ERROR'));
    result.finish();
    System.assertEquals('ERROR', result.status);
    System.assertEquals(1, result.systemErrorCount);
    System.assertEquals(6, result.results.size());
  }

  @IsTest
  static void facadeCoversEmptyNullAndLookupBranches() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    System.assertEquals(
      'Account_Data_Quality',
      new RecordHealthCheckConfigService()
        .findCheckSetDeveloperName('Account_DQ_BillingCity')
    );
    System.assertEquals(
      null,
      new RecordHealthCheckConfigService().findCheckSetDeveloperName(' ')
    );
    System.assertEquals(
      null,
      new RecordHealthCheckConfigService()
        .findCheckSetDeveloperName('No_Such_Rule')
    );

    System.assertEquals(
      0,
      RecordHealthCheck.runRule('Account_DQ_BillingCity', new List<Id>()).size()
    );
    System.assertEquals(
      0,
      RecordHealthCheck.runSet('Account_Data_Quality', new List<Id>()).size()
    );
    assertRequestFailureForNullRuleList();
    assertRequestFailureForNullSetList();

    RecordHealthCheckResult generatedRun = RecordHealthCheck.runRule(
      'Account_DQ_BillingCity',
      accountRecord.Id
    );
    System.assert(generatedRun.runId.startsWith('api-'));

    List<RecordHealthCheckSetResult> setResults = RecordHealthCheck.runSet(
      'Account_Data_Quality',
      new List<Id>{ accountRecord.Id }
    );
    System.assertEquals(1, setResults.size());

    List<Id> tooManyRecords = new List<Id>();
    for (
      Integer index = 0;
      index <= RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL;
      index++
    ) {
      tooManyRecords.add(accountRecord.Id);
    }
    try {
      RecordHealthCheck.runRule('Account_DQ_BillingCity', tooManyRecords);
      System.assert(false, 'Expected the evaluation limit to fail.');
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('too many checks'));
    }
  }

  @IsTest
  static void coversSmallValidatorAndControllerBranches() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
    RecordHealthCheckSetAvailability blankAvailability = configService.getCheckSetAvailabilityForObject(
      ' '
    );
    System.assertEquals(false, blankAvailability.hasActive);
    System.assertNotEquals(
      null,
      configService.loadRule('Account_DQ_BillingCity', 'Account_Data_Quality')
    );
    try {
      configService.getDefinitionResponse(' ', null);
      System.assert(false, 'Expected a blank Check Set to fail.');
    } catch (RecordHealthCheckConfigService.ConfigException expected) {
      System.assertEquals('CONFIG_NOT_FOUND', expected.reasonCode);
    }

    System.assertEquals(
      null,
      RecordHealthCheckConfigValidator.firstTemplateIssue(null)
    );
    Record_Health_Check_Rule__mdt invalidRule = new Record_Health_Check_Rule__mdt(
      FailureMessage__c = '{!bad.value}' // legacy-token-ok: intentional rejected-token fixture
    );
    System.assertNotEquals(
      null,
      RecordHealthCheckConfigValidator.firstTemplateIssue(invalidRule)
    );
    System.assertEquals(
      false,
      RecordHealthCheckConfigValidator.isValidApexPlugin(' ')
    );
    try {
      RecordHealthCheckController.getCheckDefinitions(' ', null, null);
      System.assert(false, 'Expected blank Check Set validation to fail.');
    } catch (AuraHandledException expected) {
      System.assert(expected.getMessage().contains('CONFIG_NOT_FOUND'));
    }
  }

  @IsTest
  static void engineMapsDeletedRecordsToNotAccessible() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account deletedAccount = RecordHealthCheckTestDataFactory.createDeletedAccount(
      'Delete me'
    );

    RecordHealthCheckResult result = new RecordHealthCheckEngine()
      .evaluate(
        'Account_Data_Quality',
        'Account_DQ_BillingCity',
        deletedAccount.Id
      );
    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals('CANNOT_EVALUATE', result.reasonCode);
  }

  @IsTest
  static void coversRemainingEngineAndConstantBoundaries() {
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Bad_Applicability_Query',
      CheckTitle__c = 'Bad applicability query',
      ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM NoSuchObject',
      ApplicabilityCountOperator__c = 'EQUALS',
      ApplicabilityCountThreshold__c = 0
    );
    System.assertEquals(
      'INVALID_SOQL_TEMPLATE',
      engine.checkSoqlApplicability(rule, new Account(Name = 'Test')).reasonCode
    );
    // An org with more than one currency also loads CurrencyIsoCode, so a
    // Currency value can be shown in the currency its own record uses.
    Set<String> expectedRecordFields = new Set<String>{ 'Id' };
    if (UserInfo.isMultiCurrencyOrganization()) {
      expectedRecordFields.add('CurrencyIsoCode');
    }
    System.assertEquals(
      expectedRecordFields,
      engine.collectRecordFields(
        new Record_Health_Check_Rule__mdt(EvaluationType__c = 'FORMULA'),
        Account.SObjectType
      )
    );
    System.assertEquals(
      'FailuresOnly',
      RecordHealthCheckConstants.toLwcComparisonDisplay('FAILURES_ONLY')
    );
    System.assertEquals(
      'AllRows',
      RecordHealthCheckConstants.toLwcComparisonDisplay('ALL_ROWS')
    );

    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    try {
      service.validateActiveRulesForDefinition(
        new List<Record_Health_Check_Rule__mdt>(),
        'No_Rules'
      );
      System.assert(false, 'Expected an empty rule list to fail.');
    } catch (RecordHealthCheckConfigService.ConfigException expected) {
      System.assertEquals('NO_ACTIVE_CHECKS', expected.reasonCode);
    }
    System.assertEquals(
      'INVALID_CHECK_TYPE',
      service
        .validateRuleForEvaluation(
          new Record_Health_Check_Rule__mdt(
            CheckTitle__c = 'Unknown type',
            EvaluationOrder__c = 1,
            EvaluationType__c = 'UNKNOWN',
            FailureSeverity__c = 'WARNING',
            FailureMessage__c = 'Failure',
            ApplicabilityMode__c = 'ALL_RECORDS'
          )
        )
        .reasonCode
    );
    service.logCheckLimitExceeded('Coverage_Set', null, 30);

    RecordHealthCheckResult inaccessible = engine.recordNotAccessibleResult(
      new Record_Health_Check_Rule__mdt(
        DeveloperName = 'Record_Access',
        CheckTitle__c = 'Record access',
        EvaluationOrder__c = 9,
        UnableToEvaluateMessage__c = 'Cannot read this record.'
      ),
      'No access'
    );
    System.assertEquals('RECORD_NOT_ACCESSIBLE', inaccessible.reasonCode);
    System.assertEquals('Cannot read this record.', inaccessible.message);
    System.assertEquals('No access', inaccessible.detailMessage);
    RecordHealthCheckResult defaultMessage = engine.recordNotAccessibleResult(
      new Record_Health_Check_Rule__mdt(DeveloperName = 'Default_Message'),
      'Missing'
    );
    System.assertEquals(
      'This check could not be evaluated.',
      defaultMessage.message
    );
    RecordHealthCheckResult handled = engine.handleRecordLoadException(
      new Record_Health_Check_Rule__mdt(
        DeveloperName = 'Handled_Access',
        UnableToEvaluateMessage__c = 'Handled'
      ),
      new RecordHealthCheckConfigService.ConfigException('Denied', 'DENIED'),
      new RecordHealthCheckLogger('run', 'set', null),
      false
    );
    System.assertEquals('CANNOT_EVALUATE', handled.reasonCode);
    System.assertEquals(
      'NO_RECORD_CONTEXT',
      engine
        .evaluate(
          'Account_Data_Quality',
          'Account_DQ_BillingCity',
          null,
          'coverage-run',
          UserInfo.getUserId()
        )
        .reasonCode
    );
  }

  @IsTest
  static void formulaApplicabilityPreservesTypedLimitReason() {
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 95;
    String[] reasonCode = new List<String>{ null };
    try {
      System.assertEquals(
        null,
        evaluator.evaluateApplicabilityFormula(
          'TRUE',
          new Account(Name = 'Formula limit'),
          reasonCode
        )
      );
      System.assertEquals('FORMULA_EVAL_LIMIT', reasonCode[0]);
    } finally {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    }
  }

  @IsTest
  static void ruleFlowActionCoversNullSuccessAndLimits() {
    System.assertEquals(
      0,
      RecordHealthCheckRunRuleFlowAction.runRule(null).size()
    );
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunRuleFlowAction.Request request = new RecordHealthCheckRunRuleFlowAction.Request();
    request.ruleDeveloperName = 'Account_DQ_BillingCity';
    request.recordId = accountRecord.Id;
    List<RecordHealthCheckRunRuleFlowAction.Response> responses = RecordHealthCheckRunRuleFlowAction.runRule(
      new List<RecordHealthCheckRunRuleFlowAction.Request>{ request }
    );
    System.assertEquals(1, responses.size());
    System.assertNotEquals(null, responses[0].status);
    System.assertNotEquals(null, responses[0].resultJson);

    List<RecordHealthCheckRunRuleFlowAction.Request> tooMany = new List<RecordHealthCheckRunRuleFlowAction.Request>();
    for (
      Integer index = 0;
      index <= RecordHealthCheck.MAX_EVALUATIONS_PER_CALL;
      index++
    ) {
      tooMany.add(request);
    }
    try {
      RecordHealthCheckRunRuleFlowAction.runRule(tooMany);
      System.assert(
        false,
        'Expected the evaluation cap to reject the request.'
      );
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('too many checks'));
    }

    tooMany.clear();
    for (
      Integer index = 0;
      index <= RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL;
      index++
    ) {
      tooMany.add(request);
    }
    try {
      RecordHealthCheckRunRuleFlowAction.runRule(tooMany);
      System.assert(false, 'Expected the record cap to reject the request.');
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('at most'));
    }
  }

  @IsTest
  static void setFlowActionCoversNullSuccessAndRecordLimit() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    System.assertEquals(
      0,
      RecordHealthCheckRunSetFlowAction.runSet(null).size()
    );
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunSetFlowAction.Request request = new RecordHealthCheckRunSetFlowAction.Request();
    request.checkSetDeveloperName = 'Account_Data_Quality';
    request.recordId = accountRecord.Id;
    List<RecordHealthCheckRunSetFlowAction.Response> responses = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ request }
    );
    System.assertEquals(1, responses.size());
    System.assertNotEquals(null, responses[0].passedCount);
    System.assertNotEquals(null, responses[0].resultJson);

    List<RecordHealthCheckRunSetFlowAction.Request> overEvaluationLimit = new List<RecordHealthCheckRunSetFlowAction.Request>();
    for (
      Integer index = 0;
      index <= RecordHealthCheck.MAX_EVALUATIONS_PER_CALL;
      index++
    ) {
      overEvaluationLimit.add(request);
    }
    try {
      RecordHealthCheckRunSetFlowAction.runSet(overEvaluationLimit);
      System.assert(
        false,
        'Expected the evaluation cap to reject the request.'
      );
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('too many checks'));
    }

    List<RecordHealthCheckRunSetFlowAction.Request> tooMany = new List<RecordHealthCheckRunSetFlowAction.Request>();
    for (
      Integer index = 0;
      index <= RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL;
      index++
    ) {
      tooMany.add(request);
    }
    try {
      RecordHealthCheckRunSetFlowAction.runSet(tooMany);
      System.assert(false, 'Expected the record cap to reject the request.');
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('at most'));
    }
  }

  private static RecordHealthCheckResult resultWithStatus(String status) {
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = status;
    return result;
  }

  private static void assertRequestFailureForNullRuleList() {
    try {
      RecordHealthCheck.runRule('Account_DQ_BillingCity', (List<Id>) null);
      System.assert(false, 'Expected null Rule record IDs to fail.');
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('required'));
    }
  }

  private static void assertRequestFailureForNullSetList() {
    try {
      RecordHealthCheck.runSet('Account_Data_Quality', (List<Id>) null);
      System.assert(false, 'Expected null Set record IDs to fail.');
    } catch (RecordHealthCheck.RecordHealthCheckRequestException expected) {
      System.assert(expected.getMessage().contains('required'));
    }
  }
}
