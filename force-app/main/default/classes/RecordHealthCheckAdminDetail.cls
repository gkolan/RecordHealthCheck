/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Diagnostics-only information. This object is never set for a normal response. */
public class RecordHealthCheckAdminDetail {
  @AuraEnabled
  public Boolean containsRestrictedDetail;
  @AuraEnabled
  public String reasonCode;
  @AuraEnabled
  public String message;
}
