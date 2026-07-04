/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckProvenanceTest {
  @isTest
  static void rendersSourceRawAndCoercion() {
    RecordHealthCheckProvenance.Detail d = new RecordHealthCheckProvenance.Detail(
      'NumberOfEmployees',
      'null',
      'blank treated as 0'
    );
    System.assertEquals(
      'NumberOfEmployees → null (blank treated as 0)',
      RecordHealthCheckProvenance.render(d)
    );
  }

  @isTest
  static void rendersSourceAndRawWithoutCoercion() {
    RecordHealthCheckProvenance.Detail d = new RecordHealthCheckProvenance.Detail(
      'Contacts',
      '0 rows',
      null
    );
    System.assertEquals(
      'Contacts → 0 rows',
      RecordHealthCheckProvenance.render(d)
    );
  }

  @isTest
  static void rendersSourceOnly() {
    RecordHealthCheckProvenance.Detail d = new RecordHealthCheckProvenance.Detail(
      'Pass/Fail condition',
      null,
      null
    );
    System.assertEquals(
      'Pass/Fail condition',
      RecordHealthCheckProvenance.render(d)
    );
  }

  @isTest
  static void rendersRawOnlyWhenSourceBlank() {
    RecordHealthCheckProvenance.Detail d = new RecordHealthCheckProvenance.Detail(
      '  ',
      '42',
      null
    );
    System.assertEquals('42', RecordHealthCheckProvenance.render(d));
  }

  @isTest
  static void returnsNullForNullDetail() {
    System.assertEquals(null, RecordHealthCheckProvenance.render(null));
  }

  @isTest
  static void returnsNullWhenEveryPartBlank() {
    RecordHealthCheckProvenance.Detail d = new RecordHealthCheckProvenance.Detail(
      '',
      '   ',
      null
    );
    System.assertEquals(
      null,
      RecordHealthCheckProvenance.render(d),
      'An all-blank detail renders nothing rather than an empty note.'
    );
  }
}
