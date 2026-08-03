/**
 * One response item containing evaluation data and optional display content.
 */
global class RecordHealthCheckResultItem {
  @AuraEnabled
  /** Stable machine-readable evaluation. */
  global RecordHealthCheckEvaluationResult evaluation;
  @AuraEnabled
  /** Optional human-facing rendering. */
  global RecordHealthCheckResultDisplay display;
}
