# Troubleshooting Details

Show Troubleshooting Details shows extra technical detail on the health check card and in the browser console. It is for troubleshooting only: leave it **off** on production Check Sets when not actively investigating a problem.

Show Troubleshooting Details does **not** save history and does **not** write any records: it only adds on-screen and console detail for the current run.

> [!WARNING]
> Turning on **Show Troubleshooting Details** on the Check Set alone does **nothing** visible. Both the Check Set flag **and** the `Record_Health_Check_View_Details` permission are required for troubleshooting output.

## Both steps are required

| Step | What to do | Where in Setup |
| ---- | ---------- | -------------- |
| **1. Check Set** | Check **Show Troubleshooting Details** | **Custom Metadata Types** → **Record Health Check Set** → open your Check Set → **Show Troubleshooting Details** (`ShowDiagnostics__c`) |
| **2. User** | Assign the Permission Set named `Record_Health_Check_Admin` | **Permission Sets** → open `Record_Health_Check_Admin` → **Manage Assignments** → add the troubleshooting user |

Step 2 grants the **`Record_Health_Check_View_Details`** custom permission. That permission unlocks advanced details; the Check Set's **Show Troubleshooting Details** flag decides when troubleshooting output appears on the card and in the console.

### Permission Sets: which one unlocks troubleshooting detail?

| API name | Setup label | Troubleshooting detail? | comparison diagnostic details (`*Detail`)? |
| -------- | ----------- | ------------------------------------ | -------------------------------- |
| `Record_Health_Check_User` | Record Health Check User | **No**: can run the card, but sees only normal pass/fail messages | **No** |
| `Record_Health_Check_Admin` | Record Health Check Admin | **Yes**: includes `Record_Health_Check_View_Details` | **Yes**: includes `Record_Health_Check_View_Details` |

If you checked Show Troubleshooting Details on the Check Set but still see a normal card, the most common cause is that the viewing user does not have the Permission Set named **`Record_Health_Check_Admin`**.

### Two custom permissions (Admin set only)

| Custom permission | What it unlocks |
| ----------------- | --------------- |
| `Record_Health_Check_View_Details` | **Always** (even with Show Troubleshooting Details off): Formula **Passes when** labels on entitled rows. **With Show Troubleshooting Details on:** gray troubleshooting lines, **Troubleshooting detail** blocks, console footnote, the `[RHC]` console summary, and comparison diagnostic details notes (`actualValueDetail` / `expectedValueDetail`) inside the nested `[RHC] Source detail` group. |
| `Record_Health_Check_Configure` | Reserved for future admin tooling (Rule Tester). Shipped in the Admin set; no runtime feature gates on it yet. |

After changing the Check Set or permission set assignment, **refresh the record page**.

## What you see on the health check card

After you **run** the checks (automatic or manual), and only when both steps above are complete:

| What | Description |
| ---- | ----------- |
| **Gray line under each result** | Compact summary, for example `FAIL · FORMULA_FALSE · 38ms · Formula`: status, reason code, time taken, Check Type (API value) |
| **Troubleshooting detail** | On checks that errored or did not run, a **Troubleshooting detail** block showing the technical message inline (SOQL problems, missing field access, and similar) |
| **Found / Expected** | On failing checks, labelled chips when the engine captured values. Found / Expected visibility is controlled by **Found/Expected Display** on the Check Set. |
| **comparison diagnostic details** | When the viewer has `Record_Health_Check_View_Details`, source details are included in the F12 browser console diagnostics, not on the card. |
| **Console hint** | Small footnote at the bottom of the card: **Check console (F12) for diagnostics.** |

Users **without** `Record_Health_Check_View_Details` never see the gray lines, Troubleshooting detail blocks, or the console hint: even when Show Troubleshooting Details is checked on the Check Set. This is intentional so technical detail is not exposed to everyday users.

## What you see in the browser console

1. Open a record page that has the health check card.
2. Press **F12** (Windows/Linux) or open **Developer Tools** (Mac) and select the **Console** tab.
3. Run the health checks on the card.
4. When the run finishes, find a group titled **`[RHC] Health Check run <runId> | <CheckSetDeveloperName> | record <recordId>`** (the middle segment is the selected **Check Set** Developer Name: use it to tell multiple health check cards apart on the same page).

Inside that group you will see:

- **Outcome summary**: one line such as `3 Passed, 2 Failed · 847ms total`.
- **Run metadata**: run id, check set, record id, user id, and timestamp (for matching Apex logs).
- **Results table**: every check with status, severity, reason code, found/expected values, duration, and evaluator type.
- **Source detail group**: when any check has diagnostic detail strings, a nested `[RHC] Source detail` group lists Found and Expected source notes per check (label, developer name, and status in the heading). No empty group is logged.

Use the **run id** to match Apex log entries when Apex logging is enabled for your user.

## Checklist

- [ ] **Show Troubleshooting Details** checked on the **same** Check Set the component uses (App Builder **Check Set** selection must match).
- [ ] Permission Set **`Record_Health_Check_Admin`** assigned to the user viewing the page.
- [ ] Record page **refreshed** after metadata or permission changes.
- [ ] Checks **run** to completion (troubleshooting detail appears after the run, not on first load while rows are still pending).
- [ ] **Show Troubleshooting Details turned off** on production Check Sets when troubleshooting is finished.

## Related documentation

| Document | Use when |
| -------- | -------- |
| [Getting Started: Permission Sets](../installation/getting-started.md#step-1b-assign-permission-sets) | First install and assigning Permission Sets |
| [Configuration Guide: Check Set fields](../guides/configuration-guide.md#3-check-set-fields) | Every Check Set field explained |
| [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting) | When a check fails or cannot run |
