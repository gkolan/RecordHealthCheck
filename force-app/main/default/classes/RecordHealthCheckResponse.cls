/**
 * Stable response envelope shared by Rule and Check Set selections.
 */
global class RecordHealthCheckResponse {
  @AuraEnabled
  global String runId;
  @AuraEnabled
  global List<Id> recordIds = new List<Id>();
  @AuraEnabled
  global List<String> ruleQualifiedApiNames = new List<String>();
  @AuraEnabled
  global List<RecordHealthCheckResultItem> results = new List<RecordHealthCheckResultItem>();
  @AuraEnabled
  global RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();
}
