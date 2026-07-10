/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Design-time picklist for the LWC's Check Set property in Lightning App Builder.
 * Replaces free-text entry of a Check Set Developer Name — the most common cause
 * of a blank card — with a dropdown of the active Check Sets that apply to the
 * record page's object.
 *
 * Both the label and the stored value are the Check Set DeveloperName: it is
 * guaranteed unique (MasterLabels are not), it is what the engine and every doc
 * reference, and it is stable. App Builder supplies the page's object through
 * DesignTimePageContext.entityName, so the list is scoped to Check Sets whose
 * ObjectApiName__c matches. Runs at design time as the admin building the page;
 * custom-metadata SOQL is not governor-limited.
 */
public with sharing class RecordHealthCheckSetPicklist extends VisualEditor.DynamicPickList {
  private final VisualEditor.DesignTimePageContext context;

  public RecordHealthCheckSetPicklist(
    VisualEditor.DesignTimePageContext context
  ) {
    this.context = context;
  }

  /**
   * Auto-selects the object's sole active Check Set so dropping the component
   * onto a page with one obvious choice works with zero clicks. With zero or
   * several matches, returns null so the admin picks explicitly.
   */
  public override VisualEditor.DataRow getDefaultValue() {
    List<String> names = scopedDeveloperNames();
    return names.size() == 1 ? row(names[0]) : null;
  }

  public override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows rows = new VisualEditor.DynamicPickListRows();
    for (String name : scopedDeveloperNames()) {
      rows.addRow(row(name));
    }
    return rows;
  }

  /** Active Check Set DeveloperNames scoped to the page's object, sorted. */
  private List<String> scopedDeveloperNames() {
    String entityName = context == null ? null : context.entityName;
    List<String> names = new List<String>();
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is setup data for App Builder design-time choices; runtime access is enforced by RecordHealthCheckAccess before definitions are exposed.
    for (Record_Health_Check_Set__mdt checkSet : [
      SELECT DeveloperName, ObjectApiName__c
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE
      ORDER BY DeveloperName ASC
    ]) {
      // Scope to the record page's object when App Builder names one; a page
      // without an entity (e.g. a template being edited) shows every active set.
      if (
        String.isBlank(entityName) ||
        entityName.equalsIgnoreCase(checkSet.ObjectApiName__c)
      ) {
        names.add(checkSet.DeveloperName);
      }
    }
    return names;
  }

  /** DeveloperName is both the label and the stored value (unique, stable). */
  private VisualEditor.DataRow row(String developerName) {
    return new VisualEditor.DataRow(developerName, developerName);
  }
}
