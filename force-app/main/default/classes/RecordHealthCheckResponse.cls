/**
 * Stable response envelope shared by Rule and Check Set selections.
 */
global class RecordHealthCheckResponse {
  @AuraEnabled
  /** Correlation identifier for the evaluation. */
  global String runId;
  @AuraEnabled
  /** Ordered normalized record scope. */
  global List<Id> recordIds = new List<Id>();
  @AuraEnabled
  /** Ordered qualified Rule identities selected for evaluation. */
  global List<String> ruleQualifiedApiNames = new List<String>();
  @AuraEnabled
  /** Ordered result items included by the selected result mode. */
  global List<RecordHealthCheckResultItem> results = new List<RecordHealthCheckResultItem>();
  @AuraEnabled
  /** Aggregate terminal-status counts. */
  global RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();
}
