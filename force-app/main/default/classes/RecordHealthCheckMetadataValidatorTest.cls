/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckMetadataValidatorTest {
  @isTest
  static void validateReturnsAListForPackagedMetadata() {
    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validate();
    Test.stopTest();

    System.assertNotEquals(null, issues);
  }

  // Guards the shipped examples: every active packaged Check Set and Rule must
  // validate clean. If this fails, an example rule has drifted out of spec and
  // would surface a runtime error to an admin who copied it. The failure
  // message lists each offending component so the fix is obvious.
  @isTest
  static void packagedActiveMetadataHasNoValidationErrors() {
    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validate();
    Test.stopTest();

    List<String> errors = new List<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (issue.severity == 'ERROR') {
        errors.add(
          issue.componentName +
            '.' +
            issue.fieldName +
            ' [' +
            issue.reasonCode +
            '] ' +
            issue.message
        );
      }
    }

    System.assertEquals(
      0,
      errors.size(),
      'Packaged active metadata must validate clean. Issues found:\n' +
      String.join(errors, '\n')
    );
  }

  @isTest
  static void validationIssueStoresConstructorValues() {
    RecordHealthCheckMetadataValidator.ValidationIssue issue = new RecordHealthCheckMetadataValidator.ValidationIssue(
      'ERROR',
      'Component_Name',
      'Field__c',
      'Message',
      'REASON'
    );

    System.assertEquals('ERROR', issue.severity);
    System.assertEquals('Component_Name', issue.componentName);
    System.assertEquals('Field__c', issue.fieldName);
    System.assertEquals('Message', issue.message);
    System.assertEquals('REASON', issue.reasonCode);
  }

  @isTest
  static void validateRejectsUnrecognizedComparisonDisplay() {
    Record_Health_Check_Set__mdt checkSet = new Record_Health_Check_Set__mdt(
      DeveloperName = 'Bad_Comparison_Display',
      ObjectApiName__c = 'Account',
      PanelHeading__c = 'Bad Comparison Display',
      PassedChecksDisplay__c = 'Show',
      SkippedChecksDisplay__c = 'Show',
      RunChecksWhen__c = 'Manual',
      RowAppearance__c = 'AllAtOnce',
      ComparisonDisplay__c = 'Bogus'
    );

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecordsForTest(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check_Rule__mdt>()
      );

    Boolean found = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (
        issue.componentName == 'Bad_Comparison_Display' &&
        issue.fieldName == 'ComparisonDisplay__c' &&
        issue.reasonCode == 'INVALID_CONFIG' &&
        issue.message.contains('Bogus')
      ) {
        found = true;
      }
    }

    System.assert(
      found,
      'Metadata validation should reject invalid ComparisonDisplay__c values.'
    );
  }
}
