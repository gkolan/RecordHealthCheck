/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckValueSourceTest {
  @IsTest
  static void rendersSourceRawAndCoercion() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      'NumberOfEmployees',
      'null',
      'blank treated as 0'
    );
    System.assertEquals(
      'NumberOfEmployees → null (blank treated as 0)',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void rendersSourceAndRawWithoutCoercion() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      'Contacts',
      '0 rows',
      null
    );
    System.assertEquals(
      'Contacts → 0 rows',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void rendersSourceOnly() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      'Pass/Fail condition',
      null,
      null
    );
    System.assertEquals(
      'Pass/Fail condition',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void rendersRawOnlyWhenSourceBlank() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      '  ',
      '42',
      null
    );
    System.assertEquals('42', RecordHealthCheckValueSource.render(d));
  }

  @IsTest
  static void rendersCoercionOnlyWithoutNullPointer() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      null,
      null,
      'blank treated as 0'
    );
    System.assertEquals(
      '(blank treated as 0)',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void returnsNullForNullDetail() {
    System.assertEquals(null, RecordHealthCheckValueSource.render(null));
  }

  @IsTest
  static void returnsNullWhenEveryPartBlank() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      '',
      '   ',
      null
    );
    System.assertEquals(
      null,
      RecordHealthCheckValueSource.render(d),
      'An all-blank detail renders nothing rather than an empty note.'
    );
  }

  @IsTest
  static void rowCountPluralizesCorrectly() {
    System.assertEquals('0 rows', RecordHealthCheckValueSource.rowCount(0));
    System.assertEquals(
      '1 row',
      RecordHealthCheckValueSource.rowCount(1),
      'A single row uses the singular unit, not "1 row(s)".'
    );
    System.assertEquals('3 rows', RecordHealthCheckValueSource.rowCount(3));
    System.assertEquals(
      '0 rows',
      RecordHealthCheckValueSource.rowCount(null),
      'Null is treated as 0.'
    );
  }
}
