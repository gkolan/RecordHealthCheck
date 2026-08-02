/**
 * One response item containing evaluation data and optional display content.
 */
global class RecordHealthCheckResultItem {
  @AuraEnabled
  global RecordHealthCheckEvaluationResult evaluation;
  @AuraEnabled
  global RecordHealthCheckResultDisplay display;
}
