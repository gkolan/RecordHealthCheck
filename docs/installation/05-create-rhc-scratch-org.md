# Create the demo scratch org

> [!NOTE]
> On this page, reproduce the project's complete first-run experience: the same org definition, Framework, examples, Lightning page, permissions, deterministic test records, and verified outcomes.

## Prerequisites

Install the Salesforce CLI, clone this repository, and authenticate a Dev Hub that is allowed to create scratch
orgs. Confirm both tools and the Dev Hub before running setup:

```bash
sf --version
git clone https://github.com/gkolan/RecordHealthCheck.git
cd RecordHealthCheck
sf org login web --set-default-dev-hub --alias my-dev-hub
sf org display --target-org my-dev-hub
```

The setup reads `config/project-scratch-def.json`. It creates a 30-day Developer Edition scratch org with
Salesforce sample data, Lightning Experience, and API password generation enabled.

## Step 1: Create the same demo org

From the repository root, run:

```bash
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-demo.sh rhc-demo
```

The script deliberately refuses to overwrite an existing alias. If `rhc-demo` already exists, delete it yourself
only when you no longer need that org, or choose another alias.

Setup performs the following operations in order:

1. Creates a 30-day scratch org from the checked-in definition.
2. Deploys `force-app`, including Core and the `Example_Account_Relationship_Risk` Check Set and Rules.
3. Deploys the demo Account record page, layouts, and list views.
4. Assigns `Record_Health_Check_Admin` to the scratch-org user.
5. Creates the deterministic Acme data set and its inactive owner scenario.
6. Generates a password, validates all RHC metadata, and runs the exact demo verification.

The command exits unsuccessfully if any step fails or if the final engine result is not exactly **3 passed, 4
failed, and 1 skipped**.

## Exact test data created

The setup creates or resets this deterministic scenario. Rerunning the data setup replaces the keyed demo Account's
Contacts, Opportunities, Opportunity Contact Roles, Tasks, Events, and Cases, so counts do not accumulate.

The factory identifies its records with demo-only stable keys rather than display names. It uses Account Number
values beginning with `RHC-DEMO-` and the demo owner's Federation ID. Duplicate rules remain enabled for the org;
only factory DML uses Salesforce's duplicate-rule bypass header.

| Salesforce object | Records created | Purpose |
| --- | ---: | --- |
| User | 1 | Jordan Blake, the owner who is deactivated after Acme receives ownership |
| Account | 3 | Corporate parent, operating division, and Acme Corporation |
| Contact | 38 | Stakeholders used for email coverage and executive sponsorship |
| Opportunity | 2 | Open pipeline totaling `$70,000` |
| Opportunity Contact Role | 3 | Executive Sponsor relationships across the two Opportunities |
| Task | 2 | Completed activity within the last 90 days |
| Case | 4 | Open High-priority customer issues |

No Event records are created. Rerunning the factory removes any earlier demo Events associated with the keyed
Acme Account so recent-activity results remain deterministic.

| Data | Exact result |
| --- | --- |
| Account hierarchy | `Asteron Global Holdings` → `Asteron Industrial Systems` → `Acme Corporation` |
| Acme classification | Type `Customer`; Industry `Manufacturing`; Annual Revenue `$500,000`; 1,250 employees |
| Parent alignment | Acme and its immediate parent both use Industry `Manufacturing` |
| Owner | Jordan Blake owns Acme and is then deactivated in a separate transaction |
| Contacts | 38 total; exactly 6 have no Email |
| Open Opportunities | 2, totaling exactly `$70,000` |
| Opportunity Contact Roles | Exactly 3 with Role `Executive Sponsor` |
| Recent activity | Exactly 2 completed Tasks in the last 90 days |
| Cases | Exactly 4 open, High-priority Cases |

The verification also checks all eight Rule outcomes individually:

| Rule Developer Name | Expected status |
| --- | --- |
| `Example_Executive_Sponsorship` | `PASS` |
| `Example_Account_Owner_Active` | `FAIL` |
| `Example_Industry_Aligns_With_Parent` | `PASS` |
| `Example_Contacts_Have_Email` | `FAIL` |
| `Example_Customer_Engagement_Current` | `PASS` |
| `Example_Pipeline_Protects_Revenue` | `FAIL` |
| `Example_No_High_Priority_Issues` | `FAIL` |
| `Example_Channel_Partner_Governance` | `SKIPPED` |

## Step 2: Open and test the experience

Open the prepared Account list:

```bash
sf org open --target-org rhc-demo --path 'lightning/o/Account/list?filterName=AllAccounts'
```

Open **Acme Corporation**. Its activated Account page already contains the Record Health Check component and the
example Check Set. Run the checks and confirm the summary is 3 passed, 4 failed, and 1 skipped. Expand values,
hover Rule titles, and follow the configured action links to exercise the same first-run UI used by maintainers.

## Step 3: Rerun or troubleshoot setup

The data seeding is idempotent for the named Acme records, but the top-level script does not reuse an org alias.
For a failed setup, inspect the failing CLI command, correct the cause, and run the setup again with a fresh
alias. The script prints each operation before executing it, so the last printed operation identifies the failed
stage.

Common checks:

```bash
sf org display --target-org rhc-demo
sf project deploy report --use-most-recent --target-org rhc-demo
sf apex run --target-org rhc-demo --file scripts/apex/validateMetadata.apex
sf apex run --target-org rhc-demo --file scripts/apex/verifyDemo.apex
```

The final verification command checks every record count and every Rule status listed on this page. A successful
run prints `RHC_DEMO_VERIFIED pass=3 fail=4 skip=1`.

## Next steps

- Replace one example Rule with a small Rule of your own.
- Rerun the verification after changing demo metadata or data.
- Turn on Show Diagnostics when an observed result differs from the expected table above.
