# Account relationship and risk demo

Create a complete 30-day scratch org with one command. Set `DEV_HUB_ALIAS` to your
Dev Hub org alias first:

```bash
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-demo.sh rhc-demo
```

Use a different scratch-org alias when needed:

```bash
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-demo.sh my-demo-alias
```

The setup deploys the core package, the `Example_Account_Relationship_Risk`
check set and its eight `Example_` rules, filtered example list views, reviewed
Set and Rule layouts, and an Account record page containing the health-check
component. It assigns `Record_Health_Check_Admin`, creates a login password,
and seeds the complete Acme scenario plus the realistic Account, Contact, and Opportunity portfolio
used by all four shipped Check Sets.

The deterministic data includes:

- `Asteron Global Holdings → Asteron Industrial Systems → Acme Corporation`;
- Jordan Blake assigned as owner and then deactivated in a separate transaction;
- 38 realistic contacts, including six without email addresses;
- three reachable Opportunity Contact Roles with `Executive Sponsor`;
- two open opportunities totaling $70,000 against $500,000 annual revenue;
- two completed activities in the last 90 days;
- four open high-priority cases.

The object-specific portfolio adds four fictional companies, eight populated Contacts, and eight
populated Opportunities. `Harborline Dispatch Pilot` has three Tasks, two Events, an Executive
Sponsor, and a Technical Buyer while intentionally retaining the two missing fields used by its
failing checks.

The final verification fails the setup immediately unless the health check
returns exactly **3 passed, 4 failed, and 1 skipped**. The skipped channel rule
must remain business-valid for Acme's `Customer` account type.

`setupDemoData.apex` is idempotent for the named Acme demo records. On rerun,
it replaces Acme's Contacts, Opportunities, Opportunity Contact Roles, Tasks,
Events, and Cases so the scenario does not drift or accumulate duplicates.
