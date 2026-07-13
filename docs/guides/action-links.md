# Action Links and Fix Instructions

Action links give users a read-only next step when a Rule fails.

They are configured on the Rule with:

- **Action Button Label** (`ActionLabel__c`)
- **Action Button URL** (`ActionUrl__c`)
- **Fix Instructions** (`FixMessage__c`)

These fields render only on **FAIL** rows. They do not render on Pass, Skipped, Unable to evaluate, or Error rows.

Record Health Check does not update records. Use action links for navigation, reports, playbooks, and guidance.

## What Users See

When a Rule fails, the card can show:

- A link, using **Action Button Label**
- Supporting text, using **Fix Instructions**

If **Action Button URL** is blank or rejected for safety, **Fix Instructions** can still show.

If **Action Button Label** is blank and the URL is valid, the link label defaults to `Fix this`.

## Allowed URL Formats

Use one of these formats:

- Same-org relative Lightning paths that start with `/lightning/`
- Other same-org relative paths that start with `/`
- External `https://` URLs

Do not use:

- `http://`
- `javascript:`
- `data:`
- `mailto:`
- Protocol-relative URLs such as `//example.com`
- URLs containing backslashes
- URLs that resolve to more than 2000 characters

Unsafe URLs are dropped. Fix Instructions can still render.

## Merge Tokens

Action URLs and Fix Instructions support merge tokens from the current record:

```text
{!record.Id}
{!record.Name}
{!record.OwnerId}
{!record.Owner.ManagerId}
{!record.ParentId}
```

The engine resolves token values before showing the link. Values substituted into URLs are URL-encoded.

## Common Link Patterns

- Open the current Account:
  `/lightning/r/Account/{!record.Id}/view`
- Open the current Account in edit mode:
  `/lightning/r/Account/{!record.Id}/edit`
- Open the Account's Contacts related list:
  `/lightning/r/Account/{!record.Id}/related/Contacts/view`
- Open a report filtered by the current record Id:
  `/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}`
- Open a report filtered by Account name:
  `/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Name}`
- Open a Contact list view:
  `/lightning/o/Contact/list?filterName=Recent`
- Open an internal Salesforce playbook page:
  `/lightning/n/Data_Quality_Playbook`
- Open an external playbook:
  `https://example.com/account-data-quality`

Replace `00Oxxxxxxxxxxxxxxx` with the report Id from your org.

## Report Links

Lightning report links can include filter values such as `fv0`, `fv1`, and `fv2`.

Example:

```text
/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}
```

Use this when the report's first filter expects the current record Id.

Report Ids are created when the report is deployed or created in the org. To get the Id:

1. Open the report in Salesforce.
2. Copy the `00O...` value from the browser URL.
3. Paste it into **Action Button URL**.

A report link is org-specific. A report Id from one org does not work in another org.

## Examples

### Missing Contact Email

Use this when a failed Rule means a user needs to fix related Contacts.

Action Button Label:
`View contacts to fix`

Action Button URL:
`/lightning/r/Account/{!record.Id}/related/Contacts/view`

Fix Instructions:
`Open the account's contacts and add the missing email addresses.`

This pattern ships in the `Example_Every_Contact_Has_Email` sample Rule.

### High Priority Open Cases

Use this when a failed Rule means a user needs to review a filtered report.

Action Button Label:
`View high-priority cases`

Action Button URL:
`/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}`

Fix Instructions:
`Review the open high-priority cases before your next renewal or executive conversation.`

This pattern ships in the `Example_No_High_Priority_Cases` sample Rule. Replace the report Id with the Id from your org.

### External Playbook

Use this when the next step is a help page outside Salesforce.

Action Button Label:
`Open data quality playbook`

Action Button URL:
`https://example.com/data-quality-playbook`

Fix Instructions:
`Review the playbook before changing ownership or account tier fields.`

Only `https://` external links are allowed.

## Review Checklist

- [ ] The link is read-only navigation, not an automated update.
- [ ] The URL starts with `/` or `https://`.
- [ ] Report links use the report Id from the target org.
- [ ] Merge tokens refer to fields readable on the current record.
- [ ] Fix Instructions still make sense if the link is hidden.
- [ ] The Rule has a useful failure message before the action link.
