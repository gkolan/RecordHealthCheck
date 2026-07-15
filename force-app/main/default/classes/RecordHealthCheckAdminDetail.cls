/** Diagnostics-only information. This object is never populated for a normal response. */
public class RecordHealthCheckAdminDetail {
  @AuraEnabled
  public Boolean containsRestrictedDetail;
  @AuraEnabled
  public List<String> fieldNames;
  @AuraEnabled
  public String reasonCode;
  @AuraEnabled
  public String message;
}
