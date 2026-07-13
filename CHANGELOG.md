# Changelog

This project follows [Semantic Versioning](https://semver.org/). Notable changes are documented here starting with the first public release.

## [Unreleased]

### Breaking changes

- Internal wire property `debugMode` renamed to `showDiagnostics` (matches `ShowDiagnostics__c`).
- `RecordHealthCheckApexEvaluatorDispatcher` renamed to `RecordHealthCheckApexEvaluator`.
- `RecordHealthCheckDualSoqlEvaluator` renamed to `RecordHealthCheckCompareQueriesEvaluator`.
- Plugin API `RecordHealthCheckProvenance` / `actualProvenance` / `expectedProvenance` renamed to `RecordHealthCheckValueSource` / `actualValueSource` / `expectedValueSource`.
- `RecordHealthCheckComparatorEngine` renamed to `RecordHealthCheckComparisonEngine` (comparison helper methods renamed accordingly).

## [1.2.0]: 2026-07-09

### App Builder & setup

- Admins pick a Check Set from a dropdown in Lightning App Builder instead of typing a developer name. The list shows active Check Sets for that page's object, and auto-selects when there is only one.
- Removed support for the old `configName` and `comparisonDisclosure` component properties. After upgrade, open existing record pages in App Builder, re-add or reconfigure the component with the new **Check Set** picker, and save. There is no automatic migration for the old properties.
- If the LWC has no Check Set selected, Apex reports whether any Check Sets exist for that object so the banner can say choose one, activate one, or create one.
- Setup banners speak to end users first (**Health Check Needs Setup** / not ready yet), with a short note to ask a Salesforce admin. They no longer read like App Builder how-to steps.

### What you see on the card

- Unexpected system failures show as red **System Error**, separate from gray **Unable to Check**.
- If Panel Heading is blank, the card uses the Check Set label (or developer name) so the title is never empty.
- Inactive Rules are noted quietly (`N inactive rules omitted`).
- When more than 25 Rules are active, the badge shows **First 25 of N**.
- Skip messages name the required check that blocked them.
- When passed or skipped rows are hidden on purpose, the card says `All checks passed. Details are hidden.` instead of looking empty.
- Card wording is shorter: no em dashes, no extra "by this Check Set" clauses, and no App Builder how-to text on the end-user card.
- Long value chips still clamp to two lines; the overflow control is now a quiet **`...`** / **`less`** toggle (screen readers still hear “Show more” / “Show less”).

### Engine & reliability

- Missing or inactive Rules report as `RULE_NOT_FOUND` / `RULE_INACTIVE` instead of the generic "config not found" code.
- Blank-setup cases use clear codes: `SETUP_REQUIRED`, `INACTIVE_CHECK_SETS_ONLY`, `NO_ACTIVE_CHECK_SETS`.
- Invalid Check Set field messages use the Setup labels admins see; object mismatch says the record's object, not "record type".
- Pure `Date` values format as dates (not datetimes) in orgs where Apex type checks overlap.
- When the same check runs more than once in one transaction, cached results keep Fix-it links and the Formula **Passes when** label.
- Schema describe results are cached for the Apex transaction so busy record pages do less repeated metadata work.

### Permissions & diagnostics

- One permission covers advanced and debug detail: `Record_Health_Check_View_Details`. The older `Record_Health_Check_Debug` permission is removed.
- Found/Expected source notes no longer appear on the card; with debug on, they show in the browser console under **Source detail**.
- Console diagnostics are cleaner: short outcome line, compact run info, and a results table with reason code and evaluator type.
- Tooltips wait **600ms** of hover before showing, so scanning rows does not flash popovers. Keyboard focus still shows sooner.

### Docs & tests

- LWC Jest suite: **106** tests; Apex local suite: **162** tests (**96%** org-wide coverage on scratch).
- Updated security notes, package manifest, docs, examples, help text, troubleshooting, and the design spec for the Check Set picker, setup messages, console-only source notes, the single details permission, Schema describe caching, and the upgrade steps for old LWC properties.
- Troubleshooting guide clarifies that `Record_Health_Check_View_Details` alone still unlocks Formula **Passes when**; full card/console troubleshooting still needs **Show Troubleshooting Details**.
- Client-side circular-dependency and skip messages now match Apex wording.
- Setup availability (`getCheckSetAvailabilityForRecord`) is no longer Aura-cacheable, so activating a Check Set refreshes the blank-setup banner on the next load.

## [1.1.0]: 2026-07-04

- Humanized **Found** / **Expected** values: numbers gain thousands separators (`70000.0` → `"70,000"`, a trailing `.0` dropped), Booleans read `"Yes"` / `"No"`, dates and datetimes render in the viewer's locale and time zone, and semicolon-delimited multi-select picklists render comma-separated. Applied at the shared `RecordHealthCheckComparisonEngine.formatValue` choke point, so typed values and metadata operand strings on both sides humanize identically; ordinary text, IDs, and codes are left unchanged.
- Long value chips now clamp to two lines with a quiet **Show more** / **Show less** toggle that appears only when the value overflows, so a long formula or list no longer dominates the card.
- Added guided remediation: a **FAIL** row now renders an optional read-only "Fix it" deep link (`ActionLabel__c` / `ActionUrl__c`) and `FixMessage__c` guidance. The URL supports one or more `{!FieldName}` merge tokens (including relationship paths), resolved against the record and URL-encoded, then sanitized (same-org relative or `https://` only; unsafe or over-2000-char URLs are dropped). Widened `ActionUrl__c` to Long Text Area (2000).
- Added readable multi-row comparison: an `Every record must pass` Query check now summarizes its **Found** line as a count (`1 of 5 Contacts did not pass`) instead of dumping every row value, with optional `DisplayFoundText__c` / `DisplayExpectedText__c` wording (supports `{!failCount}` / `{!totalCount}` tokens).
- Added a divider above Found/Expected on busy inline rows, and Rerun now collapses any comparison caret the user had opened.
- Wired the `Example - Every Contact Has Email` rule with a fix link and friendly summary as a demo.
- Added comparison display controls for Found/Expected values, including Check Set `FoundExpectedDisplay__c` and the component-level `comparisonDisclosure` initial caret setting.
- Added gated comparison provenance details via `RecordHealthCheckValueSource` and the `Record_Health_Check_View_Details` custom permission.
- Added metadata-only category and remediation fields for future grouped display and guided fixes.
- Added `Record_Health_Check_Configure` as a reserved custom permission for future configuration tooling.
- Improved provenance notes: row counts pluralize consistently (`1 row` / `3 rows`) and source notes now attach directly to the matching Found/Expected value.
- Simplified `Record_Health_Check_Rule__mdt` / `Set__mdt` labels, descriptions, and layouts for friendlier first-time admin setup (no engine changes).
- Reworked the Check Set display defaults for a friendlier first run: renamed `CardRevealMode__c` from **Result Display Style** to **How checks appear** (clearer description and inline help that explain the on-load behavior), and changed its default to `OneAtATime` so checks reveal one at a time as the run advances. Passed and skipped checks now default to `Show` (`PassedChecksDisplay__c` / `SkippedChecksDisplay__c`) so viewers see what passed and what was skipped; `Hide` remains the power-user opt-in for a summarize-only, failures-focused view. Example Check Sets updated to match, except `Account_Data_Quality`, kept as the intentional failures-only demo.
- Updated docs, examples, and plugin guidance for comparison display, provenance, and the then-current 98-test LWC suite.

## [1.0.0]: 2026-06-23

Initial release: metadata-driven record health checks, Lightning record-page component, Apex evaluation engine, 10 sample Check Sets and 88 Rules, and documentation under `docs/`.
