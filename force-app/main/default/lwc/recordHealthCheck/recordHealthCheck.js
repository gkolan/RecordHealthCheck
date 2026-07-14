/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import { LightningElement, api, track } from "lwc";
import slds1Styles from "./recordHealthCheckSlds1.css";
import slds2Styles from "./recordHealthCheckSlds2.css";
import USER_ID from "@salesforce/user/Id";
import getCheckDefinitions from "@salesforce/apex/RecordHealthCheckController.getCheckDefinitions";
import getCheckSetAvailabilityForRecord from "@salesforce/apex/RecordHealthCheckController.getCheckSetAvailabilityForRecord";
import { parseAuraError } from "./healthCheckModel";
import { annotateCheck, buildSummaryStats } from "./healthCheckPresentation";
import { HealthCheckRunner } from "./healthCheckRunner";

// Columns shown in the run-diagnostics table. Value-source detail stays in the nested
// group below — those strings are long and read better one check at a time.
const RHC_DIAG_TABLE_COLUMNS = [
  "check",
  "status",
  "severity",
  "reasonCode",
  "actualValue",
  "expectedValue",
  "durationMs",
  "evaluatorType"
];

// Pointer hover waits before the tooltip fades in so quick row scans do not flash
// popovers. Keyboard focus keeps a shorter CSS dwell (see recordHealthCheck.css).
const TOOLTIP_HOVER_DWELL_MS = 600;

const SETUP_ERROR_CODES = new Set([
  "SETUP_REQUIRED",
  "NO_ACTIVE_CHECK_SETS",
  "INACTIVE_CHECK_SETS_ONLY",
  "CONFIG_NOT_FOUND",
  "CONFIG_INACTIVE",
  "OBJECT_MISMATCH",
  "NO_RECORD_CONTEXT",
  "NO_ACTIVE_CHECKS",
  "INVALID_CONFIG"
]);

export default class RecordHealthCheck extends LightningElement {
  static stylesheets = [slds1Styles, slds2Styles];

  _checkSetName;

  /**
   * Selects the custom visual treatment owned by Record Health Check. The org
   * theme still determines which SLDS runtime Lightning base components use.
   */
  @api designSystem = "SLDS 2";

  get themeClass() {
    const normalizedVersion = String(
      this.designSystem || "SLDS 2"
    ).toUpperCase();
    return normalizedVersion === "SLDS 1"
      ? "rhc-theme rhc-theme--slds1"
      : "rhc-theme rhc-theme--slds2";
  }

  @api
  get checkSetName() {
    return this._checkSetName;
  }
  set checkSetName(value) {
    const changed = value !== this._checkSetName;
    this._checkSetName = value;
    if (this._connected && changed) {
      this._loadDefinitions();
    }
  }

