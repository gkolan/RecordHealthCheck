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
- For **Check fields on this record** checks (`EvaluationType__c` = `Formula`): org API **v63.0 or later** (Spring ’25). If you are unsure, use **Check records with a query** checks instead: they work on older API versions.
- A way to deploy the package (see Step 1). **Option A** (CLI) deploys from the repository; **Option B** (metadata deploy through your org's normal process) works if you do not use the CLI.

> [!IMPORTANT]
> **API version:** The project ships at API **66.0** (`sfdx-project.json`). The v63.0 minimum applies to **FormulaEval** on the org, not the deploy package version.

After deployment, assign Permission Sets so users can run the component (see Step 1b).

## Step 1: Deploy the package

> [!IMPORTANT]
> **Upgrading to v1.2.0 from an earlier release:** v1.2.0 removes the old Lightning component properties `configName` and `comparisonDisclosure`. Before deploying the upgrade to an org that already has Record Health Check on record pages, open those pages in **Lightning App Builder**, remove or reconfigure the old component placement, and save it with the current **Check Set** picker. This is a required admin step; v1.2.0 does not include legacy component-property support.

### Option A: Salesforce CLI

From the repository root:

**Clean install (recommended)** — the framework only, with no sample or example Check Sets. Best for production orgs:

```bash
sf project deploy start --manifest manifest/package-core.xml
```

Then add only the sample Check Sets you actually want, one manifest at a time:

```bash
sf project deploy start --manifest manifest/package-Account_Data_Quality.xml   # example: 4 formula rules
```

See [Sample Check Set packages](../examples/index.md#sample-check-set-packages) for all set manifests. The `Account_Examples_*` sets are example material. Deploy them in a sandbox or scratch org to inspect patterns, and leave them out of production.

**Full deploy** — the framework plus _every_ sample and example Check Set. Convenient for a scratch or dev org where you want the examples on hand:

```bash
sf project deploy start --source-dir force-app
```

Or via the catch-all manifest (it uses wildcards, so it also pulls in every sample and example record):

```bash
sf project deploy start --manifest manifest/package.xml
```

### Option B: Without the CLI

For a clean install, deploy `manifest/package-core.xml` first (framework only, no examples), then add individual `manifest/package-<CheckSet>.xml` files for any sample sets you want (see [Sample Check Set packages](../examples/index.md#sample-check-set-packages)). To get everything at once — examples included — deploy the `force-app` folder or `manifest/package.xml` through your org’s normal process, such as change sets, DevOps Center, Copado, or another metadata deployment tool.

### After deployment you will have

- The **recordHealthCheck** Lightning component
- Custom Metadata Types for Check Sets and Rules
- The sample Check Sets and Rules you chose to deploy — none with the clean install; a full deploy adds all **10 reusable sample** Check Sets (88 Rules), **4 teaching example** Check Sets (35 Rules), and **1 Account 360 demo** Check Set (9 Rules), all on Account, which you can copy or turn off
- Two Permission Sets (assign in Step 1b)

### Step 1b: Assign Permission Sets

Users need Apex access to run the component. Assign the least-privilege Permission Set that matches what they need:

| API name | Setup label | Assign when |
| -------- | ----------- | ----------- |
| `Record_Health_Check_User` | Record Health Check User | Run the card on record pages (no troubleshooting detail, no diagnostic details) |
| `Record_Health_Check_Admin` | Record Health Check Admin | Troubleshooting and audit: includes `Record_Health_Check_View_Details` and `Record_Health_Check_Configure` (configure is reserved for future tooling). Required for [Show Troubleshooting Details](../guides/show-diagnostics.md) and comparison diagnostic details. |

In **Setup → Permission Sets**, open the Permission Set → **Manage Assignments** → **Add Assignments**.

The Permission Set named `Record_Health_Check_User` grants Apex class access to `RecordHealthCheckController` and `RecordHealthCheck` only. It does **not** grant troubleshooting detail.

**Verify assignment:** After assigning the Permission Set named `Record_Health_Check_User`, open an Account on a page with the component and confirm checks run with pass/fail rows only: no **Troubleshooting detail** block and no `[RHC]` console block. Assign the Permission Set named `Record_Health_Check_Admin` only when you need Show Troubleshooting Details.

**Show Troubleshooting Details:** If you enable **Show Troubleshooting Details** on a Check Set, you must also assign the Permission Set named `Record_Health_Check_Admin` to see the extra lines on the card and console output. See [Show Troubleshooting Details guide](../guides/show-diagnostics.md).

## Step 2: Add the component to a record page

1. Open **Setup → Lightning App Builder**.
2. Edit an **Account** record page (or whichever object matches your Check Set).
3. Drag **recordHealthCheck** onto the page.
4. In the component properties on the right, choose **Check Set**. The picker lists active Check Sets for the record page's object by Developer Name. For example, choose:

   ```text
   Account_Data_Quality
   ```

   If the list is empty, no active Check Set targets this object yet. Create or activate one under **Setup → Custom Metadata Types → Record Health Check Set**.

5. **Save** and **Activate** the page. Assign the page to the right app and profiles if prompted.

The component only works on **record pages** because it needs the current record’s Id.

## Step 3: Verify with a sample Check Set

1. Open any Account on the page you edited.
2. If the Check Set **Start Checks** (`CardRunMode__c`) is **Run automatically when the page opens**, checks run after the page loads. If it is **Wait for the user to click Run**, click **Run** on the card.
3. If the component is configured correctly, you will see a health check card with checks and pass/fail results. When a Rule **fails**, look beneath the failure message for **Found** / **Expected** labelled chips (Query and Compare Two Queries checks) that show what the record produced versus what the rule required. Use **Found/Expected Display** on the Check Set to control whether passing checks also show values (see [Check Set fields](../metadata/check-set.md#foundexpected-display-comparisondisplay__c)). If you do not see the card at all, see [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting).

**To view the sample configuration in Setup**

1. **Setup → Custom Metadata Types**
2. Next to **Record Health Check Set**, click **Manage Records**
3. Open `Account_Data_Quality`
4. Next to **Record Health Check Rule**, click **Manage Records** to see its Rules

## Step 4: Create your first Rule

The simplest Rule is a **Check fields on this record** check: Billing City must not be blank.

1. **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records → New**
2. Fill in:

   | Setup label | API name | Value |
   | ----------- | -------- | ----- |
   | Developer Name | `DeveloperName` | `My_Billing_City_Required` |
   | Label | Master Label | `Billing City Required` |
   | Check Name | `CheckTitle__c` | `Billing City Required` |
   | Check Set | `Record_Health_Check_Set__c` | Your Check Set |
   | Run Order (lower runs first) | `EvaluationOrder__c` | `100` (lower numbers run first) |
   | Active | `IsActive__c` | Checked |
   | Check Type | `EvaluationType__c` | `Check fields on this record` |
   | Pass Condition (Formula) | `PassConditionFormula__c` | `NOT(ISBLANK(BillingCity))` |
   | Applies To | `ApplicabilityMode__c` | `All records` |
   | Severity | `FailureSeverity__c` | `Error` |
   | Message When Check Fails | `FailureMessage__c` | `Billing City is required.` |

3. **Save**, refresh the Account record page, and confirm the new Rule appears.

> [!TIP]
> To draft Rules faster, use the [LLM Configuration Guide](../guides/llm-configuration.md): ask for Section 4 tables, then copy values into Setup.

After you edit Check Set or Rule metadata in Setup, **refresh the record page** to load the changes.

For more patterns, see [Formula checks: example 1](../examples/formula/01-single-required-field.md).

## Step 5: Before go-live

Use the [Review Checklist](../guides/configuration-guide.md#14-review-checklist) in the Configuration Guide. At minimum:

- The component's **Check Set** selection points to the Check Set you intend to run
- **Record Object API Name** on the Check Set matches the record page object (for example, `Account`)
- **Show Troubleshooting Details** is **unchecked** in production (troubleshooting only)

## Optional: Run a check from Apex

You do not need the record-page card to evaluate a single Rule:

- **Apex:** `RecordHealthCheck.run('My_Check_Set', 'My_Rule', recordId)`

The packaged Flow invocable action is **not included**. Call `RecordHealthCheck.run`
from a bulk-designed Apex invocable that groups records and evaluates them within
transaction limits, or from scheduled/batch Apex with an intentionally small scope.
Keep it out of a per-request loop, which multiplies governor cost.

Details: [Design Specification 13](../reference/record-health-check-design-spec.md#13-programmatic-api-recordhealthcheck).

## Next steps

| Goal | Document |
| ---- | -------- |
| Draft checks with AI | [LLM Configuration Guide](../guides/llm-configuration.md) |
| Understand every field | [Configuration Guide: field reference](../guides/configuration-guide.md#3-check-set-fields) |
| Copy working examples | [Examples index](../examples/index.md) |
| Review runtime contract | [Design Specification](../reference/record-health-check-design-spec.md) |
| Navigate source code | [Architecture Map](../reference/architecture-map.md) |
| Fix a failure | [Configuration Guide: troubleshooting](../guides/configuration-guide.md#13-troubleshooting) |

More patterns: [Examples catalog](../examples/index.md#core-examples).
