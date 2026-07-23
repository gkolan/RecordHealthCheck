@IsTest
private class RecordHealthCheckTemplateServiceTest {
  @IsTest
  static void parsesCanonicalNamespacesAndSpans() {
    String template = '{!record.Name} {!rhcRule.checkTitle}';
    List<RecordHealthCheckToken> tokens = RecordHealthCheckTemplateService.parse(
      template
    );
    System.assertEquals(2, tokens.size());
    System.assertEquals('record', tokens[0].namespaceName);
    System.assertEquals('Name', tokens[0].propertyPath);
    System.assertEquals(
      '{!record.Name}',
      template.substring(tokens[0].startIndex, tokens[0].endIndex)
    );
    System.assertEquals('rhcRule', tokens[1].namespaceName);
  }

  @IsTest
  static void rejectsLegacyGenericUnknownAndSoqlFrameworkTokens() {
    assertIssue('{!' + 'Name}', 'DISPLAY', 'LEGACY_FLAT_TOKEN');
    assertIssue(
      '{!' + 'result.status}',
      'DISPLAY',
      'UNSUPPORTED_TOKEN_NAMESPACE'
    );
    assertIssue('{!rhcRule.title}', 'DISPLAY', 'UNKNOWN_TOKEN_PROPERTY');
    assertIssue(
      '{!rhcRule.checkTitle}',
      'SOQL',
      'TOKEN_NOT_ALLOWED_ON_SURFACE'
    );
  }

