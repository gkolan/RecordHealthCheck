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
    System.assertEquals('CONFIG_NOT_FOUND', result.reasonCode);
    System.assertEquals('Does_Not_Exist', result.checkDeveloperName);
    System.assertNotEquals(null, result.durationMs);
  }

  @isTest
  static void evaluateRunsQueryCheckAgainstSharedAccountData() {
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
    System.assertEquals('Account_QC_IsNotBlank', result.checkDeveloperName);
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
      CheckName__c = 'Related Sum Matches Formula',
      CheckMethod__c = 'Query',
      Severity__c = 'Warning',
      DataQuery__c = 'SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!Id}',
      FieldToRead__c = 'totalAmount',
      WhenMultipleRows__c = 'OneResult',
      Operator__c = 'Equals',
      CompareAgainst__c = 'RecordFormula',
      RecordFormulaValue__c = 'AnnualRevenue * 0.1',
      WhenZeroRows__c = 'Fail',
      WhenValueIsEmpty__c = 'MissingMeansNoMatch',
      MessageWhenFailed__c = 'Related opportunity amount does not match expected revenue.',
      RunOrder__c = 10
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
    System.assertEquals('Query', result.evaluatorType);
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
      CheckName__c = 'All Contacts With Email',
      CheckMethod__c = 'Query',
      Severity__c = 'Warning',
      DataQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!Id}',
      FieldToRead__c = 'Email',
      WhenMultipleRows__c = 'AllRowsPass',
      Operator__c = 'IsNotBlank',
      WhenZeroRows__c = 'Fail',
      WhenValueIsEmpty__c = 'SkipRecordsWithMissingValue',
      MessageWhenFailed__c = 'A contact is missing email.',
      RunOrder__c = 11
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
      CheckName__c = 'Exact List Duplicates',
      CheckMethod__c = 'CompareTwoQueries',
      Severity__c = 'Warning',
      DataQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!Id}',
      FieldToRead__c = 'MailingCity',
      CompareToQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!Id}',
      CompareToField__c = 'BillingCity',
      WhenMultipleRows__c = 'CompareAsLists',
      Operator__c = 'ExactListMatch',
      WhenZeroRows__c = 'Fail',
      WhenValueIsEmpty__c = 'MissingMeansNoMatch',
      MessageWhenFailed__c = 'Contact city list does not exactly match.',
      RunOrder__c = 12
    );

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckDualSoqlEvaluator()
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
      CheckName__c = 'DateTime Order',
      CheckMethod__c = 'CompareTwoQueries',
      Severity__c = 'Warning',
      DataQuery__c = 'SELECT CreatedDate FROM Account WHERE Id = {!Id}',
      FieldToRead__c = 'CreatedDate',
      CompareToQuery__c = 'SELECT LastModifiedDate FROM Account WHERE Id = {!Id}',
      CompareToField__c = 'LastModifiedDate',
      WhenMultipleRows__c = 'OneResult',
      Operator__c = 'LessThanOrEqual',
      WhenZeroRows__c = 'Fail',
      WhenValueIsEmpty__c = 'MissingMeansNoMatch',
      MessageWhenFailed__c = 'CreatedDate should not be after LastModifiedDate.',
      RunOrder__c = 13
    );

    Test.startTest();
    RecordHealthCheckResult result = new RecordHealthCheckDualSoqlEvaluator()
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
  static void apexRuleUsesDefaultsForMissingAndOutOfRangeParameters() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckTestDataFactory.createCompletedTask(accountRecord.Id);
    AccountHasRecentActivityCheck rule = new AccountHasRecentActivityCheck();
    RecordHealthCheckContext context = new RecordHealthCheckContext();
    context.recordId = accountRecord.Id;

    context.parameters = null;
    System.assertEquals('PASS', rule.evaluate(context).status);
    context.parameters = new Map<String, Object>();
    System.assertEquals('PASS', rule.evaluate(context).status);
    context.parameters = new Map<String, Object>{ 'daysBack' => 0 };
    System.assertEquals('PASS', rule.evaluate(context).status);
    context.parameters = new Map<String, Object>{ 'daysBack' => 'bad' };
    System.assertEquals('PASS', rule.evaluate(context).status);
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
    System.assertEquals('CONFIG_NOT_FOUND', result.reasonCode);
  }

  @isTest
  static void applicabilityBranchesReturnSkipUnableOrProceed() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    Record_Health_Check_Rule__mdt rule = applicabilityRule();

    rule.RunThisCheckWhen__c = null;
    System.assertEquals(
      null,
      engine.checkApplicability(rule, accountRecord.Id, accountRecord),
      'Blank applicability mode should proceed like Always.'
    );

    rule.RunThisCheckWhen__c = 'Formula';
    rule.RunWhenFormula__c = 'FALSE';
    RecordHealthCheckResult skipped = engine.checkApplicability(
      rule,
      accountRecord.Id,
      accountRecord
    );
    System.assertEquals('SKIPPED', skipped.status);
    System.assertEquals('APPLICABILITY_NOT_MET', skipped.reasonCode);

    rule.RunWhenFormula__c = 'NOT_A_REAL_FIELD__c > 0';
    RecordHealthCheckResult invalidFormula = engine.checkApplicability(
      rule,
      accountRecord.Id,
      accountRecord
    );
    System.assertEquals('UNABLE_TO_EVALUATE', invalidFormula.status);

    rule.RunThisCheckWhen__c = 'Unsupported';
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
    rule.RunThisCheckWhen__c = 'SOQL';

    rule.RunWhenCountQuery__c = null;
    System.assertEquals(
      'INVALID_SOQL_TEMPLATE',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );

    rule.RunWhenCountQuery__c = 'SELECT Id FROM Account';
    System.assertEquals(
      'INVALID_SOQL_TEMPLATE',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );

    rule.RunWhenCountQuery__c = 'SELECT COUNT(Id) FROM Contact';
    rule.CountThreshold__c = null;
    System.assertEquals(
      'INVALID_CONFIG',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );

    rule.CountThreshold__c = 0;
    rule.CountOperator__c = 'Nope';
    System.assertEquals(
      'INVALID_COMPARATOR',
      engine.checkSoqlApplicability(rule, accountRecord).reasonCode
    );
  }

  /**
   * Second top-level evaluate() in the same transaction must not return a
   * memoized result from the first call.
   */
  @isTest
  static void secondTopLevelEvaluateReEvaluatesAfterRecordChange() {
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
    String template = 'SELECT Id FROM Account WHERE Name = \'{!Name}\' OR Name = {!Name}';
    String bound = evaluator.bindTokens(template, accountRecord);
    String escaped = String.escapeSingleQuotes(accountRecord.Name);
    System.assert(
      bound.contains('\'' + escaped + '\''),
      'Quoted token should remain a quoted literal.'
    );
    System.assert(
      !bound.contains('{!Name}'),
      'Both quoted and unquoted token forms must be consumed.'
    );
  }

  @isTest
  static void bindTokensDoesNotReExpandTokenTextFromFieldValues() {
    Account accountRecord = new Account(
      Name = '{!Website}',
      Website = 'https://example.com'
    );
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    String bound = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!Name} AND Website = {!Website}',
      accountRecord
    );

    System.assert(
      bound.contains('Name = \'{!Website}\''),
      'The literal token-looking text from Name must stay inside the Name value.'
    );
    System.assert(
      bound.contains('Website = \'https://example.com\''),
      'The real Website token should still resolve at its original position.'
    );
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
      RecordHealthCheckComparatorEngine.valuesEqual(d, dt)
    );
  }

  @isTest
  static void valuesEqualNormalizesIdAndString() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    System.assertEquals(
      true,
      RecordHealthCheckComparatorEngine.valuesEqual(
        accountRecord.Id,
        String.valueOf(accountRecord.Id)
      )
    );
  }

  @isTest
  static void multiRowFoundSummaryIsDerivedAndOverridable() {
    Account acc = new Account(Name = 'Summary Test Co');
    insert acc;
    insert new List<Contact>{
      new Contact(
        LastName = 'HasEmail',
        Email = 'a@example.com',
        AccountId = acc.Id
      ),
      new Contact(LastName = 'NoEmail', AccountId = acc.Id)
    };

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_MultiRow_Summary',
      MasterLabel = 'Test MultiRow Summary',
      CheckName__c = 'MultiRow Summary',
      CheckMethod__c = 'Query',
      Severity__c = 'Warning',
      DataQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!Id}',
      FieldToRead__c = 'Email',
      WhenMultipleRows__c = 'AllRowsPass',
      Operator__c = 'IsNotBlank',
      WhenZeroRows__c = 'Fail',
      WhenValueIsEmpty__c = 'MissingMeansNoMatch',
      MessageWhenFailed__c = 'A contact is missing email.',
      RunOrder__c = 10
    );

    Test.startTest();
    RecordHealthCheckResult derived = new RecordHealthCheckSoqlEvaluator()
      .evaluate(rule, acc.Id, acc);

    rule.FoundSummaryOverride__c = '{!failCount} of {!totalCount} contacts missing email';
    rule.ExpectedSummaryOverride__c = 'every contact has an email';
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
      'Override should resolve {!failCount}/{!totalCount} tokens'
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
      null,
      engine.sanitizeActionUrl('/'.rightPad(2002, 'x')),
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
      CheckName__c = 'Remediation Fail',
      PrimaryActionUrl__c = '/lightning/r/Account/{!Id}/view',
      PrimaryActionLabel__c = 'Open account',
      FixInstructions__c = 'Review the record.'
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
      'The {!Id} token should resolve to the record Id'
    );
    System.assertEquals('Open account', result.actionLabel);
    System.assertEquals('Review the record.', result.fixInstructions);
  }

  @isTest
  static void remediationActionAbsentOnPass() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Remediation_Pass',
      MasterLabel = 'Test Remediation Pass',
      CheckName__c = 'Remediation Pass',
      PrimaryActionUrl__c = '/lightning/r/Account/{!Id}/view',
      PrimaryActionLabel__c = 'Open account',
      FixInstructions__c = 'Review the record.'
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
      CheckName__c = 'Remediation Unsafe',
      PrimaryActionUrl__c = 'javascript:alert(document.cookie)',
      PrimaryActionLabel__c = 'Do not click',
      FixInstructions__c = 'Contact your admin.'
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
  static void resolveUrlMergeFieldsEncodesValues() {
    Account accountRecord = new Account(Name = 'Acme & Co');
    String resolved = new RecordHealthCheckFormulaEvaluator()
      .resolveUrlMergeFields('/find?q={!Name}', accountRecord);
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
      MessageWhenFailed__c = 'Generic metadata failure for {!Name}.'
    );
    RecordHealthCheckResult evalResult = new RecordHealthCheckResult();
    evalResult.status = 'FAIL';
    evalResult.message = 'Plugin detail: inactive approver Alice.';

    new RecordHealthCheckEngine()
      .resolveEvalResultMessage(evalResult, rule, accountRecord);

    System.assertEquals(
      'Plugin detail: inactive approver Alice.',
      evalResult.message,
      'A non-blank evaluator message must not be replaced by MessageWhenFailed__c.'
    );
  }

  @isTest
  static void failMessageFallsBackToMetadataWhenEvaluatorMessageBlank() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      MessageWhenFailed__c = 'Generic failure for {!Name}.'
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
    Account accountRecord = new Account(Name = 'Acme', Description = '{!Name}');
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    System.assertEquals(
      '{!Name} / Acme',
      evaluator.resolveMergeFields('{!Description} / {!Name}', accountRecord),
      'Token-looking text from Description should remain literal.'
    );
    System.assertEquals(
      '/find?q=%7B%21Name%7D&name=Acme',
      evaluator.resolveUrlMergeFields(
        '/find?q={!Description}&name={!Name}',
        accountRecord
      ),
      'URL merge values should be encoded once and never re-expanded.'
    );
  }

  private static Record_Health_Check_Rule__mdt applicabilityRule() {
    return new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Test_Applicability_Branches',
      MasterLabel = 'Test Applicability Branches',
      CheckName__c = 'Applicability Branches',
      CheckMethod__c = 'Formula',
      Severity__c = 'Warning',
      PassFailFormula__c = 'TRUE',
      MessageWhenFailed__c = 'Failed.',
      MessageWhenCannotRun__c = 'Cannot run.',
      RunOrder__c = 10,
      RunThisCheckWhen__c = 'Always',
      CountOperator__c = 'GreaterThan',
      CountThreshold__c = 0
    );
  }
}
