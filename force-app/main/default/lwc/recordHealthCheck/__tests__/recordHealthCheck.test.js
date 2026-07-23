/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import { createElement } from "lwc";
import RecordHealthCheck from "c/recordHealthCheck";
import {
  annotateCheck,
  buildSummaryStats,
  splitMessageLines,
  safeActionUrl
} from "../healthCheckPresentation";
import { HealthCheckRunner } from "../healthCheckRunner";
import getCheckDefinitions from "@salesforce/apex/RecordHealthCheckController.getCheckDefinitions";
import getCheckSetAvailabilityForRecord from "@salesforce/apex/RecordHealthCheckController.getCheckSetAvailabilityForRecord";
import evaluateCheck from "@salesforce/apex/RecordHealthCheckController.evaluateCheck";
import completeRun from "@salesforce/apex/RecordHealthCheckController.completeRun";

// The LWC jest transformer rewrites `import foo from '@salesforce/apex/...'`
// to `require('@salesforce/apex/...').default`, so the factory must return
// { default: jest.fn() } — not a bare jest.fn().
jest.mock(
  "@salesforce/apex/RecordHealthCheckController.getCheckDefinitions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RecordHealthCheckController.getCheckSetAvailabilityForRecord",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RecordHealthCheckController.evaluateCheck",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RecordHealthCheckController.completeRun",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => Promise.resolve();
const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
};

async function appendAndLoad(element) {
  document.body.appendChild(element);
  jest.runOnlyPendingTimers();
  await flushPromises();
  await flushPromises();
}

async function clickRun(element) {
  element.shadowRoot.querySelector(".rhc-action-button").click();
  await flushPromises();
  await flushPromises();
  await flushPromises();
}

beforeEach(() => {
  jest.useFakeTimers();
  completeRun.mockResolvedValue();
  getCheckSetAvailabilityForRecord.mockResolvedValue({
    hasActive: true,
    hasInactive: false
  });
});

afterEach(() => {
  jest.useRealTimers();
});

const PASS_RESULT = (developerName) => ({
  ruleDeveloperName: developerName,
  label: developerName,
  status: "PASS",
  severity: null,
  message: null,
  priority: 1,
  evaluatorType: "Formula"
});

const FAIL_RESULT = (developerName) => ({
  ruleDeveloperName: developerName,
  label: developerName,
  status: "FAIL",
  severity: "Error",
  message: "Check failed.",
  priority: 1,
  evaluatorType: "Formula"
});

const ERROR_RESULT = (developerName) => ({
  ruleDeveloperName: developerName,
  label: developerName,
  status: "ERROR",
  reasonCode: "APEX_EVALUATOR_ERROR",
  message: "An unexpected error occurred.",
  priority: 1,
  evaluatorType: null
});

const SKIPPED_RESULT = (developerName) => ({
  ruleDeveloperName: developerName,
  label: developerName,
  status: "SKIPPED",
  reasonCode: "APPLICABILITY_NOT_MET",
  message: "Check skipped.",
  priority: 1,
  evaluatorType: "Formula"
});

const makeDefinitions = (overrides = {}) => ({
  displayTitle: "Account Health",
  displayDescription: null,
  triggerMode: "Manual",
  revealMode: "AllAtOnce",
  successDisplayMode: "Show",
  skippedDisplayMode: "Hide",
  stopOnFirstError: false,
  totalAvailableCheckCount: 2,
  checksOmittedByLimit: false,
  checks: [
    {
      developerName: "Check_A",
      label: "Check A",
      description: "First check",
      priority: 1,
      dependsOnRuleDeveloperName: null
    },
    {
      developerName: "Check_B",
      label: "Check B",
      description: "Second check",
      priority: 2,
      dependsOnRuleDeveloperName: null
    }
  ],
  ...overrides
});

function createComponent() {
  const el = createElement("c-record-health-check", { is: RecordHealthCheck });
  el.checkSetName = "Account_Data_Quality";
  el.recordId = "001000000000001AAA";
  return el;
}

function makeRunnerHost(checks = []) {
  return {
    checks,
    completedCheckCount: 0,
    runComplete: false,
    hasCompletedRunOnce: false,
    stopOnFirstError: false,
    showDiagnostics: false,
    checkSetName: "Account_Data_Quality",
    recordId: "001000000000001AAA",
    _logRunDiagnostics: jest.fn()
  };
}

describe("c-record-health-check — design theme", () => {
  let element;

  afterEach(() => {
    if (element?.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("defaults to the SLDS 1 visual treatment", () => {
    element = createComponent();
    document.body.appendChild(element);

    expect(
      element.shadowRoot.querySelector(".rhc-theme--slds1")
    ).not.toBeNull();
  });

  it("supports the SLDS 2 visual treatment", () => {
    element = createComponent();
    element.designSystem = "SLDS 2";
    document.body.appendChild(element);

    expect(
      element.shadowRoot.querySelector(".rhc-theme--slds2")
    ).not.toBeNull();
  });

  it("falls back to SLDS 1 for an unsupported value", () => {
    element = createComponent();
    element.designSystem = "unsupported";
    document.body.appendChild(element);

    expect(
      element.shadowRoot.querySelector(".rhc-theme--slds1")
    ).not.toBeNull();
  });
});

describe("c-record-health-check — load and error states", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("renders the action button after definitions load in Manual mode", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    await appendAndLoad(element);

    const btn = element.shadowRoot.querySelector(".rhc-action-button");
    expect(btn).not.toBeNull();
  });

  it("shows pre-run guidance for Manual + OneAtATime before the first run", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ revealMode: "OneAtATime" })
    );
    await appendAndLoad(element);

    const hint = element.shadowRoot.querySelector(".rhc-pre-run-hint");
    expect(hint).not.toBeNull();
    expect(hint.textContent).toContain("Click Run to evaluate");
    expect(hint.textContent).toContain("2 checks");
    expect(element.shadowRoot.querySelectorAll(".rhc-list li")).toHaveLength(0);
  });

  it("singularizes the pre-run hint count when there is one check", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        revealMode: "OneAtATime",
        checks: [makeDefinitions().checks[0]]
      })
    );
    await appendAndLoad(element);

    const hint = element.shadowRoot.querySelector(".rhc-pre-run-hint");
    expect(hint.textContent).toContain("1 check");
    expect(hint.textContent).not.toContain("1 checks");
  });

  it("says first 25 in the pre-run hint when the set exceeds the cap", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        revealMode: "OneAtATime",
        checksOmittedByLimit: true,
        totalAvailableCheckCount: 40
      })
    );
    await appendAndLoad(element);

    const hint = element.shadowRoot.querySelector(".rhc-pre-run-hint");
    expect(hint.textContent).toContain("the first 25 of 40 checks");
  });

  it("shows the pre-run hint above the rows in AllAtOnce mode too", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ revealMode: "AllAtOnce" })
    );
    await appendAndLoad(element);

    const hint = element.shadowRoot.querySelector(".rhc-pre-run-hint");
    expect(hint).not.toBeNull();
    expect(hint.textContent).toContain("2 checks");
    // Rows are visible up-front in this mode, so the hint sits alongside them.
    expect(
      element.shadowRoot.querySelectorAll(".rhc-list li").length
    ).toBeGreaterThan(0);
  });

  it("shows error banner when getCheckDefinitions rejects with JSON body", async () => {
    const body = JSON.stringify({
      reasonCode: "CONFIG_INACTIVE",
      message: "The config is inactive."
    });
    getCheckDefinitions.mockRejectedValue({ body: { message: body } });
    await appendAndLoad(element);

    const banner = element.shadowRoot.querySelector(".rhc-error-banner");
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain("The config is inactive.");
  });

  it("shows error banner when getCheckDefinitions rejects with plain body", async () => {
    getCheckDefinitions.mockRejectedValue({ body: { message: "plain error" } });
    await appendAndLoad(element);

    const banner = element.shadowRoot.querySelector(".rhc-error-banner");
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain("plain error");
  });

  it("auto-runs checks when triggerMode is Automatic", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic" })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    expect(evaluateCheck).toHaveBeenCalled();
    expect(evaluateCheck).toHaveBeenCalledWith(
      expect.objectContaining({ source: "RUN_ON_LOAD" })
    );
    expect(completeRun).not.toHaveBeenCalled();
  });

  it("shows first-25 badge when checksOmittedByLimit is true", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        checksOmittedByLimit: true,
        totalAvailableCheckCount: 40
      })
    );
    await appendAndLoad(element);

    const badge = element.shadowRoot.querySelector(".rhc-check-pill--warn");
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("First 25 of 40 shown");
    expect(badge.title).toContain("first 25 of 40");
  });

  it("shows a load error when a definition has a duplicate developerName", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        checks: [
          {
            developerName: "Dup",
            label: "A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          },
          {
            developerName: "Dup",
            label: "B",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: null
          }
        ]
      })
    );
    await appendAndLoad(element);
    expect(
      element.shadowRoot.querySelector(".rhc-error-banner")
    ).not.toBeNull();
    // The row list is gated off entirely while the component is in an error state.
    expect(element.shadowRoot.querySelector(".rhc-list")).toBeNull();
  });

  it("shows a load error when a definition is missing its developerName", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        checks: [
          {
            developerName: "",
            label: "Nameless",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          }
        ]
      })
    );
    await appendAndLoad(element);
    expect(
      element.shadowRoot.querySelector(".rhc-error-banner")
    ).not.toBeNull();
  });

  it("treats an unrecognized revealMode as AllAtOnce", async () => {
    const checks = [0, 1, 2].map((i) => ({
      developerName: `Check_${i}`,
      label: `Check ${i}`,
      description: "",
      priority: i,
      dependsOnRuleDeveloperName: null
    }));
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        triggerMode: "Automatic",
        revealMode: "SomethingUnknown",
        checks
      })
    );
    // Hold evaluations open so the rows stay mid-run.
    evaluateCheck.mockImplementation(() => new Promise(() => {}));
    await appendAndLoad(element);

    // AllAtOnce renders every row up front; OneAtATime would reveal only one.
    expect(element.shadowRoot.querySelectorAll(".rhc-row").length).toBe(3);
  });

  it("falls back to a Manual Run affordance for an unrecognized triggerMode", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Whenever" })
    );
    await appendAndLoad(element);

    // An unknown mode must not silently auto-run...
    expect(evaluateCheck).not.toHaveBeenCalled();
    // ...and must still expose a Run button so the checks remain runnable
    // (rather than rendering neither auto-run nor a button).
    expect(
      element.shadowRoot.querySelector(".rhc-action-button")
    ).not.toBeNull();
  });

  it("labels the setup-error icon as 'Setup required', not 'Error'", async () => {
    element.checkSetName = null; // triggers the SETUP_REQUIRED banner
    await appendAndLoad(element);

    const icon = element.shadowRoot.querySelector("lightning-icon");
    expect(icon).not.toBeNull();
    expect(icon.iconName).toBe("utility:setup");
    expect(icon.alternativeText).toBe("Setup required");
  });

  it("asks the admin to choose a Check Set when none is selected but sets exist", async () => {
    element.checkSetName = "";
    getCheckSetAvailabilityForRecord.mockResolvedValue({
      hasActive: true,
      hasInactive: false
    });
    await appendAndLoad(element);

    const banner = element.shadowRoot.querySelector(".rhc-error-banner");
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain("Health Check Needs Setup");
    expect(banner.textContent).toContain(
      "Record Health Check is not ready on this page yet"
    );
    expect(banner.textContent).toContain("Ask your Salesforce admin");
    expect(banner.textContent).toContain("choose a Check Set for this page");
    expect(getCheckSetAvailabilityForRecord).toHaveBeenCalledWith({
      recordId: element.recordId
    });
    expect(getCheckDefinitions).not.toHaveBeenCalled();
  });

  it("tells the admin to activate when only inactive Check Sets exist", async () => {
    element.checkSetName = "";
    getCheckSetAvailabilityForRecord.mockResolvedValue({
      hasActive: false,
      hasInactive: true
    });
    await appendAndLoad(element);

    const banner = element.shadowRoot.querySelector(".rhc-error-banner");
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain(
      "Record Health Check is not ready on this page yet"
    );
    expect(banner.textContent).toContain(
      "activate a Check Set for this object"
    );
    expect(getCheckDefinitions).not.toHaveBeenCalled();
  });

  it("tells the admin to create a Check Set when none exist for the object", async () => {
    element.checkSetName = "";
    getCheckSetAvailabilityForRecord.mockResolvedValue({
      hasActive: false,
      hasInactive: false
    });
    await appendAndLoad(element);

    const banner = element.shadowRoot.querySelector(".rhc-error-banner");
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain(
      "Record Health Check is not ready on this page yet"
    );
    expect(banner.textContent).toContain("set up a Check Set for this object");
    expect(getCheckDefinitions).not.toHaveBeenCalled();
  });

  it("treats server-side setup errors as admin configuration issues", async () => {
    getCheckDefinitions.mockRejectedValue({
      body: {
        message: JSON.stringify({
          reasonCode: "NO_ACTIVE_CHECKS",
          message: 'Check Set "Account_Data_Quality" has no active checks.'
        })
      }
    });

    await appendAndLoad(element);

    const banner = element.shadowRoot.querySelector(".rhc-error-banner");
    const icon = element.shadowRoot.querySelector("lightning-icon");
    expect(banner.textContent).toContain("Health Check Needs Setup");
    expect(banner.textContent).toContain("no active checks");
    expect(banner.textContent).toContain("Ask your Salesforce admin");
    expect(banner.textContent).toContain("add an active Rule");
    expect(icon.iconName).toBe("utility:setup");
    expect(icon.alternativeText).toBe("Setup required");
  });
});

