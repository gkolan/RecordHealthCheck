/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** View-formatting helpers: map check results into template-ready flags and classes. */
const OUTCOME_STYLES = {
  pass: { label: "Pass", modifier: "pass", message: false },
  error: { label: "Failed", modifier: "error", message: true },
  warning: { label: "Warning", modifier: "warning", message: true },
  info: { label: "Info", modifier: "info", message: true },
  skipped: { label: "Skipped", modifier: "skipped", message: false },
  unable: { label: "Unable to Check", modifier: "unable", message: true }
};

// Summary pills reuse the same status-icon CSS modifiers as rows.
const SUMMARY_ROWS = [
  { key: "pass", suffix: "pass", label: (n) => `${n} Passed` },
  { key: "error", suffix: "error", label: (n) => `${n} Failed` },
  {
    key: "warn",
    suffix: "warning",
    label: (n) => `${n} ${n === 1 ? "Warning" : "Warnings"}`
  },
  { key: "info", suffix: "info", label: (n) => `${n} Info` },
  { key: "skip", suffix: "skipped", label: (n) => `${n} Skipped` },
  { key: "unable", suffix: "unable", label: (n) => `${n} Unable` }
];

/** Split admin-authored messages on newlines for stacked display in the template. */
export function splitMessageLines(message) {
  if (message == null) return [];
  const lines = String(message)
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n");
  while (lines.length && lines[0].trim() === "") lines.shift();
  while (lines.length && lines[lines.length - 1].trim() === "") lines.pop();
  return lines.map((text, idx) => {
    const isBlank = text.trim() === "";
    return {
      key: idx,
      text,
      isBlank,
      lineClass: isBlank
        ? "rhc-row__message-line rhc-row__message-line--blank"
        : "rhc-row__message-line"
    };
  });
}

/** Join message lines for screen-reader aria-labels. */
function joinForSpeech(lines) {
  const parts = lines.map((line) => line.trim()).filter(Boolean);
  return parts.reduce((acc, part, idx) => {
    if (idx === 0) return part;
    const sep = /[.!?:;]$/.test(acc) ? " " : ". ";
    return acc + sep + part;
  }, "");
}

/**
 * Classifies a resolved check into one of the OUTCOME_STYLES keys. Returns null
 * for rows that are still pending/loading or have no result yet.
 */
function classifyOutcome(status, severity) {
  switch (status) {
    case "PASS":
      return "pass";
    case "FAIL":
      if (severity === "Warning") return "warning";
      if (severity === "Info") return "info";
      return "error";
    case "SKIPPED":
      return "skipped";
    case "UNABLE_TO_EVALUATE":
    case "ERROR":
      return "unable";
    default:
      return null;
  }
}

const COMPARISON_MODES = new Set(["OnDemand", "FailuresOnly", "AllRows"]);
function normalizeComparisonMode(mode) {
  return COMPARISON_MODES.has(mode) ? mode : "OnDemand";
}

