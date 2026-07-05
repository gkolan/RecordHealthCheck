/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Central authorization checks for privileged Record Health Check features. */
public with sharing class RecordHealthCheckAccess {
  @TestVisible
  private static Boolean debugPermissionOverride;
  @TestVisible
  private static Boolean viewDetailsPermissionOverride;

  /** Raw evaluator/query/plugin details are restricted even when metadata enables debug mode. */
  public static Boolean canViewDebugDetails() {
    if (Test.isRunningTest() && debugPermissionOverride != null) {
      return debugPermissionOverride;
    }
    return FeatureManagement.checkPermission('Record_Health_Check_Debug');
  }

  /**
   * Comparison provenance (source/raw/coercion notes) is a lighter tier than
   * full debug detail — it lets entitled business users audit what a check
   * compared without exposing raw exceptions. Gates the *Detail strings only;
   * the Found/Expected values themselves are governed by display policy, not
   * this permission.
   */
  public static Boolean canViewDetails() {
    if (Test.isRunningTest() && viewDetailsPermissionOverride != null) {
      return viewDetailsPermissionOverride;
    }
    return FeatureManagement.checkPermission(
      'Record_Health_Check_View_Details'
    );
  }
}