describe("c-record-health-check — run orchestration", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("calls evaluateCheck for every check in the set", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    expect(evaluateCheck).toHaveBeenCalledTimes(2);
    expect(evaluateCheck).toHaveBeenCalledWith(
      expect.objectContaining({ source: "USER_INITIATED" })
    );
    expect(completeRun).toHaveBeenCalledTimes(1);
    expect(completeRun).toHaveBeenCalledWith(
      expect.objectContaining({ source: "USER_INITIATED" })
    );
  });

  it("threads a correlation runId into both Apex calls", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    // Definitions load carries a non-blank runId.
    const defArgs = getCheckDefinitions.mock.calls[0][0];
    expect(typeof defArgs.runId).toBe("string");
    expect(defArgs.runId.length).toBeGreaterThan(0);

    await clickRun(element);

    // Every evaluateCheck call carries the same runId for the run, and that id is
    // distinct from the definitions-load id (a fresh id per run).
    const evalArgs = evaluateCheck.mock.calls.map((c) => c[0]);
    const runIds = new Set(evalArgs.map((a) => a.runId));
    expect(runIds.size).toBe(1);
    const [runRunId] = [...runIds];
    expect(typeof runRunId).toBe("string");
    expect(runRunId.length).toBeGreaterThan(0);
    expect(runRunId).not.toBe(defArgs.runId);
  });

  it("shows per-row diagnostics meta when showDiagnostics is on", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", showDiagnostics: true })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    expect(element.shadowRoot.querySelector(".rhc-debug-meta")).not.toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "Check console (F12) for diagnostics."
    );
  });

  it("shows the debug detail message inline, with no click-to-expand", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        triggerMode: "Automatic",
        showDiagnostics: true,
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "UNABLE_TO_EVALUATE",
      reasonCode: "INVALID_FORMULA",
      message: "This check could not be evaluated.",
      adminDetailMessage: "Formula could not generate the requested field.",
      priority: 1,
      evaluatorType: "Formula"
    });
    await appendAndLoad(element);

    // The technical detail is rendered directly — no <details>/<summary> wrapper
    // the admin has to open.
    expect(element.shadowRoot.querySelector("details")).toBeNull();
    const body = element.shadowRoot.querySelector(".rhc-debug-detail__body");
    expect(body).not.toBeNull();
    expect(body.textContent).toContain(
      "Formula could not generate the requested field."
    );
  });

  it("shows re-run button after run completes", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    const btn = element.shadowRoot.querySelector(".rhc-action-button");
    expect(btn).not.toBeNull();
    expect(btn.textContent.trim()).toBe("Rerun");
    // The check count lives in the hover tooltip now, not the label.
    expect(btn.title).toContain("Checks");
  });

  it("keeps the button visible, disabled, and busy while a run is in flight", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    const pending = deferred();
    evaluateCheck.mockReturnValue(pending.promise);
    await appendAndLoad(element);

    // Start the run but leave the first evaluateCheck unresolved.
    element.shadowRoot.querySelector(".rhc-action-button").click();
    await flushPromises();

    const btn = element.shadowRoot.querySelector(".rhc-action-button");
    expect(btn).not.toBeNull();
    expect(btn.textContent.trim()).toBe("Run");
    expect(btn.disabled).toBe(true);
    expect(btn.getAttribute("aria-busy")).toBe("true");
    expect(btn.title).toContain("Running");
    expect(btn.querySelector(".rhc-action-button__spinner")).not.toBeNull();
    expect(btn.querySelector(".rhc-action-button__play")).toBeNull();

    // Let it finish so the run resolves cleanly.
    pending.resolve(PASS_RESULT("Check_A"));
    await flushPromises();
    await flushPromises();
  });

  it("keeps the Rerun label and spinner while a re-run is in flight", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);
    await flushPromises();

    const pending = deferred();
    evaluateCheck.mockReturnValue(pending.promise);
    element.shadowRoot.querySelector(".rhc-action-button").click();
    await flushPromises();

    const btn = element.shadowRoot.querySelector(".rhc-action-button");
    expect(btn.textContent.trim()).toBe("Rerun");
    expect(btn.disabled).toBe(true);
    expect(btn.title).toContain("Re-running");
    expect(btn.querySelector(".rhc-action-button__spinner")).not.toBeNull();

    pending.resolve(PASS_RESULT("Check_A"));
    await flushPromises();
    await flushPromises();
  });

  it("uses the same neutral button styling for Run and Rerun", async () => {
    getCheckDefinitions.mockResolvedValue(makeDefinitions());
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    expect(
      element.shadowRoot
        .querySelector(".rhc-action-button")
        .classList.contains("slds-button_neutral")
    ).toBe(true);

    await clickRun(element);

    expect(
      element.shadowRoot
        .querySelector(".rhc-action-button")
        .classList.contains("slds-button_neutral")
    ).toBe(true);
  });

  it("hides passed rows in Automatic mode when SuccessDisplayMode is Hide", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", successDisplayMode: "Hide" })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);
    jest.runOnlyPendingTimers();
    await flushPromises();
    await flushPromises();

    const rows = element.shadowRoot.querySelectorAll(".rhc-row--pass");
    expect(rows).toHaveLength(0);
  });

  it("shows a hidden-results notice with summary stats when every row is hidden", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", successDisplayMode: "Hide" })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);
    jest.runOnlyPendingTimers();
    await flushPromises();
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll(".rhc-row")).toHaveLength(0);
    const notice = element.shadowRoot.querySelector(".rhc-hidden-results");
    expect(notice).not.toBeNull();
    expect(notice.textContent).toContain("All checks passed");
    expect(notice.textContent).toContain("Details are hidden");
    expect(notice.textContent).not.toContain("Check Set");
    expect(element.shadowRoot.querySelector(".rhc-stats-bar")).not.toBeNull();
  });

  it("mentions inactive rules that are omitted from the run", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ inactiveRuleCount: 2 })
    );
    await appendAndLoad(element);

    const notice = element.shadowRoot.querySelector(".rhc-inactive-rules");
    expect(notice).not.toBeNull();
    expect(notice.textContent).toContain("2 inactive rules omitted");
  });

  it("styles system ERROR rows differently from Unable to Check", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue(ERROR_RESULT("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);

    expect(
      element.shadowRoot.querySelector(".rhc-row--system-error")
    ).not.toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row--unable")).toBeNull();
    expect(element.shadowRoot.textContent).toContain("1 System Error");
    expect(element.shadowRoot.textContent).not.toContain("1 Unable");
  });

  it("reveals a ready visible result without waiting behind a slower hidden check", async () => {
    // OneAtATime + Hide passes: Check_A (declared first) is a hidden PASS that is
    // SLOW; Check_B is a visible FAIL that resolves FIRST. The visible failure must
    // surface immediately instead of being withheld behind Check_A's spinner.
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        triggerMode: "Automatic",
        revealMode: "OneAtATime",
        successDisplayMode: "Hide"
      })
    );
    const dA = deferred();
    const dB = deferred();
    evaluateCheck.mockImplementation(({ ruleDeveloperName }) => {
      return ruleDeveloperName === "Check_A" ? dA.promise : dB.promise;
    });

    await appendAndLoad(element);

    // Check_B (visible FAIL) resolves while Check_A (hidden PASS) is still loading.
    dB.resolve(FAIL_RESULT("Check_B"));
    await flushPromises();
    await flushPromises();

    // The FAIL row is shown now, alongside a single loading spinner for Check_A.
    // Pre-fix this list held only the spinner (the FAIL was withheld).
    expect(element.shadowRoot.querySelectorAll(".rhc-row--error")).toHaveLength(
      1
    );
    expect(
      element.shadowRoot.querySelectorAll(".rhc-row--loading")
    ).toHaveLength(1);

    // The hidden PASS resolves: it stays hidden, the FAIL remains, no spinner.
    dA.resolve(PASS_RESULT("Check_A"));
    await flushPromises();
    await flushPromises();
    expect(element.shadowRoot.querySelectorAll(".rhc-row--pass")).toHaveLength(
      0
    );
    expect(
      element.shadowRoot.querySelectorAll(".rhc-row--loading")
    ).toHaveLength(0);
    expect(element.shadowRoot.querySelectorAll(".rhc-row")).toHaveLength(1);
    expect(element.shadowRoot.querySelectorAll(".rhc-row--error")).toHaveLength(
      1
    );
  });

  it("synthesizes error result when evaluateCheck network call throws", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        triggerMode: "Automatic",
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          }
        ],
        totalAvailableCheckCount: 1
      })
    );
    evaluateCheck.mockRejectedValue(new Error("network failure"));
    await appendAndLoad(element);

    // Run completes (error synthesized) — re-run button appears
    const btn = element.shadowRoot.querySelector(".rhc-action-button");
    expect(btn).not.toBeNull();
  });
});

