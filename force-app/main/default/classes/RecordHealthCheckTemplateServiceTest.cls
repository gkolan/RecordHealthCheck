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
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withRule(rule)
      .withResult(result, true);
    context.failedRecordCount = 2;
    context.totalRecordCount = 5;

    System.assertEquals(
      'Acme | {!record.Name} | Stable_Name | Setup Label | Visible title | Critical | FAIL | 2/5',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name} | {!record.Description} | {!rhcRule.developerName} | {!rhcRule.masterLabel} | {!rhcRule.checkTitle} | {!rhcRule.failureSeverity} | {!rhcResult.status} | {!rhcResult.failedRecordCount}/{!rhcResult.totalRecordCount}',
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
  static void rejectsDeferredRunNamespace() {
    // The `rhcRun` namespace is deferred (BLK-7): validation must reject its
    // tokens so config never accepts a token that would fail at runtime.
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      '{!rhcRun.runId}',
      'DISPLAY'
    );
    System.assertEquals(
      1,
      issues.size(),
      'Expected exactly one issue for the deferred rhcRun namespace'
    );
    System.assertEquals(
      'UNSUPPORTED_TOKEN_NAMESPACE',
      issues[0].reasonCode,
      'rhcRun should be reported as an unsupported namespace'
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
