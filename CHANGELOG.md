# Changelog

This project follows [Semantic Versioning](https://semver.org/). Notable changes are documented here starting with the first public release.

## [1.1.0]: 2026-07-04

- Humanized **Found** / **Expected** values: numbers gain thousands separators (`70000.0` → `"70,000"`, a trailing `.0` dropped), Booleans read `"Yes"` / `"No"`, dates and datetimes render in the viewer's locale and time zone, and semicolon-delimited multi-select picklists render comma-separated. Applied at the shared `RecordHealthCheckComparatorEngine.formatValue` choke point, so typed values and metadata operand strings on both sides humanize identically; ordinary text, IDs, and codes are left unchanged.
- Long value chips now clamp to two lines with a quiet **Show more** / **Show less** toggle that appears only when the value overflows, so a long formula or list no longer dominates the card.
- Added guided remediation: a **FAIL** row now renders an optional read-only "Fix it" deep link (`PrimaryActionLabel__c` / `PrimaryActionUrl__c`) and `FixInstructions__c` guidance. The URL supports one or more `{!FieldName}` merge tokens (including relationship paths), resolved against the record and URL-encoded, then sanitized (same-org relative or `https://` only; unsafe or over-2000-char URLs are dropped). Widened `PrimaryActionUrl__c` to Long Text Area (2000).
- Added readable multi-row comparison: an `Every record must pass` Query check now summarizes its **Found** line as a count (`1 of 5 Contacts did not pass`) instead of dumping every row value, with optional `FoundSummaryOverride__c` / `ExpectedSummaryOverride__c` wording (supports `{!failCount}` / `{!totalCount}` tokens).
- Added a divider above Found/Expected on busy inline rows, and Rerun now collapses any comparison caret the user had opened.
- Wired the `Example - Every Contact Has Email` rule with a fix link and friendly summary as a demo.
- Added comparison display controls for Found/Expected values, including Check Set `ComparisonDisplay__c` and the component-level `comparisonDisclosure` initial caret setting.
- Added gated comparison provenance details via `RecordHealthCheckProvenance` and the `Record_Health_Check_View_Details` custom permission.
- Added metadata-only category and remediation fields for future grouped display and guided fixes.
- Added `Record_Health_Check_Configure` as a reserved custom permission for future configuration tooling.
- Improved provenance notes: row counts pluralize consistently (`1 row` / `3 rows`) and source notes now attach directly to the matching Found/Expected value.
- Simplified `Record_Health_Check_Rule__mdt` / `Set__mdt` labels, descriptions, and layouts for friendlier first-time admin setup (no engine changes).
- Reworked the Check Set display defaults for a friendlier first run: renamed `RowAppearance__c` from **Result Display Style** to **How checks appear** (clearer description and inline help that explain the on-load behavior), and changed its default to `OneAtATime` so checks reveal one at a time as the run advances. Passed and skipped checks now default to `Show` (`PassedChecksDisplay__c` / `SkippedChecksDisplay__c`) so viewers see what passed and what was skipped; `Hide` remains the power-user opt-in for a summarize-only, failures-focused view. Example Check Sets updated to match, except `Account_Data_Quality`, kept as the intentional failures-only demo.
- Updated docs, examples, and plugin guidance for comparison display, provenance, and the current 98-test LWC suite.

## [1.0.0]: 2026-06-23

Initial release: metadata-driven record health checks, Lightning record-page component, Apex evaluation engine, 10 sample Check Sets and 88 Rules, and documentation under `docs/`.