describe("c-record-health-check — success display modes", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("keeps passed rows visible when SuccessDisplayMode is Show", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ successDisplayMode: "Show" })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    const rows = element.shadowRoot.querySelectorAll(".rhc-row--pass");
    expect(rows).toHaveLength(2);
    // The standalone success footer note no longer exists.
    expect(element.shadowRoot.querySelector(".rhc-footer-note")).toBeNull();
    const pill = element.shadowRoot.querySelector(".rhc-stat--pass");
    expect(pill).not.toBeNull();
    expect(pill.classList).not.toContain("rhc-tooltip-anchor");
    expect(pill.getAttribute("data-tooltip")).toBeNull();
    expect(pill.getAttribute("tabindex")).toBeNull();
  });

  it("hides passed rows but rolls them into the Passed pill when SuccessDisplayMode is Hide", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ successDisplayMode: "Hide" })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    const rows = element.shadowRoot.querySelectorAll(".rhc-row--pass");
    expect(rows).toHaveLength(0);
    // No standalone footer note — passed rules roll up into the summary bar's
    // Passed pill, whose tooltip lists the rule labels.
    expect(element.shadowRoot.querySelector(".rhc-footer-note")).toBeNull();
    const pill = element.shadowRoot.querySelector(".rhc-stat--pass");
    expect(pill).not.toBeNull();
    expect(pill.textContent).toContain("2 Passed");
    expect(pill.classList).toContain("rhc-tooltip-anchor");
    expect(pill.getAttribute("tabindex")).toBe("0");
    expect(pill.getAttribute("data-tooltip")).toContain("Check A");
    expect(pill.getAttribute("data-tooltip")).toContain("Check B");
  });

  it("shows hidden passed rows when showDiagnostics authorizes the overlay", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ successDisplayMode: "Hide", showDiagnostics: true })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    // Diagnostics overrides count-only: every passed row is expanded (§2.11).
    const rows = element.shadowRoot.querySelectorAll(".rhc-row--pass");
    expect(rows).toHaveLength(2);
  });

  it("explains when a mix of passed and skipped rows is hidden", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        successDisplayMode: "Hide",
        skippedDisplayMode: "Hide"
      })
    );
    evaluateCheck.mockImplementation(({ ruleDeveloperName }) =>
      Promise.resolve(
        ruleDeveloperName === "Check_A"
          ? PASS_RESULT(ruleDeveloperName)
          : SKIPPED_RESULT(ruleDeveloperName)
      )
    );
    await appendAndLoad(element);
    await clickRun(element);

    expect(element.shadowRoot.textContent).toContain(
      "All checks passed or were skipped. Details are hidden."
    );
  });
});

describe("c-record-health-check — skipped display modes", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("keeps skipped rows visible when SkippedDisplayMode is Show", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ skippedDisplayMode: "Show" })
    );
    evaluateCheck.mockResolvedValue(SKIPPED_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    const rows = element.shadowRoot.querySelectorAll(".rhc-row--skipped");
    expect(rows).toHaveLength(2);
    expect(element.shadowRoot.querySelector(".rhc-footer-note")).toBeNull();
    const pill = element.shadowRoot.querySelector(".rhc-stat--skipped");
    expect(pill).not.toBeNull();
    expect(pill.classList).not.toContain("rhc-tooltip-anchor");
    expect(pill.getAttribute("data-tooltip")).toBeNull();
    expect(pill.getAttribute("tabindex")).toBeNull();
  });

  it("hides skipped rows but rolls them into the Skipped pill when SkippedDisplayMode is Hide", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ skippedDisplayMode: "Hide" })
    );
    evaluateCheck.mockResolvedValue(SKIPPED_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    const rows = element.shadowRoot.querySelectorAll(".rhc-row--skipped");
    expect(rows).toHaveLength(0);
    // No standalone footer line — skipped rules roll up into the summary bar's
    // Skipped pill, whose tooltip lists the rule labels.
    expect(element.shadowRoot.querySelector(".rhc-footer-note")).toBeNull();
    const pill = element.shadowRoot.querySelector(".rhc-stat--skipped");
    expect(pill).not.toBeNull();
    expect(pill.textContent).toContain("2 Skipped");
    expect(pill.classList).toContain("rhc-tooltip-anchor");
    expect(pill.getAttribute("tabindex")).toBe("0");
    expect(pill.getAttribute("data-tooltip")).toContain("Check A");
    expect(pill.getAttribute("data-tooltip")).toContain("Check B");
  });

  it("shows hidden skipped rows when showDiagnostics authorizes the overlay", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ skippedDisplayMode: "Hide", showDiagnostics: true })
    );
    evaluateCheck.mockResolvedValue(SKIPPED_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    // Diagnostics overrides count-only: every skipped row is expanded (§2.11).
    const rows = element.shadowRoot.querySelectorAll(".rhc-row--skipped");
    expect(rows).toHaveLength(2);
  });
});

describe("c-record-health-check — dependency gating", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("skips dependent check with DEPENDENCY_NOT_IN_RUN when dep is absent from taskMap", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          },
          {
            developerName: "Check_B",
            label: "Check B",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: "Check_MISSING"
          }
        ]
      })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    // Check_B has a dep not in this run — evaluateCheck only called for Check_A
    expect(evaluateCheck).toHaveBeenCalledTimes(1);
    expect(evaluateCheck).toHaveBeenCalledWith(
      expect.objectContaining({ ruleDeveloperName: "Check_A" })
    );
  });

  it("skips dependent check when prerequisite does not PASS", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          },
          {
            developerName: "Check_B",
            label: "Check B",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: "Check_A"
          }
        ]
      })
    );
    // Check_A FAILS — Check_B should be skipped (never calls evaluateCheck for B)
    evaluateCheck.mockResolvedValueOnce(FAIL_RESULT("Check_A"));
    await appendAndLoad(element);

    await clickRun(element);

    expect(evaluateCheck).toHaveBeenCalledTimes(1);
    expect(evaluateCheck).not.toHaveBeenCalledWith(
      expect.objectContaining({ ruleDeveloperName: "Check_B" })
    );
  });

  it("runs dependent check when prerequisite passes", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          },
          {
            developerName: "Check_B",
            label: "Check B",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: "Check_A"
          }
        ]
      })
    );
    evaluateCheck
      .mockResolvedValueOnce(PASS_RESULT("Check_A"))
      .mockResolvedValueOnce(PASS_RESULT("Check_B"));
    await appendAndLoad(element);

    await clickRun(element);

    expect(evaluateCheck).toHaveBeenCalledTimes(2);
  });

  it("reports circular dependencies without calling Apex", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        skippedDisplayMode: "Show",
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: "Check_B"
          },
          {
            developerName: "Check_B",
            label: "Check B",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: "Check_A"
          }
        ]
      })
    );
    await appendAndLoad(element);

    await clickRun(element);

    expect(evaluateCheck).not.toHaveBeenCalled();
    expect(element.shadowRoot.textContent).toContain(
      'Circular dependency with "Check_B".'
    );
    expect(element.shadowRoot.textContent).toContain(
      'Circular dependency with "Check_A".'
    );
  });
});

describe("c-record-health-check — stopOnFirstError", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("synthesizes SKIPPED for unreturned checks after a system ERROR", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        triggerMode: "Automatic",
        stopOnFirstError: true,
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          },
          {
            developerName: "Check_B",
            label: "Check B",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: null
          }
        ]
      })
    );
    // A returns ERROR; B should never start when stopOnFirstError is true.
    evaluateCheck
      .mockResolvedValueOnce(ERROR_RESULT("Check_A"))
      .mockResolvedValueOnce(PASS_RESULT("Check_B"));
    await appendAndLoad(element);

    expect(evaluateCheck).toHaveBeenCalledTimes(1);
    expect(evaluateCheck).toHaveBeenCalledWith(
      expect.objectContaining({ ruleDeveloperName: "Check_A" })
    );
    const btn = element.shadowRoot.querySelector(".rhc-action-button");
    expect(btn).not.toBeNull(); // re-run button visible = runComplete
    // The synthesized SKIPPED check rolls up into the Skipped summary pill.
    const pill = element.shadowRoot.querySelector(".rhc-stat--skipped");
    expect(pill).not.toBeNull();
    expect(pill.textContent).toContain("1 Skipped");
  });

  it("does not stop early on FAIL (only stops on system ERROR)", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", stopOnFirstError: true })
    );
    evaluateCheck
      .mockResolvedValueOnce(FAIL_RESULT("Check_A"))
      .mockResolvedValueOnce(PASS_RESULT("Check_B"));
    await appendAndLoad(element);
    await flushPromises();

    // stopOnFirstError does not trigger on FAIL — both checks evaluated
    expect(evaluateCheck).toHaveBeenCalledTimes(2);
  });
});

