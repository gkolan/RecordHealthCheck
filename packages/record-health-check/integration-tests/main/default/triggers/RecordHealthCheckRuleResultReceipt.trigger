/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Scratch-org-only consumer used to verify publish-after-commit behavior. */
trigger RecordHealthCheckRuleResultReceipt on Record_Health_Check_Rule_Result__e(
  after insert
) {
  RHCRuleResultReceiptHandler.afterInsert(Trigger.New);
}
