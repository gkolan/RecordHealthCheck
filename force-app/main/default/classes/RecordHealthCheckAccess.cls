/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Central authorization checks for privileged Record Health Check features. */
public with sharing class RecordHealthCheckAccess {
  @TestVisible
  private static Boolean viewDetailsPermissionOverride;

  /**
   * Single Advanced-tier permission. Power-user explanation (Passes when,
   * provenance) and troubleshooting internals (raw exceptions, timings) are one
   * audience, so they share one grant: Record_Health_Check_View_Details.
   * The Check Set's DebugMode__c flag still decides *when* the troubleshooting
   * subset is shown — it is a per-set switch, not a second permission.
   */
  public static Boolean canViewDetails() {
    if (Test.isRunningTest() && viewDetailsPermissionOverride != null) {
      return viewDetailsPermissionOverride;
    }
    return FeatureManagement.checkPermission(
      'Record_Health_Check_View_Details'
    );
  }

  /**
   * Raw troubleshooting detail. Same grant as canViewDetails(); callers pair it
   * with the Check Set's DebugMode__c so internals never surface in production.
   */
  public static Boolean canViewDebugDetails() {
    return canViewDetails();
  }
}