describe("c-record-health-check — _parseAuraError", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("extracts reasonCode and message from a JSON-serialized Aura error body", async () => {
    const body = JSON.stringify({
      reasonCode: "OBJECT_MISMATCH",
      message: "Record type does not match."
    });
    getCheckDefinitions.mockRejectedValue({ body: { message: body } });
    await appendAndLoad(element);

    expect(
      element.shadowRoot.querySelector(".rhc-error-banner")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector(".rhc-error-banner").textContent
    ).toContain("Record type does not match.");
  });

  it("falls back gracefully when error body is not JSON", async () => {
    getCheckDefinitions.mockRejectedValue({
      body: { message: "Internal server error" }
    });
    await appendAndLoad(element);

    expect(
      element.shadowRoot.querySelector(".rhc-error-banner")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector(".rhc-error-banner").textContent
    ).toContain("Internal server error");
  });

  it("uses a default message when error has no body", async () => {
    getCheckDefinitions.mockRejectedValue({});
    await appendAndLoad(element);

    expect(
      element.shadowRoot.querySelector(".rhc-error-banner")
    ).not.toBeNull();
  });
});

describe("c-record-health-check — reactive recordId reload", () => {
  const RECORD_A = "001000000000001AAA";
  const RECORD_B = "001000000000002AAA";
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createElement("c-record-health-check", {
      is: RecordHealthCheck
    });
    element.checkSetName = "Account_Data_Quality";
    element.recordId = RECORD_A;
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  it("runs the new record's Automatic checks after an in-place record swap mid-run", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic" })
    );
    // Record A's evaluations never resolve, leaving the run in flight; record B's resolve.
    evaluateCheck.mockImplementation(({ recordId }) => {
      if (recordId === RECORD_A) {
        return new Promise(() => {});
      }
      return Promise.resolve(PASS_RESULT("Check_A"));
    });

    await appendAndLoad(element);

    // Record A fired both concurrent evaluations and they are still pending.
    expect(
      evaluateCheck.mock.calls.filter((c) => c[0].recordId === RECORD_A).length
    ).toBe(2);

    // Swap the record in place while A's run is still in flight.
    element.recordId = RECORD_B;
    await flushPromises();
    await flushPromises();
    await flushPromises();

    // The new record's run must NOT be suppressed by a leftover _runInProgress flag.
    expect(
      evaluateCheck.mock.calls.filter((c) => c[0].recordId === RECORD_B).length
    ).toBe(2);
  });

  it("never exceeds five concurrent evaluations across a mid-run record swap", async () => {
    const checks = Array.from({ length: 12 }, (_, i) => ({
      developerName: `Check_${i}`,
      label: `Check ${i}`,
      description: "",
      priority: i,
      dependsOnRuleDeveloperName: null
    }));
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", checks })
    );

    // Global in-flight counter across BOTH records: a request fired by the
    // abandoned record-A run still occupies a real slot until it settles.
    let active = 0;
    let peak = 0;
    const pendingA = [];
    evaluateCheck.mockImplementation(({ recordId, ruleDeveloperName }) => {
      active++;
      peak = Math.max(peak, active);
      const call = deferred();
      const settle = () => {
        active--;
        call.resolve(PASS_RESULT(ruleDeveloperName));
      };
      if (recordId === RECORD_A) {
        // Hold A's calls open so they keep occupying slots during the swap.
        pendingA.push(settle);
      } else {
        // B's calls settle on the next microtask turn.
        Promise.resolve().then(settle);
      }
      return call.promise;
    });

    await appendAndLoad(element);
    // Record A saturated the pool: 5 in flight, the rest queued.
    expect(
      evaluateCheck.mock.calls.filter((c) => c[0].recordId === RECORD_A).length
    ).toBe(5);
    expect(active).toBe(5);

    // Swap mid-run. A's 5 calls are still open; the new run must treat them as
    // occupying the pool rather than launching a second batch on top.
    element.recordId = RECORD_B;
    await flushPromises();
    await flushPromises();

    // No B evaluation may start while A still holds all five slots.
    expect(
      evaluateCheck.mock.calls.filter((c) => c[0].recordId === RECORD_B).length
    ).toBe(0);
    expect(peak).toBeLessThanOrEqual(5);

    // Drain A's abandoned calls one at a time; each freed slot lets exactly one
    // B check start, so the global peak stays capped at five throughout.
    let safety = 0;
    while (
      evaluateCheck.mock.calls.filter((c) => c[0].recordId === RECORD_B)
        .length < 12 &&
      safety++ < 40
    ) {
      const next = pendingA.shift();
      if (next) next();
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    expect(
      evaluateCheck.mock.calls.filter((c) => c[0].recordId === RECORD_B).length
    ).toBe(12);
    expect(peak).toBeLessThanOrEqual(5);
  });

  it("discards a stale in-flight result from the previously-viewed record", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        triggerMode: "Automatic",
        successDisplayMode: "Show",
        checks: [
          {
            developerName: "Check_A",
            label: "Check A",
            description: "",
            priority: 1,
            dependsOnRuleDeveloperName: null
          }
        ],
        totalAvailableCheckCount: 1
      })
    );

    let resolveStale;
    const staleResult = {
      ...FAIL_RESULT("Check_A"),
      message: "STALE-RECORD-A-MESSAGE"
    };
    evaluateCheck.mockImplementation(({ recordId }) => {
      if (recordId === RECORD_A) {
        return new Promise((res) => {
          resolveStale = () => res(staleResult);
        });
      }
      return Promise.resolve(PASS_RESULT("Check_A"));
    });

    await appendAndLoad(element);

    // Swap to record B; its run resolves with PASS.
    element.recordId = RECORD_B;
    await flushPromises();
    await flushPromises();
    await flushPromises();

    // Record A's evaluation finally resolves — after the record has changed.
    resolveStale();
    await flushPromises();
    await flushPromises();

    // The stale record-A message must never render under record B.
    expect(element.shadowRoot.textContent).not.toContain(
      "STALE-RECORD-A-MESSAGE"
    );
  });
});

