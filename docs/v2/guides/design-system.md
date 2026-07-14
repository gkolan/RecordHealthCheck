# Design System (SLDS 2 / SLDS 1)

The Record Health Check card can render in two visual treatments. You choose the
one you want on the record page in the **Lightning App Builder** — it is a
per-placement setting, so different pages can use different treatments.

> [!NOTE]
> This setting only changes how the **Record Health Check card** looks. It does
> **not** change your org theme, and it does not affect any other component on
> the page.

## The setting

On the record page, select the **Record Health Check** component in the
Lightning App Builder. In its properties, set **Design System**:

| Value      | When to use it                                                                                       |
| ---------- | ---------------------------------------------------------------------------------------------------- |
| **SLDS 2** | Default. Designed for the Salesforce **Cosmos** theme — the current Lightning look.                  |
| **SLDS 1** | Preserves the **legacy** SLDS styling. Use it where the surrounding page still uses the older theme. |

If you do nothing, the card uses **SLDS 2**.

## What it changes

The choice swaps a self-contained theming layer on the card only — card
background, borders, radius, shadow, header, and text all read from theme
variables that switch with the setting. Your checks, results, messages, and
"Fix it" links behave identically in both treatments; only the visual styling
differs.

## Why per-placement, not org-wide

Orgs adopt the Cosmos theme at their own pace, and a single org can have pages on
both the old and new look during a transition. Making Design System a
per-placement property lets the card match whichever page it sits on, instead of
forcing one choice across the whole org.

## Related

- [Configuration Guide](configuration-guide.md) — every card and Check Set setting
- [Getting Started](../installation/getting-started.md) — add the card to a record page
