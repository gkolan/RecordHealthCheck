# Record Health Check

**See a Salesforce record's data health when you open it—without changing the record.**

Record Health Check is a metadata-driven framework that evaluates the record on screen and shows a
card of results: each check reads as **Pass**, **Fail**, **Skipped**, or **Unable to Check**, and a
failing check is flagged **Critical**, **Warning**, or **Info**. You define the checks declaratively
in Custom Metadata; the framework runs them and renders the card.

It is **advisory and read-only**. Because it evaluates at read time instead of save time, it can
look across related records, compare aggregates, and surface data that predates your rules — things
a validation rule cannot. It never blocks a save and never writes a field. When you need to _block_
a save, use validation rules, Flow, or Apex; use Record Health Check to _reveal_ what needs attention.

## The ecosystem — three repositories

Everything belongs to exactly one of three repositories, so you install only what you need.

| Repository                                                                                          | What it gives you                                                                                               | Status                                    |
| --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Core** — `RecordHealthCheck`                                                                      | The card, Check Set and Rule Custom Metadata Types, permissions, Apex and Flow actions, and one working example | **Shipping (V2)**                         |
| **Examples** — [`RecordHealthCheck-Examples`](https://github.com/gkolan/RecordHealthCheck-Examples) | Reusable scenario packs you install and adapt — data quality, readiness, relationships, and more                | **Shipping**                              |
| **Extensions** — `RecordHealthCheck-Extensions`                                                     | Optional tools that use Core platform events and Apex methods for history, notifications, or scheduled runs     | **Planned — first extension in progress** |

Core stands on its own. Examples and Extensions are independently installable and never require a
change to Core.

## Pick your path

- **Evaluating it?** Read this page, then [[Install the Core]] and drop the hero example onto an
  Account page — you'll see a working card in about ten minutes.
- **Setting it up?** [[Install the Core]] → [[Author Checks]] to build your own Check Sets and Rules.
- **Building on it?** [[Explore the Examples]] for packs and the pattern library,
  [[Integrate]] for Apex, Flow, and platform events, and [[Extend]] for optional add-ons.

## At a glance

- **Author declaratively** — a **Check Set** per object holds a list of **Rules**; add or retune
  checks in metadata without touching the component.
- **Four ways to check** — a formula, one SOQL query, a comparison of two queries, or your own Apex.
- **Runs your way** — automatically as the page loads, or on demand when the user clicks **Run**.
- **Safe by design** — page-load evaluation only displays; it never fires automation. Platform-event
  publication is opt-in and off by default. See [[Extend]].

---

New to it? Start with **[[Install the Core]]**. For the V2 changes, read **[[What Is New in V2]]**.
Detailed behavior is documented in the
[design specification](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/record-health-check-design-spec.md).