describe("c-record-health-check — enterprise boundary and concurrency", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) document.body.removeChild(element);
  });

  it("ignores an out-of-order definition response from an older record", async () => {
    const oldLoad = deferred();
    const newLoad = deferred();
    getCheckDefinitions
      .mockReturnValueOnce(oldLoad.promise)
      .mockReturnValueOnce(newLoad.promise);
    await appendAndLoad(element);

    element.recordId = "001000000000002AAA";
    newLoad.resolve(makeDefinitions({ displayTitle: "Newest record" }));
    await flushPromises();
    await flushPromises();
    oldLoad.resolve(makeDefinitions({ displayTitle: "Stale record" }));
    await flushPromises();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Newest record");
    expect(element.shadowRoot.textContent).not.toContain("Stale record");
  });

  it("clears a transient load error after a successful record reload", async () => {
    getCheckDefinitions
      .mockRejectedValueOnce({ body: { message: "Temporary failure" } })
      .mockResolvedValueOnce(makeDefinitions());
    await appendAndLoad(element);
    expect(element.shadowRoot.querySelector('[role="alert"]')).not.toBeNull();

    element.recordId = "001000000000002AAA";
    await flushPromises();
    await flushPromises();

    expect(element.shadowRoot.querySelector('[role="alert"]')).toBeNull();
    expect(element.shadowRoot.textContent).toContain("Account Health");
  });

  it("reloads safely when the configured Check Set changes", async () => {
    getCheckDefinitions
      .mockResolvedValueOnce(makeDefinitions({ displayTitle: "First set" }))
      .mockResolvedValueOnce(makeDefinitions({ displayTitle: "Second set" }));
    await appendAndLoad(element);

    element.checkSetName = "Account_Advanced_Checks";
    await flushPromises();
    await flushPromises();

    expect(getCheckDefinitions.mock.calls[1][0].checkSetDeveloperName).toBe(
      "Account_Advanced_Checks"
    );
    expect(element.shadowRoot.textContent).toContain("Second set");
  });

  it("ignores a deferred load after the component disconnects", async () => {
    const load = deferred();
    getCheckDefinitions.mockReturnValue(load.promise);
    await appendAndLoad(element);
    document.body.removeChild(element);

    load.resolve(makeDefinitions({ triggerMode: "Automatic" }));
    await flushPromises();
    await flushPromises();

    expect(evaluateCheck).not.toHaveBeenCalled();
  });

  it("completes an empty Automatic run without hanging", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", checks: [] })
    );
    await appendAndLoad(element);

    expect(evaluateCheck).not.toHaveBeenCalled();
    expect(
      element.shadowRoot.querySelector(".rhc-action-button")
    ).not.toBeNull();
  });

  it.each([null, { status: "FUTURE_STATUS" }])(
    "normalizes malformed evaluation result %#",
    async (badResult) => {
      getCheckDefinitions.mockResolvedValue(
        makeDefinitions({ checks: [makeDefinitions().checks[0]] })
      );
      evaluateCheck.mockResolvedValue(badResult);
      await appendAndLoad(element);
      await clickRun(element);

      expect(element.shadowRoot.textContent).toMatch(
        /invalid result|unsupported result status/
      );
      expect(element.shadowRoot.textContent).toContain("System Error");
    }
  );

  it("never runs more than five Apex evaluations concurrently", async () => {
    const checks = Array.from({ length: 12 }, (_, i) => ({
      developerName: `Check_${i}`,
      label: `Check ${i}`,
      description: "",
      priority: i,
      dependsOnRuleDeveloperName: null
    }));
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ triggerMode: "Automatic", checks })
    );
    let active = 0;
    let peak = 0;
    const pending = [];
    evaluateCheck.mockImplementation(({ ruleDeveloperName }) => {
      active++;
      peak = Math.max(peak, active);
      const call = deferred();
      pending.push(() => {
        active--;
        call.resolve(PASS_RESULT(ruleDeveloperName));
      });
      return call.promise;
    });

    await appendAndLoad(element);
    expect(evaluateCheck).toHaveBeenCalledTimes(5);
    let safety = 0;
    while (evaluateCheck.mock.calls.length < 12 && safety++ < 12) {
      const batch = pending.splice(0, pending.length);
      batch.forEach((resolve) => resolve());
      // The next worker batch is intentionally released one microtask turn at a time.
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    expect(evaluateCheck).toHaveBeenCalledTimes(12);
    expect(peak).toBeLessThanOrEqual(5);
  });

  it("renders semantic heading, tooltip descriptions, focusable rows, and status text", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        successDisplayMode: "Show",
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);

    expect(element.shadowRoot.querySelector("h2").textContent).toContain(
      "Account Health"
    );
    // Description is no longer an inline line — it is surfaced as a row tooltip
    // and folded into the row's accessible name.
    expect(
      element.shadowRoot.querySelector(".rhc-row__description")
    ).toBeNull();
    const row = element.shadowRoot.querySelector("li.rhc-row");
    expect(row.getAttribute("data-tooltip")).toContain("First check");
    expect(row.getAttribute("aria-label")).toContain("First check");
    expect(
      element.shadowRoot.querySelector("[role='status']").textContent
    ).toContain("Pass");
  });

  it("waits before showing a row tooltip on pointer hover", async () => {
    jest.useFakeTimers();
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        successDisplayMode: "Show",
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);

    const row = element.shadowRoot.querySelector("li.rhc-tooltip-anchor");
    expect(row).not.toBeNull();
    expect(row.classList.contains("rhc-tooltip-anchor--dwell")).toBe(false);

    row.dispatchEvent(
      new MouseEvent("mouseover", { bubbles: true, relatedTarget: null })
    );
    jest.advanceTimersByTime(599);
    expect(row.classList.contains("rhc-tooltip-anchor--dwell")).toBe(false);

    jest.advanceTimersByTime(1);
    expect(row.classList.contains("rhc-tooltip-anchor--dwell")).toBe(true);

    row.dispatchEvent(
      new MouseEvent("mouseout", { bubbles: true, relatedTarget: null })
    );
    expect(row.classList.contains("rhc-tooltip-anchor--dwell")).toBe(false);

    jest.useRealTimers();
  });

  it("clears a pending tooltip dwell when focus leaves the row", async () => {
    jest.useFakeTimers();
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        successDisplayMode: "Show",
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);

    const row = element.shadowRoot.querySelector("li.rhc-tooltip-anchor");
    row.dispatchEvent(
      new MouseEvent("mouseover", { bubbles: true, relatedTarget: null })
    );
    row.dispatchEvent(
      new FocusEvent("focusout", { bubbles: true, relatedTarget: null })
    );
    jest.advanceTimersByTime(600);
    expect(row.classList.contains("rhc-tooltip-anchor--dwell")).toBe(false);

    jest.useRealTimers();
  });

  it("makes only rows with a tooltip a tab stop", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        successDisplayMode: "Show",
        checks: [
          {
            developerName: "With_Desc",
            label: "Has tooltip",
            description: "A description",
            priority: 1,
            dependsOnRuleDeveloperName: null
          },
          {
            developerName: "No_Desc",
            label: "No tooltip",
            description: "",
            priority: 2,
            dependsOnRuleDeveloperName: null
          }
        ]
      })
    );
    evaluateCheck.mockImplementation(({ ruleDeveloperName }) =>
      Promise.resolve(PASS_RESULT(ruleDeveloperName))
    );
    await appendAndLoad(element);
    await clickRun(element);

    const rows = element.shadowRoot.querySelectorAll("li.rhc-row");
    expect(rows[0].getAttribute("tabindex")).toBe("0");
    expect(rows[1].getAttribute("tabindex")).toBe("-1");
  });

  it("logs a console summary and diagnostics group when showDiagnostics completes a run", async () => {
    const group = jest.spyOn(console, "group").mockImplementation(() => {});
    const log = jest.spyOn(console, "log").mockImplementation(() => {});
    const table = jest.spyOn(console, "table").mockImplementation(() => {});
    const groupEnd = jest
      .spyOn(console, "groupEnd")
      .mockImplementation(() => {});
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        showDiagnostics: true,
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue({
      ...PASS_RESULT("Check_A"),
      actualValue: '"Technology"',
      expectedValue: 'to equal "Technology"',
      actualValueDetail: 'Industry → "Technology"',
      expectedValueDetail: 'Fixed value → "Technology"'
    });
    await appendAndLoad(element);
    await clickRun(element);
    await flushPromises();
    await flushPromises();

    expect(group).toHaveBeenCalledWith(
      expect.stringContaining("Account_Data_Quality")
    );
    expect(log).toHaveBeenCalledWith("1 Passed");
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        runId: expect.any(String),
        checkSet: "Account_Data_Quality",
        recordId: expect.any(String),
        userId: expect.any(String),
        generatedAt: expect.any(String)
      })
    );
    expect(table).toHaveBeenCalledWith(expect.any(Array), [
      "check",
      "status",
      "severity",
      "reasonCode",
      "actualValue",
      "expectedValue",
      "durationMs",
      "evaluatorType"
    ]);
    expect(group).toHaveBeenCalledWith("[RHC] Source detail (1 check)");
    expect(group).toHaveBeenCalledWith(
      expect.stringContaining("Check A (Check_A)")
    );
    expect(log).toHaveBeenCalledWith("Found", 'Industry → "Technology"');
    expect(log).toHaveBeenCalledWith("Expected", 'Fixed value → "Technology"');
    expect(groupEnd).toHaveBeenCalled();
    group.mockRestore();
    log.mockRestore();
    table.mockRestore();
    groupEnd.mockRestore();
  });

  it("does not log an empty diagnostics group when diagnostic details are absent", async () => {
    const group = jest.spyOn(console, "group").mockImplementation(() => {});
    const log = jest.spyOn(console, "log").mockImplementation(() => {});
    const table = jest.spyOn(console, "table").mockImplementation(() => {});
    const groupEnd = jest
      .spyOn(console, "groupEnd")
      .mockImplementation(() => {});
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        showDiagnostics: true,
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue(PASS_RESULT("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);
    await flushPromises();
    await flushPromises();

    expect(group).not.toHaveBeenCalledWith(
      expect.stringContaining("Source detail")
    );
    group.mockRestore();
    log.mockRestore();
    table.mockRestore();
    groupEnd.mockRestore();
  });

  it("includes system errors and elapsed time in the diagnostics summary", async () => {
    const group = jest.spyOn(console, "group").mockImplementation(() => {});
    const log = jest.spyOn(console, "log").mockImplementation(() => {});
    const table = jest.spyOn(console, "table").mockImplementation(() => {});
    const groupEnd = jest
      .spyOn(console, "groupEnd")
      .mockImplementation(() => {});
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        showDiagnostics: true,
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue({
      ...ERROR_RESULT("Check_A"),
      durationMs: 17
    });
    await appendAndLoad(element);
    await clickRun(element);

    expect(log).toHaveBeenCalledWith("1 Error · 17ms total");
    group.mockRestore();
    log.mockRestore();
    table.mockRestore();
    groupEnd.mockRestore();
  });
});

