/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The unit of work handed to a Rule: the records to evaluate, and the context
 * needed to evaluate them.
 *
 * The scope is read-only. Fields are exposed through getters and `recordIds`
 * hands back a detached copy, so a plugin holding a reference cannot mutate
 * engine state.
 *
 * `source` is deliberately absent. It is telemetry the engine already owns, and
 * a plugin must not branch on it. Putting it in the extension contract would
 * permanently enable exactly the source-dependent behavior this architecture
 * rejects.
 *
 * Interactive evaluation is a bulk evaluation whose scope happens to contain
 * one record. Not a different API, path, or standard.
 */
global class RecordHealthCheckScope {
  global String objectApiName { get; private set; }
  global String ruleDeveloperName { get; private set; }
  global String checkSetDeveloperName { get; private set; }
  global String runId { get; private set; }

  private List<Id> recordIdsInternal;
  private Map<String, Object> parametersInternal;

  /** A detached copy: mutating the returned list cannot reach engine state. */
  global List<Id> recordIds {
    get {
      return new List<Id>(recordIdsInternal);
    }
  }

  /** Parsed from ApexParametersJson__c. Never null; an unconfigured Rule gets an empty map. */
  global Map<String, Object> parameters {
    get {
      return new Map<String, Object>(parametersInternal);
    }
  }

  global Integer size() {
    return recordIdsInternal.size();
  }

  /**
   * Built by the engine only. Duplicate Ids are removed here, preserving first
   * occurrence, and a scope mixing object types is rejected before any
   * evaluator sees it, because a Rule is authored against one object.
   */
  public RecordHealthCheckScope(
    String objectApiName,
    List<Id> recordIds,
    Map<String, Object> parameters,
    String ruleDeveloperName,
    String checkSetDeveloperName,
    String runId
  ) {
    this.objectApiName = objectApiName;
    this.ruleDeveloperName = ruleDeveloperName;
    this.checkSetDeveloperName = checkSetDeveloperName;
    this.runId = runId;
    this.parametersInternal = parameters == null
      ? new Map<String, Object>()
      : parameters;
    this.recordIdsInternal = dedupe(recordIds, objectApiName);
  }

  private static List<Id> dedupe(List<Id> recordIds, String objectApiName) {
    List<Id> ordered = new List<Id>();
    Set<Id> seen = new Set<Id>();
    if (recordIds == null) {
      return ordered;
    }
    for (Id recordId : recordIds) {
      if (recordId == null || seen.contains(recordId)) {
        continue;
      }
      String actual = recordId.getSObjectType().getDescribe().getName();
      if (objectApiName != null && !objectApiName.equalsIgnoreCase(actual)) {
        throw new RecordHealthCheckScopeException(
          'A scope cannot mix object types. Expected ' +
            objectApiName +
            ' but received ' +
            actual +
            '.'
        );
      }
      seen.add(recordId);
      ordered.add(recordId);
    }
    return ordered;
  }

  global class RecordHealthCheckScopeException extends Exception {
  }
}
