# Changelog

This project follows [Semantic Versioning](https://semver.org/). Notable changes are documented here starting with the first public release.

## [Unreleased]

## [1.1.0]: 2026-07-03

- Added comparison display controls for Found/Expected values, including Check Set `ComparisonDisplay__c` and the component-level `comparisonDisclosure` initial caret setting.
- Added gated comparison provenance details via `RecordHealthCheckProvenance` and the `Record_Health_Check_View_Details` custom permission.
- Added metadata-only category and remediation fields for future grouped display and guided fixes.
- Added `Record_Health_Check_Configure` as a reserved custom permission for future configuration tooling.
- Improved provenance notes: row counts pluralize consistently (`1 row` / `3 rows`) and are grouped under a single "Where these values came from" sub-section.
- Simplified `Record_Health_Check_Rule__mdt` / `Set__mdt` labels, descriptions, and layouts for friendlier first-time admin setup (no engine changes).
- Updated docs, examples, and plugin guidance for comparison display, provenance, and the current 90-test LWC suite.

## [1.0.0]: 2026-06-23

Initial release: metadata-driven record health checks, Lightning record-page component, Apex evaluation engine, 10 sample Check Sets and 88 Rules, and documentation under `docs/`.