describe("c-record-health-check — FAIL styling and accessibility", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  const FAIL_NO_SEVERITY = (developerName) => ({
    ruleDeveloperName: developerName,
    label: developerName,
    status: "FAIL",
    severity: null,
    message: "This field needs attention.",
    priority: 1,
    evaluatorType: "Formula"
  });

  it("renders a FAIL with missing severity as Error, not Unable", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue(FAIL_NO_SEVERITY("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);

    // Error styling is applied (not an unstyled / "unable" row)
    expect(element.shadowRoot.querySelector(".rhc-row--error")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row--unable")).toBeNull();
    // Summary bar counts it as Failed, not Unable
    expect(element.shadowRoot.textContent).toContain("1 Failed");
    expect(element.shadowRoot.textContent).not.toContain("1 Unable");
  });

  it("folds the failure message into the row's accessible name", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue(FAIL_NO_SEVERITY("Check_A"));
    await appendAndLoad(element);
    await clickRun(element);

    const row = element.shadowRoot.querySelector("li[aria-label]");
    expect(row).not.toBeNull();
    expect(row.getAttribute("aria-label")).toContain(
      "This field needs attention."
    );
  });

  it("renders the found/expected comparison as labelled key/value chips and announces it", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ...FAIL_NO_SEVERITY("Check_A"),
      actualValue: "Finance",
      expectedValue: "to equal Technology"
    });
    await appendAndLoad(element);
    await clickRun(element);

    const comparison = element.shadowRoot.querySelector(".rhc-row__comparison");
    expect(comparison).not.toBeNull();
    const keys = [...comparison.querySelectorAll(".rhc-cmp__key")].map((n) =>
      n.textContent.trim()
    );
    const vals = [...comparison.querySelectorAll(".rhc-cmp__val")].map((n) =>
      n.textContent.trim()
    );
    expect(keys).toEqual(["Found", "Expected"]);
    expect(vals).toEqual(["Finance", "to equal Technology"]);

    const row = element.shadowRoot.querySelector("li[aria-label]");
    expect(row.getAttribute("aria-label")).toContain("Found Finance");
    expect(row.getAttribute("aria-label")).toContain(
      "Expected to equal Technology"
    );
  });

  it("renders only the expected clause when there is no found value", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ...FAIL_NO_SEVERITY("Check_A"),
      actualValue: null,
      expectedValue: "ISBLANK(BillingCity)"
    });
    await appendAndLoad(element);
    await clickRun(element);

    const comparison = element.shadowRoot.querySelector(".rhc-row__comparison");
    expect(comparison).not.toBeNull();
    const keys = [...comparison.querySelectorAll(".rhc-cmp__key")].map((n) =>
      n.textContent.trim()
    );
    const vals = [...comparison.querySelectorAll(".rhc-cmp__val")].map((n) =>
      n.textContent.trim()
    );
    expect(keys).toEqual(["Expected"]);
    expect(vals).toEqual(["ISBLANK(BillingCity)"]);
  });

  it("labels an echoed pass/fail condition with its own key instead of 'Expected'", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ...FAIL_NO_SEVERITY("Check_A"),
      actualValue: null,
      expectedValue: "Owner.IsActive",
      expectedValueLabel: "Passes when"
    });
    await appendAndLoad(element);
    await clickRun(element);

    const comparison = element.shadowRoot.querySelector(".rhc-row__comparison");
    expect(comparison).not.toBeNull();
    const keys = [...comparison.querySelectorAll(".rhc-cmp__key")].map((n) =>
      n.textContent.trim()
    );
    const vals = [...comparison.querySelectorAll(".rhc-cmp__val")].map((n) =>
      n.textContent.trim()
    );
    expect(keys).toEqual(["Passes when"]);
    expect(vals).toEqual(["Owner.IsActive"]);

    const row = element.shadowRoot.querySelector("li[aria-label]");
    expect(row.getAttribute("aria-label")).toContain(
      "Passes when Owner.IsActive"
    );
  });

  it("renders a Found chip when the actual value is 0", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ...FAIL_NO_SEVERITY("Check_A"),
      actualValue: 0,
      expectedValue: 'at least "1"'
    });
    await appendAndLoad(element);
    await clickRun(element);

    const comparison = element.shadowRoot.querySelector(".rhc-row__comparison");
    expect(comparison).not.toBeNull();
    const keys = [...comparison.querySelectorAll(".rhc-cmp__key")].map((n) =>
      n.textContent.trim()
    );
    expect(keys).toEqual(["Found", "Expected"]);
    const vals = [...comparison.querySelectorAll(".rhc-cmp__val")].map((n) =>
      n.textContent.trim()
    );
    // Truthiness would have suppressed the 0; nullish keeps it visible.
    expect(vals[0]).toBe("0");
    const row = element.shadowRoot.querySelector("li[aria-label]");
    expect(row.getAttribute("aria-label")).toContain("Found 0");
  });

  it("clamps long values and toggles a value chip open and closed", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ...FAIL_NO_SEVERITY("Check_A"),
      actualValue: null,
      expectedValue:
        "OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)), NOT(ISBLANK(Fax)))",
      expectedValueLabel: "Passes when"
    });
    await appendAndLoad(element);
    await clickRun(element);

    // Every value chip renders clampable, with a paired "..." toggle. jsdom
    // has no layout so scrollHeight is 0 and the toggle stays hidden until the
    // renderedCallback measures a real overflow — but the toggle handler is
    // exercised directly here.
    const chip = element.shadowRoot.querySelector(
      ".rhc-cmp__val--clampable[data-clampval]"
    );
    expect(chip).not.toBeNull();
    const toggle = element.shadowRoot.querySelector("[data-clamptoggle]");
    expect(toggle).not.toBeNull();
    expect(toggle.textContent.trim()).toBe("+");
    expect(toggle.getAttribute("aria-label")).toBe("Expand value");

    toggle.click();
    await Promise.resolve();
    expect(chip.classList.contains("rhc-cmp__val--expanded")).toBe(true);
    expect(toggle.textContent.trim()).toBe("−");
    expect(toggle.getAttribute("aria-expanded")).toBe("true");
    expect(toggle.getAttribute("aria-label")).toBe("Collapse value");

    toggle.click();
    await Promise.resolve();
    expect(chip.classList.contains("rhc-cmp__val--expanded")).toBe(false);
    expect(toggle.textContent.trim()).toBe("+");
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
    expect(toggle.getAttribute("aria-label")).toBe("Expand value");
  });

  it("does not render the comparison block on a passing row", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({
        successDisplayMode: "Show",
        checks: [makeDefinitions().checks[0]]
      })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "PASS",
      priority: 1,
      evaluatorType: "Query",
      actualValue: '"Technology"',
      expectedValue: 'to equal "Technology"'
    });
    await appendAndLoad(element);
    await clickRun(element);

    expect(element.shadowRoot.querySelector(".rhc-row__comparison")).toBeNull();
  });
});

describe("annotateCheck — comparison disclosure matrix", () => {
  const resolved = (result) => ({
    uiState: "RESOLVED",
    label: "L",
    description: null,
    result
  });

  const passWithValues = {
    status: "PASS",
    actualValue: '"Technology"',
    expectedValue: 'to equal "Technology"'
  };
  const failWithValuesAndProvenance = {
    status: "FAIL",
    severity: "Error",
    message: "Nope.",
    actualValue: "0",
    expectedValue: 'at least "1"',
    actualValueDetail: "Contacts → 0 rows (query returned no matching rows)",
    expectedValueDetail: "Fixed value → 1"
  };

  it("OnDemand: a passing row with values gets a caret but no inline chips", () => {
    const a = annotateCheck(resolved(passWithValues), false, "OnDemand", false);
    expect(a.showInlineComparison).toBe(false);
    expect(a.showCaret).toBe(true);
    expect(a.detailExpanded).toBe(false);
  });

  it("OnDemand: expanding a passing row reveals Found/Expected values", () => {
    const a = annotateCheck(resolved(passWithValues), false, "OnDemand", true);
    expect(a.detailExpanded).toBe(true);
    expect(a.showExpandedActual).toBe(true);
    expect(a.showExpandedExpected).toBe(true);
  });

  it("OnDemand: a failing row shows values inline without card diagnostic details", () => {
    const collapsed = annotateCheck(
      resolved(failWithValuesAndProvenance),
      false,
      "OnDemand",
      false
    );
    expect(collapsed.showInlineComparison).toBe(true);
    expect(collapsed.showActual).toBe(true);
    expect(collapsed.showExpected).toBe(true);
    expect(collapsed.showCaret).toBe(false);
    expect(collapsed.actualValueDetail).toBeUndefined();
    expect(collapsed.expectedValueDetail).toBeUndefined();
    expect(collapsed.showActualDetail).toBeUndefined();
    expect(collapsed.showExpectedDetail).toBeUndefined();

    const open = annotateCheck(
      resolved(failWithValuesAndProvenance),
      false,
      "OnDemand",
      true
    );
    expect(open.showActualDetail).toBeUndefined();
    expect(open.showExpectedDetail).toBeUndefined();
    // Values were already inline, so there is no expanded region.
    expect(open.detailExpanded).toBe(false);
    expect(open.showExpandedActual).toBe(false);
  });

  it("keeps card diagnostic details out of the view model when expanding values", () => {
    const a = annotateCheck(resolved(passWithValues), false, "OnDemand", true);
    expect(a.showExpandedActual).toBe(true);
    expect(a.showActualDetail).toBeUndefined();
    expect(a.showExpectedDetail).toBeUndefined();
  });

  it("FailuresOnly: a passing row has no caret and shows nothing", () => {
    const a = annotateCheck(
      resolved(passWithValues),
      false,
      "FailuresOnly",
      true // even if a placement asked to expand
    );
    expect(a.showCaret).toBe(false);
    expect(a.showInlineComparison).toBe(false);
    expect(a.detailExpanded).toBe(false);
  });

  it("AllRows: a passing row shows Found/Expected inline, no caret when there are no diagnostic details", () => {
    const a = annotateCheck(resolved(passWithValues), false, "AllRows", false);
    expect(a.showInlineComparison).toBe(true);
    expect(a.showActual).toBe(true);
    expect(a.showCaret).toBe(false);
  });

  it("falls back to OnDemand for an unrecognized mode", () => {
    const a = annotateCheck(resolved(passWithValues), false, "Whatever", false);
    expect(a.showInlineComparison).toBe(false);
    expect(a.showCaret).toBe(true);
  });

  it("renders a value of 0 rather than treating it as missing", () => {
    const a = annotateCheck(
      resolved({ status: "PASS", actualValue: 0, expectedValue: "" }),
      false,
      "AllRows",
      false
    );
    expect(a.showActual).toBe(true);
    expect(a.actualValue).toBe(0);
    expect(a.showExpected).toBe(true); // empty string is a real value
    expect(a.expectedValue).toBe("");
  });

  it("keeps comparison values out of the accessible name until they are visible", () => {
    const collapsed = annotateCheck(
      resolved(passWithValues),
      false,
      "OnDemand",
      false
    );
    expect(collapsed.accessibleLabel).not.toContain("Found");
    const open = annotateCheck(
      resolved(passWithValues),
      false,
      "OnDemand",
      true
    );
    expect(open.accessibleLabel).toContain('Found "Technology"');
  });
});

describe("annotateCheck — guided remediation", () => {
  const resolved = (result) => ({
    uiState: "RESOLVED",
    label: "L",
    description: null,
    result
  });

  const failWithLink = {
    status: "FAIL",
    severity: "Warning",
    message: "Contacts missing email.",
    actualValue: "1 of 2 contacts missing email",
    expectedValue: "every contact has an email",
    actionUrl: "/lightning/r/Report/00O/view?fv0=001",
    actionLabel: "View contacts missing email",
    fixInstructions: "Opens a filtered report for this account."
  };

  it("surfaces the link, label, instructions, and divider on a FAIL", () => {
    const a = annotateCheck(resolved(failWithLink), false, "OnDemand", false);
    expect(a.showAction).toBe(true);
    expect(a.showActionBlock).toBe(true);
    expect(a.actionUrl).toBe("/lightning/r/Report/00O/view?fv0=001");
    expect(a.actionLabel).toBe("View contacts missing email");
    expect(a.showFixInstructions).toBe(true);
    // Message + action above, evidence below → divider between them.
    expect(a.showComparisonDivider).toBe(true);
    expect(a.accessibleLabel).toContain("Link: View contacts missing email");
  });

  it("defaults the label when a URL is present but no label was authored", () => {
    const a = annotateCheck(
      resolved({ ...failWithLink, actionLabel: null }),
      false,
      "OnDemand",
      false
    );
    expect(a.actionLabel).toBe("Fix this");
  });

  it("shows instructions with no link when the URL was omitted/suppressed", () => {
    const a = annotateCheck(
      resolved({ ...failWithLink, actionUrl: null }),
      false,
      "OnDemand",
      false
    );
    expect(a.showAction).toBe(false);
    expect(a.actionLabel).toBe(null);
    expect(a.showFixInstructions).toBe(true);
    expect(a.showActionBlock).toBe(true);
  });

  it("renders no action block on a PASS (server sends no link)", () => {
    const a = annotateCheck(
      resolved({ status: "PASS", actualValue: "x", expectedValue: "y" }),
      false,
      "OnDemand",
      false
    );
    expect(a.showAction).toBe(false);
    expect(a.showFixInstructions).toBe(false);
    expect(a.showActionBlock).toBe(false);
  });
});