  // recordId is a getter/setter so the component reloads when the record page
  // swaps the underlying record without remounting the component (e.g. console
  // navigation, dynamic record pages). Without this, results would be stale or
  // belong to the previously-viewed record.
  _recordId;
  _connected = false;

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    const changed = value !== this._recordId;
    this._recordId = value;
    // Only reload on a genuine change after the initial connectedCallback load;
    // the first load is owned by connectedCallback so it can defer one macrotask.
    if (this._connected && changed) {
      this._loadDefinitions();
    }
  }

  @track displayTitle;
  @track displayDescription;
  @track triggerMode;
  @track revealMode;
  @track successDisplayMode;
  @track skippedDisplayMode;
  @track comparisonDisplay = "OnDemand";
  @track stopOnFirstError;
  @track showDiagnostics = false;
  @track totalCheckCount = 0;
  @track totalAvailableCheckCount = 0;
  @track inactiveRuleCount = 0;
  @track completedCheckCount = 0;
  @track runComplete = false;
  /** Stays true after the first completed run until definitions reload — drives
   *  the Run/Rerun label while a subsequent run is in flight (runComplete is
   *  false during that window). */
  @track hasCompletedRunOnce = false;
  @track componentError = null; // safe user-facing message
  @track componentErrorCode = null;
  @track checksOmittedByLimit = false;
  @track isLoading = true;

  @track checks = [];

  // Per-row disclosure overrides, keyed by developerName. Absent → the row
  // starts collapsed (the default). Reassigned on toggle so
  // the visibleChecks getter re-annotates. Lives outside `checks` because the
  // runner rebuilds that array on every result; expand state must survive that.
  @track _expandedNames = {};

  // Run orchestration (result buffer, reveal pointer, concurrency pool, run id,
  // and the run token that discards stale in-flight results) lives in the runner;
  // the component owns lifecycle, definition loading, display, and diagnostics.
  _runner = new HealthCheckRunner(this);
  _loadToken = 0;
  _initialLoadTimer;
  _tooltipListenersBound = false;
  _tooltipDwellTimers = new WeakMap();
  _pendingTooltipAnchors = new Set();
  _summaryStatsSource = null;
  _summaryStatsTooltipSignature = "";
  _summaryStatsCache = [];

  connectedCallback() {
    this._connected = true;
    // Defer one macrotask so the record page frame finishes its initial render
    // before we fire Apex calls. Without this, Automatic mode sends up to 25
    // concurrent requests while the page is still mounting other components.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._initialLoadTimer = setTimeout(() => this._loadDefinitions(), 0);
  }

  disconnectedCallback() {
    this._connected = false;
    this._loadToken++;
    if (this._initialLoadTimer) {
      clearTimeout(this._initialLoadTimer);
      this._initialLoadTimer = null;
    }
    // Bump the run token and clear the concurrency pool so any in-flight
    // evaluation resolves to a discarded result instead of mutating a dead component.
    this._runner.invalidate();
    if (this._tooltipListenersBound) {
      this.template.removeEventListener("mouseover", this._positionTooltip);
      this.template.removeEventListener(
        "mouseover",
        this._handleTooltipMouseOver
      );
      this.template.removeEventListener("focusin", this._positionTooltip);
      this.template.removeEventListener("mouseout", this._clearTooltipFlip);
      this.template.removeEventListener(
        "mouseout",
        this._handleTooltipMouseOut
      );
      this.template.removeEventListener("focusout", this._clearTooltipFlip);
      this.template.removeEventListener(
        "focusout",
        this._handleTooltipFocusOut
      );
      this._tooltipListenersBound = false;
    }
    this._clearAllTooltipDwells();
  }

  renderedCallback() {
    // Content grows as checks resolve, so re-measure clamped value chips on every
    // render to reveal a "..." toggle only on those that overflow two lines.
    this._measureClampedValues();
    if (this._tooltipListenersBound) {
      return;
    }
    this._tooltipListenersBound = true;
    // Tooltips open downward by default (pure CSS). On hover/focus we measure the
    // anchor against the viewport and add --flip-up when there is not enough room
    // below, so a tooltip near the bottom of the screen opens upward instead of
    // being clipped. Delegated on the template root — mouseover and focusin both
    // bubble, so one listener pair covers every rule row and summary pill.
    this.template.addEventListener("mouseover", this._positionTooltip);
    this.template.addEventListener("mouseover", this._handleTooltipMouseOver);
    this.template.addEventListener("focusin", this._positionTooltip);
    this.template.addEventListener("mouseout", this._clearTooltipFlip);
    this.template.addEventListener("mouseout", this._handleTooltipMouseOut);
    this.template.addEventListener("focusout", this._clearTooltipFlip);
    this.template.addEventListener("focusout", this._handleTooltipFocusOut);
  }

  // Removes the flip-up modifier once the pointer/focus leaves the anchor entirely
  // (ignoring moves between the anchor's own children), so the next open recomputes
  // direction from the default downward position instead of a stale flipped state.
  _clearTooltipFlip = (event) => {
    const anchor =
      event.target && event.target.closest
        ? event.target.closest(".rhc-tooltip-anchor")
        : null;
    if (!anchor) {
      return;
    }
    const movingTo = event.relatedTarget;
    if (movingTo && anchor.contains(movingTo)) {
      return;
    }
    anchor.classList.remove("rhc-tooltip-anchor--flip-up");
  };

  // Decide open direction for the hovered/focused tooltip anchor. Flips upward only
  // when the space below the anchor is tight AND there is more room above, so the
  // default (downward, matching the rule rows) is preserved everywhere it fits.
  _positionTooltip = (event) => {
    const target = event.target;
    const anchor =
      target && target.closest ? target.closest(".rhc-tooltip-anchor") : null;
    if (!anchor) {
      return;
    }
    const rect = anchor.getBoundingClientRect();
    const viewportHeight =
      window.innerHeight || document.documentElement.clientHeight || 0;
    const spaceBelow = viewportHeight - rect.bottom;
    const spaceAbove = rect.top;
    // Roomy enough for the multi-line summary/rule bubbles; below this we flip.
    const ESTIMATED_TOOLTIP_HEIGHT = 180;
    const flipUp =
      spaceBelow < ESTIMATED_TOOLTIP_HEIGHT && spaceAbove > spaceBelow;
    anchor.classList.toggle("rhc-tooltip-anchor--flip-up", flipUp);
  };

  _findTooltipAnchor(event) {
    const target = event.target;
    return target && target.closest
      ? target.closest(".rhc-tooltip-anchor")
      : null;
  }

  _isTooltipAnchorExit(event, anchor) {
    const movingTo = event.relatedTarget;
    return !(movingTo && anchor.contains(movingTo));
  }

  _tooltipHoverDwellMs() {
    if (
      typeof window !== "undefined" &&
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      return 0;
    }
    return TOOLTIP_HOVER_DWELL_MS;
  }

  _clearTooltipDwell(anchor) {
    const timer = this._tooltipDwellTimers.get(anchor);
    if (timer != null) {
      clearTimeout(timer);
      this._tooltipDwellTimers.delete(anchor);
    }
    this._pendingTooltipAnchors.delete(anchor);
    anchor.classList.remove("rhc-tooltip-anchor--dwell");
  }

  _clearAllTooltipDwells() {
    for (const anchor of this._pendingTooltipAnchors) {
      this._clearTooltipDwell(anchor);
    }
    this._pendingTooltipAnchors.clear();
  }

  _scheduleTooltipDwell(anchor, delayMs) {
    this._clearTooltipDwell(anchor);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    const timer = setTimeout(() => {
      this._tooltipDwellTimers.delete(anchor);
      this._pendingTooltipAnchors.delete(anchor);
      anchor.classList.add("rhc-tooltip-anchor--dwell");
    }, delayMs);
    this._tooltipDwellTimers.set(anchor, timer);
    this._pendingTooltipAnchors.add(anchor);
  }

  _handleTooltipMouseOver = (event) => {
    const anchor = this._findTooltipAnchor(event);
    if (!anchor) {
      return;
    }
    const from = event.relatedTarget;
    if (from && anchor.contains(from)) {
      return;
    }
    if (this._tooltipDwellTimers.has(anchor)) {
      return;
    }
    this._scheduleTooltipDwell(anchor, this._tooltipHoverDwellMs());
  };

  _handleTooltipMouseOut = (event) => {
    const anchor = this._findTooltipAnchor(event);
    if (!anchor || !this._isTooltipAnchorExit(event, anchor)) {
      return;
    }
    this._clearTooltipDwell(anchor);
  };

  _handleTooltipFocusOut = (event) => {
    const anchor = this._findTooltipAnchor(event);
    if (!anchor || !this._isTooltipAnchorExit(event, anchor)) {
      return;
    }
    this._clearTooltipDwell(anchor);
  };

  async _loadDefinitions() {
    const loadToken = ++this._loadToken;
    const requestedCheckSetName = this.checkSetName;
    const requestedRecordId = this.recordId;
    if (this._initialLoadTimer) {
      clearTimeout(this._initialLoadTimer);
      this._initialLoadTimer = null;
    }
    // Invalidate any run still in flight from a previously-viewed record. This
    // method is the entry point for both the first load AND the in-place record
    // swap (console navigation / dynamic record pages), so without this reset a
    // stale evaluateCheck result from record A could drain into record B's rows
    // (the run token guards stale results, and B reuses A's developerName keys),
    // and a leftover in-progress run would suppress B's Automatic run entirely.
    this._runner.invalidate();
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
    this.completedCheckCount = 0;
    this.checks = [];
    // Per-row expand state belongs to the previous record's rows; clear it so a
    // new record starts from the placement default rather than inheriting stale
    // carets keyed by reused developerNames.
    this._expandedNames = {};

    this.isLoading = true;
    this.componentError = null;
    this.componentErrorCode = null;

    if (!this.checkSetName || !this.checkSetName.trim()) {
      await this._applyBlankCheckSetSetupError(loadToken, requestedRecordId);
      return;
    }

    const runId = this._runner.beginRunId();

    try {
      const response = await getCheckDefinitions({
        configName: requestedCheckSetName,
        recordId: requestedRecordId,
        runId
      });

      if (loadToken !== this._loadToken || !this._connected) return;
      if (!response || !Array.isArray(response.checks)) {
        throw new Error(
          "The server returned an invalid health-check definition response."
        );
      }

      const seenNames = new Set();
      for (const def of response.checks) {
        if (!def || !def.developerName) {
          throw new Error(
            "A health-check definition is missing its developer name."
          );
        }
        if (seenNames.has(def.developerName)) {
          throw new Error(
            `Duplicate health-check developer name: ${def.developerName}.`
          );
        }
        seenNames.add(def.developerName);
      }

      this.displayTitle = response.displayTitle;
      this.displayDescription = response.displayDescription;
      this.triggerMode =
        response.triggerMode === "Automatic" ? "Automatic" : "Manual";
      this.revealMode =
        response.revealMode === "OneAtATime" ? "OneAtATime" : "AllAtOnce";
      this.successDisplayMode = response.successDisplayMode;
      this.skippedDisplayMode = response.skippedDisplayMode;
      // Normalize comparison mode; unknown values fall back to OnDemand.
      this.comparisonDisplay = ["OnDemand", "FailuresOnly", "AllRows"].includes(
        response.comparisonDisplay
      )
        ? response.comparisonDisplay
        : "OnDemand";
      this.stopOnFirstError = response.stopOnFirstError;
      this.showDiagnostics = response.showDiagnostics === true;
      this.totalCheckCount = response.checks.length;
      this.totalAvailableCheckCount =
        typeof response.totalAvailableCheckCount === "number"
          ? response.totalAvailableCheckCount
          : response.checks.length;
      this.inactiveRuleCount =
        typeof response.inactiveRuleCount === "number"
          ? response.inactiveRuleCount
          : 0;
      this.checksOmittedByLimit = response.checksOmittedByLimit || false;

      // Build per-check rows — all start PENDING
      this.checks = response.checks.map((def) => ({
        developerName: def.developerName,
        label: def.label,
        description: def.description,
        priority: def.priority,
        dependsOnCheckDeveloperName: def.dependsOnCheckDeveloperName || null,
        uiState: "PENDING",
        result: null
      }));

      this.isLoading = false;
      this.componentError = null;
      this.componentErrorCode = null;

      if (this.triggerMode === "Automatic") {
        this._runner.run(true);
      }
    } catch (err) {
      if (loadToken !== this._loadToken || !this._connected) return;
      this.isLoading = false;
      const parsed = parseAuraError(err);
      this.componentError = parsed.message;
      this.componentErrorCode = parsed.reasonCode;
    }
  }

  get hasComponentError() {
    return !!this.componentError;
  }

  /**
   * Blank checkSetName is ambiguous until we ask Apex what Check Sets exist for
   * this object. Active sets → SETUP_REQUIRED (pick one). Inactive only →
   * INACTIVE_CHECK_SETS_ONLY. None at all → NO_ACTIVE_CHECK_SETS. Probe failures
   * and missing recordId fall back to SETUP_REQUIRED so we never falsely claim
   * the org has no Check Sets.
   */
  async _applyBlankCheckSetSetupError(loadToken, requestedRecordId) {
    let availability = { hasActive: true, hasInactive: false };
    if (requestedRecordId) {
      try {
        const response = await getCheckSetAvailabilityForRecord({
          recordId: requestedRecordId
        });
        availability = {
          hasActive: response?.hasActive === true,
          hasInactive: response?.hasInactive === true
        };
      } catch {
        // Probe failed (e.g. transient Apex error) — fall back to SETUP_REQUIRED
        // rather than falsely claiming the org has no Check Sets for this object.
        availability = { hasActive: true, hasInactive: false };
      }
    }
    if (loadToken !== this._loadToken || !this._connected) {
      return;
    }
    this.isLoading = false;
    if (availability.hasActive) {
      this.componentError =
        "Record Health Check is not ready on this page yet.";
      this.componentErrorCode = "SETUP_REQUIRED";
      return;
    }
    if (availability.hasInactive) {
      this.componentError =
        "Record Health Check is not ready on this page yet.";
      this.componentErrorCode = "INACTIVE_CHECK_SETS_ONLY";
      return;
    }
    this.componentError = "Record Health Check is not ready on this page yet.";
    this.componentErrorCode = "NO_ACTIVE_CHECK_SETS";
  }

  get isSetupError() {
    return SETUP_ERROR_CODES.has(this.componentErrorCode);
  }

  get errorBannerIcon() {
    return this.isSetupError ? "utility:setup" : "utility:error";
  }

  get errorBannerIconAltText() {
    return this.isSetupError ? "Setup required" : "Error";
  }

  get errorBannerTitle() {
    return this.isSetupError
      ? "Health Check Needs Setup"
      : "Health Check Unavailable";
  }

  get setupErrorHint() {
    switch (this.componentErrorCode) {
      case "CONFIG_NOT_FOUND":
      case "SETUP_REQUIRED":
        return "Ask your Salesforce admin to choose a Check Set for this page.";
      case "INACTIVE_CHECK_SETS_ONLY":
        return "Ask your Salesforce admin to activate a Check Set for this object.";
      case "NO_ACTIVE_CHECK_SETS":
        return "Ask your Salesforce admin to set up a Check Set for this object.";
      case "CONFIG_INACTIVE":
        return "Ask your Salesforce admin to activate this Check Set.";
      case "OBJECT_MISMATCH":
        return "Ask your Salesforce admin to choose a Check Set for this object.";
      case "NO_ACTIVE_CHECKS":
        return "Ask your Salesforce admin to add an active Rule.";
      case "NO_RECORD_CONTEXT":
        return "Ask your Salesforce admin to place this on a record page.";
      case "INVALID_CONFIG":
        return "Ask your Salesforce admin to review this Check Set in Setup.";
      default:
        return "";
    }
  }

  get showRunButton() {
    // Stays rendered while a run is in progress (disabled + spinner; label stays
    // Run or Rerun per hasCompletedRunOnce — see actionButtonLabel).
    return this.triggerMode === "Manual" && !this.runComplete;
  }

  get showRerunButton() {
    return this.runComplete;
  }

  get isAllAtOnce() {
    return this.revealMode === "AllAtOnce";
  }

  get isOneAtATime() {
    return this.revealMode === "OneAtATime";
  }

  get visibleChecks() {
    let filtered;
    if (this.isAllAtOnce) {
      filtered = this.checks.filter((c) => {
        if (this._isHiddenSkipped(c)) {
          return false;
        }
        if (this._isHiddenSuccess(c)) {
          return false;
        }
        return true;
      });
    } else {
      // OneAtATime: reveal every resolved (non-hidden) row as soon as it lands
      const nextPending = this.checks.find((c) => c.uiState !== "RESOLVED");
      const revealName = nextPending ? nextPending.developerName : null;
      filtered = this.checks.filter((c) => {
        if (c.uiState === "RESOLVED") {
          if (this._isHiddenSkipped(c)) {
            return false;
          }
          if (this._isHiddenSuccess(c)) {
            return false;
          }
          return true;
        }
        return (
          (c.uiState === "LOADING" ||
            (c.uiState === "PENDING" && this._runner.isRunning)) &&
          c.developerName === revealName
        );
      });
    }
    // Annotate each check with computed display properties for the template
    return filtered.map((c) =>
      annotateCheck(
        c,
        this.showDiagnostics,
        this.comparisonDisplay,
        this._isRowExpanded(c.developerName)
      )
    );
  }

  // Whether a row's comparison detail is currently expanded. Carets default to
  // collapsed; a user toggle records an explicit state in _expandedNames.
  _isRowExpanded(developerName) {
    if (
      Object.prototype.hasOwnProperty.call(this._expandedNames, developerName)
    ) {
      return this._expandedNames[developerName];
    }
    return false;
  }

  handleToggleDetail(event) {
    const developerName = event.currentTarget.dataset.check;
    if (!developerName) {
      return;
    }
    const next = !this._isRowExpanded(developerName);
    // Reassign (not mutate) so the tracked field change re-runs visibleChecks.
    this._expandedNames = {
      ...this._expandedNames,
      [developerName]: next
    };
  }

  // Value chips clamp to two lines by default (see .rhc-cmp__val--clampable). A
  // long formula or list therefore needs a quiet "..." affordance; we only
  // want it on chips that actually overflow, which is only knowable after
  // layout. Scan the rendered chips and reveal the sibling toggle on the ones
  // whose full content is taller than the clamped box. Skip already-expanded
  // chips so a re-render (another check resolving) does not hide their toggle.
  _measureClampedValues() {
    const chips = this.template.querySelectorAll("[data-clampval]");
    for (const chip of chips) {
      const pair = chip.closest(".rhc-cmp__pair");
      const toggle = pair && pair.querySelector("[data-clamptoggle]");
      if (!toggle) {
        continue;
      }
      if (chip.classList.contains("rhc-cmp__val--expanded")) {
        continue;
      }
      const overflowing = chip.scrollHeight - chip.clientHeight > 1;
      toggle.hidden = !overflowing;
    }
  }

  // Expand or re-clamp a single value chip in place. Imperative because the
  // clamp/expand state is purely presentational and per-chip — threading it
  // through the annotateCheck pipeline would need a stable key per chip for no
  // functional gain.
  handleToggleValue(event) {
    const toggle = event.currentTarget;
    const pair = toggle.closest(".rhc-cmp__pair");
    const chip = pair && pair.querySelector("[data-clampval]");
    if (!chip) {
      return;
    }
    const expanded = chip.classList.toggle("rhc-cmp__val--expanded");
    toggle.textContent = expanded ? "less" : "...";
    toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    toggle.setAttribute("aria-label", expanded ? "Show less" : "Show more");
  }

  get checkCountLabel() {
    const n = this.totalCheckCount;
    return `${n} ${n === 1 ? "Check" : "Checks"}`;
  }

  // Count phrase for the pre-run hint: pluralized, and when the set exceeds the
  // 25-rule cap it makes clear only the first 25 will run (matching the
  // limit badge).
  get checkCountPhrase() {
    if (this.checksOmittedByLimit) {
      return `the first 25 of ${this.totalAvailableCheckCount} checks`;
    }
    const n = this.totalCheckCount;
    return `${n} ${n === 1 ? "check" : "checks"}`;
  }

  get limitNoticeLabel() {
    return `First 25 of ${this.totalAvailableCheckCount} shown`;
  }

  get limitNoticeTitle() {
    return `Showing the first 25 of ${this.totalAvailableCheckCount} active rules.`;
  }

  get showActionButton() {
    return this.showRunButton || this.showRerunButton;
  }

  get showPreRunHint() {
    // Shown before the first Manual run in BOTH reveal modes for a consistent
    // call to action: OneAtATime shows the hint alone (no rows yet),
    // AllAtOnce shows it above the already-listed rows.
    return (
      this.triggerMode === "Manual" &&
      !this.isLoading &&
      !this.runComplete &&
      !this._runner.isRunning &&
      this.checks.length > 0
    );
  }

  get preRunHintText() {
    return `Click Run to evaluate ${this.checkCountPhrase}.`;
  }

  get showInactiveRulesNotice() {
    return (
      !this.isLoading && !this.hasComponentError && this.inactiveRuleCount > 0
    );
  }

  get inactiveRulesNotice() {
    const n = this.inactiveRuleCount;
    return `${n} inactive ${n === 1 ? "rule" : "rules"} omitted.`;
  }

  get showSummaryStats() {
    return this.runComplete && this.summaryStats.length > 0;
  }

  /**
   * When Passed/Skipped display is Hide and every resolved row is filtered out,
   * the list looks empty even though the run succeeded. Surface a short status
   * so the card does not appear broken beside the summary pills.
   */
  get showHiddenResultsNotice() {
    return (
      this.runComplete &&
      !this.isLoading &&
      this.checks.length > 0 &&
      this.visibleChecks.length === 0
    );
  }

  get hiddenResultsNotice() {
    const hiddenPasses = this.checks.some((c) => this._isHiddenSuccess(c));
    const hiddenSkips = this.checks.some((c) => this._isHiddenSkipped(c));
    if (hiddenPasses && hiddenSkips) {
      return "All checks passed or were skipped. Details are hidden.";
    }
    if (hiddenPasses) {
      return "All checks passed. Details are hidden.";
    }
    if (hiddenSkips) {
      return "All checks were skipped. Details are hidden.";
    }
    return "Details are hidden.";
  }

  get actionTitle() {
    // Check count lives in the hover tooltip; while a run is in flight the title
    // carries the busy state because the visible label stays "Run" / "Rerun".
    if (this._runner.isRunning) {
      return this.hasCompletedRunOnce
        ? `Re-running ${this.checkCountLabel}`
        : `Running ${this.checkCountLabel}`;
    }
    return this.hasCompletedRunOnce
      ? `Re-run ${this.checkCountLabel}`
      : `Run ${this.checkCountLabel}`;
  }

  get actionButtonLabel() {
    return this.hasCompletedRunOnce ? "Rerun" : "Run";
  }

  get actionButtonAriaLabel() {
    if (this._runner.isRunning) {
      return this.actionTitle;
    }
    return this.actionButtonLabel;
  }

  get actionButtonBusy() {
    return this._runner.isRunning;
  }

  // While a run is in flight the button stays put but is disabled, so it reads
  // as busy instead of vanishing.
  get actionButtonDisabled() {
    return this._runner.isRunning;
  }

  handleAction() {
    // A Rerun starts a fresh evaluation, so per-row carets the user opened on the
    // previous run should collapse back to the placement default rather than
    // linger open over rows whose values are being recomputed.
    this._expandedNames = {};
    this._runner.run(false);
  }

  get summaryStats() {
    const tooltipKeys = this._summaryTooltipKeys();
    const tooltipSignature = tooltipKeys.join("|");
    if (
      this._summaryStatsSource !== this.checks ||
      this._summaryStatsTooltipSignature !== tooltipSignature
    ) {
      this._summaryStatsSource = this.checks;
      this._summaryStatsTooltipSignature = tooltipSignature;
      this._summaryStatsCache = buildSummaryStats(
        this.checks,
        new Set(tooltipKeys)
      );
    }
    return this._summaryStatsCache;
  }

  get showLimitNotice() {
    return this.checksOmittedByLimit;
  }

  _isSkipped(check) {
    return (
      check &&
      check.uiState === "RESOLVED" &&
      check.result &&
      check.result.status === "SKIPPED"
    );
  }

  // Diagnostics is an authorized troubleshooting overlay: when active it auto-
  // expands every check, overriding count-only display, so an admin can see the
  // rows a count-only summary hides. showDiagnostics is already gated server-side
  // (Set flag AND the diagnostics permission), so normal users are unaffected.
  // See V2-RELEASE-PLAN §2.11.
  _isHiddenSkipped(check) {
    if (this.showDiagnostics) return false;
    return this._isSkipped(check) && this.skippedDisplayMode === "Hide";
  }

  _isSuccess(check) {
    return (
      check &&
      check.uiState === "RESOLVED" &&
      check.result &&
      check.result.status === "PASS"
    );
  }

  _isHiddenSuccess(check) {
    if (this.showDiagnostics) return false; // auto-expand under diagnostics (§2.11)
    return this._isSuccess(check) && this.successDisplayMode === "Hide";
  }

  _summaryTooltipKeys() {
    const keys = [];
    if (this.checks.some((c) => this._isHiddenSuccess(c))) {
      keys.push("pass");
    }
    if (this.checks.some((c) => this._isHiddenSkipped(c))) {
      keys.push("skip");
    }
    return keys;
  }

  get showDiagnosticsConsoleHint() {
    return this.showDiagnostics && this.runComplete;
  }

  _buildRunDiagnostics() {
    return {
      runId: this._runner.runId,
      userId: USER_ID,
      recordId: this.recordId,
      configName: this.checkSetName,
      generatedAt: new Date().toISOString(),
      checks: this.checks.map((c) => {
        const r = c.result || {};
        return {
          check: c.developerName,
          label: c.label || c.developerName,
          status: r.status || c.uiState,
          severity: r.severity || null,
          reasonCode: r.reasonCode || null,
          actualValue: r.actualValue ?? null,
          expectedValue: r.expectedValue ?? null,
          actualValueDetail: r.actualValueDetail ?? null,
          expectedValueDetail: r.expectedValueDetail ?? null,
          durationMs: r.durationMs != null ? r.durationMs : null,
          evaluatorType: r.evaluatorType ?? null
        };
      })
    };
  }

  _formatRunSummary(checks) {
    const counts = {
      PASS: 0,
      FAIL: 0,
      SKIPPED: 0,
      ERROR: 0,
      UNABLE_TO_EVALUATE: 0
    };
    let totalMs = 0;
    for (const row of checks) {
      const status = row.status;
      if (Object.prototype.hasOwnProperty.call(counts, status)) {
        counts[status]++;
      }
      if (row.durationMs != null) {
        totalMs += row.durationMs;
      }
    }
    const parts = [];
    if (counts.PASS) {
      parts.push(`${counts.PASS} Passed`);
    }
    if (counts.FAIL) {
      parts.push(`${counts.FAIL} Failed`);
    }
    if (counts.SKIPPED) {
      parts.push(`${counts.SKIPPED} Skipped`);
    }
    if (counts.UNABLE_TO_EVALUATE) {
      parts.push(`${counts.UNABLE_TO_EVALUATE} Unable`);
    }
    if (counts.ERROR) {
      parts.push(`${counts.ERROR} Error`);
    }
    const outcome =
      parts.length > 0 ? parts.join(", ") : `${checks.length} checks`;
    const timing = totalMs > 0 ? ` · ${totalMs}ms total` : "";
    return `${outcome}${timing}`;
  }

  _logRunDiagnostics() {
    const diag = this._buildRunDiagnostics();
    const configLabel = diag.configName || "(unset configName)";
    console.group(
      `[RHC] Health Check run ${diag.runId} | ${configLabel} | record ${diag.recordId}`
    );
    console.log(this._formatRunSummary(diag.checks));
    console.log({
      runId: diag.runId,
      checkSet: diag.configName,
      recordId: diag.recordId,
      userId: diag.userId,
      generatedAt: diag.generatedAt
    });
    console.table(diag.checks, RHC_DIAG_TABLE_COLUMNS);
    this._logProvenanceDiagnostics(diag.checks);
    console.groupEnd();
  }

  _logProvenanceDiagnostics(checks) {
    const withDetail = checks.filter(
      (c) => c.actualValueDetail != null || c.expectedValueDetail != null
    );
    if (withDetail.length === 0) {
      return;
    }
    const noun = withDetail.length === 1 ? "check" : "checks";
    console.group(`[RHC] Source detail (${withDetail.length} ${noun})`);
    for (const c of withDetail) {
      const heading = `${c.label} (${c.check}) · ${c.status}`;
      console.group(heading);
      if (c.actualValueDetail != null) {
        console.log("Found", c.actualValueDetail);
      }
      if (c.expectedValueDetail != null) {
        console.log("Expected", c.expectedValueDetail);
      }
      console.groupEnd();
    }
    console.groupEnd();
  }
}
