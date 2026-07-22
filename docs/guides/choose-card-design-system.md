# Choose the card design system

> [!NOTE]
> On this page, choose the SLDS generation that matches each Lightning record page and understand how Record Health Check preserves the same behavior across SLDS 1 and SLDS 2 styling.
>
> **Reference**
>
> - This guide covers only the **Design System** setting; it changes the card's look, not your org
>   theme or any other component on the page.
> - For every other card and Check Set setting, use the [Configure Check Sets and Rules](configure-check-sets-and-rules.md).

Use the **Design System** component property to match the Record Health Check card to each Lightning
record page. Select SLDS 2 for a page using the Salesforce Cosmos theme; leave SLDS 1 for established
Lightning styling.

The setting changes visual treatment only. The Check Set, Rules, results, messages, actions,
keyboard interaction, and accessible labels behave the same in SLDS 1 and SLDS 2.

## Change the design system

1. In **Lightning App Builder**, open the record page containing **Record Health Check**.
2. Select the component on the page canvas.
3. In the component properties, choose **SLDS 1** or **SLDS 2** under **Design System**.
4. Save and activate the page, then open a record to confirm the card matches the surrounding page.

## Choose between SLDS 1 and SLDS 2

| Value | When to use it |
| --- | --- |
| **SLDS 1** | Default. Use where the surrounding page uses established Lightning styling. |
| **SLDS 2** | Use for pages on the Salesforce **Cosmos** theme. |

If you do nothing, the card uses **SLDS 1**. Existing placements can opt into
SLDS 2 individually when their pages adopt the Cosmos theme.

## What it changes

The setting swaps card background, borders, radius, shadow, header, and text between
theme variables. Checks, results, messages, and action links behave identically in
both treatments; only the styling differs. The component stores the choice in the App
Builder attribute `designSystem`. Behavior, semantic structure, keyboard interaction,
and accessible labels stay the same in both treatments.

## Why per-placement, not org-wide

Orgs adopt the Cosmos theme at their own pace, and one org can have pages on both looks
during a transition. A per-placement setting lets the card match whichever page it sits
on, instead of forcing one choice org-wide.

## Related

- [Configure Check Sets and Rules](configure-check-sets-and-rules.md): every card and Check Set setting
- [Create your first Rule](../installation/03-create-your-first-rule.md): add the card to a record page
