/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Focused tests for SOQL record-token binding.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RecordHealthCheckSoqlTokenBinderTest {
  @IsTest
  static void bindsTypedAndEscapedValues() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'O\'Hare', 'NumberOfEmployees' => 25 }
    );

    Test.startTest();
    String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name} ' +
      'AND NumberOfEmployees = {!record.NumberOfEmployees}',
      record
    );
    Test.stopTest();

    Assert.isTrue(
      bound.contains('O\\\'Hare'),
      'String values should be escaped before insertion.'
    );
    Assert.isTrue(
      bound.contains('NumberOfEmployees = 25'),
      'Numeric values should remain unquoted.'
    );
  }

  @IsTest
  static void rejectsDisallowedQueryKeywords() {
    Test.startTest();
    try {
      RecordHealthCheckSoqlTokenBinder.validateNoDisallowedKeywords(
        'SELECT Id FROM Account FOR UPDATE'
      );
      Assert.fail('FOR UPDATE should be rejected.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'The rejection should use the template error reason.'
      );
    }
    Test.stopTest();
  }
}
