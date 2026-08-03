# Understand adaptive card styling

> [!NOTE]
> Use this page to understand how Record Health Check follows the active Salesforce design system without a per-component theme setting.

## One component placement

Add Record Health Check to a Lightning record page and select its Check Set. There is no Design
System property to maintain. The same placement works when the page uses established SLDS styling
or the Salesforce Cosmos theme.

Record Health Check uses supported semantic SLDS global styling hooks. In Cosmos, the current
surface, text, border, radius, spacing, and shadow hooks supply the visual treatment. Where a
semantic hook is unavailable, the stylesheet falls back to an established Lightning token and then
to a safe static value.

This approach avoids guessing the org theme from browser classes or undocumented runtime state.
Lightning base components continue to follow the design system selected by Salesforce.

## What remains consistent

The design system may change color, radius, spacing, and elevation. Record Health Check preserves:

- semantic structure and heading order;
- keyboard navigation and focus behavior;
- assistive labels and live-region announcements;
- Rule ordering, statuses, actions, and diagnostics;
- responsive behavior and record-page configuration.

## Verification checklist

Use this checklist before release:

- Place the component on representative pages in established Lightning and Cosmos environments.
- Verify default, loading, empty, passed, failed, skipped, unable, and error states.
- Verify diagnostic and narrow-width states.
- Run the SLDS linter and Jest suite after every styling change.

## Related

- [Install and verify](../installation/02-install-and-verify.md)
- [Configure metadata](../metadata/README.md)
- [Troubleshoot with diagnostics](troubleshoot-with-show-diagnostics.md)
