# Check Set fields (`Record_Health_Check_Set__mdt`)

Parent metadata record for one health-check panel on a record page. The Lightning component points at a Check Set through the **Check Set** App Builder property (`checkSetName` in the LWC, sent to Apex as `configName`).

> [!NOTE]
> This reference is the source of truth for Check Set fields. Guides and examples link here rather than restating these values.

Walkthroughs: [Configuration Guide](../guides/configuration-guide.md). Troubleshooting: [Show Troubleshooting Details](../guides/debug-mode.md).

## Field reference

### Identity and display

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Developer Name | `DeveloperName` | Text | Yes | API key selected by the Lightning component's **Check Set** property. Stable link between the page and metadata; survives label changes. |
| Label | Master Label | Text | Yes | Name shown in Setup record lists. Standard metadata identity; not shown to end users in the component. |
| Panel Title | `PanelHeading__c` | Text | Yes | Card header title (for example, `Account Health Check`). Required on the Custom Metadata Type; enforced by the validator. Runtime definition load does not reject a blank value. |
| Panel Subtitle | `PanelSubheading__c` | Text | No | One-line subtitle beneath the title row (full card width). Brief context without opening each Rule. |

### Scope

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Record Object API Name | `ObjectApiName__c` | Text | Yes | Object API name (for example, `Account`). Prevents running Account checks on Contact pages. Must match the record page object. Blank or invalid value causes `INVALID_CONFIG` at definition load. |
| Active | `IsActive__c` | Checkbox | No | When unchecked, the Check Set does not load. Defaults to checked. Disable a configuration without deleting Rules or removing the component. |

### Run behavior

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Start Checks | `RunChecksWhen__c` | Picklist | Yes | `Automatic`: run after page load. `Manual`: wait for **Run** / **Rerun**. While checks run the button shows a spinner; the label stays **Run** (first run) or **Rerun** (after any completed run), never "Running…". Busy detail is in `title` / `aria-label`. See [picklist values](#start-checks-runcheckswhen__c). |
| Stop After System Error | `StopOnSystemError__c` | Checkbox | No | Stops remaining checks after the first `ERROR` status and runs checks sequentially (one Apex call at a time). Does **not** stop on `FAIL`, `SKIPPED`, or `UNABLE_TO_EVALUATE`. |

### Result presentation

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| How checks appear | `RowAppearance__c` | Picklist | Yes | `AllAtOnce`: every eligible check is listed on load (pending) and fills in its result in place. `OneAtATime` (**default**): no rows on load; each check appears as the run reaches it. Cosmetic only — same checks, order, and outcomes either way. Checks hidden by Passed/Skipped display modes stay hidden in both modes. |
| Found/Expected Display | `ComparisonDisplay__c` | Picklist | Yes | Controls when **Found** / **Expected** values appear for each check. Default: **On demand**. See [picklist values](#foundexpected-display-comparisondisplay__c). Detailed source/value notes do not render on the card; for users with **`Record_Health_Check_View_Details`** they appear in the F12 console diagnostics. See [Comparison provenance](../reference/record-health-check-design-spec.md#comparison-provenance). |
| Passed Checks | `PassedChecksDisplay__c` | Picklist | Yes | `Show` (default) lists passed checks; `Hide` removes them but the **Passed** summary pill still shows the count (hover for rule labels). |
| Skipped Checks | `SkippedChecksDisplay__c` | Picklist | Yes | Same options for `SKIPPED` checks. `Show` (default) lists them; `Hide` collapses them into the **Skipped** summary pill. |
| Show Troubleshooting Details | `DebugMode__c` | Checkbox | No | When checked **and** the viewer has **`Record_Health_Check_View_Details`** (from permission set `Record_Health_Check_Admin`), shows extra troubleshooting detail on the card and in the browser console. Does **not** affect what regular users see. Walkthrough: [Show Troubleshooting Details](../guides/debug-mode.md). |

### Framework limits (not fields)

- **25 active Rules maximum** per run (lowest **Run Order** first, then `DeveloperName`). When Rules are omitted, the header badge shows **First 25 of N shown**, using Apex `totalAvailableCheckCount` for N.
- **Metadata reload:** `getCheckDefinitions` is not cacheable. Reload the page to pick up metadata edits. After the component connects, a change to `recordId` also reloads definitions (for example, navigating to a different record on the same page).
- **Concurrency:** up to **5** in-flight `evaluateCheck` calls when Stop After System Error is unchecked (remaining checks queue client-side; up to 25 Rules may be scheduled per run). When Stop After System Error is checked, checks run sequentially (one Apex call at a time).
- **Dependencies outside the cap:** if a prerequisite Rule is among the omitted Rules, dependents are skipped with reason `DEPENDENCY_NOT_IN_RUN` (LWC only; this reason code is not emitted by Apex).

## Picklist values

### Start Checks (`RunChecksWhen__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `Automatic` | Run automatically when the page opens | Checks run when the page loads (after a short deferral). |
| `Manual` | Wait for the user to click Run | User clicks **Run**. Use for expensive checks. |

### Passed and Skipped Checks (`PassedChecksDisplay__c`, `SkippedChecksDisplay__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `Show` | Show each check | **Default** (both Passed and Skipped). Checks stay in the list, so viewers see what passed and what was skipped alongside failures. |
| `Hide` | Hide checks, show count only | Checks are hidden from the list. After the run completes, counts appear in the summary bar pill for that outcome (**Passed** or **Skipped**). Hover or keyboard-focus the pill to see the rule labels. A power-user opt-in for a summarize-only, failures-focused view. |

Use `Hide` on Check Sets like `Account_Data_Quality` when a failures-only check list is needed but an at-a-glance pass count in the summary bar is still required.

### How checks appear (`RowAppearance__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `AllAtOnce` | Show all checks at once | Every eligible check is listed on load as a pending row, then fills in (loading → done) in place. The list length is stable from the start. Checks hidden by Passed or Skipped display modes are still hidden. |
| `OneAtATime` | Reveal checks one at a time | **Default.** No check rows on load (just the run hint); each eligible check appears as the ordered run reaches it, so the list grows as the run advances rather than all rows landing at once. |

### Found/Expected Display (`ComparisonDisplay__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `OnDemand` | On demand | **Default.** Failed checks show **Found** / **Expected** inline. Passing checks can be expanded to reveal values when values are available. |
| `FailuresOnly` | Failed checks only | **Found** / **Expected** inline on failed checks only. Passing checks stay compact. |
| `AllRows` | Show on every check | **Found** / **Expected** inline on every check that captured values (pass and fail). Detailed source/value notes stay out of the card and appear only in console diagnostics for entitled viewers. |

## See also

- [Rule fields](rule-fields.md)
- [Configuration Guide](../guides/configuration-guide.md)
- [Design Specification](../reference/record-health-check-design-spec.md)
