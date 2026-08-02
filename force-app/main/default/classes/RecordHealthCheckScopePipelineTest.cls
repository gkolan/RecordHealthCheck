/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopePipelineTest {
  private static final String PHONE_RULE = 'Example_Profile_Phone_Available';

  @IsTest
  static void qualifiedRuleEvaluatesDeduplicatedScopeInInputOrder() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account first = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'First', 'Phone' => '312-555-0100' }
    );
    Account second = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Second', 'Phone' => '312-555-0200' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ first, second }
    );

    RecordHealthCheckRequest request = RecordHealthCheckRequest.forRule(
      RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
      new List<Id>{ second.Id, first.Id, second.Id }
    );

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Test.stopTest();

    Assert.areEqual(
      new List<Id>{ second.Id, first.Id },
      response.recordIds,
      'The response should preserve first-seen input order and remove duplicates.'
    );
    Assert.areEqual(
      2,
      response.results.size(),
      'One Rule should return one item per record.'
    );
    Assert.areEqual(
      second.Id,
      response.results[0].evaluation.recordId,
      'The first item should match input order.'
    );
    Assert.areEqual(
      first.Id,
      response.results[1].evaluation.recordId,
      'The second item should match input order.'
    );
    Assert.areEqual(
      2,
      response.summary.passed,
      'Both populated phone records should pass.'
    );
    Assert.isNull(
      response.results[0].display,
      'Evaluation mode should omit display content.'
    );
  }

  @IsTest
  static void displayModeAddsDisplayWithoutChangingEnvelope() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Missing Phone' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forRule(
        RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
        account.Id
      )
      .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY);

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);

    Assert.areEqual(
      1,
      response.results.size(),
      'The Rule should return one result item.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      response.results[0].evaluation.status,
      'A blank phone should fail.'
    );
    Assert.isNotNull(
      response.results[0].display,
      'Display mode should attach display content.'
    );
    Assert.isNotNull(
      response.results[0].display.renderedMessage,
      'A failure should render its configured message.'
    );
  }

  @IsTest
  static void summaryModeOmitsPassingItemsButRetainsCounts() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Passing Phone',
        'Phone' => '312-555-0300'
      }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forRule(
        RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
        account.Id
      )
      .withResultMode(RecordHealthCheckResultMode.SUMMARY);

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);

    Assert.areEqual(
      1,
      response.summary.passed,
      'The summary should count a passing Rule.'
    );
    Assert.areEqual(
      0,
      response.results.size(),
      'Summary mode should omit non-actionable items.'
    );
  }

  @IsTest
  static void publicationOptionsAreCallerDrivenAndFilterBeforeMetadata() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Silent Default',
        'Phone' => '312-555-0400'
      }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    Integer beforeDefault = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forRule(
        RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
        account.Id
      )
    );
    Assert.areEqual(
      0,
      Limits.getDmlStatements() - beforeDefault,
      'The default programmatic request must publish nothing.'
    );

    Integer beforeActionable = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forRule(
          RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
          account.Id
        )
        .withEventPublication(RecordHealthCheckEventPublication.ACTIONABLE)
    );
    Assert.areEqual(
      0,
      Limits.getDmlStatements() - beforeActionable,
      'ACTIONABLE should publish nothing for an all-pass response.'
    );

    Integer beforeAll = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forRule(
          RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
          account.Id
        )
        .withEventPublication(RecordHealthCheckEventPublication.ALL)
    );
    Assert.isTrue(
      Limits.getDmlStatements() > beforeAll,
      'ALL should publish lifecycle events for a passing response.'
    );
  }

  @IsTest
  static void rejectsUnknownIdentityAndWrongRecordType() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forRule(
          'Definitely_Missing_Rule',
          new List<Id>()
        )
      );
      Assert.fail('An unknown qualified Rule identity should be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('was not found'),
        'The error should identify the missing Rule.'
      );
    }

    Contact contact = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{ 'LastName' => 'Wrong Type' }
    );
    RecordHealthCheckTestDataFactory.createContact(contact);
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forRule(
          RecordHealthCheckTestDataFactory.qualifiedRuleName(PHONE_RULE),
          contact.Id
        )
      );
      Assert.fail('A Contact should not run through an Account Rule.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('not Contact'),
        'The error should name the mismatched object type.'
      );
    }
  }

  @IsTest
  static void rejectsNullRequest() {
    try {
      RecordHealthCheck.evaluate(null);
      Assert.fail('A null request should be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('request is required'),
        'The error should identify the missing request.'
      );
    }
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
