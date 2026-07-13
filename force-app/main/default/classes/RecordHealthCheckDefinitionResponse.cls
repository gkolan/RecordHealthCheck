/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public class RecordHealthCheckDefinitionResponse {
  @AuraEnabled
  public String displayTitle;
  @AuraEnabled
  public String displayDescription;
  @AuraEnabled
  public String triggerMode; // Automatic, Manual — mapped from CardRunMode__c
  @AuraEnabled
  public String revealMode; // AllAtOnce, OneAtATime — mapped from CardRevealMode__c
  @AuraEnabled
  public String successDisplayMode; // Show, Hide — mapped from PassedChecksDisplay__c
  @AuraEnabled
  public String skippedDisplayMode; // Show, Hide — mapped from SkippedChecksDisplay__c
  @AuraEnabled
  public String comparisonDisplay; // OnDemand, FailuresOnly, AllRows — mapped from FoundExpectedDisplay__c
  @AuraEnabled
  public Boolean stopOnFirstError;
  @AuraEnabled
  public Integer totalAvailableCheckCount; // active checks before framework cap truncation
  @AuraEnabled
  public Boolean checksOmittedByLimit; // true when active checks were omitted
  @AuraEnabled
  public Integer inactiveRuleCount; // inactive Rules on the Check Set (not run)
  @AuraEnabled
  public Boolean showDiagnostics; // mirrors ShowDiagnostics__c — tells LWC to show adminDetailMessage
  @AuraEnabled
  public List<RecordHealthCheckDefinition> checks;
}
