/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckEngineTest {
  @testSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @isTest
  static void evaluateReturnsUnableWhenRuleIsMissing() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckEngine()
      .evaluate('Account_Data_Quality', 'Does_Not_Exist', accountRecord.Id);
    Test.stopTest();

    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals('RULE_NOT_FOUND', result.reasonCode);
    System.assertEquals('Does_Not_Exist', result.ruleDeveloperName);
    System.assertNotEquals(null, result.durationMs);
  }

  @isTest
  static void evaluateReturnsUnableWhenRuleIsInactive() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckEngine()
      .evaluate(
        'Account_Examples_Apex',
        'Approval_No_Inactive_Approvers',
        accountRecord.Id
      );
    Test.stopTest();

    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals('RULE_INACTIVE', result.reasonCode);
    System.assertEquals('This rule is inactive.', result.message);
  }

  @isTest
  static void evaluateRunsQueryCheckAgainstSharedAccountData() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckEngine()
      .evaluate(
        'Account_Query_Coverage',
        'Account_QC_IsNotBlank',
        accountRecord.Id
      );
    Test.stopTest();

    System.assertEquals('PASS', result.status);
    System.assertEquals('Account_QC_IsNotBlank', result.ruleDeveloperName);
    System.assertEquals('Query', result.evaluatorType);
  }

  @isTest
  static void queryEvaluatorComparesRelatedSumToFormulaResult() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckTestDataFactory.createOpportunity(
      accountRecord.Id,
      'Record Health Sum Test',
      accountRecord.AnnualRevenue * 0.1
    );

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Related_Sum_Matches_Formula',
      MasterLabel = 'Test Related Sum Matches Formula',
      CheckTitle__c = 'Related Sum Matches Formula',
      EvaluationType__c = 'QUERY',
      FailureSeverity__c = 'WARNING',
      SourceQuery__c = 'SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id}',
      SourceQueryField__c = 'totalAmount',
      QueryResultHandling__c = 'ONE_RESULT',
      ComparisonOperator__c = 'EQUALS',
      ExpectedValueSource__c = 'RECORD_FORMULA',
      ExpectedRecordFormula__c = 'AnnualRevenue * 0.1',
      DisplayFoundText__c = 'Pipeline: {!rhcResult.foundValue}',
      DisplayExpectedText__c = 'Target: {!rhcResult.expectedValue}',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'AS_NO_MATCH',
      FailureMessage__c = 'Related opportunity amount does not match expected revenue.',
      EvaluationOrder__c = 10
    );

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(rule, accountRecord.Id, accountRecord);
    Test.stopTest();

    System.assertEquals(
      'PASS',
      result.status,
      'Unexpected result detail: ' + result.detailMessage
    );
    // Direct evaluator calls expose the evaluator contract. The engine maps
    // this value to the LWC wire string only at its response boundary.
    System.assertEquals('QUERY', result.evaluatorType);
    System.assert(
      result.actualValue.startsWith('Pipeline: '),
      'Single-value Found template should preserve and label the query value.'
    );
    System.assert(
      result.expectedValue.startsWith('Target: '),
      'Single-value Expected template should preserve and label the comparison value.'
    );
  }

  @isTest
  static void queryEvaluatorSkipsNullRowsForAllRecordsMatch() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckTestDataFactory.createEmailCoverageContacts(
      accountRecord.Id
    );

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_All_Contacts_With_Email',
      MasterLabel = 'Test All Contacts With Email',
      CheckTitle__c = 'All Contacts With Email',
      EvaluationType__c = 'QUERY',
      FailureSeverity__c = 'WARNING',
      SourceQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!record.Id}',
      SourceQueryField__c = 'Email',
      QueryResultHandling__c = 'ALL_ROWS_PASS',
      ComparisonOperator__c = 'IS_NOT_BLANK',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'SKIP_RECORD',
      FailureMessage__c = 'A contact is missing email.',
      EvaluationOrder__c = 11
    );

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(rule, accountRecord.Id, accountRecord);
    Test.stopTest();

    System.assertEquals(
      'PASS',
      result.status,
      'Null rows should be skipped; detail: ' + result.detailMessage
    );
  }

  @isTest
  static void dualQueryExactListMatchHonorsDuplicateCounts() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckTestDataFactory.createMatchingCityContacts(
      accountRecord.Id,
      accountRecord.BillingCity
    );

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Exact_List_Duplicates',
      MasterLabel = 'Test Exact List Duplicates',
      CheckTitle__c = 'Exact List Duplicates',
      EvaluationType__c = 'COMPARE_TWO_QUERIES',
      FailureSeverity__c = 'WARNING',
      SourceQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}',
      SourceQueryField__c = 'MailingCity',
      ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}',
      ComparisonQueryField__c = 'BillingCity',
      QueryResultHandling__c = 'COMPARE_AS_LISTS',
      ComparisonOperator__c = 'LISTS_MATCH_EXACTLY',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'AS_NO_MATCH',
      FailureMessage__c = 'Contact city list does not exactly match.',
      EvaluationOrder__c = 12
    );

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluate(rule, accountRecord.Id, accountRecord);
    Test.stopTest();

    System.assertEquals(
      'FAIL',
      result.status,
      'Duplicate city rows must not collapse into a single set value.'
    );
  }

  @isTest
  static void dualQueryOrderedComparisonSupportsDateTimeValues() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_DateTime_Order',
      MasterLabel = 'Test DateTime Order',
      CheckTitle__c = 'DateTime Order',
      EvaluationType__c = 'COMPARE_TWO_QUERIES',
      FailureSeverity__c = 'WARNING',
      SourceQuery__c = 'SELECT CreatedDate FROM Account WHERE Id = {!record.Id}',
      SourceQueryField__c = 'CreatedDate',
      ComparisonQuery__c = 'SELECT LastModifiedDate FROM Account WHERE Id = {!record.Id}',
      ComparisonQueryField__c = 'LastModifiedDate',
      QueryResultHandling__c = 'ONE_RESULT',
      ComparisonOperator__c = 'LESS_THAN_OR_EQUAL',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'AS_NO_MATCH',
      FailureMessage__c = 'CreatedDate should not be after LastModifiedDate.',
      EvaluationOrder__c = 13
    );

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluate(rule, accountRecord.Id, accountRecord);
    Test.stopTest();

    System.assertEquals(
      'PASS',
      result.status,
      'DateTime comparison should use temporal ordering; detail: ' +
      result.detailMessage
    );
  }

  @isTest
  static void evaluateRejectsRuleFromDifferentCheckSet() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    RecordHealthCheckResult result = new RecordHealthCheckEngine()
      .evaluate(
        'Account_Data_Quality',
        'Account_QC_IsNotBlank',
        accountRecord.Id
      );

    System.assertEquals('UNABLE_TO_EVALUATE', result.status);
    System.assertEquals('RULE_NOT_FOUND', result.reasonCode);
  }

  @isTest
  static void applicabilityBranchesReturnSkipUnableOrProceed() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    Record_Health_Check_Rule__mdt rule = applicabilityRule();

    rule.ApplicabilityMode__c = null;
    System.assertEquals(
      null,
      engine.checkApplicability(rule, accountRecord.Id, accountRecord),
      'Blank applicability mode should proceed like Always.'
    );

    rule.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    rule.ApplicabilityFormula__c = 'FALSE';
    RecordHealthCheckResult skipped = engine.checkApplicability(
      rule,
      accountRecord.Id,
      accountRecord
    );
    System.assertEquals('SKIPPED', skipped.status);
    System.assertEquals(
      RecordHealthCheckReasonCodes.NOT_APPLICABLE_BY_FORMULA,
      skipped.reasonCode
    );

    rule.ApplicabilityFormula__c = 'NOT_A_REAL_FIELD__c > 0';
    RecordHealthCheckResult invalidFormula = engine.checkApplicability(
      rule,
      accountRecord.Id,
      accountRecord
    );
    System.assertEquals('UNABLE_TO_EVALUATE', invalidFormula.status);

    rule.ApplicabilityMode__c = 'Unsupported';
    RecordHealthCheckResult invalidMode = engine.checkApplicability(
      rule,
      accountRecord.Id,
      accountRecord
    );
    System.assertEquals('UNABLE_TO_EVALUATE', invalidMode.status);
    System.assertEquals('INVALID_CONFIG', invalidMode.reasonCode);
  }

  @isTest
  static void soqlApplicabilityDefensiveBranchesReturnUnable() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    Record_Health_Check_Rule__mdt rule = applicabilityRule();
    rule.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';

    rule.ApplicabilityCountQuery__c = null;
    System.assertEquals(
      'INVALID_SOQL_TEMPLATE',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );

    rule.ApplicabilityCountQuery__c = 'SELECT Id FROM Account';
    System.assertEquals(
      'INVALID_SOQL_TEMPLATE',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );

    rule.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Contact';
    rule.ApplicabilityCountThreshold__c = null;
    System.assertEquals(
      'INVALID_CONFIG',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );

    rule.ApplicabilityCountThreshold__c = 0;
    rule.ApplicabilityCountOperator__c = 'Nope';
    System.assertEquals(
      'INVALID_OPERATOR',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );
  }

  /**
   * Second top-level evaluate() in the same transaction must not return a
   * memoized result from the first call.
   */
  @isTest
  static void secondTopLevelEvaluateReEvaluatesAfterRecordChange() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    RecordHealthCheckResult first = engine.evaluate(
      'Account_Data_Quality',
      'Account_DQ_BillingCity',
      accountRecord.Id
    );
    System.assertEquals('PASS', first.status);

    accountRecord.BillingCity = null;
    update accountRecord;

    RecordHealthCheckResult second = engine.evaluate(
      'Account_Data_Quality',
      'Account_DQ_BillingCity',
      accountRecord.Id
    );
    System.assertEquals(
      'FAIL',
      second.status,
      'Cache must clear between top-level evaluate() calls.'
    );
  }

  @isTest
  static void bindTokensMixedQuotedAndUnquotedSubstitutesBoth() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    String template = 'SELECT Id FROM Account WHERE Name = \'{!record.Name}\' OR Name = {!record.Name}';
    String bound = evaluator.bindTokens(template, accountRecord);
    String escaped = String.escapeSingleQuotes(accountRecord.Name);
    System.assert(
      bound.contains('\'' + escaped + '\''),
      'Quoted token should remain a quoted literal.'
    );
    System.assert(
      !bound.contains('{!record.Name}'),
      'Both quoted and unquoted token forms must be consumed.'
    );
  }

  @isTest
  static void bindTokensDoesNotReExpandTokenTextFromFieldValues() {
    Account accountRecord = new Account(
      Name = '{!record.Website}',
      Website = 'https://example.com'
    );
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    String bound = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name} AND Website = {!record.Website}',
      accountRecord
    );

    System.assert(
      bound.contains('Name = \'{!record.Website}\''),
      'The literal token-looking text from Name must stay inside the Name value.'
    );
    System.assert(
      bound.contains('Website = \'https://example.com\''),
      'The real Website token should still resolve at its original position.'
    );
  }

  @isTest
  static void bindTokensUsesTypedFallbacksForBlankValues() {
    Account accountRecord = new Account(
      Name = null,
      Description = '',
      AnnualRevenue = null,
      NumberOfEmployees = null
    );
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    String bound = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name|Unnamed Account} AND Description = {!record.Description|Needs review} AND AnnualRevenue >= {!record.AnnualRevenue|500000} AND NumberOfEmployees >= {!record.NumberOfEmployees|100}',
      accountRecord
    );

    System.assert(bound.contains('Name = \'Unnamed Account\''));
    System.assert(bound.contains('Description = \'Needs review\''));
    System.assert(bound.contains('AnnualRevenue >= 500000'));
    System.assert(bound.contains('NumberOfEmployees >= 100'));

    Account populatedZero = new Account(AnnualRevenue = 0);
    System.assert(
      evaluator
        .bindTokens(
          'SELECT Id FROM Account WHERE AnnualRevenue = {!record.AnnualRevenue|500000}',
          populatedZero
        )
        .contains('AnnualRevenue = 0'),
      'A populated zero must not be replaced by its fallback.'
    );

    User inactiveUser = new User(IsActive = false);
    System.assert(
      evaluator
        .bindTokens(
          'SELECT Id FROM User WHERE IsActive = {!record.IsActive|true}',
          inactiveUser
        )
        .contains('IsActive = false'),
      'A populated false must not be replaced by its fallback.'
    );

    Opportunity opportunityRecord = new Opportunity();
    String temporal = evaluator.bindTokens(
      'SELECT Id FROM Opportunity WHERE CloseDate = {!record.CloseDate|2026-12-31} AND CreatedDate >= {!record.CreatedDate|2026-01-01T00:00:00Z}',
      opportunityRecord
    );
    System.assert(temporal.contains('CloseDate = 2026-12-31'));
    System.assert(temporal.contains('CreatedDate >= 2026-01-01T00:00:00Z'));
  }

  @isTest
  static void bindTokensRejectsFallbackWithWrongFieldType() {
    try {
      new RecordHealthCheckSoqlEvaluator()
        .bindTokens(
          'SELECT Id FROM Account WHERE AnnualRevenue >= {!record.AnnualRevenue|not-a-number}',
          new Account()
        );
      System.assert(false, 'Expected an invalid numeric fallback to fail.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('MISSING_BIND_VALUE', ex.reasonCode);
    }
  }

  @isTest
  static void bindTokensRejectsSemicolonOnlyMultiSelectSegments() {
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    try {
      evaluator.buildMultiSelectIncludesClause(';');
      System.assert(
        false,
        'Expected MISSING_BIND_VALUE for semicolon-only value.'
      );
    } catch (RecordHealthCheckEvaluatorException ex) {
      System.assertEquals('MISSING_BIND_VALUE', ex.reasonCode);
    }
    System.assertEquals(
      '(\'North\', \'South\')',
      evaluator.buildMultiSelectIncludesClause('North;South')
    );
  }

  @isTest
  static void valuesEqualNormalizesDateAndDatetime() {
    Date d = Date.newInstance(2024, 6, 15);
    Datetime dt = Datetime.newInstance(2024, 6, 15, 0, 0, 0);
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.valuesEqual(d, dt)
    );
  }

  @isTest
  static void valuesEqualNormalizesIdAndString() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.valuesEqual(
        accountRecord.Id,
        String.valueOf(accountRecord.Id)
      )
    );
  }

  @isTest
  static void multiRowFoundSummaryIsDerivedAndOverridable() {
    Account acc = RecordHealthCheckTestDataFactory.createAccount(
      'Summary Test Co'
    );
    RecordHealthCheckTestDataFactory.createContacts(
      new List<Contact>{
        new Contact(
          LastName = 'HasEmail',
          Email = 'a@example.com',
          AccountId = acc.Id
        ),
        new Contact(LastName = 'NoEmail', AccountId = acc.Id)
      }
    );

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_MultiRow_Summary',
      MasterLabel = 'Test MultiRow Summary',
      CheckTitle__c = 'MultiRow Summary',
      EvaluationType__c = 'QUERY',
      FailureSeverity__c = 'WARNING',
      SourceQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!record.Id}',
      SourceQueryField__c = 'Email',
      QueryResultHandling__c = 'ALL_ROWS_PASS',
      ComparisonOperator__c = 'IS_NOT_BLANK',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'AS_NO_MATCH',
      FailureMessage__c = 'A contact is missing email.',
      EvaluationOrder__c = 10
    );

    Test.startTest();
    RecordHealthCheckResult derived = new RecordHealthCheckSoqlEvaluator()
      .evaluate(rule, acc.Id, acc);

    rule.DisplayFoundText__c = '{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} contacts missing email';
    rule.DisplayExpectedText__c = 'every contact has an email';
    RecordHealthCheckResult overridden = new RecordHealthCheckSoqlEvaluator()
      .evaluate(rule, acc.Id, acc);
    Test.stopTest();

    System.assertEquals('FAIL', derived.status);
    System.assertEquals(
      '1 of 2 Contacts did not pass',
      derived.actualValue,
      'Derived summary should count failing rows and pluralize the object'
    );

    System.assertEquals(
      '1 of 2 contacts missing email',
      overridden.actualValue,
      'Override should resolve {!rhcResult.failedRecordCount}/{!rhcResult.totalRecordCount} tokens'
    );
    System.assertEquals(
      'every contact has an email',
      overridden.expectedValue,
      'Expected override should replace the derived condition'
    );
  }

  @isTest
  static void sanitizeActionUrlAcceptsRelativeAndHttps() {
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    System.assertEquals(
      '/lightning/r/Report/00O/view?fv0=001',
      engine.sanitizeActionUrl('  /lightning/r/Report/00O/view?fv0=001  '),
      'A same-org relative path should be accepted and trimmed'
    );
    System.assertEquals(
      'https://help.example.com/docs',
      engine.sanitizeActionUrl('https://help.example.com/docs'),
      'An absolute https URL should be accepted'
    );
  }

  @isTest
  static void sanitizeActionUrlRejectsUnsafeSchemesAndLength() {
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('javascript:alert(1)'),
      'javascript: must be rejected'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('data:text/html,<script>'),
      'data: must be rejected'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('http://insecure.example.com'),
      'plain http must be rejected'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('//evil.example.com/path'),
      'protocol-relative must be rejected'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('/\\evil.example.com/path'),
      'backslash-normalized protocol-relative URLs must be rejected'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('java\nscript:alert(1)'),
      'control-character-obfuscated scheme must be rejected'
    );
    System.assertEquals(
      '/'.rightPad(2000, 'x'),
      engine.sanitizeActionUrl('/'.rightPad(2000, 'x')),
      'exactly 2000 chars must be accepted'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('/'.rightPad(2001, 'x')),
      'over 2000 chars must be rejected'
    );
    System.assertEquals(
      null,
      engine.sanitizeActionUrl('   '),
      'blank must be rejected'
    );
  }

  @isTest
  static void remediationActionPopulatedAndTokenResolvedOnFail() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Remediation_Fail',
      MasterLabel = 'Test Remediation Fail',
      CheckTitle__c = 'Remediation Fail',
      ActionUrl__c = '/lightning/r/Account/{!record.Id}/view',
      ActionLabel__c = 'Open account',
      FixMessage__c = 'Review the record.'
    );
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'FAIL';

    Test.startTest();
    new RecordHealthCheckEngine()
      .populateRemediationAction(result, rule, accountRecord);
    Test.stopTest();

    System.assertEquals(
      '/lightning/r/Account/' + accountRecord.Id + '/view',
      result.actionUrl,
      'The {!record.Id} token should resolve to the record Id'
    );
    System.assertEquals('Open account', result.actionLabel);
    System.assertEquals('Review the record.', result.fixInstructions);
  }

  @isTest
  static void copyResultPreservesRemediationAndPassesWhenFields() {
    RecordHealthCheckResult source = new RecordHealthCheckResult();
    source.ruleDeveloperName = 'Cached_Check';
    source.status = 'FAIL';
    source.expectedValue = 'NOT(ISBLANK(BillingCity))';
    source.expectedValueLabel = RecordHealthCheckResult.PASSES_WHEN_LABEL;
    source.actionLabel = 'Open account';
    source.actionUrl = '/lightning/r/Account/001xx/view';
    source.fixInstructions = 'Review the record.';

    RecordHealthCheckResult copy = new RecordHealthCheckEngine()
      .copyResult(source);

    System.assertEquals(source.expectedValueLabel, copy.expectedValueLabel);
    System.assertEquals(source.actionLabel, copy.actionLabel);
    System.assertEquals(source.actionUrl, copy.actionUrl);
    System.assertEquals(source.fixInstructions, copy.fixInstructions);
  }

  @isTest
  static void dependencyCacheHitPreservesRemediationFields() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    String checkSetDeveloperName = 'Account_Data_Quality';
    String checkName = 'Account_DQ_BillingCity';
    String cacheKey =
      checkSetDeveloperName +
      '|' +
      accountRecord.Id +
      '|' +
      checkName;

    RecordHealthCheckResult cached = new RecordHealthCheckResult();
    cached.ruleDeveloperName = checkName;
    cached.status = 'FAIL';
    cached.expectedValueLabel = RecordHealthCheckResult.PASSES_WHEN_LABEL;
    cached.actionLabel = 'Fix';
    cached.actionUrl = '/lightning/o/Account/home';
    cached.fixInstructions = 'Do it';

    RecordHealthCheckEngine.transactionResultCache.put(cacheKey, cached);
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'cache-hit-test',
      checkSetDeveloperName,
      accountRecord.Id
    );

    RecordHealthCheckResult hit = new RecordHealthCheckEngine()
      .doEvaluate(
        checkSetDeveloperName,
        checkName,
        accountRecord.Id,
        new Set<String>(),
        logger
      );

    System.assertEquals(cached.expectedValueLabel, hit.expectedValueLabel);
    System.assertEquals(cached.actionLabel, hit.actionLabel);
    System.assertEquals(cached.actionUrl, hit.actionUrl);
    System.assertEquals(cached.fixInstructions, hit.fixInstructions);

    RecordHealthCheckEngine.transactionResultCache.clear();
  }

  @isTest
  static void remediationActionAbsentOnPass() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Remediation_Pass',
      MasterLabel = 'Test Remediation Pass',
      CheckTitle__c = 'Remediation Pass',
      ActionUrl__c = '/lightning/r/Account/{!record.Id}/view',
      ActionLabel__c = 'Open account',
      FixMessage__c = 'Review the record.'
    );
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'PASS';

    new RecordHealthCheckEngine()
      .populateRemediationAction(result, rule, accountRecord);

    System.assertEquals(null, result.actionUrl, 'PASS carries no link');
    System.assertEquals(null, result.actionLabel);
    System.assertEquals(null, result.fixInstructions);
  }

  @isTest
  static void remediationUnsafeUrlSuppressedButKeepsInstructions() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Remediation_Unsafe',
      MasterLabel = 'Test Remediation Unsafe',
      CheckTitle__c = 'Remediation Unsafe',
      ActionUrl__c = 'javascript:alert(document.cookie)',
      ActionLabel__c = 'Do not click',
      FixMessage__c = 'Contact your admin.'
    );
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'FAIL';

    new RecordHealthCheckEngine()
      .populateRemediationAction(result, rule, accountRecord);

    System.assertEquals(
      null,
      result.actionUrl,
      'An unsafe URL must not surface as an href'
    );
    System.assertEquals(
      null,
      result.actionLabel,
      'No label without a valid link'
    );
    System.assertEquals(
      'Contact your admin.',
      result.fixInstructions,
      'Instructions still render so the row keeps guidance'
    );
    System.assert(
      result.detailMessage != null &&
      result.detailMessage.contains('suppressed'),
      'A breadcrumb is left in the admin detail channel'
    );
  }

  @isTest
  static void remediationBlankUrlTokenUsesFallbackOrSuppressesLink() {
    Account accountRecord = new Account(Name = 'Independent Account');
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'FAIL';
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      ActionUrl__c = '/find?parent={!record.ParentId}',
      ActionLabel__c = 'Review parent'
    );

    new RecordHealthCheckEngine()
      .populateRemediationAction(result, rule, accountRecord);
    System.assertEquals(null, result.actionUrl);
    System.assertEquals(null, result.actionLabel);
    System.assert(result.detailMessage.contains('MISSING_TOKEN_VALUE'));

    result = new RecordHealthCheckResult();
    result.status = 'FAIL';
    rule.ActionUrl__c = '/find?parent={!record.ParentId|unassigned}';
    new RecordHealthCheckEngine()
      .populateRemediationAction(result, rule, accountRecord);
    System.assertEquals('/find?parent=unassigned', result.actionUrl);
    System.assertEquals('Review parent', result.actionLabel);
  }

  @isTest
  static void resolveUrlMergeFieldsEncodesValues() {
    Account accountRecord = new Account(Name = 'Acme & Co');
    String resolved = new RecordHealthCheckFormulaEvaluator()
      .resolveUrlMergeFields('/find?q={!record.Name}', accountRecord);
    System.assertEquals(
      '/find?q=Acme+%26+Co',
      resolved,
      'Token values must be URL-encoded when dropped into a URL'
    );
  }

  @isTest
  static void failMessagePreservesNonBlankEvaluatorMessageOverMetadata() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      FailureMessage__c = 'Generic metadata failure for {!record.Name}.'
    );
    RecordHealthCheckResult evalResult = new RecordHealthCheckResult();
    evalResult.status = 'FAIL';
    evalResult.message = 'Plugin detail: inactive approver Alice.';

    new RecordHealthCheckEngine()
      .resolveEvalResultMessage(evalResult, rule, accountRecord);

    System.assertEquals(
      'Plugin detail: inactive approver Alice.',
      evalResult.message,
      'A non-blank evaluator message must not be replaced by FailureMessage__c.'
    );
  }

  @isTest
  static void failMessageFallsBackToMetadataWhenEvaluatorMessageBlank() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      FailureMessage__c = 'Generic failure for {!record.Name}.'
    );
    RecordHealthCheckResult evalResult = new RecordHealthCheckResult();
    evalResult.status = 'FAIL';

    new RecordHealthCheckEngine()
      .resolveEvalResultMessage(evalResult, rule, accountRecord);

    System.assertEquals(
      'Generic failure for ' + accountRecord.Name + '.',
      evalResult.message
    );
  }

  @isTest
  static void mergeFieldsDoNotReExpandTokenTextFromFieldValues() {
    Account accountRecord = new Account(
      Name = 'Acme',
      Description = '{!record.Name}'
    );
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    System.assertEquals(
      '{!record.Name} / Acme',
      evaluator.resolveMergeFields(
        '{!record.Description} / {!record.Name}',
        accountRecord
      ),
      'Token-looking text from Description should remain literal.'
    );
    System.assertEquals(
      '/find?q=%7B%21record.Name%7D&name=Acme',
      evaluator.resolveUrlMergeFields(
        '/find?q={!record.Description}&name={!record.Name}',
        accountRecord
      ),
      'URL merge values should be encoded once and never re-expanded.'
    );
  }

  private static Record_Health_Check_Rule__mdt applicabilityRule() {
    return new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Applicability_Branches',
      MasterLabel = 'Test Applicability Branches',
      CheckTitle__c = 'Applicability Branches',
      EvaluationType__c = 'FORMULA',
      FailureSeverity__c = 'WARNING',
      PassConditionFormula__c = 'TRUE',
      FailureMessage__c = 'Failed.',
      UnableToEvaluateMessage__c = 'Cannot run.',
      EvaluationOrder__c = 10,
      ApplicabilityMode__c = 'ALL_RECORDS',
      ApplicabilityCountOperator__c = 'GREATER_THAN',
      ApplicabilityCountThreshold__c = 0
    );
  }
}
