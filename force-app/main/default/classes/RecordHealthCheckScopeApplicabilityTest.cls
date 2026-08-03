/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopeApplicabilityTest {
  private static final String PHONE_RULE = 'Example_Profile_Phone_Available';

  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void helperBranchesCoverEmptyScopeApplicabilityAndComparisons() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Applicability' }
    );
    Record_Health_Check_Rule__mdt falseRule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'FALSE',
        'ApplicabilityNotMetMessage__c' => 'Not applicable',
        'UnableToEvaluateMessage__c' => 'Unable'
      }
    );
    Record_Health_Check_Rule__mdt invalidRule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'NOT_VALID(',
        'ApplicabilityNotMetMessage__c' => 'Not applicable',
        'UnableToEvaluateMessage__c' => 'Unable'
      }
    );

    Test.startTest();
    RecordHealthCheckResponse emptyResponse = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forRule(
        RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
        new List<Id>()
      )
    );
    RecordHealthCheckInternalResult skipped = resultSupport.applicabilityResult(
      falseRule,
      record
    );
    RecordHealthCheckInternalResult unable = resultSupport.applicabilityResult(
      invalidRule,
      record
    );
    RecordHealthCheckInternalResult applicable = resultSupport.applicabilityResult(
      RecordHealthCheckTestDataFactory.rule(
        new Map<String, Object>{
          'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
          'ApplicabilityFormula__c' => 'TRUE'
        }
      ),
      record
    );
    List<Boolean> comparisons = new List<Boolean>{
      resultSupport.compareCount('EQUALS', 2, 2),
      resultSupport.compareCount('NOT_EQUALS', 1, 2),
      resultSupport.compareCount('GREATER_THAN', 2, 1),
      resultSupport.compareCount('GREATER_THAN_OR_EQUAL', 2, 2),
      resultSupport.compareCount('LESS_THAN', 1, 2),
      resultSupport.compareCount('LESS_THAN_OR_EQUAL', 2, 2)
    };
    Test.stopTest();

    Assert.areEqual(
      0,
      emptyResponse.results.size(),
      'An empty scope returns no items.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      skipped.status,
      'False applicability skips.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      unable.status,
      'Invalid applicability is unable.'
    );
    Assert.isNull(
      applicable,
      'A true applicability formula continues evaluation.'
    );
    Assert.areEqual(
      6,
      comparisons.size(),
      'Every comparison operator should execute.'
    );
  }

  @IsTest
  static void countApplicabilityQueriesOnceAndSkipsBeforeEvaluation() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account applicable = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Applicable', 'AnnualRevenue' => 100 }
    );
    Account skipped = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Skipped', 'AnnualRevenue' => 100 }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ applicable, skipped }
    );
    RecordHealthCheckTestDataFactory.createOpportunity(
      RecordHealthCheckTestDataFactory.opportunity(
        new Map<String, Object>{
          'Name' => 'Open Pipeline',
          'AccountId' => applicable.Id,
          'StageName' => 'Prospecting',
          'CloseDate' => Date.today().addDays(30),
          'Amount' => 100
        }
      )
    );
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forRule(
      RecordHealthCheckTestDataFactory.qualifiedRuleName(
        'Example_Pipeline_Protects_Revenue'
      ),
      new List<Id>{ skipped.Id, applicable.Id }
    );

    RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    Test.startTest();
    Integer beforeQueries = Limits.getQueries();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Integer queryDelta = Limits.getQueries() - beforeQueries;
    Test.stopTest();

    Assert.areEqual(
      4,
      queryDelta,
      'The request should use metadata, record load, one applicability query, and one source query.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      response.results[0].evaluation.status,
      'A record below the count threshold should be skipped in place.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      response.results[1].evaluation.status,
      'Only the applicable record should reach the query evaluator.'
    );
  }

  @IsTest
  static void defensiveHelpersPreserveStableResults() {
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityNotMetMessage__c' => 'Not applicable.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult notMigrated = resultSupport.applicabilityResult(
      rule,
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Applicability' }
      )
    );
    RecordHealthCheckInternalResult skipped = resultSupport.skippedResult(rule);
    Boolean invalidComparison = resultSupport.compareCount('UNKNOWN', 1, 1);
    String blankUrl = resultSupport.sanitizeActionUrl(' ');
    String unsafeUrl = resultSupport.sanitizeActionUrl('//example.com');
    String safeUrl = resultSupport.sanitizeActionUrl('/lightning/page/home');
    Test.stopTest();

    Assert.areEqual('APPLICABILITY_NOT_MIGRATED', notMigrated.reasonCode);
    Assert.areEqual('Not applicable.', skipped.message);
    Assert.isNull(invalidComparison, 'An unknown count operator is invalid.');
    Assert.isNull(blankUrl, 'A blank action URL must be omitted.');
    Assert.isNull(
      unsafeUrl,
      'A protocol-relative action URL must be rejected.'
    );
    Assert.areEqual('/lightning/page/home', safeUrl);
  }

  @IsTest
  static void malformedCountApplicabilityReturnsStableUnavailableResult() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Count applicability' }
      )
    );
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityCountQuery__c' => 'SELECT Id FROM Contact',
        'ApplicabilityCountThreshold__c' => 1,
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        rule,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account }
      );
    Test.stopTest();

    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      results.get(account.Id).reasonCode
    );
  }

  @IsTest
  static void unknownCountApplicabilityOperatorReturnsUnavailable() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Unknown count operator' }
      )
    );
    Record_Health_Check_Rule__mdt rule = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityCountQuery__c' => 'SELECT COUNT(Id) total FROM Contact WHERE AccountId = {!record.Id}',
        'ApplicabilityCountOperator__c' => 'UNKNOWN',
        'ApplicabilityCountThreshold__c' => 0,
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        rule,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account }
      );
    Test.stopTest();

    Assert.areEqual('INVALID_OPERATOR', results.get(account.Id).reasonCode);
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