  @IsTest
  static void resolvesRecordRuleAndResultWithoutRecursiveExpansion() {
    Account record = new Account(Name = 'Acme', Description = '{!record.Name}');
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'Stable_Name',
      MasterLabel = 'Setup Label',
      CheckTitle__c = 'Visible title',
      FailureSeverity__c = 'CRITICAL'
    );
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'FAIL';
    result.actualValue = 'Found';
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'run-123',
      'APEX_API'
    );
    run.startedAt = Datetime.newInstanceGmt(2026, 7, 14, 12, 0, 0);
    run.completedAt = Datetime.newInstanceGmt(2026, 7, 14, 12, 0, 1);
    run.durationMs = 1000;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withRule(rule)
      .withResult(result, true)
      .withRun(run);
    context.failedRecordCount = 2;
    context.totalRecordCount = 5;

    System.assertEquals(
      'Acme | {!record.Name} | Stable_Name | Setup Label | Visible title | Critical | FAIL | 2/5 | run-123/APEX_API/1000',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name} | {!record.Description} | {!rhcRule.developerName} | {!rhcRule.masterLabel} | {!rhcRule.checkTitle} | {!rhcRule.failureSeverity} | {!rhcResult.status} | {!rhcResult.failedRecordCount}/{!rhcResult.totalRecordCount} | {!rhcRun.runId}/{!rhcRun.source}/{!rhcRun.durationMs}',
        context
      )
    );
  }

  @IsTest
  static void encodesUrlValuesOnceAndEnforcesResultPhase() {
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(new Account(Name = 'A & B'));
    System.assertEquals(
      '/find?q=A+%26+B',
      RecordHealthCheckTemplateService.resolveUrl(
        '/find?q={!record.Name}',
        context
      )
    );
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.status}',
        context
      );
      System.assert(false, 'Expected unavailable result token to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      System.assertEquals('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }
  }

  @IsTest
  static void acceptsRunNamespaceAndRequiresRunContext() {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      '{!rhcRun.runId}',
      'DISPLAY'
    );
    System.assertEquals(0, issues.size(), 'rhcRun should be allowlisted.');
    assertIssue('{!rhcRun.unknown}', 'DISPLAY', 'UNKNOWN_TOKEN_PROPERTY');
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcRun.runId}',
        new RecordHealthCheckMergeContext()
      );
      System.assert(false, 'Expected a missing run context to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      System.assertEquals('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }
  }

  @IsTest
  static void resolvesEverySetResultAndRunProperty() {
    Record_Health_Check_Set__mdt checkSet = new Record_Health_Check_Set__mdt(
      DeveloperName = 'Set_Name',
      MasterLabel = 'Set label',
      CardTitle__c = 'Card title',
      CardSubtitle__c = 'Card subtitle',
      ObjectApiName__c = 'Account'
    );
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'FAIL';
    result.actualValue = 'Found';
    result.expectedValue = 'Expected';
    result.reasonCode = 'MISMATCH';
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'run-456',
      'FLOW'
    );
    run.startedAt = Datetime.newInstanceGmt(2026, 7, 14, 1, 2, 3);
    run.completedAt = Datetime.newInstanceGmt(2026, 7, 14, 1, 2, 4);
    run.durationMs = 1000;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext();
    context.checkSet = checkSet;
    context.withResult(result, true).withRun(run);
    context.failedRecordCount = 3;
    context.totalRecordCount = 7;

    String resolved = RecordHealthCheckTemplateService.resolveDisplay(
      '{!rhcSet.developerName}|{!rhcSet.masterLabel}|{!rhcSet.cardTitle}|{!rhcSet.cardSubtitle}|{!rhcSet.objectApiName}|{!rhcResult.foundValue}|{!rhcResult.expectedValue}|{!rhcResult.reasonCode}|{!rhcRun.runId}|{!rhcRun.source}|{!rhcRun.startedAt}|{!rhcRun.completedAt}|{!rhcRun.durationMs}',
      context
    );
    System.assert(resolved.contains('Set_Name|Set label|Card title'));
    System.assert(resolved.contains('Found|Expected|MISMATCH'));
    System.assert(resolved.contains('run-456|FLOW|2026-07-14T01:02:03.000Z'));
    System.assert(resolved.endsWith('|1000'));

    result.actualValue = '1';
    System.assertEquals(
      '1 Sponsor',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
        context
      )
    );
    result.actualValue = '3';
    System.assertEquals(
      '3 Sponsors',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
        context
      )
    );
  }

  @IsTest
  static void coversTemplateLimitsMalformedSyntaxAndRelationshipRules() {
    String tooManyTokens = '';
    for (Integer index = 0; index < 101; index++) {
      tooManyTokens += '{!record.Name}';
    }
    assertIssue(tooManyTokens, 'DISPLAY', 'TOKEN_LIMIT_EXCEEDED');
    assertIssue('{!record.Name', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue('{!rhcResult.status}', 'URL', 'TOKEN_NOT_ALLOWED_ON_SURFACE');

    Account accountRecord = new Account(Name = null);
    System.assertEquals(
      'Value: ',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Value: {!record.Name}',
        new RecordHealthCheckMergeContext().withRecord(accountRecord)
      )
    );
    System.assertEquals(
      null,
      RecordHealthCheckTemplateService.resolveDisplay(null, null)
    );
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Parent.Parent.Parent.Parent.Parent.Parent.Name}',
        new RecordHealthCheckMergeContext().withRecord(accountRecord)
      );
      System.assert(false, 'Expected relationship depth to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      System.assertEquals('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }

    String longTemplate = ''.leftPad(20001, 'x');
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        longTemplate,
        new RecordHealthCheckMergeContext()
      );
      System.assert(false, 'Expected resolved length to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      System.assertEquals('RESOLVED_TEMPLATE_TOO_LONG', ex.reasonCode);
    }
  }

  @IsTest
  static void coversUnavailableContextsAndAssertValid() {
    List<String> templates = new List<String>{
      '{!record.Name}',
      '{!rhcRule.checkTitle}',
      '{!rhcSet.cardTitle}',
      '{!rhcResult.status}',
      '{!rhcRun.runId}'
    };
    for (String template : templates) {
      try {
        RecordHealthCheckTemplateService.resolveDisplay(
          template,
          new RecordHealthCheckMergeContext()
        );
        System.assert(false, 'Expected unavailable context for ' + template);
      } catch (RecordHealthCheckTemplateService.TemplateException ex) {
        System.assertEquals('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
      }
    }
    try {
      RecordHealthCheckTemplateService.resolveDisplay('{!record.Name}', null);
      System.assert(false, 'Expected a missing merge context to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      System.assertEquals('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }
    try {
      RecordHealthCheckTemplateService.assertValid('{!bad.value}', 'DISPLAY'); // legacy-token-ok: intentional rejected-token fixture
      System.assert(false, 'Expected assertValid to throw.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      System.assertEquals('UNSUPPORTED_TOKEN_NAMESPACE', ex.reasonCode);
      System.assertEquals('{!bad.value}', ex.token); // legacy-token-ok: intentional rejected-token fixture
    }
    System.assertEquals(
      new Set<String>{ 'Name', 'Owner.Name' },
      RecordHealthCheckTemplateService.recordPaths(
        '{!record.Name} {!record.Owner.Name} {!rhcRun.runId}',
        'DISPLAY'
      )
    );
  }

  @IsTest
  static void resolvesRemainingRulePropertiesAndNullRelationship() {
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      CheckDescription__c = 'Description',
      Category__c = 'DATA_QUALITY',
      EvaluationType__c = 'COMPARE_TWO_QUERIES',
      EvaluationOrder__c = 42
    );
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRule(rule)
      .withRecord(new Account(Name = 'Child'));
    System.assertEquals(
      'Description|Data Quality|Compare Two Queries|42|',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcRule.checkDescription}|{!rhcRule.category}|{!rhcRule.evaluationType}|{!rhcRule.evaluationOrder}|{!record.Parent.Name}',
        context
      )
    );
  }

  private static void assertIssue(
    String template,
    String surface,
    String code
  ) {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      surface
    );
    System.assertEquals(code, issues[0].reasonCode, issues[0].message);
  }
}
