/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import evaluateCheck from "@salesforce/apex/RecordHealthCheckController.evaluateCheck";
import {
  synthesizeResult,
  normalizeResult,
  detectDependencyCycles,
  newRunId
} from "./healthCheckModel";

const MAX_CONCURRENT_EVALUATIONS = 5;

/**
 * Run lifecycle: dependency gating, concurrency-capped evaluation, progressive reveal.
 */
export class HealthCheckRunner {
  _resultBuffer = {};
  _stopped = false;
  _runInProgress = false;
  _runToken = 0;
  _runId = null;
  /** In-flight Apex calls across run tokens; not zeroed on invalidate. */
  _activeEvaluations = 0;
  _evaluationQueue = [];

  constructor(host) {
    this.host = host;
  }

  get isRunning() {
    return this._runInProgress;
  }

  get runId() {
    return this._runId;
  }

  /** Starts a fresh correlation id, stores it for the upcoming run, and returns it. */
  beginRunId() {
    this._runId = newRunId();
    return this._runId;
  }

  /**
   * Invalidate any run still in flight (token bump) and clear orchestration
   * state. Called on record/config reload and on disconnect. The component
   * resets its own reactive counters (completedCheckCount, runComplete).
   */
  invalidate() {
    this._runToken++;
    this._runInProgress = false;
    this._stopped = false;
    this._resultBuffer = {};
    this._resetEvaluationPool();
  }

  run(reuseRunId = false) {
    if (this._runInProgress) return;
    this._runInProgress = true;
    if (!reuseRunId || !this._runId) {
      this._runId = newRunId();
    }
    const token = ++this._runToken; // capture token for this run; prior in-flight calls carry the old value
    this.host.completedCheckCount = 0;
    this.host.runComplete = false;
    this._resultBuffer = {};
    this._stopped = false;
    this._resetEvaluationPool();

    // Reset all rows to PENDING and clear previous results
    this.host.checks = this.host.checks.map((c) => ({
      ...c,
      uiState: "PENDING",
      result: null
    }));

    if (this.host.checks.length === 0) {
      this.host.runComplete = true;
      this.host.hasCompletedRunOnce = true;
      this._runInProgress = false;
      return;
    }

    // Pre-seed circular dependencies as errors so their Promises resolve immediately
    // rather than hanging indefinitely awaiting each other.
    const cycleNames = detectDependencyCycles(this.host.checks);
    for (const name of cycleNames) {
      const check = this.host.checks.find((c) => c.developerName === name);
      if (check) {
        this._resultBuffer[name] = synthesizeResult(
          check,
          "UNABLE_TO_EVALUATE",
          "CIRCULAR_DEPENDENCY",
          "This check has a circular dependency and cannot be evaluated."
        );
      }
    }

    const checkMap = {};
    for (const check of this.host.checks) {
      checkMap[check.developerName] = check;
    }

    if (this.host.stopOnFirstError) {
      this._runChecksSequentially(checkMap, cycleNames, token).catch(() => {
        if (token === this._runToken) {
          this._runInProgress = false;
        }
      });
      return;
    }

    // Fire checks concurrently, but create tasks recursively so dependencies
    // can point to checks that appear later in the ordered run list.
    const taskMap = {}; // developerName -> Promise
    const runCheck = this._makeRunCheck(taskMap, checkMap, cycleNames, token);

    for (const check of this.host.checks) {
      runCheck(check);
    }
  }

  /**
   * Builds the recursive task launcher shared by the concurrent and sequential
   * run paths. Each check's promise is memoized in taskMap so a check is only
   * evaluated once even when several dependents point at it; cycle members
   * short-circuit to an already-resolved promise (their result is pre-seeded).
   */
  _makeRunCheck(taskMap, checkMap, cycleNames, token) {
    const runCheck = (check) => {
      if (taskMap[check.developerName]) {
        return taskMap[check.developerName];
      }
      if (cycleNames.has(check.developerName)) {
        taskMap[check.developerName] = Promise.resolve();
        this._drain(token);
        return taskMap[check.developerName];
      }
      taskMap[check.developerName] = this._runOneCheck(
        check,
        taskMap,
        checkMap,
        runCheck,
        token
      );
      return taskMap[check.developerName];
    };
    return runCheck;
  }

  async _runChecksSequentially(checkMap, cycleNames, token) {
    try {
      const taskMap = {};
      const runCheck = this._makeRunCheck(taskMap, checkMap, cycleNames, token);

      for (const check of this.host.checks) {
        if (this._stopped) {
          break;
        }
        // stopOnFirstError must wait for each result before starting the next check.
        // eslint-disable-next-line no-await-in-loop
        await runCheck(check);
      }
    } finally {
      if (token === this._runToken) {
        const allResolved = this.host.checks.every(
          (c) => this._resultBuffer[c.developerName] !== undefined
        );
        if (!allResolved) {
          this._runInProgress = false;
        }
      }
    }
  }

