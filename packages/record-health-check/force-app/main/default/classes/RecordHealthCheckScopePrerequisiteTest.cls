/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopePrerequisiteTest {
  private static final String PHONE_RULE = 'Example_Profile_Phone_Available';

  @IsTest
  static void missingPrerequisiteDoesNotBlockSingleRuleSelection() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Missing Prerequisite' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    Record_Health_Check_Rule__mdt ruleWithPrerequisite = RecordHealthCheckTestDataFactory.rule(
      new Map<String, Object>{
        'DeveloperName' => 'Rule_B',
        'PrerequisiteRule__c' => 'Rule_A'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        ruleWithPrerequisite,
        account.Id,
        new Map<String, RecordHealthCheckResultItem>()
      );
    Test.stopTest();

    Assert.isNull(
      result,
      'A qualified single-Rule request has no prerequisite history and must not invent a failed dependency.'
    );
  }

  @IsTest
  static void passingPrerequisiteAllowsDependentRule() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Passing Prerequisite' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    RecordHealthCheckResultItem prerequisiteResult = buildPrerequisiteResultItem(
      account.Id,
      'Rule_A',
      RecordHealthCheckStatus.PASS
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        buildRuleWithPrerequisite('Rule_A'),
        account.Id,
        new Map<String, RecordHealthCheckResultItem>{
          String.valueOf(account.Id) + '|Rule_A' => prerequisiteResult
        }
      );
    Test.stopTest();

    Assert.isNull(
      result,
      'Only a PASS result from the Prerequisite Rule may allow the Rule to run.'
    );
  }

  @IsTest
  static void everyNonPassingPrerequisiteStatusSkipsDependentRule() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Non-Passing Prerequisite' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    List<String> terminalStatuses = new List<String>{
      RecordHealthCheckStatus.FAIL,
      RecordHealthCheckStatus.SKIPPED,
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      RecordHealthCheckStatus.ERROR
    };

    Test.startTest();
    for (String status : terminalStatuses) {
      RecordHealthCheckResultItem prerequisiteResult = buildPrerequisiteResultItem(
        account.Id,
        'namespace__Rule_A',
        status
      );
      RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
        .findPrerequisiteBlock(
          buildRuleWithPrerequisite('Rule_A'),
          account.Id,
          new Map<String, RecordHealthCheckResultItem>{
            String.valueOf(account.Id) +
            '|namespace__Rule_A' => prerequisiteResult
          }
        );
      Assert.areEqual(
        RecordHealthCheckStatus.SKIPPED,
        result.status,
        status + ' must block the Rule that requires the Prerequisite Rule.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET,
        result.reasonCode,
        status + ' means the Prerequisite Rule ran but did not pass.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void prerequisiteOutcomeIsScopedToTheSameRecord() {
    Account first = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'First Scope Record' }
    );
    Account second = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Second Scope Record' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ first, second }
    );
    Map<String, RecordHealthCheckResultItem> priorItems = new Map<String, RecordHealthCheckResultItem>{
      String.valueOf(first.Id) + '|Rule_A' => buildPrerequisiteResultItem(
        first.Id,
        'Rule_A',
        RecordHealthCheckStatus.PASS
      ),
      String.valueOf(second.Id) + '|Rule_A' => buildPrerequisiteResultItem(
        second.Id,
        'Rule_A',
        RecordHealthCheckStatus.FAIL
      )
    };

    Test.startTest();
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    RecordHealthCheckInternalResult firstResult = resultSupport.findPrerequisiteBlock(
      buildRuleWithPrerequisite('Rule_A'),
      first.Id,
      priorItems
    );
    RecordHealthCheckInternalResult secondResult = resultSupport.findPrerequisiteBlock(
      buildRuleWithPrerequisite('Rule_A'),
      second.Id,
      priorItems
    );
    Test.stopTest();

    Assert.isNull(
      firstResult,
      'The record whose Prerequisite Rule passed may proceed.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET,
      secondResult.reasonCode,
      'A different record\'s PASS must not unblock this record.'
    );
  }

  @IsTest
  static void prerequisiteLookupIgnoresSpoofedMapIdentity() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Spoofed prerequisite identity' }
      )
    );
    RecordHealthCheckResultItem spoofed = buildPrerequisiteResultItem(
      account.Id,
      'Rule_A',
      RecordHealthCheckStatus.PASS
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        buildRuleWithPrerequisite('Rule_A'),
        account.Id,
        new Map<String, RecordHealthCheckResultItem>{
          'attacker-controlled-key' => spoofed
        }
      );
    Test.stopTest();

    Assert.isNull(
      result,
      'A value under the wrong identity key is ignored and absent history remains unknown.'
    );
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
