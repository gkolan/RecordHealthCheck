# Getting Started

Use this when you are ready to create your first Rule and connect it to a real record page.

**You need:** Permission to edit Lightning record pages and manage Custom Metadata in Setup (typically **Customize Application** on your profile or permission set).  
**You do not need:** Apex, Flow, or command-line tools to complete this guide.

This guide gets Record Health Check running on a Salesforce org and walks you through your first working check.

> [!NOTE]
> **Setup labels vs API names:** Tables below show **Setup label** (what you click) and **API name** (what metadata XML and the LLM guide use). You only need the Setup column to configure checks in the UI.

## What you are building

Record Health Check adds a **card** to a record page (for example, an Account page). The card runs a list of **Rules** you define in Setup and shows whether each Rule passed, failed, was skipped, or did not run.

You configure two record types in **Setup → Custom Metadata Types**:

| Plain name | Setup name | API type | One sentence |
| ---------- | ---------- | -------- | ------------ |
| **Check Set** | Record Health Check Set | `Record_Health_Check_Set__mdt` | The panel: which object it runs on, when it runs, and how results display |
| **Rule** | Record Health Check Rule | `Record_Health_Check_Rule__mdt` | One check inside that card (for example, “Billing City must not be blank”) |

The card does **not** block saves or change field values. It only **shows** health information.

## Prerequisites

