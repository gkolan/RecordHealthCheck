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
  static void rendersCoercionOnlyWithoutNullPointer() {
    RecordHealthCheckProvenance.Detail d = new RecordHealthCheckProvenance.Detail(
      null,
      null,
      'blank treated as 0'
    );
    System.assertEquals(
      '(blank treated as 0)',
      RecordHealthCheckProvenance.render(d)
    );
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

  @isTest
  static void rowCountPluralizesCorrectly() {
    System.assertEquals('0 rows', RecordHealthCheckProvenance.rowCount(0));
    System.assertEquals(
      '1 row',
      RecordHealthCheckProvenance.rowCount(1),
      'A single row uses the singular unit, not "1 row(s)".'
    );
    System.assertEquals('3 rows', RecordHealthCheckProvenance.rowCount(3));
    System.assertEquals(
      '0 rows',
      RecordHealthCheckProvenance.rowCount(null),
      'Null is treated as 0.'
    );
  }
}
