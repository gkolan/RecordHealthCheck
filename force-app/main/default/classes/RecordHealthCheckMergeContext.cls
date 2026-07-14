/** Typed sources available to V2 merge-token resolution. */
public class RecordHealthCheckMergeContext {
  public SObject record;
  public Record_Health_Check_Rule__mdt rule;
  public SObject checkSet;
  public RecordHealthCheckResult result;
  public Integer failedRecordCount;
  public Integer totalRecordCount;
  public Boolean resultFinalized = false;

  public RecordHealthCheckMergeContext withRecord(SObject value) {
    record = value;
    return this;
  }
  public RecordHealthCheckMergeContext withRule(
    Record_Health_Check_Rule__mdt value
  ) {
    rule = value;
    if (value != null) {
      checkSet = value.getSObject('Record_Health_Check_Set__r');
    }
    return this;
  }
  public RecordHealthCheckMergeContext withResult(
    RecordHealthCheckResult value,
    Boolean finalized
  ) {
    result = value;
    resultFinalized = finalized == true;
    return this;
  }
}