- A Salesforce org where you can customize Lightning pages and edit Custom Metadata
- For **Verify with a formula** checks (`EvaluationType__c` = `FORMULA`): org API **v63.0 or later** (Spring ’25). If you are unsure, use **Verify with a query** checks instead: they work on older API versions.
- A way to deploy the package (see Step 1). **Option A** (CLI) deploys from the repository; **Option B** (metadata deploy through your org's normal process) works if you do not use the CLI.

> [!IMPORTANT]
> **API version:** The project ships at API **66.0** (`sfdx-project.json`). The v63.0 minimum applies to **FormulaEval** on the org, not the deploy package version.

After deployment, assign Permission Sets so users can run the component (see Step 1b).

## Step 1: Deploy the package

> [!IMPORTANT]
> **Upgrading to V2:** V2 is a breaking metadata-contract release with no dual-read support for v1.x field names. Back up custom metadata and follow [Upgrading to V2](upgrading-to-v2.md) before deploying to production. After upgrade, reopen each Lightning record page that includes the component, confirm the **Check Set** selection, and save.

### Option A: Salesforce CLI

From the **RecordHealthCheck** (Core) repository root:

**Recommended install** — framework plus the one hero Check Set that proves the card works:

```bash
sf project deploy start --manifest manifest/package-core.xml
sf project deploy start --manifest manifest/package-Example_Account_360_Health_Check.xml
```

Optional scenario packs (data quality, relationships, industry readiness, and more) are **not** part of Core. They live in
[**RecordHealthCheck-Examples**](https://github.com/gkolan/RecordHealthCheck-Examples).
Install packs from that repository after Core — see the
[Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md)
and the [pack index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md).

Single-rule copy/paste patterns (formulas, SOQL, Apex walkthroughs) are in the Examples
[pattern library](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md).

### Option B: Change set or DevOps Center

Deploy only the components named in `manifest/package-core.xml`, followed by the components in
`manifest/package-Example_Account_360_Health_Check.xml`. Do not include other example Check Sets
from the Core working tree. Install optional packs from
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples) using its
[install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md).

### After deployment you will have

- The **recordHealthCheck** Lightning component
- Custom Metadata Types for Check Sets and Rules
- The hero Check Set **`Example_Account_360_Health_Check`** (when you deployed its manifest)
- Two Permission Sets (assign in Step 1b)
- Any optional packs you later install from **RecordHealthCheck-Examples**

### Step 1b: Assign Permission Sets

Users need Apex access to run the component. Assign the least-privilege Permission Set that matches what they need:

| API name | Setup label | Assign when |
| -------- | ----------- | ----------- |
| `Record_Health_Check_User` | Record Health Check User | Run the card on record pages (no troubleshooting detail, no diagnostic details) |
| `Record_Health_Check_Admin` | Record Health Check Admin | Troubleshooting and audit: includes `Record_Health_Check_View_Details` and `Record_Health_Check_Configure` (configure is reserved for future tooling). Required for [Show Diagnostics](../guides/show-diagnostics.md) and comparison diagnostic details. |

In **Setup → Permission Sets**, open the Permission Set → **Manage Assignments** → **Add Assignments**.

The Permission Set named `Record_Health_Check_User` grants Apex class access to `RecordHealthCheckController` and `RecordHealthCheck` only. It does **not** grant troubleshooting detail.

**Verify assignment:** After assigning the Permission Set named `Record_Health_Check_User`, open an Account on a page with the component and confirm checks run with pass/fail rows only: no **Troubleshooting detail** block and no `[RHC]` console block. Assign the Permission Set named `Record_Health_Check_Admin` only when you need Show Diagnostics.

**Show Diagnostics:** If you enable **Show Diagnostics** on a Check Set, you must also assign the Permission Set named `Record_Health_Check_Admin` to see the extra lines on the card and console output. See [Show Diagnostics guide](../guides/show-diagnostics.md).

## Step 2: Add the component to a record page

1. Open **Setup → Lightning App Builder**.
2. Edit an **Account** record page (or whichever object matches your Check Set).
3. Drag **recordHealthCheck** onto the page.
4. In the component properties on the right, choose **Check Set**. The picker lists active Check Sets for the record page's object by Developer Name. For example, choose:

   ```text
   Example_Account_360_Health_Check
   ```

   That is the hero Check Set shipped with Core. After you install an optional pack from
   [RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples), its Check Set
   Developer Name appears in the same picker.

   If the list is empty, no active Check Set targets this object yet. Create or activate one under **Setup → Custom Metadata Types → Record Health Check Set**.

5. _(Optional)_ Set **Design System** to **SLDS 2** (default) or **SLDS 1** to match the page's visual style. This changes only the card, not your org theme — see [Design System](../guides/design-system.md).
6. **Save** and **Activate** the page. Assign the page to the right app and profiles if prompted.

The component only works on **record pages** because it needs the current record’s Id.

## Step 3: Verify with the Core Hero Check Set

1. Open any Account on the page you edited.
2. If the Check Set **When Checks Run** (`CardRunMode__c`) is **Run automatically when the page opens**, checks run after the page loads. If it is **When the user clicks Run** (`RUN_ON_REQUEST`), click **Run** on the card.
3. If the component is configured correctly, you will see a health check card with checks and pass/fail results. When a Rule **fails**, look beneath the failure message for **Found** / **Expected** labelled chips (Query and Compare Two Queries checks) that show what the record produced versus what the rule required. Use **Found/Expected Display** on the Check Set to control whether passing checks also show values (see [Check Set fields](../metadata/check-set.md#foundexpected-display-comparisondisplay__c)). If you do not see the card at all, see [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting).

**To view the sample configuration in Setup**

1. **Setup → Custom Metadata Types**
2. Next to **Record Health Check Set**, click **Manage Records**
3. Open `Example_Account_360_Health_Check`
4. Next to **Record Health Check Rule**, click **Manage Records** to see its Rules

## Step 4: Create your first Rule

The simplest Rule is a **Verify with a formula** check: Billing City must not be blank.

1. **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records → New**
2. Fill in:

   | Setup label | API name | Value |
   | ----------- | -------- | ----- |
   | Developer Name | `DeveloperName` | `My_Billing_City_Required` |
   | Label | Master Label | `Billing City Required` |
   | Check Title | `CheckTitle__c` | `Billing City Required` |
   | Check Set | `Record_Health_Check_Set__c` | Your Check Set |
   | Evaluation Order | `EvaluationOrder__c` | `100` (lower numbers run first) |
   | Active | `IsActive__c` | Checked |
   | Evaluation Type | `EvaluationType__c` | `FORMULA` (Setup: Verify with a formula) |
   | Pass Condition | `PassConditionFormula__c` | `NOT(ISBLANK(BillingCity))` |
   | Applies To | `ApplicabilityMode__c` | `ALL_RECORDS` (Setup: All records) |
   | Failure Severity | `FailureSeverity__c` | `CRITICAL` |
   | Message When Failed | `FailureMessage__c` | `Billing City is required.` |

3. **Save**, refresh the Account record page, and confirm the new Rule appears.

> [!TIP]
> To draft Rules faster, use the [LLM Configuration Guide](../guides/llm-configuration.md): ask for Section 4 tables, then copy values into Setup.

After you edit Check Set or Rule metadata in Setup, **refresh the record page** to load the changes.

For more patterns, see [Formula checks: example 1](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/formula/01-single-required-field.md).

## Step 5: Before go-live

Use the [Review Checklist](../guides/configuration-guide.md#14-review-checklist) in the Configuration Guide. At minimum:

- The component's **Check Set** selection points to the Check Set you intend to run
- **Object** on the Check Set matches the record page object (for example, `Account`)
- **Show Diagnostics** is **unchecked** in production (troubleshooting only)

## Optional: Run checks from Apex or Flow

You do not need the record-page card to evaluate health checks:

- **One Rule (Apex):** `RecordHealthCheck.run('My_Check_Set', 'My_Rule', recordId)`
- **Whole Check Set (Apex):** `RecordHealthCheck.runSet('My_Check_Set', recordId)`
- **Flow:** packaged action **Run Record Health Check** (`RecordHealthCheckFlowAction`). Leave Rule API Name blank to run the Check Set.

Calls are capped (`MAX_RECORDS_PER_CALL = 200`, `MAX_EVALUATIONS_PER_CALL = 15`). Opt-in lifecycle events can publish after façade/Flow runs; the Lightning card never publishes. Details: [Programmatic API and Flow](../apex/programmatic-api.md) and [Lifecycle events](../reference/lifecycle-events.md).

## Next steps

| Goal | Document |
| ---- | -------- |
| Install optional packs | [Examples install guide](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/install.md) |
| Browse pack catalog | [Examples pack index](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/examples-index.md) |
| Copy a single-rule pattern | [Pattern library](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md) |
| Draft checks with AI | [LLM Configuration Guide](../guides/llm-configuration.md) |
| Understand every field | [Configuration Guide: field reference](../guides/configuration-guide.md#3-check-set-fields) |
| Call from Apex or Flow | [Programmatic API and Flow](../apex/programmatic-api.md) |
| Subscribe to results | [Lifecycle events](../reference/lifecycle-events.md) |
| Reason codes | [Reason codes](../reference/reason-codes.md) |
| Review runtime contract | [Design Specification](../reference/record-health-check-design-spec.md) |
| Navigate source code | [Architecture Map](../reference/architecture-map.md) |
| Fix a failure | [Configuration Guide: troubleshooting](../guides/configuration-guide.md#13-troubleshooting) |

More patterns: [Examples catalog](https://github.com/gkolan/RecordHealthCheck-Examples/blob/main/docs/pattern-library/index.md#starter-patterns).
