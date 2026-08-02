/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopePlannerTest {
  private static final String PHONE_RULE = 'Example_Profile_Phone_Available';

  @IsTest
  static void missingSelectionIsRejected() {
    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner().resolveSelection(null);
      Assert.fail('A missing qualified selection must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('qualified selection'),
        'The error must identify the missing selection.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void missingCheckSetIdentityIsRejected() {
    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner().resolveCheckSet('No_Such_Check_Set');
      Assert.fail('An unknown Check Set identity must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('was not found'),
        'The error must identify the missing Check Set.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void ruleWithoutOwningCheckSetIsRejected() {
    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .contextFromRule(
          RecordHealthCheckTestDataFactory.rule(new Map<String, Object>())
        );
      Assert.fail('A Rule without an owning Check Set must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('owning Check Set'),
        'The error must identify the absent owning Check Set.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void scopeValidationRejectsInactiveCheckSet() {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.checkSetActive = false;
    context.objectApiName = 'Account';

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .validateScope(context, new List<Id>());
      Assert.fail('An inactive Check Set must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('inactive'),
        'The error must identify the inactive Check Set.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void formulaBudgetRejectsOversizedPlan() {
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'DisplayFoundFormula__c' => 'Name',
        'DisplayExpectedFormula__c' => 'Name'
      }
    );

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .enforceFormulaBudget(
          new List<Record_Health_Check_Rule__mdt>{ rule },
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE
        );
      Assert.fail('An oversized FormulaEval plan must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('FormulaEval calls'),
        'The error must describe the FormulaEval budget.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void formulaBudgetAccountsForCallsAlreadyUsed() {
    Integer originalCount = RecordHealthCheckFormulaEvaluator.formulaEvalCallCount;
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{ 'EvaluationType__c' => 'FORMULA' }
    );

    Test.startTest();
    try {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;
      new RecordHealthCheckScopePlanner()
        .enforceFormulaBudget(
          new List<Record_Health_Check_Rule__mdt>{ rule },
          1
        );
      Assert.fail(
        'A spent transaction budget must reject another Formula Rule.'
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('0 remain'),
        'The error must report transaction-aware remaining capacity.'
      );
    } finally {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = originalCount;
    }
    Test.stopTest();
  }

  @IsTest
  static void pluginBudgetCountsConstructionAndExecutionSavepoints() {
    List<Record_Health_Check_Rule__mdt> rules = new List<Record_Health_Check_Rule__mdt>();
    Integer apexRuleCount = (Limits.getLimitDmlStatements() / 2) + 1;
    for (Integer index = 0; index < apexRuleCount; index++) {
      rules.add(
        RecordHealthCheckTestDataFactory.rule(
          new Map<String, Object>{ 'EvaluationType__c' => 'APEX' }
        )
      );
    }

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner().enforcePluginSavepointBudget(rules);
      Assert.fail('An oversized plugin savepoint plan must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('PLUGIN_SAVEPOINT_BUDGET_EXCEEDED'),
        'The error must use the stable savepoint-budget reason.'
      );
      Assert.isTrue(
        error.getMessage().contains('required=' + apexRuleCount * 2),
        'The required budget must include construction and execution savepoints.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void activeScopeIgnoresNullRecordIdentity() {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.checkSetActive = true;
    context.objectApiName = 'Account';

    Integer queriesBefore = Limits.getQueries();
    Integer dmlBefore = Limits.getDmlStatements();
    Test.startTest();
    new RecordHealthCheckScopePlanner()
      .validateScope(context, new List<Id>{ null });
    Test.stopTest();

    Assert.areEqual(
      queriesBefore,
      Limits.getQueries(),
      'Ignoring a null identity must not query records.'
    );
    Assert.areEqual(
      dmlBefore,
      Limits.getDmlStatements(),
      'Scope validation must remain read-only.'
    );
  }

  @IsTest
  static void duplicateQualifiedCheckSetIdentityIsRejected() {
    List<Record_Health_Check_Set__mdt> duplicates = new List<Record_Health_Check_Set__mdt>{
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{ 'DeveloperName' => 'First' }
      ),
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{ 'DeveloperName' => 'Second' }
      )
    };

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .requireSingleCheckSet(duplicates, 'Duplicate.Set');
      Assert.fail(
        'An ambiguous qualified Check Set identity must be rejected.'
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('ambiguous'),
        'The error must identify the ambiguous Check Set.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void ruleLimitRejectsTwentySixRules() {
    List<Record_Health_Check_Rule__mdt> rules = new List<Record_Health_Check_Rule__mdt>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
      index++
    ) {
      rules.add(
        RecordHealthCheckTestDataFactory.rule(new Map<String, Object>())
      );
    }

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner().enforceRuleLimit(rules);
      Assert.fail('Twenty-six Rules must exceed the Framework limit.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('FRAMEWORK_MAX_CHECKS_EXCEEDED'),
        'The error must use the stable Framework-limit reason.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void scopeRejectsBlankAndUnknownConfiguredObjects() {
    RecordHealthCheckScopePlanner planner = new RecordHealthCheckScopePlanner();
    List<String> configuredNames = new List<String>{ null, 'Missing__c' };

    Test.startTest();
    for (String configuredName : configuredNames) {
      RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
      context.checkSetActive = true;
      context.objectApiName = configuredName;
      try {
        planner.validateScope(context, new List<Id>{ UserInfo.getUserId() });
        Assert.fail('An invalid configured object must be rejected.');
      } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
        Assert.isTrue(
          error.getMessage().contains('INVALID_OBJECT_API_NAME'),
          'Blank and unknown objects must use the stable configuration error.'
        );
      }
    }
    Test.stopTest();
  }

  private static RecordHealthCheckScopePipeline.SelectionContext evaluationContext() {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetDeveloperName = 'Synthetic_Set';
    context.showDiagnostics = false;
    return context;
  }

  private static Record_Health_Check_Rule__mdt queryCountRule(
    String developerName,
    String failureMessage
  ) {
    return RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'QualifiedApiName' => developerName,
        'DeveloperName' => developerName,
        'CheckTitle__c' => developerName,
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'QUERY',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'SourceQuery__c' => 'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'total',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ExpectedValueSource__c' => 'FIXED_VALUE',
        'ExpectedFixedValue__c' => '0',
        'ComparisonOperator__c' => 'GREATER_THAN',
        'EmptyValueHandling__c' => 'AS_NO_MATCH',
        'NoRowsResult__c' => 'PASS',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => failureMessage,
        'UnableToEvaluateMessage__c' => 'Unable.',
        'MaxQueryRows__c' => 100
      }
    );
  }

  private static Record_Health_Check_Rule__mdt buildRuleWithPrerequisite(
    String prerequisiteName
  ) {
    return RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'DeveloperName' => 'Rule_B',
        'QualifiedApiName' => 'namespace__Rule_B',
        'PrerequisiteRule__c' => prerequisiteName
      }
    );
  }

  private static RecordHealthCheckResultItem buildPrerequisiteResultItem(
    Id recordId,
    String qualifiedRuleName,
    String status
  ) {
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.recordId = recordId;
    item.evaluation.ruleQualifiedApiName = qualifiedRuleName;
    item.evaluation.status = status;
    return item;
  }
}
