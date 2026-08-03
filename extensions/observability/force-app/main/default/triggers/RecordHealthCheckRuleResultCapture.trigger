/** Persists actionable Framework Rule Result lifecycle events. */
trigger RecordHealthCheckRuleResultCapture on Record_Health_Check_Rule_Result__e(
  after insert
) {
  RecordHealthCheckCaptureService.captureRuleEvents(Trigger.new);
}
