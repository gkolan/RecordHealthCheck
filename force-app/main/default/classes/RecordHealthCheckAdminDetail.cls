/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Diagnostics-only information. This object is never set for a normal response. */
global class RecordHealthCheckAdminDetail {
  @AuraEnabled
  global Boolean containsRestrictedDetail;
  @AuraEnabled
  global String reasonCode;
  @AuraEnabled
  global String message;
  @AuraEnabled
  global String configurationJson;
  @AuraEnabled
  global String resolutionJson;
}
