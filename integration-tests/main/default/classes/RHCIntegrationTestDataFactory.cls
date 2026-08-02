/** Centralizes integration-harness test records that are not part of Framework. */
@IsTest
public class RHCIntegrationTestDataFactory {
  public static void createRecords(List<SObject> records) {
    insert records;
  }

  public static SObject createRecord(SObject record) {
    insert record;
    return record;
  }

  public static RHC_Benchmark_Result__c benchmarkResult(
    Map<String, Object> fields
  ) {
    RHC_Benchmark_Result__c result = new RHC_Benchmark_Result__c();
    applyFields(result, fields);
    return result;
  }

  public static RHC_Event_Export__c eventExport(Map<String, Object> fields) {
    RHC_Event_Export__c result = new RHC_Event_Export__c();
    applyFields(result, fields);
    return result;
  }

  private static void applyFields(SObject record, Map<String, Object> fields) {
    for (String fieldName : fields?.keySet() ?? new Set<String>()) {
      record.put(fieldName, fields.get(fieldName));
    }
  }
}
