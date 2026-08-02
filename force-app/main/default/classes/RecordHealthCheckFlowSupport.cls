/** Shared normalization and result-alignment behavior for Flow actions. */
public with sharing class RecordHealthCheckFlowSupport {
  public class FlowSupportException extends Exception {
  }

  /** Finds the aligned response item for one record. */
  public static RecordHealthCheckResultItem itemForRecord(
    RecordHealthCheckResponse response,
    Id recordId
  ) {
    for (RecordHealthCheckResultItem item : response.results) {
      if (item.evaluation.recordId == recordId) {
        return item;
      }
    }
    throw new FlowSupportException(
      'No result was returned for ' + recordId + '.'
    );
  }

  /** Indexes response items once for constant-time Flow row alignment. */
  public static Map<Id, List<RecordHealthCheckResultItem>> itemsByRecord(
    RecordHealthCheckResponse response
  ) {
    Map<Id, List<RecordHealthCheckResultItem>> indexed = new Map<Id, List<RecordHealthCheckResultItem>>();
    if (response == null) {
      return indexed;
    }
    for (RecordHealthCheckResultItem item : response.results) {
      Id recordId = item?.evaluation?.recordId;
      if (recordId == null) {
        continue;
      }
      if (!indexed.containsKey(recordId)) {
        indexed.put(recordId, new List<RecordHealthCheckResultItem>());
      }
      indexed.get(recordId).add(item);
    }
    return indexed;
  }

  /** Normalizes a required Flow publication string. */
  public static String normalizedPublication(String value) {
    if (String.isBlank(value)) {
      throw new FlowSupportException(
        'Event Publication is required. Use NONE, ACTIONABLE, or ALL.'
      );
    }
    return value.trim().toUpperCase();
  }

  /** Maps a normalized Flow publication string to the public enum. */
  public static RecordHealthCheckEventPublication publication(String value) {
    if (value == 'NONE') {
      return RecordHealthCheckEventPublication.NONE;
    }
    if (value == 'ACTIONABLE') {
      return RecordHealthCheckEventPublication.ACTIONABLE;
    }
    if (value == 'ALL') {
      return RecordHealthCheckEventPublication.ALL;
    }
    throw new FlowSupportException(
      'INVALID_EVENT_PUBLICATION: expected NONE, ACTIONABLE, or ALL.'
    );
  }

  /** Returns the highest-priority status represented by a run summary. */
  public static String overallStatus(RecordHealthCheckRunSummary summary) {
    if (summary.systemError > 0) {
      return 'ERROR';
    }
    if (summary.unable > 0) {
      return 'UNABLE_TO_EVALUATE';
    }
    if (summary.failed > 0) {
      return 'FAIL';
    }
    if (summary.passed > 0) {
      return 'PASS';
    }
    return 'SKIPPED';
  }
}
