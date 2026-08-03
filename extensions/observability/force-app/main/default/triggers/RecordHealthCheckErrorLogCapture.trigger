/** Persists Framework Error Log events when publication is enabled on the Check Set. */
trigger RecordHealthCheckErrorLogCapture on Record_Health_Check_Log__e(
  after insert
) {
  RecordHealthCheckCaptureService.captureErrorEvents(Trigger.new);
}
