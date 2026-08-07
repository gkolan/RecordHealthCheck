@IsTest
private with sharing class RecordHealthCheckAutomationFlowTest {
  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void flowActionsRejectUsersWithoutRunPermission() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckRunRuleFlowAction.Request ruleRequest = new RecordHealthCheckRunRuleFlowAction.Request();
    ruleRequest.ruleQualifiedApiName = 'Missing.Rule';
    ruleRequest.recordId = recordId;
    ruleRequest.eventPublication = 'NONE';
    RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
    setRequest.checkSetQualifiedApiName = 'Missing.Set';
    setRequest.recordId = recordId;
    setRequest.eventPublication = 'NONE';

    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      List<RecordHealthCheckRunRuleFlowAction.Response> ruleOutputs = RecordHealthCheckRunRuleFlowAction.runRule(
        new List<RecordHealthCheckRunRuleFlowAction.Request>{ ruleRequest }
      );
      List<RecordHealthCheckRunSetFlowAction.Response> setOutputs = RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
      );
      Assert.areEqual('AUTHORIZATION', ruleOutputs[0].errorType);
      Assert.areEqual('AUTHORIZATION', setOutputs[0].errorType);
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void missingMetadataGroupsReturnAlignedExecutionErrors() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckRunRuleFlowAction.Request ruleRequest = new RecordHealthCheckRunRuleFlowAction.Request();
    ruleRequest.ruleQualifiedApiName = 'Missing.Rule';
    ruleRequest.recordId = recordId;
    ruleRequest.eventPublication = 'NONE';
    RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
    setRequest.checkSetQualifiedApiName = 'Missing.Set';
    setRequest.recordId = recordId;
    setRequest.eventPublication = 'NONE';

    Test.startTest();
    List<RecordHealthCheckRunRuleFlowAction.Response> ruleOutputs = RecordHealthCheckRunRuleFlowAction.runRule(
      new List<RecordHealthCheckRunRuleFlowAction.Request>{ ruleRequest }
    );
    List<RecordHealthCheckRunSetFlowAction.Response> setOutputs = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
    );
    Test.stopTest();

    Assert.areEqual('EXECUTION', ruleOutputs[0].errorType);
    Assert.areEqual('EXECUTION', setOutputs[0].errorType);
  }

  @IsTest
  static void flowExecutorPropagatesFatalPluginSideEffects() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Flow fatal side-effect propagation'
    );
    String groupKey = RecordHealthCheckFlowGroupExecutor.key(
      RecordHealthCheckTestDataFactory.qualifiedRuleName(
        'Example_Profile_Phone_Available'
      ),
      'NONE'
    );

    RecordHealthCheckScopePipeline.evaluatorFailureOverride = 'SIDE_EFFECT';
    Test.startTest();
    try {
      RecordHealthCheckFlowGroupExecutor.evaluate(
        groupKey,
        new List<Id>{ accountRecord.Id },
        RecordHealthCheckFlowGroupExecutor.SelectionKind.RULE
      );
      Assert.fail('A fatal plugin side effect must escape the Flow executor.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
        error.reasonCode,
        'The Flow executor must preserve the fatal side-effect reason.'
      );
      Assert.areEqual(
        'DML',
        error.effect,
        'The Flow executor must preserve the detected effect.'
      );
      Assert.isTrue(
        error.reversible,
        'The Flow executor must preserve rollback semantics.'
      );
    } finally {
      RecordHealthCheckScopePipeline.evaluatorFailureOverride = null;
      Test.stopTest();
    }
  }

  @IsTest
  static void flowActionsCanonicalizeAndBoundQualifiedIdentities() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckRunRuleFlowAction.Request ruleRequest = new RecordHealthCheckRunRuleFlowAction.Request();
    ruleRequest.ruleQualifiedApiName = '  Missing.Rule  ';
    ruleRequest.recordId = recordId;
    RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
    setRequest.checkSetQualifiedApiName = overlongIdentity();
    setRequest.recordId = recordId;

    Test.startTest();
    List<RecordHealthCheckRunRuleFlowAction.Response> ruleOutputs = RecordHealthCheckRunRuleFlowAction.runRule(
      new List<RecordHealthCheckRunRuleFlowAction.Request>{ ruleRequest }
    );
    List<RecordHealthCheckRunSetFlowAction.Response> setOutputs = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
    );
    Test.stopTest();

    Assert.areEqual('Missing.Rule', ruleRequest.ruleQualifiedApiName);
    Assert.areEqual(
      'VALIDATION',
      ruleOutputs[0].errorType,
      'Missing required Event Publication must be a validation error.'
    );
    Assert.areEqual('VALIDATION', setOutputs[0].errorType);
    Assert.isTrue(
      setOutputs[0].errorMessage.contains('must not exceed 255 characters')
    );
  }

  @IsTest
  static void flowActionsMapAlignmentAndPayloadBoundaryFailures() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Flow boundary fixture'
    );
    RecordHealthCheckRunRuleFlowAction.Request ruleRequest = new RecordHealthCheckRunRuleFlowAction.Request();
    ruleRequest.ruleQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedRuleName(
      'Example_Profile_Phone_Available'
    );
    ruleRequest.recordId = accountRecord.Id;
    ruleRequest.eventPublication = 'NONE';
    RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
    setRequest.checkSetQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Account_Data_Quality'
    );
    setRequest.recordId = accountRecord.Id;
    setRequest.eventPublication = 'NONE';

    try {
      RecordHealthCheckFlowSupport.itemsByRecordOverride = new Map<Id, List<RecordHealthCheckResultItem>>();
      List<RecordHealthCheckRunRuleFlowAction.Response> missingRule = RecordHealthCheckRunRuleFlowAction.runRule(
        new List<RecordHealthCheckRunRuleFlowAction.Request>{ ruleRequest }
      );
      Assert.areEqual('EXECUTION', missingRule[0].errorType);

      RecordHealthCheckFlowSupport.itemsByRecordOverride = null;
      RecordHealthCheckFlowSupport.nullItemsByRecordOverride = true;
      List<RecordHealthCheckRunSetFlowAction.Response> emptySet = RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
      );
      Assert.isTrue(emptySet[0].isSuccess);
      Assert.areEqual('SKIPPED', emptySet[0].status);

      RecordHealthCheckFlowSupport.nullItemsByRecordOverride = false;
      RecordHealthCheckFlowSupport.itemsByRecordOverride = new Map<Id, List<RecordHealthCheckResultItem>>{
        accountRecord.Id => new List<RecordHealthCheckResultItem>{ null }
      };
      List<RecordHealthCheckRunSetFlowAction.Response> malformedSet = RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
      );
      Assert.areEqual('EXECUTION', malformedSet[0].errorType);

      RecordHealthCheckFlowSupport.itemsByRecordOverride = null;
      RecordHealthCheckFlowSupport.payloadBudgetStartOverride = RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS;
      List<RecordHealthCheckRunRuleFlowAction.Response> oversizedRule = RecordHealthCheckRunRuleFlowAction.runRule(
        new List<RecordHealthCheckRunRuleFlowAction.Request>{ ruleRequest }
      );
      List<RecordHealthCheckRunSetFlowAction.Response> oversizedSet = RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
      );
      Assert.areEqual('LIMIT', oversizedRule[0].errorType);
      Assert.areEqual('LIMIT', oversizedSet[0].errorType);
    } finally {
      RecordHealthCheckFlowSupport.itemsByRecordOverride = null;
      RecordHealthCheckFlowSupport.nullItemsByRecordOverride = false;
      RecordHealthCheckFlowSupport.payloadBudgetStartOverride = null;
    }
  }

  @IsTest
  static void rejectsExcessiveRuleGroupsBeforeEvaluation() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    List<RecordHealthCheckRunRuleFlowAction.Request> requests = new List<RecordHealthCheckRunRuleFlowAction.Request>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_FLOW_GROUPS;
      index++
    ) {
      RecordHealthCheckRunRuleFlowAction.Request input = new RecordHealthCheckRunRuleFlowAction.Request();
      input.ruleQualifiedApiName = 'Hostile.Rule.' + index;
      input.recordId = recordId;
      input.eventPublication = 'NONE';
      requests.add(input);
    }

    Test.startTest();
    List<RecordHealthCheckRunRuleFlowAction.Response> outputs = RecordHealthCheckRunRuleFlowAction.runRule(
      requests
    );
    Test.stopTest();

    Assert.areEqual(
      requests.size(),
      outputs.size(),
      'Outputs must stay aligned.'
    );
    for (RecordHealthCheckRunRuleFlowAction.Response output : outputs) {
      Assert.isFalse(output.isSuccess, 'No excessive group may execute.');
      Assert.areEqual('LIMIT', output.errorType, 'Fan-out is a limit error.');
      Assert.isTrue(
        output.errorMessage.contains('MAX_FLOW_GROUPS_EXCEEDED'),
        'The stable group-limit code must be returned.'
      );
    }
  }

  @IsTest
  static void excessiveSetGroupsPreserveExistingValidationErrors() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    List<RecordHealthCheckRunSetFlowAction.Request> requests = new List<RecordHealthCheckRunSetFlowAction.Request>();
    requests.add(new RecordHealthCheckRunSetFlowAction.Request());
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_FLOW_GROUPS;
      index++
    ) {
      RecordHealthCheckRunSetFlowAction.Request input = new RecordHealthCheckRunSetFlowAction.Request();
      input.checkSetQualifiedApiName = 'Hostile.Set.' + index;
      input.recordId = recordId;
      input.eventPublication = 'NONE';
      requests.add(input);
    }

    Test.startTest();
    List<RecordHealthCheckRunSetFlowAction.Response> outputs = RecordHealthCheckRunSetFlowAction.runSet(
      requests
    );
    Test.stopTest();

    Assert.areEqual(
      requests.size(),
      outputs.size(),
      'Outputs must stay aligned.'
    );
    Assert.areEqual(
      'VALIDATION',
      outputs[0].errorType,
      'The invalid row must retain its specific error.'
    );
    for (Integer index = 1; index < outputs.size(); index++) {
      Assert.areEqual(
        'LIMIT',
        outputs[index].errorType,
        'Every valid excessive group must be rejected.'
      );
    }
  }

  @IsTest
  static void payloadBudgetCoversExactOverflowAndMissingAccumulator() {
    Test.startTest();
    Integer exact = RecordHealthCheckFlowSupport.consumePayloadBudget(
      RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS - 1,
      'x'
    );
    Integer fromZero = RecordHealthCheckFlowSupport.consumePayloadBudget(
      null,
      'x'
    );
    try {
      RecordHealthCheckFlowSupport.consumePayloadBudget(
        RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS,
        'x'
      );
      Assert.fail('One character above the response budget must fail.');
    } catch (RecordHealthCheckFlowSupport.PayloadBudgetException expected) {
      Assert.isTrue(
        expected.getMessage().contains('FLOW_RESPONSE_BUDGET_EXCEEDED'),
        'The stable response-budget code must be returned.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS,
      exact,
      'The exact configured boundary must remain usable.'
    );
    Assert.areEqual(1, fromZero, 'A missing accumulator must begin at zero.');
  }

  private static String overlongIdentity() {
    String value = '';
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH;
      index++
    ) {
      value += 'x';
    }
    return value;
  }

  @IsTest
  static void flowSupportAlignsMatchingAndMalformedResults() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckResultItem matching = new RecordHealthCheckResultItem();
    matching.evaluation = new RecordHealthCheckEvaluationResult();
    matching.evaluation.recordId = recordId;
    RecordHealthCheckResultItem missingIdentity = new RecordHealthCheckResultItem();
    missingIdentity.evaluation = new RecordHealthCheckEvaluationResult();
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.results.add(missingIdentity);
    response.results.add(matching);

    Test.startTest();
    RecordHealthCheckResultItem aligned = RecordHealthCheckFlowSupport.itemForRecord(
      response,
      recordId
    );
    Map<Id, List<RecordHealthCheckResultItem>> nullIndex = RecordHealthCheckFlowSupport.itemsByRecord(
      null
    );
    Map<Id, List<RecordHealthCheckResultItem>> indexed = RecordHealthCheckFlowSupport.itemsByRecord(
      response
    );
    Test.stopTest();

    Assert.areEqual(
      matching,
      aligned,
      'The matching result must stay aligned.'
    );
    Assert.isTrue(nullIndex.isEmpty(), 'A null response must index no rows.');
    Assert.areEqual(
      1,
      indexed.get(recordId).size(),
      'A result without a record identity must be ignored.'
    );
  }

  @IsTest
  static void excessiveRuleGroupsPreserveExistingValidationErrors() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    List<RecordHealthCheckRunRuleFlowAction.Request> requests = new List<RecordHealthCheckRunRuleFlowAction.Request>{
      new RecordHealthCheckRunRuleFlowAction.Request()
    };
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_FLOW_GROUPS;
      index++
    ) {
      RecordHealthCheckRunRuleFlowAction.Request input = new RecordHealthCheckRunRuleFlowAction.Request();
      input.ruleQualifiedApiName = 'Hostile.Rule.' + index;
      input.recordId = recordId;
      input.eventPublication = 'NONE';
      requests.add(input);
    }

    Test.startTest();
    List<RecordHealthCheckRunRuleFlowAction.Response> outputs = RecordHealthCheckRunRuleFlowAction.runRule(
      requests
    );
    Test.stopTest();

    Assert.areEqual(
      'VALIDATION',
      outputs[0].errorType,
      'The invalid row must retain its validation error.'
    );
    Assert.areEqual(
      'LIMIT',
      outputs[1].errorType,
      'Valid rows must receive the group-limit error.'
    );
  }

  @IsTest
  static void bulkifiesTwoHundredDuplicateRows() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Two hundred duplicate Flow rows'
    );
    List<RecordHealthCheckRunRuleFlowAction.Request> requests = new List<RecordHealthCheckRunRuleFlowAction.Request>();
    for (
      Integer index = 0;
      index < RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      RecordHealthCheckRunRuleFlowAction.Request input = new RecordHealthCheckRunRuleFlowAction.Request();
      input.ruleQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedRuleName(
        'Example_Profile_Phone_Available'
      );
      input.recordId = accountRecord.Id;
      input.eventPublication = 'NONE';
      requests.add(input);
    }

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    List<RecordHealthCheckRunRuleFlowAction.Response> outputs = RecordHealthCheckRunRuleFlowAction.runRule(
      requests
    );
    Integer queriesUsed = Limits.getQueries() - queriesBefore;
    Test.stopTest();

    Assert.areEqual(200, outputs.size(), 'Every Flow row needs a response.');
    Assert.isTrue(
      queriesUsed <= 20,
      'One group must use a bounded query budget; used=' + queriesUsed
    );
    for (RecordHealthCheckRunRuleFlowAction.Response output : outputs) {
      Assert.isTrue(
        output.isSuccess,
        'Every duplicate row must reuse the result.'
      );
    }
  }
}
