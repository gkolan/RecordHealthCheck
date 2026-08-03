/** Persists terminal Framework Set Run lifecycle events. */
trigger RecordHealthCheckSetRunCapture on Record_Health_Check_Set_Run__e(
  after insert
) {
  RecordHealthCheckCaptureService.captureSetEvents(Trigger.new);
}
