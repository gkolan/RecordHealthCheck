/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** The single public execution entry point for Record Health Check 2.0. */
global with sharing class RecordHealthCheck {
  /**
   * Executes one qualified Rule or Check Set request through the scope pipeline.
   *
   * @param request Immutable qualified selection, record IDs, and options.
   * @return One ordered response envelope for every selector and scope size.
   */
  global static RecordHealthCheckResponse evaluate(
    RecordHealthCheckRequest request
  ) {
    try {
      return new RecordHealthCheckScopePipeline().evaluate(request);
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }
}
