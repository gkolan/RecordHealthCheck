/** Counts terminal statuses across one response. */
global class RecordHealthCheckRunSummary {
  @AuraEnabled
  global Integer passed = 0;
  @AuraEnabled
  global Integer failed = 0;
  @AuraEnabled
  global Integer skipped = 0;
  @AuraEnabled
  global Integer unable = 0;
  @AuraEnabled
  global Integer systemError = 0;

  /** @param status Terminal Record Health Check status to count. */
  global void add(String status) {
    if (RecordHealthCheckStatus.PASS == status) {
      passed++;
    } else if (RecordHealthCheckStatus.FAIL == status) {
      failed++;
    } else if (RecordHealthCheckStatus.SKIPPED == status) {
      skipped++;
    } else if (RecordHealthCheckStatus.UNABLE_TO_EVALUATE == status) {
      unable++;
    } else {
      systemError++;
    }
  }

  /** @return Total terminal results represented by this summary. */
  global Integer total() {
    return passed + failed + skipped + unable + systemError;
  }
}