  async _runOneCheck(check, taskMap, checkMap, runCheck, token) {
    if (this._stopped || token !== this._runToken) return;

    // Client-side dependency gate before calling Apex.
    if (check.dependsOnCheckDeveloperName) {
      const dependencyCheck = checkMap[check.dependsOnCheckDeveloperName];
      if (!dependencyCheck) {
        // Dependency was not included in this run (e.g. excluded by the framework cap).
        // Skip with a clear reason rather than silently falling through.
        const skipped = synthesizeResult(
          check,
          "SKIPPED",
          "DEPENDENCY_NOT_IN_RUN",
          "This check was skipped because its required check was not included in this run."
        );
        this._resultBuffer[check.developerName] = skipped;
        this._drain(token);
        return;
      }
      if (!taskMap[check.dependsOnCheckDeveloperName]) {
        runCheck(dependencyCheck);
      }
      await taskMap[check.dependsOnCheckDeveloperName];
      if (this._stopped || token !== this._runToken) return;
      const prereqResult =
        this._resultBuffer[check.dependsOnCheckDeveloperName];
      if (!prereqResult || prereqResult.status !== "PASS") {
        const skipped = synthesizeResult(
          check,
          "SKIPPED",
          "DEPENDENCY_NOT_PASSED",
          "This check was skipped because a required check did not pass."
        );
        this._resultBuffer[check.developerName] = skipped;
        this._drain(token);
        return;
      }
    }

    // Set row to LOADING
    this._setCheckUiState(check.developerName, "LOADING");

    if (this._activeEvaluations >= MAX_CONCURRENT_EVALUATIONS) {
      const acquired = await this._acquireEvaluationSlot(token);
      if (!acquired) return;
      if (token !== this._runToken) {
        this._releaseEvaluationSlot();
        return;
      }
    } else {
      this._activeEvaluations++;
    }

    let result;
    try {
      result = await evaluateCheck({
        configName: this.host.configName,
        checkDeveloperName: check.developerName,
        recordId: this.host.recordId,
        runId: this._runId
      });
    } catch {
      result = synthesizeResult(
        check,
        "ERROR",
        "CLIENT_CALL_FAILED",
        "The check could not be reached. Please try again."
      );
    } finally {
      this._releaseEvaluationSlot();
    }

    // Discard result if a newer run has started since this call was fired
    if (token !== this._runToken) return;

    this._resultBuffer[check.developerName] = normalizeResult(result, check);
    this._drain(token);
  }

  _drain(token) {
    if (token !== this._runToken) return;

    this.host.checks = this.host.checks.map((c) => {
      const buffered = this._resultBuffer[c.developerName];
      if (buffered !== undefined && c.uiState !== "RESOLVED") {
        return {
          ...c,
          uiState: "RESOLVED",
          result: normalizeResult(buffered, c)
        };
      }
      return c;
    });
    this.host.completedCheckCount = this.host.checks.filter(
      (c) => c.uiState === "RESOLVED"
    ).length;

    // Stop on first ERROR: synthesize SKIPPED for checks not yet evaluated.
    if (this.host.stopOnFirstError && !this._stopped) {
      const errored = this.host.checks.some(
        (c) =>
          c.uiState === "RESOLVED" && c.result && c.result.status === "ERROR"
      );
      if (errored) {
        this._stopped = true;
        let synthesizedAny = false;
        for (const c of this.host.checks) {
          if (this._resultBuffer[c.developerName] === undefined) {
            this._resultBuffer[c.developerName] = synthesizeResult(
              c,
              "SKIPPED",
              "STOPPED_AFTER_ERROR",
              "This check was skipped because an earlier check encountered an error."
            );
            synthesizedAny = true;
          }
        }
        if (synthesizedAny) {
          this._drain(token);
          return;
        }
      }
    }

    // The run is complete once every check has produced a result.
    const allResolved = this.host.checks.every(
      (c) => this._resultBuffer[c.developerName] !== undefined
    );
    if (allResolved) {
      this.host.runComplete = true;
      this.host.hasCompletedRunOnce = true;
      this._runInProgress = false;
      if (this.host.debugMode) {
        this.host._logRunDiagnostics();
      }
    }
  }

  _acquireEvaluationSlot(token) {
    return new Promise((resolve) => {
      if (token !== this._runToken) {
        resolve(false);
      } else {
        this._evaluationQueue.push({ token, resolve });
      }
    });
  }

  _releaseEvaluationSlot() {
    // Slot frees when any in-flight request settles, including from a prior run.
    this._activeEvaluations = Math.max(0, this._activeEvaluations - 1);
    while (
      this._evaluationQueue.length > 0 &&
      this._activeEvaluations < MAX_CONCURRENT_EVALUATIONS
    ) {
      const next = this._evaluationQueue.shift();
      if (next.token !== this._runToken) {
        next.resolve(false);
        continue;
      }
      this._activeEvaluations++;
      next.resolve(true);
      break;
    }
  }

  _resetEvaluationPool() {
    // Do not zero _activeEvaluations; abandoned runs decrement on settle.
    for (const pending of this._evaluationQueue) {
      pending.resolve(false);
    }
    this._evaluationQueue = [];
  }

  _setCheckUiState(developerName, uiState) {
    this.host.checks = this.host.checks.map((c) => {
      return c.developerName === developerName ? { ...c, uiState } : c;
    });
  }
}
