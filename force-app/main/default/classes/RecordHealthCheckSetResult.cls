/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Versioned response for one Check Set evaluated against one record. */
public class RecordHealthCheckSetResult {
  @AuraEnabled
  public String contractVersion = RecordHealthCheckResult.CONTRACT_VERSION;
  @AuraEnabled
  public String checkSetDeveloperName;
  @AuraEnabled
  public Id recordId;
  @AuraEnabled
  public String runId;
  @AuraEnabled
  public String status;
  @AuraEnabled
  public Integer passedCount = 0;
  @AuraEnabled
  public Integer failedCount = 0;
  @AuraEnabled
  public Integer skippedCount = 0;
  @AuraEnabled
  public Integer unableCount = 0;
  @AuraEnabled
  public Integer systemErrorCount = 0;
  @AuraEnabled
  public List<RecordHealthCheckResult> results = new List<RecordHealthCheckResult>();

  public void add(RecordHealthCheckResult result) {
    results.add(result);
    if (result.status == 'PASS') {
      passedCount++;
    } else if (result.status == 'FAIL') {
      failedCount++;
    } else if (result.status == 'SKIPPED') {
      skippedCount++;
    } else if (result.status == 'ERROR') {
      systemErrorCount++;
    } else {
      unableCount++;
    }
  }

  public void finish() {
    if (systemErrorCount > 0) {
      status = 'ERROR';
    } else if (unableCount > 0) {
      status = 'UNABLE_TO_EVALUATE';
    } else if (failedCount > 0) {
      status = 'FAIL';
    } else if (passedCount > 0) {
      status = 'PASS';
    } else {
      status = 'SKIPPED';
    }
  }
}
