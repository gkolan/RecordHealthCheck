/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public class RecordHealthCheckResult {
  @AuraEnabled
  public String checkDeveloperName;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String status; // PASS, FAIL, UNABLE_TO_EVALUATE, SKIPPED, ERROR
  @AuraEnabled
  public String severity; // Error, Warning, Info — only when status == FAIL
  @AuraEnabled
  public String message;
  @AuraEnabled
  public String actualValue; // what the record/query produced — populated on a determinate PASS/FAIL
  @AuraEnabled
  public String expectedValue; // the comparator + comparison operand the value was tested against
  @AuraEnabled
  public String actualValueDetail; // provenance note for the Found side — gated by Record_Health_Check_View_Details
  @AuraEnabled
  public String expectedValueDetail; // provenance note for the Expected side — gated by the same permission
  // Structured provenance the evaluators populate; the engine renders these into
  // the two *Detail strings above and gates them by permission. Intentionally not
  // @AuraEnabled — the public contract is the rendered strings, not this shape.
  public RecordHealthCheckProvenance.Detail actualProvenance;
  public RecordHealthCheckProvenance.Detail expectedProvenance;
  public String detailMessage; // intentionally not @AuraEnabled — raw exception text, internal only
  @AuraEnabled
  public String adminDetailMessage; // populated from detailMessage when DebugMode__c is on
  @AuraEnabled
  public String reasonCode;
  @AuraEnabled
  public Decimal priority;
  @AuraEnabled
  public Long durationMs;
  @AuraEnabled
  public String evaluatorType; // Formula, Query, CompareTwoQueries, Apex
}
