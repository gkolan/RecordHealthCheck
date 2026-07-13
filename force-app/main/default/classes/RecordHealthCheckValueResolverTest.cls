/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Unit tests for RecordHealthCheckValueResolver. Pure in-memory logic — no DML.
 * Focuses on consolidated behavior the evaluators share: native Date comparison
 * (never coerced to midnight DateTime) and relationship-path extraction with
 * missing-field classification.
 */
@isTest
private class RecordHealthCheckValueResolverTest {
  // ─── Extraction ────────────────────────────────────────────────────────────

  @isTest
  static void singleValueFromRowReadsSimpleField() {
    Account a = new Account(Name = 'Acme');
    System.assertEquals(
      'Acme',
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Name')
    );
  }

  @isTest
  static void singleValueFromRowTraversesRelationshipPath() {
    // Build a nested SObject in memory via JSON so getSObject('Parent') resolves.
    Account a = (Account) JSON.deserialize(
      '{"attributes":{"type":"Account"},"Name":"Child","Parent":{"attributes":{"type":"Account"},"Name":"ParentCo"}}',
      Account.class
    );
    System.assertEquals(
      'ParentCo',
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Parent.Name')
    );
  }

  @isTest
  static void singleValueFromRowNullRelationshipYieldsNull() {
    Account a = new Account(Name = 'Child');
    System.assertEquals(
      null,
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Parent.Name')
    );
  }

