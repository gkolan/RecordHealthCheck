/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckSecurityAndOpsTest {
  @isTest
  static void debugDetailRequiresViewDetailsPermission() {
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.detailMessage = 'sensitive query detail';
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    // Troubleshooting detail now shares the single Advanced-tier grant with
    // value source; canViewDebugDetails() delegates to canViewDetails().
    RecordHealthCheckAccess.viewDetailsPermissionOverride = false;
    System.assertEquals(false, RecordHealthCheckAccess.canViewDebugDetails());
    System.assertEquals(
      null,
      engine.applyShowDiagnostics(result, true).adminDetailMessage
    );

    RecordHealthCheckAccess.viewDetailsPermissionOverride = true;
    System.assertEquals(true, RecordHealthCheckAccess.canViewDebugDetails());
    System.assertEquals(
      'sensitive query detail',
      engine.applyShowDiagnostics(result, true).adminDetailMessage
    );
    RecordHealthCheckAccess.viewDetailsPermissionOverride = null;
    System.assertNotEquals(
      null,
      RecordHealthCheckAccess.canViewDebugDetails(),
      'The platform permission check must always return a Boolean.'
    );
  }

  @isTest
  static void restrictedReasonIsNeutralOutsideAuthorizedDiagnostics() {
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.status = 'UNABLE_TO_EVALUATE';
    result.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE;
    result.detailMessage = 'Secret_Field__c is not accessible';

    RecordHealthCheckAccess.viewDetailsPermissionOverride = false;
    RecordHealthCheckResult normal = engine.applyShowDiagnostics(result, true);
    System.assertEquals(
      RecordHealthCheckReasonCodes.CANNOT_EVALUATE,
      normal.reasonCode,
      'A normal response must use the neutral reason.'
    );
    System.assertEquals(
      null,
      normal.adminDetail,
      'A normal response must not disclose restriction presence.'
    );

    result.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE;
    RecordHealthCheckAccess.viewDetailsPermissionOverride = true;
    RecordHealthCheckResult diagnostic = engine.applyShowDiagnostics(
      result,
      true
    );
    System.assertEquals(
      RecordHealthCheckReasonCodes.CANNOT_EVALUATE,
      diagnostic.reasonCode,
      'The public reason remains neutral under diagnostics.'
    );
    System.assertEquals(true, diagnostic.adminDetail.containsRestrictedDetail);
    System.assertEquals(
      RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE,
      diagnostic.adminDetail.reasonCode
    );
    System.assertEquals(
      'Secret_Field__c is not accessible',
      diagnostic.adminDetail.message
    );
    RecordHealthCheckAccess.viewDetailsPermissionOverride = null;
  }

  @isTest
  static void passesWhenLineRequiresViewDetailsPermission() {
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    // Not entitled → the raw pass/fail condition is cleared so business users see
    // the failure message only, not the formula text.
    RecordHealthCheckAccess.viewDetailsPermissionOverride = false;
    RecordHealthCheckResult gated = engine.applyPassesWhenEntitlement(
      newPassesWhenResult()
    );
    System.assertEquals(null, gated.expectedValue);
    System.assertEquals(null, gated.expectedValueLabel);

    // Entitled → the Passes when line survives untouched.
    RecordHealthCheckAccess.viewDetailsPermissionOverride = true;
    RecordHealthCheckResult shown = engine.applyPassesWhenEntitlement(
      newPassesWhenResult()
    );
    System.assertEquals('NOT(ISBLANK(BillingCity))', shown.expectedValue);
    System.assertEquals(
      RecordHealthCheckResult.PASSES_WHEN_LABEL,
      shown.expectedValueLabel
    );

    // A business Expected (display formula: no expectedValueLabel) is never gated.
    RecordHealthCheckResult businessExpected = new RecordHealthCheckResult();
    businessExpected.expectedValue = '"50,000"';
    RecordHealthCheckAccess.viewDetailsPermissionOverride = false;
    RecordHealthCheckResult keep = engine.applyPassesWhenEntitlement(
      businessExpected
    );
    System.assertEquals('"50,000"', keep.expectedValue);

    RecordHealthCheckAccess.viewDetailsPermissionOverride = null;
  }

  private static RecordHealthCheckResult newPassesWhenResult() {
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.expectedValue = 'NOT(ISBLANK(BillingCity))';
    result.expectedValueLabel = RecordHealthCheckResult.PASSES_WHEN_LABEL;
    return result;
  }

  @isTest
  static void provenanceDetailRequiresViewDetailsPermission() {
    RecordHealthCheckResult result = new RecordHealthCheckResult();
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      'NumberOfEmployees',
      'null',
      'blank treated as 0'
    );
    result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
      'Fixed value',
      '10',
      null
    );
    RecordHealthCheckEngine engine = new RecordHealthCheckEngine();

    // Not entitled → the public *Detail strings stay null (the Found/Expected
    // values themselves are unaffected — they are governed by display policy).
    RecordHealthCheckAccess.viewDetailsPermissionOverride = false;
    System.assertEquals(false, RecordHealthCheckAccess.canViewDetails());
    RecordHealthCheckResult gated = engine.applyValueSourceDetail(result);
    System.assertEquals(null, gated.actualValueDetail);
    System.assertEquals(null, gated.expectedValueDetail);

    // Entitled → the structured value source renders into the two strings.
    RecordHealthCheckAccess.viewDetailsPermissionOverride = true;
    System.assertEquals(true, RecordHealthCheckAccess.canViewDetails());
    RecordHealthCheckResult shown = engine.applyValueSourceDetail(result);
    System.assertEquals(
      'NumberOfEmployees → null (blank treated as 0)',
      shown.actualValueDetail
    );
    System.assertEquals('Fixed value → 10', shown.expectedValueDetail);

    RecordHealthCheckAccess.viewDetailsPermissionOverride = null;
    System.assertNotEquals(
      null,
      RecordHealthCheckAccess.canViewDetails(),
      'The platform permission check must always return a Boolean.'
    );
  }

  @isTest
  static void structuredLogValuesCannotForgeNewLines() {
    System.assertEquals(
      'ticket forged value',
      RecordHealthCheckLogger.sanitize('ticket\nforged\tvalue', 120)
    );
    System.assertEquals(
      '12345',
      RecordHealthCheckLogger.sanitize('123456789', 5)
    );
  }

  @isTest
  static void fieldPlanningIgnoresLiteralsAndInvalidMessageTokens() {
    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'CONTAINS(Website, "example.com") && NOT(ISBLANK(Parent.Name))',
      FailureMessage__c = 'Bad token stays blank: {!record.Parent.Missing__c}'
    );

    Set<String> fields = new RecordHealthCheckEngine()
      .collectRecordFields(rule, Account.SObjectType);

    System.assert(fields.contains('Website'));
    System.assert(fields.contains('Parent.Name'));
    System.assert(!fields.contains('example.com'));
    System.assert(!fields.contains('Parent.Missing__c'));
  }

  @isTest
  static void sharedValidatorCoversObjectsPluginsAndJson() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures())
      return;
    System.assert(
      RecordHealthCheckConfigValidator.isValidObjectApiName('Account')
    );
    System.assert(
      !RecordHealthCheckConfigValidator.isValidObjectApiName('Nope__c')
    );
    System.assert(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'AccountHasRecentActivityCheck'
      )
    );
    System.assert(
      !RecordHealthCheckConfigValidator.isValidApexPlugin('String')
    );
    System.assert(
      RecordHealthCheckConfigValidator.isJsonObject('{"daysBack":90}')
    );
    System.assert(!RecordHealthCheckConfigValidator.isJsonObject('[1,2,3]'));
  }
}
