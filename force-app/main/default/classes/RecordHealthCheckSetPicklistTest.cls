/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@isTest
private class RecordHealthCheckSetPicklistTest {
  @isTest
  static void scopesRowsToPageObject() {
    VisualEditor.DesignTimePageContext ctx = new VisualEditor.DesignTimePageContext();
    ctx.entityName = 'Account';
    RecordHealthCheckSetPicklist picklist = new RecordHealthCheckSetPicklist(
      ctx
    );

    VisualEditor.DynamicPickListRows rows = picklist.getValues();
    System.assertNotEquals(null, rows);

    Integer activeAccountSets = [
      SELECT COUNT()
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE AND ObjectApiName__c = 'Account'
    ];
    System.assertEquals(
      activeAccountSets,
      rows.size(),
      'One row per active Check Set scoped to the page object'
    );
    // Account ships with several active Check Sets, so there is no single
    // obvious choice — getDefaultValue stays null and the admin picks explicitly.
    // (The auto-select branch fires only when exactly one set matches the object;
    // the sample data has no single-set object to exercise it via data.)
    System.assert(
      activeAccountSets != 1,
      'Fixture assumption: Account has multiple active Check Sets'
    );
    System.assertEquals(
      null,
      picklist.getDefaultValue(),
      'With several matches there is no auto-default'
    );
  }

  @isTest
  static void emptyForUnknownObjectAndNullContextIsSafe() {
    VisualEditor.DesignTimePageContext ctx = new VisualEditor.DesignTimePageContext();
    ctx.entityName = 'ZZ_No_Such_Object__x';
    RecordHealthCheckSetPicklist unknown = new RecordHealthCheckSetPicklist(
      ctx
    );
    System.assertEquals(
      0,
      unknown.getValues().size(),
      'An object with no Check Sets yields an empty dropdown'
    );
    System.assertEquals(
      null,
      unknown.getDefaultValue(),
      'No match → no auto-default'
    );

    // A null context (e.g. a page template with no bound entity) must not throw
    // and falls back to every active Check Set.
    Integer allActive = [
      SELECT COUNT()
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE
    ];
    System.assertEquals(
      allActive,
      new RecordHealthCheckSetPicklist(null).getValues().size(),
      'Null page context shows all active Check Sets'
    );
  }
}
