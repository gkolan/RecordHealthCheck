/**
 * Stable machine-readable result for one Rule evaluated against one record.
 */
global class RecordHealthCheckEvaluationResult {
  @AuraEnabled
  global Id recordId;
  @AuraEnabled
  global String ruleQualifiedApiName;
  @AuraEnabled
  global String status;
  @AuraEnabled
  global String severity;
  @AuraEnabled
  global String reasonCode;
  @AuraEnabled
  global RecordHealthCheckValue found;
  @AuraEnabled
  global String comparisonOperator;
  @AuraEnabled
  global RecordHealthCheckValue expected;
}