  @isTest
  static void singleValueFromRowMissingFieldThrowsInvalidTemplate() {
    Account a = new Account(Name = 'Acme');
    try {
      RecordHealthCheckValueResolver.singleValueFromRow(a, 'Not_A_Field__c');
      System.assert(false, 'Expected ResolverException.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @isTest
  static void stringListIncludesNullAsEmpty() {
    List<SObject> rows = new List<SObject>{
      new Account(Name = 'A'),
      new Account()
    };
    List<String> out = RecordHealthCheckValueResolver.stringList(rows, 'Name');
    System.assertEquals(2, out.size());
    System.assertEquals('A', out[0]);
    System.assertEquals('', out[1], 'Null becomes empty string.');
  }

  // ─── Equality ──────────────────────────────────────────────────────────────

  @isTest
  static void valuesEqualNumericAcrossTypes() {
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.valuesEqual(1, 1.0)
    );
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.valuesEqual(1, 2)
    );
  }

  @isTest
  static void valuesEqualNullSafe() {
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.valuesEqual(null, null)
    );
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.valuesEqual(null, 'x')
    );
  }

  @isTest
  static void valuesEqualDates() {
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.valuesEqual(
        Date.newInstance(2026, 1, 1),
        Date.newInstance(2026, 1, 1)
      )
    );
  }

  @isTest
  static void valuesEqualDateStringsAndInvalidIds() {
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.valuesEqual(
        Date.newInstance(2026, 1, 1),
        '2026-01-01 00:00:00'
      ),
      'Date equality should parse comparable string values.'
    );
    assertIncompatibleEquality(Date.newInstance(2026, 1, 1), 'not-a-date');

    Id accountId = '001000000000001AAA';
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.valuesEqual(accountId, 'not-an-id'),
      'An Id compared to an unparseable Id string should be false, not an exception.'
    );
  }

  // ─── Ordered comparison ────────────────────────────────────────────────────

  @isTest
  static void orderedNumeric() {
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.applyOrdered('GREATER_THAN', 5, 3)
    );
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.applyOrdered('LESS_THAN_OR_EQUAL', 3, 3)
    );
  }

  @isTest
  static void orderedNativeDateUsesDateLadderNotMidnightDateTime() {
    // L6: two native Dates must compare as Dates.
    Date earlier = Date.newInstance(2026, 1, 1);
    Date later = Date.newInstance(2026, 6, 19);
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.applyOrdered('LESS_THAN', earlier, later)
    );
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.applyOrdered(
        'GREATER_THAN',
        earlier,
        later
      )
    );
  }

  @isTest
  static void orderedDateTime() {
    Datetime earlier = Datetime.newInstance(2026, 1, 1, 0, 0, 0);
    Datetime later = Datetime.newInstanceGmt(2026, 1, 1, 10, 0, 0);
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.applyOrdered('LESS_THAN', earlier, later)
    );
  }

  @isTest
  static void orderedIncompatibleTypesThrows() {
    try {
      RecordHealthCheckValueResolver.applyOrdered(
        'GREATER_THAN',
        'not-a-number',
        'also-not'
      );
      System.assert(false, 'Expected INCOMPATIBLE_COMPARISON_TYPES.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      System.assertEquals('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }
  }

  // ─── Misc ──────────────────────────────────────────────────────────────────

  @isTest
  static void isNumericObjectClassifies() {
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.isNumericObject(5)
    );
    System.assertEquals(
      true,
      RecordHealthCheckValueResolver.isNumericObject(5.0)
    );
    System.assertEquals(
      false,
      RecordHealthCheckValueResolver.isNumericObject('5')
    );
  }

  @isTest
  static void classifyQueryExceptionDistinguishesAccess() {
    System.assertEquals(
      'INVALID_SOQL_TEMPLATE',
      RecordHealthCheckValueResolver.classifyQueryException(
        new TestQueryException('malformed query')
      )
    );
    System.assertEquals(
      'FIELD_NOT_ACCESSIBLE',
      RecordHealthCheckValueResolver.classifyQueryException(
        new TestQueryException('insufficient access rights on field')
      )
    );
  }

  @isTest
  static void remainingTypedBranchesAreCovered() {
    try {
      RecordHealthCheckValueResolver.stringList(
        new List<SObject>{ new Account(Name = 'A') },
        null
      );
      System.assert(false, 'Expected a required-field error.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      System.assertEquals('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Datetime earlier = Datetime.newInstance(2026, 1, 1, 0, 0, 0);
    Datetime earlierGmt = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
    Datetime later = earlier.addHours(1);
    Date earlierDate = Date.newInstance(2026, 1, 1);
    Date laterDate = earlierDate.addDays(1);

    System.assert(
      RecordHealthCheckValueResolver.valuesEqual(earlier, '2026-01-01 00:00:00')
    );
    assertIncompatibleEquality(earlier, 'not-a-datetime');
    assertIncompatibleEquality(earlierDate, 'not-a-date');

    for (
      String operator : new List<String>{
        'GREATER_THAN',
        'GREATER_THAN_OR_EQUAL',
        'LESS_THAN',
        'LESS_THAN_OR_EQUAL'
      }
    ) {
      RecordHealthCheckValueResolver.orderedDecimal(operator, 2, 1);
      RecordHealthCheckValueResolver.orderedDateTime(operator, later, earlier);
    }

    assertInvalidOrderedOperator('Decimal');
    assertInvalidOrderedOperator('DATETIME');
    System.assertEquals(
      earlierGmt,
      RecordHealthCheckValueResolver.coerceDateTime('2026-01-01T00:00:00Z')
    );
    try {
      RecordHealthCheckValueResolver.applyOrdered('Nope', 1, 1);
      System.assert(false, 'Expected an invalid ordered operator.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
  }

  private static void assertIncompatibleEquality(Object left, Object right) {
    try {
      RecordHealthCheckValueResolver.valuesEqual(left, right);
      System.assert(false, 'Expected incompatible equality operands.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      System.assertEquals('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }
  }

  private static void assertInvalidOrderedOperator(String valueType) {
    try {
      if (valueType == 'Decimal') {
        RecordHealthCheckValueResolver.orderedDecimal('Nope', 1, 1);
      } else if (valueType == 'DATETIME') {
        RecordHealthCheckValueResolver.orderedDateTime(
          'Nope',
          System.now(),
          System.now()
        );
      } else {
        RecordHealthCheckValueResolver.orderedDateTime(
          'Nope',
          System.now(),
          System.now()
        );
      }
      System.assert(false, 'Expected an invalid operator.');
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      System.assertEquals('INVALID_OPERATOR', ex.reasonCode);
    }
  }

  // Lets us construct a QueryException with a controlled message.
  private class TestQueryException extends Exception {
  }
}