describe("c-record-health-check — comparison disclosure (integration)", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  const PASS_WITH_VALUES = {
    ruleDeveloperName: "Check_A",
    label: "Check_A",
    status: "PASS",
    priority: 1,
    evaluatorType: "Query",
    actualValue: '"Technology"',
    expectedValue: 'to equal "Technology"',
    actualValueDetail: 'Industry → "Technology"',
    expectedValueDetail: 'Fixed value → "Technology"'
  };

  const onePassCheck = (overrides = {}) =>
    makeDefinitions({
      successDisplayMode: "Show",
      comparisonDisplay: "OnDemand",
      checks: [makeDefinitions().checks[0]],
      ...overrides
    });

  it("OnDemand: passing row shows a caret; clicking it reveals values without source notes", async () => {
    getCheckDefinitions.mockResolvedValue(onePassCheck());
    evaluateCheck.mockResolvedValue(PASS_WITH_VALUES);
    await appendAndLoad(element);
    await clickRun(element);

    // Collapsed by default: caret present, no inline comparison, no detail.
    const caret = element.shadowRoot.querySelector(".rhc-caret");
    expect(caret).not.toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row__comparison")).toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row__detail")).toBeNull();

    caret.click();
    await flushPromises();

    const detail = element.shadowRoot.querySelector(".rhc-row__detail");
    expect(detail).not.toBeNull();
    const vals = [...detail.querySelectorAll(".rhc-cmp__val")].map((n) =>
      n.textContent.trim()
    );
    expect(vals).toEqual(['"Technology"', 'to equal "Technology"']);
    expect(detail.querySelector(".rhc-cmp__source")).toBeNull();
    expect(detail.textContent).not.toContain('Industry → "Technology"');
    expect(caret.getAttribute("aria-expanded")).toBe("true");
  });

  it("renders the Fix-it link, instructions, and divider on a failing row", async () => {
    getCheckDefinitions.mockResolvedValue(onePassCheck());
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "FAIL",
      severity: "Warning",
      message: "Contacts missing email.",
      actualValue: "1 of 2 contacts missing email",
      expectedValue: "every contact has an email",
      actionUrl: "/lightning/r/Report/00O/view?fv0=001",
      actionLabel: "View contacts missing email",
      fixInstructions: "Opens a filtered report for this account."
    });
    await appendAndLoad(element);
    await clickRun(element);

    const link = element.shadowRoot.querySelector(".rhc-row__action-link");
    expect(link).not.toBeNull();
    expect(link.getAttribute("href")).toBe(
      "/lightning/r/Report/00O/view?fv0=001"
    );
    expect(link.getAttribute("target")).toBe("_blank");
    expect(link.getAttribute("rel")).toContain("noopener");
    expect(link.textContent.trim()).toBe("View contacts missing email");
    expect(
      element.shadowRoot.querySelector(".rhc-row__fix-instructions").textContent
    ).toContain("filtered report");
    expect(
      element.shadowRoot.querySelector(".rhc-row__divider")
    ).not.toBeNull();
  });

  it("Rerun collapses a caret the user opened on the previous run", async () => {
    getCheckDefinitions.mockResolvedValue(onePassCheck());
    evaluateCheck.mockResolvedValue(PASS_WITH_VALUES);
    await appendAndLoad(element);
    await clickRun(element);

    // Open the passing row's caret, then rerun.
    element.shadowRoot.querySelector(".rhc-caret").click();
    await flushPromises();
    expect(
      element.shadowRoot
        .querySelector(".rhc-caret")
        .getAttribute("aria-expanded")
    ).toBe("true");

    await clickRun(element);

    // The rerun starts the row back at the placement default (collapsed).
    expect(
      element.shadowRoot
        .querySelector(".rhc-caret")
        .getAttribute("aria-expanded")
    ).toBe("false");
    expect(element.shadowRoot.querySelector(".rhc-row__detail")).toBeNull();
  });

  it("keeps source notes off the card when expanded details are null", async () => {
    getCheckDefinitions.mockResolvedValue(onePassCheck());
    evaluateCheck.mockResolvedValue({
      ...PASS_WITH_VALUES,
      actualValueDetail: null,
      expectedValueDetail: null
    });
    await appendAndLoad(element);
    await clickRun(element);

    element.shadowRoot.querySelector(".rhc-caret").click();
    await flushPromises();

    const detail = element.shadowRoot.querySelector(".rhc-row__detail");
    expect(detail).not.toBeNull();
    expect(detail.querySelector(".rhc-cmp__val")).not.toBeNull();
    expect(detail.querySelector(".rhc-cmp__source")).toBeNull();
  });

  it("FailuresOnly: a passing row shows neither a caret nor comparison", async () => {
    getCheckDefinitions.mockResolvedValue(
      onePassCheck({ comparisonDisplay: "FailuresOnly" })
    );
    evaluateCheck.mockResolvedValue(PASS_WITH_VALUES);
    await appendAndLoad(element);
    await clickRun(element);

    expect(element.shadowRoot.querySelector(".rhc-caret")).toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row__comparison")).toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row__detail")).toBeNull();
  });

  it("AllRows: a passing row shows Found/Expected inline", async () => {
    getCheckDefinitions.mockResolvedValue(
      onePassCheck({ comparisonDisplay: "AllRows" })
    );
    evaluateCheck.mockResolvedValue(PASS_WITH_VALUES);
    await appendAndLoad(element);
    await clickRun(element);

    const comparison = element.shadowRoot.querySelector(".rhc-row__comparison");
    expect(comparison).not.toBeNull();
    const keys = [...comparison.querySelectorAll(".rhc-cmp__key")].map((n) =>
      n.textContent.trim()
    );
    expect(keys).toEqual(["Found", "Expected"]);
  });

  it("an OnDemand pass row starts with its comparison caret collapsed", async () => {
    getCheckDefinitions.mockResolvedValue(onePassCheck());
    evaluateCheck.mockResolvedValue(PASS_WITH_VALUES);
    await appendAndLoad(element);
    await clickRun(element);

    // The caret exists (there are values to reveal) but the detail stays closed
    // until the user clicks it — there is no placement-level pre-open.
    expect(element.shadowRoot.querySelector(".rhc-caret")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".rhc-row__detail")).toBeNull();
  });
});

describe("buildSummaryStats — label pluralization", () => {
  const resolved = (label, status, severity) => ({
    label,
    result: { status, severity }
  });
  const labelFor = (checks, suffixMatch) =>
    buildSummaryStats(checks).find((s) => s.key === suffixMatch).label;

  it("pluralizes Warning only when there is more than one", () => {
    expect(labelFor([resolved("A", "FAIL", "Warning")], "warn")).toBe(
      "1 Warning"
    );
    expect(
      labelFor(
        [resolved("A", "FAIL", "Warning"), resolved("B", "FAIL", "Warning")],
        "warn"
      )
    ).toBe("2 Warnings");
  });

  it("labels informational failures and ignores unknown outcomes", () => {
    const checks = [
      {
        label: "Informational",
        uiState: "RESOLVED",
        result: { status: "FAIL", severity: "Info" }
      },
      {
        label: "Future status",
        uiState: "RESOLVED",
        result: { status: "FUTURE_STATUS", severity: null }
      }
    ];

    expect(buildSummaryStats(checks).map((stat) => stat.label)).toEqual([
      "1 Info",
      "1 Unable"
    ]);
    expect(annotateCheck(checks[1], false, "OnDemand", false).statusLabel).toBe(
      ""
    );
  });

  it("leaves visible buckets as plain summary pills without tooltips", () => {
    const passes = ["A", "B"].map((n) => resolved(n, "PASS", null));
    const stat = buildSummaryStats(passes).find((s) => s.key === "pass");
    expect(stat.cssClass).toBe("rhc-stat rhc-stat--pass");
    expect(stat.tooltip).toBeNull();
    expect(stat.tabIndex).toBeNull();
  });

  it("lists every name in the tooltip for hidden buckets, even when the bucket is large", () => {
    const passes = ["A", "B", "C", "D", "E", "F", "G"].map((n) =>
      resolved(n, "PASS", null)
    );
    const stat = buildSummaryStats(passes, new Set(["pass"])).find(
      (s) => s.key === "pass"
    );
    expect(stat.tooltip).toBe("7 Passed: A, B, C, D, E, F, G");
  });

  it("lists every name for small hidden buckets", () => {
    const passes = ["A", "B", "C"].map((n) => resolved(n, "PASS", null));
    const stat = buildSummaryStats(passes, new Set(["pass"])).find(
      (s) => s.key === "pass"
    );
    expect(stat.tooltip).toBe("3 Passed: A, B, C");
  });
});

describe("splitMessageLines — newline handling", () => {
  const texts = (lines) => lines.map((l) => l.text);

  it("returns an empty array for null/undefined", () => {
    expect(splitMessageLines(null)).toEqual([]);
    expect(splitMessageLines(undefined)).toEqual([]);
  });

  it("returns a one-entry array for a single-line message (no regression)", () => {
    const lines = splitMessageLines("This field needs attention.");
    expect(lines).toHaveLength(1);
    expect(lines[0].text).toBe("This field needs attention.");
    expect(lines[0].isBlank).toBe(false);
    expect(lines[0].lineClass).toBe("rhc-row__message-line");
  });

  it("splits a two-line message on \\n", () => {
    expect(texts(splitMessageLines("Headline\nDetail"))).toEqual([
      "Headline",
      "Detail"
    ]);
  });

  it("preserves an interior blank line as a flagged spacer", () => {
    const lines = splitMessageLines("Headline\n\nAction");
    expect(texts(lines)).toEqual(["Headline", "", "Action"]);
    expect(lines.map((l) => l.isBlank)).toEqual([false, true, false]);
    expect(lines[1].lineClass).toContain("rhc-row__message-line--blank");
  });

  it("normalizes CRLF and bare CR to LF", () => {
    expect(texts(splitMessageLines("a\r\nb\rc"))).toEqual(["a", "b", "c"]);
  });

  it("trims leading and trailing blank lines but keeps interior ones", () => {
    expect(texts(splitMessageLines("\n\nHeadline\n\nAction\n\n"))).toEqual([
      "Headline",
      "",
      "Action"
    ]);
  });

  it("assigns a unique key per line for the template for:each", () => {
    const keys = splitMessageLines("a\nb\nc").map((l) => l.key);
    expect(new Set(keys).size).toBe(3);
  });
});

