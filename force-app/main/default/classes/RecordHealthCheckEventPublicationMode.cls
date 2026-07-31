/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Controls whether an evaluation publishes lifecycle Platform Events.
 *
 * Event publication is a side effect. Interactive entry points (record page,
 * Flow) keep the administrator's configured behavior; programmatic Apex entry
 * points publish nothing unless the caller asks, so batch jobs, integrations,
 * and tests never emit events by accident.
 *
 * - `NONE`                publishes nothing, whatever the metadata says.
 * - `CONFIGURED_RESULTS`  honors `PublishResultEvent__c` / `PublishRunEvent__c`.
 * - `ACTIONABLE_RESULTS`  honors the same metadata switches but emits Rule
 *                         Result events only for outcomes that need attention
 *                         (`FAIL`, `UNABLE_TO_EVALUATE`, `ERROR`). Set Run
 *                         summary events are unaffected: one per run is already
 *                         aggregate, and a scan needs its totals.
 */
public enum RecordHealthCheckEventPublicationMode {
  NONE,
  CONFIGURED_RESULTS,
  ACTIONABLE_RESULTS
}
