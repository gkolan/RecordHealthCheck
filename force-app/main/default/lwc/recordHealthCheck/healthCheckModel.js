/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

export const VALID_RESULT_STATUSES = new Set([
  "PASS",
  "FAIL",
  "SKIPPED",
  "UNABLE_TO_EVALUATE",
  "ERROR"
]);

/** Client-synthesized result when the server never evaluated the check. */
export function synthesizeResult(check, status, reasonCode, message) {
  return {
    ruleDeveloperName: check.developerName,
    label: check.label,
    status,
    reasonCode,
    message,
    priority: check.priority,
    evaluatorType: null
  };
}

/** Normalize Apex result; malformed responses become ERROR. */
export function normalizeResult(result, check) {
  if (!result || typeof result !== "object") {
    return synthesizeResult(
      check,
      "ERROR",
      "MALFORMED_RESPONSE",
      "The server returned an invalid result. Contact your administrator."
    );
  }
  if (!VALID_RESULT_STATUSES.has(result.status)) {
    return synthesizeResult(
      check,
      "ERROR",
      "UNKNOWN_RESULT_STATUS",
      "The server returned an unsupported result status. Contact your administrator."
    );
  }
  return result;
}

/** Developer names that participate in a RequiresCheck dependency cycle. */
export function detectDependencyCycles(checks) {
  const depMap = {};
  for (const check of checks) {
    if (check.dependsOnRuleDeveloperName) {
      depMap[check.developerName] = check.dependsOnRuleDeveloperName;
    }
  }
  const cycleMembers = new Set();
  for (const check of checks) {
    if (!depMap[check.developerName]) continue;
    const path = [];
    const pathSet = new Set();
    let current = check.developerName;
    while (depMap[current] && !cycleMembers.has(current)) {
      if (pathSet.has(current)) {
        // Found a cycle — add only the nodes from where the cycle starts
        const cycleStart = path.indexOf(current);
        for (let i = cycleStart; i < path.length; i++) {
          cycleMembers.add(path[i]);
        }
        break;
      }
      path.push(current);
      pathSet.add(current);
      current = depMap[current];
    }
  }
  return cycleMembers;
}

/** Parse Aura error body; defaults to LOAD_FAILED when reason code is absent. */
export function parseAuraError(err) {
  try {
    const body = err.body && err.body.message ? err.body.message : "";
    const parsed = JSON.parse(body);
    return {
      reasonCode: parsed.reasonCode || "LOAD_FAILED",
      message: parsed.message || "An error occurred loading health checks."
    };
  } catch {
    return {
      reasonCode: "LOAD_FAILED",
      message:
        (err.body && err.body.message) ||
        "An error occurred loading health checks."
    };
  }
}

/** Correlation id for one run's Apex log lines. */
export function newRunId() {
  try {
    if (
      typeof crypto !== "undefined" &&
      crypto &&
      typeof crypto.randomUUID === "function"
    ) {
      return crypto.randomUUID();
    }
  } catch {
    // fall through to the timestamp-based id
  }
  return `rhc-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
