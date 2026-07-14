# Extend

Extensions are optional Salesforce projects for result history, notifications, scheduled runs, or
exports. They keep their own metadata, objects, permissions, and removal steps outside Core.

> **Status:** the Apex methods, platform events, and Apex check interface ship in V2. The
> `RecordHealthCheck-Extensions` repository and its first extension are **in progress**. This page
> describes the model so you can design against it today.

## The rule that protects the product

Opening a record shows health without changing data or starting other automation. Extensions must
preserve that behavior.

- **Page-load evaluation only displays.** It never creates records, calls external systems, or
  publishes events — regardless of any setting.
- **Platform event publishing is optional and off by default.** It applies only to Apex and Flow
  runs, not record-page checks.
- **Automatic remediation lives in extensions, never in Core.** A Rule may offer a user-initiated
  **Fix it** link; acting on it is the user's choice, not an automatic consequence of viewing a record.

## Supported extension choices

| Choice                               | Uses                                                         | Can it change a check result?                        |
| ------------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------- |
| **Rule result subscriber**           | `Record_Health_Check_Rule_Result__e`                         | No                                                   |
| **Check Set run subscriber**         | `Record_Health_Check_Set_Run__e`                             | No                                                   |
| **Scheduled, batch, or REST caller** | Public `RecordHealthCheck` Apex methods                      | It chooses which documented Check Set or Rule to run |
| **Custom Apex check**                | `RecordHealthCheckRule` interface                            | Yes, through the result it returns                   |
| **Reporting or guided action**       | The extension's own objects, reports, Flows, and permissions | No                                                   |

Two shared event streams serve the whole ecosystem — extensions never add their own core event type.

## What ships first

The first planned extension stores Check Set run and Rule result history from the platform events.
It will define its own retention period, reports, and permissions. Notifications, scheduled checks,
and exports remain separate optional projects.

## Build one

Every extension must document the Core version it supports, platform events or Apex methods it uses,
objects it creates, permissions it requires, and how to disable and remove it. A subscriber failure
must never alter a completed health result.

Full contracts and the plugin-author checklist are in the design specification:
[Extension architecture (§4)](https://github.com/gkolan/RecordHealthCheck/blob/main/releases/v2/V2-RELEASE-PLAN.md).

## Next

- The contracts you'll build against → **[[Integrate]]**
- Where the roadmap is heading → the
  [post-V2 functionality plan](https://github.com/gkolan/RecordHealthCheck/blob/main/releases/v2/V2-RELEASE-NEW-FUNCTIONALITY.md)