describe("c-record-health-check — multi-line messages", () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    element = createComponent();
  });

  afterEach(() => {
    if (element.isConnected) {
      document.body.removeChild(element);
    }
  });

  const lineTexts = (el) =>
    [...el.shadowRoot.querySelectorAll(".rhc-row__message-line")].map(
      (n) => n.textContent
    );

  it("renders a multi-line FAIL message as separate visual lines", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "FAIL",
      severity: "Error",
      message: "Out of balance.\nDebit: 100\nCredit: 75",
      priority: 1,
      evaluatorType: "Formula"
    });
    await appendAndLoad(element);
    await clickRun(element);

    expect(lineTexts(element)).toEqual([
      "Out of balance.",
      "Debit: 100",
      "Credit: 75"
    ]);
  });

  it("renders a blank-line spacer between paragraphs in a FAIL message", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "FAIL",
      severity: "Error",
      message: "Out of balance.\n\nContact Finance.",
      priority: 1,
      evaluatorType: "Formula"
    });
    await appendAndLoad(element);
    await clickRun(element);

    const spacer = element.shadowRoot.querySelector(
      ".rhc-row__message-line--blank"
    );
    expect(spacer).not.toBeNull();
    expect(lineTexts(element)).toEqual([
      "Out of balance.",
      "",
      "Contact Finance."
    ]);
  });

  it("renders a multi-line Unable to Check message as separate lines", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "UNABLE_TO_EVALUATE",
      reasonCode: "INVALID_FORMULA",
      message: "Could not evaluate.\nCheck the field configuration.",
      priority: 1,
      evaluatorType: "Formula"
    });
    await appendAndLoad(element);
    await clickRun(element);

    expect(element.shadowRoot.querySelector(".rhc-row--unable")).not.toBeNull();
    expect(lineTexts(element)).toEqual([
      "Could not evaluate.",
      "Check the field configuration."
    ]);
  });

  it("renders a single-line message as one line with no spacer (regression)", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "FAIL",
      severity: "Error",
      message: "This field needs attention.",
      priority: 1,
      evaluatorType: "Formula"
    });
    await appendAndLoad(element);
    await clickRun(element);

    expect(lineTexts(element)).toEqual(["This field needs attention."]);
    expect(
      element.shadowRoot.querySelector(".rhc-row__message-line--blank")
    ).toBeNull();
  });

  it("folds multi-line message lines into a coherent aria-label (a11y)", async () => {
    getCheckDefinitions.mockResolvedValue(
      makeDefinitions({ checks: [makeDefinitions().checks[0]] })
    );
    evaluateCheck.mockResolvedValue({
      ruleDeveloperName: "Check_A",
      label: "Check_A",
      status: "FAIL",
      severity: "Error",
      message: "Out of balance.\n\nContact Finance.",
      priority: 1,
      evaluatorType: "Formula"
    });
    await appendAndLoad(element);
    await clickRun(element);

    const row = element.shadowRoot.querySelector("li[aria-label]");
    const label = row.getAttribute("aria-label");
    // Lines joined with ". " — no raw newline, no empty run from the blank line.
    expect(label).toContain("Out of balance. Contact Finance.");
    expect(label).not.toContain("\n");
  });
});

describe("safeActionUrl — client-side scheme guard (HI-3)", () => {
  // Assemble dangerous schemes with a variable operand so ESLint flags neither
  // a literal script URL (no-script-url) nor a useless concat (no-useless-concat),
  // while the runtime value under test stays exactly "javascript:"/"vbscript:".
  const colon = ":";
  const jsScheme = "javascript" + colon;
  const vbScheme = "vbscript" + colon;

  it("accepts an in-app absolute path", () => {
    expect(safeActionUrl("/lightning/r/Report/00O/view?fv0=001")).toBe(
      "/lightning/r/Report/00O/view?fv0=001"
    );
  });

  it("accepts an https URL regardless of case", () => {
    expect(safeActionUrl("https://example.com/x")).toBe(
      "https://example.com/x"
    );
    expect(safeActionUrl("HTTPS://example.com/x")).toBe(
      "HTTPS://example.com/x"
    );
  });

  it("trims surrounding whitespace before deciding", () => {
    expect(safeActionUrl("  /path  ")).toBe("/path");
  });

  it("rejects dangerous and non-allowlisted schemes", () => {
    for (const bad of [
      jsScheme + "alert(1)",
      jsScheme.toUpperCase() + "alert(1)",
      "  " + jsScheme + "alert(1)",
      "data:text/html,<script>alert(1)</script>",
      "http://example.com/x",
      "mailto:a@b.com",
      "//evil.example.com/x",
      vbScheme + "msgbox(1)",
      "relative/path"
    ]) {
      expect(safeActionUrl(bad)).toBeNull();
    }
  });

  it("rejects empty and non-string input", () => {
    expect(safeActionUrl("")).toBeNull();
    expect(safeActionUrl("   ")).toBeNull();
    expect(safeActionUrl(null)).toBeNull();
    expect(safeActionUrl(undefined)).toBeNull();
    expect(safeActionUrl(42)).toBeNull();
  });

  it("annotateCheck drops a javascript: link but keeps the instructions", () => {
    const resolved = (result) => ({
      uiState: "RESOLVED",
      label: "L",
      description: null,
      result
    });
    const a = annotateCheck(
      resolved({
        status: "FAIL",
        severity: "Warning",
        message: "Contacts missing email.",
        actionUrl: jsScheme + "alert(document.cookie)",
        actionLabel: "Fix this",
        fixInstructions: "Open the filtered report for this account."
      }),
      false,
      "OnDemand",
      false
    );
    expect(a.actionUrl).toBeNull();
    expect(a.showAction).toBe(false);
    // The instructions survive independently so the user isn't left stranded.
    expect(a.showFixInstructions).toBe(true);
    expect(a.showActionBlock).toBe(true);
  });
});

describe("HealthCheckRunner — defensive orchestration branches", () => {
  it("does not start a second run while one is already active", () => {
    const host = makeRunnerHost([
      { developerName: "A", dependsOnRuleDeveloperName: null }
    ]);
    const runner = new HealthCheckRunner(host);
    runner._runInProgress = true;
    const callCount = evaluateCheck.mock.calls.length;

    runner.run();

    expect(evaluateCheck).toHaveBeenCalledTimes(callCount);
    expect(host.checks[0].uiState).toBeUndefined();
  });

  it("reuses a memoized task when multiple dependents request one prerequisite", async () => {
    const prerequisite = {
      developerName: "Prerequisite",
      dependsOnRuleDeveloperName: null
    };
    const runner = new HealthCheckRunner(makeRunnerHost([prerequisite]));
    const taskMap = {};
    runner._runToken = 1;
    runner._runOneCheck = jest.fn().mockResolvedValue();
    const runCheck = runner._makeRunCheck(
      taskMap,
      { Prerequisite: prerequisite },
      new Set(),
      1
    );

    const first = runCheck(prerequisite);
    const second = runCheck(prerequisite);
    await first;

    expect(second).toBe(first);
    expect(runner._runOneCheck).toHaveBeenCalledTimes(1);
  });

  it("launches a prerequisite that appears later in the run list", async () => {
    const dependency = {
      developerName: "Prerequisite",
      label: "Prerequisite",
      dependsOnRuleDeveloperName: null
    };
    const dependent = {
      developerName: "Dependent",
      label: "Dependent",
      dependsOnRuleDeveloperName: "Prerequisite"
    };
    const host = makeRunnerHost([dependent, dependency]);
    const runner = new HealthCheckRunner(host);
    evaluateCheck.mockClear();
    runner._runToken = 1;
    runner._runId = "run-1";
    evaluateCheck.mockImplementation(({ ruleDeveloperName }) =>
      Promise.resolve(PASS_RESULT(ruleDeveloperName))
    );
    const taskMap = {};
    const runCheck = runner._makeRunCheck(
      taskMap,
      { Dependent: dependent, Prerequisite: dependency },
      new Set(),
      1
    );

    await runCheck(dependent);

    expect(evaluateCheck).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({ ruleDeveloperName: "Prerequisite" })
    );
    expect(evaluateCheck).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({ ruleDeveloperName: "Dependent" })
    );
  });

  it("rejects stale queued evaluation slots and releases an acquired stale slot", async () => {
    const runner = new HealthCheckRunner(makeRunnerHost());
    runner._runToken = 2;

    await expect(runner._acquireEvaluationSlot(1)).resolves.toBe(false);

    runner._activeEvaluations = 5;
    const queued = runner._acquireEvaluationSlot(2);
    runner._runToken = 3;
    runner._releaseEvaluationSlot();

    await expect(queued).resolves.toBe(false);
    expect(runner._activeEvaluations).toBe(4);
  });

  it("clears the running flag when a sequential launcher rejects", async () => {
    const host = makeRunnerHost([
      { developerName: "A", dependsOnRuleDeveloperName: null }
    ]);
    host.stopOnFirstError = true;
    const runner = new HealthCheckRunner(host);
    runner._runChecksSequentially = jest
      .fn()
      .mockRejectedValue(new Error("unexpected launcher failure"));

    runner.run();
    await flushPromises();

    expect(runner.isRunning).toBe(false);
  });

  it("clears an incomplete sequential run in the finally guard", async () => {
    const check = { developerName: "A", dependsOnRuleDeveloperName: null };
    const runner = new HealthCheckRunner(makeRunnerHost([check]));
    runner._runToken = 7;
    runner._runInProgress = true;
    runner._makeRunCheck = jest.fn(() => jest.fn().mockResolvedValue());

    await runner._runChecksSequentially({ A: check }, new Set(), 7);

    expect(runner.isRunning).toBe(false);
  });
});