/** Add template-ready display flags for one check row. */
export function annotateCheck(c, debugMode, comparisonMode, isExpanded) {
  const uiState = c.uiState;
  const result = c.result || {};
  const status = result.status || "";
  const severity = result.severity || "";

  const isPending = uiState === "PENDING";
  const isLoading = uiState === "LOADING";
  const isResolved = uiState === "RESOLVED";

  const outcome = isResolved ? classifyOutcome(status, severity) : null;
  const style = outcome ? OUTCOME_STYLES[outcome] : null;

  const isPass = outcome === "pass";

  const statusLabel = style ? style.label : "";
  let statusIconClass = "rhc-status-icon ";
  let rowClass = "rhc-row";
  let messageClass = "rhc-row__message";
  let rowAccentClass = "";

  if (style) {
    statusIconClass += `rhc-status-icon--${style.modifier}`;
    rowClass += ` rhc-row--${style.modifier}`;
    rowAccentClass = `rhc-row__accent rhc-row__accent--${style.modifier}`;
    if (style.message) {
      messageClass += ` rhc-row__message--${style.modifier}`;
    }
  } else if (isLoading) {
    rowClass += " rhc-row--loading";
  } else if (isPending) {
    rowClass += " rhc-row--pending";
  }

  if (c.description) {
    rowClass += " rhc-tooltip-anchor rhc-tooltip-anchor--row";
  }

  const tabIndex = c.description ? 0 : -1;

  const showMessage = isResolved && !isPass && !!(c.result && c.result.message);

  const messageLines = showMessage ? splitMessageLines(c.result.message) : [];

  const mode = normalizeComparisonMode(comparisonMode);
  const rowExpanded = isExpanded === true;
  const actualValue =
    isResolved && result.actualValue != null ? result.actualValue : null;
  const expectedValue =
    isResolved && result.expectedValue != null ? result.expectedValue : null;
  const hasValues = actualValue != null || expectedValue != null;

  // Provenance is permission-gated on the server; null *Detail means not entitled.
  const actualValueDetail =
    isResolved && result.actualValueDetail != null
      ? result.actualValueDetail
      : null;
  const expectedValueDetail =
    isResolved && result.expectedValueDetail != null
      ? result.expectedValueDetail
      : null;
  const hasProvenance =
    actualValueDetail != null || expectedValueDetail != null;

  const showInlineComparison =
    isResolved && hasValues && (!isPass || mode === "AllRows");

  let valuesBehindCaret = false;
  let provenanceBehindCaret = false;
  if (isResolved && !(mode === "FailuresOnly" && isPass)) {
    valuesBehindCaret = hasValues && !showInlineComparison;
    provenanceBehindCaret = hasProvenance;
  }
  const showCaret = valuesBehindCaret || provenanceBehindCaret;
  const detailExpanded = showCaret && rowExpanded;

  // Inline chips
  const showActual = showInlineComparison && actualValue != null;
  const showExpected = showInlineComparison && expectedValue != null;

  // Expanded region: values only when they were not already inline, provenance
  // whenever present and entitled.
  const showExpandedActual =
    detailExpanded && valuesBehindCaret && actualValue != null;
  const showExpandedExpected =
    detailExpanded && valuesBehindCaret && expectedValue != null;
  const showActualDetail = detailExpanded && actualValueDetail != null;
  const showExpectedDetail = detailExpanded && expectedValueDetail != null;

  const caretExpanded = detailExpanded;
  const caretLabel = detailExpanded
    ? "Hide comparison detail"
    : "Show comparison detail";
  const caretClass = detailExpanded ? "rhc-caret rhc-caret--open" : "rhc-caret";

  const accessibleMessage = showMessage
    ? joinForSpeech(
        messageLines.filter((line) => !line.isBlank).map((line) => line.text)
      )
    : null;

  // Fold message and visible comparison values into aria-label (li text is overridden).
  const comparisonAudible =
    showInlineComparison || (detailExpanded && valuesBehindCaret);

  const accessibleLabel = [
    c.label,
    isLoading ? "Evaluating" : isPending ? "Pending" : statusLabel,
    c.description,
    accessibleMessage,
    comparisonAudible && actualValue != null ? `Found ${actualValue}` : null,
    comparisonAudible && expectedValue != null
      ? `Expected ${expectedValue}`
      : null,
    showActualDetail ? actualValueDetail : null,
    showExpectedDetail ? expectedValueDetail : null
  ]
    .filter(Boolean)
    .join(". ");

  const adminDetailMessage =
    (isResolved && c.result && c.result.adminDetailMessage) || null;
  const showAdminDetail = debugMode && !!adminDetailMessage;

  const r = c.result || {};
  const debugMeta =
    debugMode && isResolved
      ? [
          r.status,
          r.reasonCode,
          r.durationMs != null ? `${r.durationMs}ms` : null,
          r.evaluatorType
        ]
          .filter(Boolean)
          .join(" · ")
      : "";
  const showDebugMeta = !!debugMeta;
  const showRowAccent = !!rowAccentClass;

  return {
    ...c,
    isPending,
    isLoading,
    isResolved,
    statusLabel,
    statusIconClass,
    rowClass,
    tabIndex,
    showRowAccent,
    rowAccentClass,
    messageClass,
    showMessage,
    messageLines,
    actualValue,
    expectedValue,
    actualValueDetail,
    expectedValueDetail,
    showInlineComparison,
    showActual,
    showExpected,
    showCaret,
    caretExpanded,
    caretLabel,
    caretClass,
    detailExpanded,
    showExpandedActual,
    showExpandedExpected,
    showActualDetail,
    showExpectedDetail,
    adminDetailMessage,
    showAdminDetail,
    debugMeta,
    showDebugMeta,
    accessibleLabel
  };
}

/** Build summary-bar pill rows from resolved check results. */
export function buildSummaryStats(checks, tooltipKeys = new Set()) {
  const buckets = {
    pass: [],
    error: [],
    warn: [],
    info: [],
    skip: [],
    unable: []
  };
  for (const c of checks) {
    if (!c.result) continue;
    const outcome = classifyOutcome(c.result.status, c.result.severity);
    let key;
    if (outcome === "pass") key = "pass";
    else if (outcome === "error") key = "error";
    else if (outcome === "warning") key = "warn";
    else if (outcome === "info") key = "info";
    else if (outcome === "skipped") key = "skip";
    else key = "unable";
    buckets[key].push(c.label);
  }

  return SUMMARY_ROWS.filter((row) => buckets[row.key].length > 0).map(
    (row) => {
      const names = buckets[row.key];
      const label = row.label(names.length);
      const hasTooltip = tooltipKeys.has(row.key);
      const baseClass = `rhc-stat rhc-stat--${row.suffix}`;
      return {
        key: row.key,
        label,
        cssClass: hasTooltip
          ? `${baseClass} rhc-tooltip-anchor rhc-tooltip-anchor--footer rhc-tooltip-anchor--stat`
          : baseClass,
        tooltip: hasTooltip ? `${label}: ${tooltipNames(names)}` : null,
        tabIndex: hasTooltip ? "0" : null,
        iconClass: `rhc-status-icon rhc-status-icon--${row.suffix}`
      };
    }
  );
}

function tooltipNames(names) {
  return names.join(", ");
}
