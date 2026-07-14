# Check Set fields (`Record_Health_Check_Set__mdt`)

Parent metadata record for one health-check card on a record page. The Lightning component points at a Check Set through the **Check Set** App Builder property (`checkSetName` in the LWC, sent to Apex as `configName`).

> [!NOTE]
> This reference is the source of truth for Check Set fields. Setup labels and stored picklist values match shipped Custom Metadata. Guides and examples link here rather than restating these values.

Walkthroughs: [Configuration Guide](../guides/configuration-guide.md). Diagnostics: [Show Diagnostics](../guides/show-diagnostics.md). Upgrade notes: [Upgrading to V2](../installation/upgrading-to-v2.md).

Stored picklist values are `UPPER_SNAKE_CASE`. Apex maps a few Check Set modes to legacy LWC DTO strings (`Automatic` / `Manual`, `Show` / `Hide`, and so on) at the wire boundary; author metadata with the API values below.

## Field reference

### 1. Basics

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Developer Name | `DeveloperName` | Text | Yes | API key selected by the Lightning component **Check Set** property. Stable link between the page and metadata. |
| Label | Master Label | Text | Yes | Name shown in Setup record lists. Not shown to end users on the card. |
| Object | `ObjectApiName__c` | Text | Yes | Object API name (for example, `Account`). Must match the record page object. Blank or invalid value causes `INVALID_CONFIG` at definition load. |
| Active | `IsActive__c` | Checkbox | No | When unchecked, the Check Set does not load. Defaults to checked. |

### 2. Card Text

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Card Title | `CardTitle__c` | Text | Yes | Card header title (for example, `Account Data Quality`). Required in Custom Metadata and by the deploy-time validator. If a blank value somehow reaches runtime, the card falls back to the Check Set label, then developer name. |
| Card Subtitle | `CardSubtitle__c` | Text | No | Optional one-line subtitle under the title. |

### 3. Run Behavior

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| When Checks Run | `CardRunMode__c` | Picklist | No | Default `RUN_ON_REQUEST`. See [picklist values](#when-checks-run-cardrunmode__c). |
| Stop after a system error | `StopOnSystemError__c` | Checkbox | No | Stops remaining checks after the first `ERROR` status and runs checks sequentially (one Apex call at a time). Does **not** stop on `FAIL`, `SKIPPED`, or `UNABLE_TO_EVALUATE`. Off by default. |

### 4. Result Display

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Reveal Mode | `CardRevealMode__c` | Picklist | No | Default `ONE_BY_ONE`. Cosmetic only — same checks, order, and outcomes either way. See [picklist values](#reveal-mode-cardrevealmode__c). |
| Found/Expected Display | `FoundExpectedDisplay__c` | Picklist | No | Default `ON_DEMAND`. Controls when **Found** / **Expected** values appear. See [picklist values](#foundexpected-display-foundexpecteddisplay__c). |
| Passed Checks | `PassedChecksDisplay__c` | Picklist | No | Default `SHOW_EACH_CHECK`. See [picklist values](#passed-and-skipped-checks). |
| Skipped Checks | `SkippedChecksDisplay__c` | Picklist | No | Default `SHOW_EACH_CHECK`. Same options as Passed Checks for `SKIPPED` rows. |

### 5. Troubleshooting

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Show Diagnostics | `ShowDiagnostics__c` | Checkbox | No | When checked **and** the viewer has **`Record_Health_Check_View_Details`** (from permission set `Record_Health_Check_Admin`), shows extra troubleshooting detail on the card and in the browser console. Walkthrough: [Show Diagnostics](../guides/show-diagnostics.md). |

### 6. Lifecycle Events

| Setup label | API name | Type | Required | Description |
| ----------- | -------- | ---- | -------- | ----------- |
| Publish Run Event | `PublishRunEvent__c` | Checkbox | No | Publishes a Check Set Run event after a deliberately initiated run completes. Page-load runs never publish. Off by default. |

### Framework limits (not fields)

- **25 active Rules maximum** per run (lowest **Evaluation Order** first, then `DeveloperName`). When Rules are omitted, the header badge shows **First 25 of N shown**.
- **Metadata reload:** `getCheckDefinitions` and `getCheckSetAvailabilityForRecord` are not cacheable. Reload the page (or reconnect the component) to pick up metadata edits.
- **Concurrency:** up to **5** in-flight `evaluateCheck` calls when **Stop after a system error** is unchecked; sequential when it is checked.
- **Dependencies outside the cap:** if a prerequisite Rule is among the omitted Rules, dependents are skipped with reason `DEPENDENCY_NOT_IN_RUN` (LWC only).

## Picklist values

### When Checks Run (`CardRunMode__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `RUN_ON_LOAD` | When the page opens | Checks run when the page loads (after a short deferral). |
| `RUN_ON_REQUEST` | When the user clicks Run | **Default.** User clicks **Run**. Use for expensive checks. |

### Reveal Mode (`CardRevealMode__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `ALL_AT_ONCE` | All at once | Every eligible check is listed on load as a pending row, then fills in in place. |
| `ONE_BY_ONE` | One by one | **Default.** No check rows on load; each eligible check appears as the ordered run reaches it. |

### Found/Expected Display (`FoundExpectedDisplay__c`)

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `ON_DEMAND` | On demand | **Default.** Failed checks show **Found** / **Expected** inline. Passing checks can be expanded when values are available. |
| `FAILURES_ONLY` | Failed checks only | **Found** / **Expected** inline on failed checks only. |
| `ALL_ROWS` | Every check | **Found** / **Expected** inline on every check that captured values. |

### Passed and Skipped Checks

Fields: `PassedChecksDisplay__c`, `SkippedChecksDisplay__c`

| Value (API) | Setup label | Behavior |
| ----------- | ----------- | -------- |
| `SHOW_EACH_CHECK` | Show each check | **Default.** Checks stay in the list. |
| `SHOW_COUNT_ONLY` | Show count only | Rows are hidden; the summary bar pill still shows the count (hover for rule labels). |

## See also

- [Rule fields](rule-fields.md)
- [Configuration Guide](../guides/configuration-guide.md)
- [Design Specification](../reference/record-health-check-design-spec.md)
