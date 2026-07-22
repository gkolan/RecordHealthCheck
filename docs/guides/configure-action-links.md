# Configure action links

> [!NOTE]
> On this page, turn a failed Rule into a useful next step by pairing a clear Fix Message with a safe, context-aware action link when navigation genuinely helps.
>
> **Reference**
>
> - This guide covers allowed URL formats, merge tokens, and link patterns.
> - For the field definitions, use the [Rule fields reference](../metadata/fields-rule.md).

Use **Fix Message**, **Action Label**, and **Action URL** to turn a failed Rule into a clear next
step. The Rule can guide a user to a Salesforce record, related list, report, Knowledge article,
external site, or prefilled create page instead of requiring the user to search for the destination.

## What you will learn

| Goal | Framework setting |
| --- | --- |
| Explain what the user should correct | **Fix Message** (`FixMessage__c`) |
| Give the destination a clear button label | **Action Label** (`ActionLabel__c`) |
| Open a verified Salesforce or HTTPS destination | **Action URL** (`ActionUrl__c`) |
| Reuse the current record or parent values in guidance | `{!record.FieldApiName}` merge tokens |

These settings are configured on the Rule:

- [**Action Label** (`ActionLabel__c`)](../metadata/fields-rule.md#action-label-actionlabel__c)
- [**Action URL** (`ActionUrl__c`)](../metadata/fields-rule.md#action-url-actionurl__c)
- [**Fix Message** (`FixMessage__c`)](../metadata/fields-rule.md#fix-message-fixmessage__c)

These fields render only on `FAIL` rows, not on `PASS`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`
rows.

Rendering or opening the link does not make Record Health Check perform DML. A user can still edit or
create a record on the destination page and choose to save it.

## What users see

When a Rule fails, the card can show:

- A link, using **Action Label**
- Supporting text, using **Fix Message**

If **Action URL** is blank or rejected for safety, **Fix Message** can still show.

If **Action Label** is blank and the URL is valid, the link label defaults to `Fix this`.

## Allowed URL formats

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

Unsafe URLs are dropped. Fix Message can still render.

## Merge tokens

Action URLs and Fix Message support merge tokens from the current record:

```text
{!record.Id}
{!record.Name}
{!record.OwnerId}
{!record.Owner.ManagerId}
{!record.ParentId}
{!record.Parent.Parent.Name}
{!record.Parent.Customer_Tier__c}
```

The engine resolves token values before showing the link. Values substituted into URLs are URL-encoded.
Relationship paths can traverse up to five levels. Custom fields are supported when the field exists
in the target org and the running user can read it; replace `Customer_Tier__c` with a real field API
name from your data model.

## Common link patterns

| Goal | Action URL pattern |
| --- | --- |
| Create a Case with Account, Subject, and Origin defaults | `/lightning/o/Case/new?defaultFieldValues=AccountId={!record.Id},Subject=Review%20{!record.Name},Origin=Web` |
| Open a Knowledge article | `/lightning/r/Knowledge__kav/ka0xxxxxxxxxxxxxxx/view` |
| Open an external support playbook | `https://support.example.com/account-readiness?accountId={!record.Id}` |
| View the current Account | `/lightning/r/Account/{!record.Id}/view` |
| Edit the current Account | `/lightning/r/Account/{!record.Id}/edit` |
| Open the Account's Contacts related list | `/lightning/r/Account/{!record.Id}/related/Contacts/view` |
| Open a report filtered by record ID | `/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}` |
| Open a report with record and parent filters | `/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}&fv1={!record.Parent.Name}` |
| Open a Contact list view | `/lightning/o/Contact/list?filterName=Recent` |
| Open an internal Lightning page | `/lightning/n/Data_Quality_Playbook` |

Replace the placeholder `00O...`, `ka0...`, object, relationship, field, and page API names with
values that exist in the target org. A default-field-values URL prefills the create form; the user
still reviews and saves the record.

## Report links

Lightning report links can include filter values such as `fv0`, `fv1`, and `fv2`.

Example:

```text
/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}
```

Use this when the report's first filter expects the current record Id.

Report Ids are created when the report is deployed or created in the org. To get the Id:

1. Open the report in Salesforce.
2. Copy the `00O...` value from the browser URL.
3. Paste it into **Action URL**.

A report link is org-specific. A report Id from one org does not work in another org.

## Examples

### Missing Contact email

Use this when a failed Rule means a user needs to fix related Contacts.

Action Label:
`View contacts to fix`

Action URL:
`/lightning/r/Account/{!record.Id}/related/Contacts/view`

Fix Message:
`Open the account's contacts and add the missing email addresses.`

This pattern ships in the `Example_Every_Contact_Has_Email` sample Rule.

### High-priority open Cases

Use this when a failed Rule means a user needs to review a filtered report.

Action Label:
`View high-priority cases`

Action URL:
`/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}`

Fix Message:
`Review the open high-priority cases before your next renewal or executive conversation.`

This pattern ships in the `Example_No_High_Priority_Cases` sample Rule. Replace the report Id with the Id from your org.

### External playbook

Use this when the next step is a help page outside Salesforce.

Action Label:
`Open data quality playbook`

Action URL:
`https://example.com/data-quality-playbook`

Fix Message:
`Review the playbook before changing ownership or account tier fields.`

Only `https://` external links are allowed.

## Review checklist

- [ ] The link itself does not perform DML or launch hidden automation.
- [ ] The URL starts with `/` or `https://`.
- [ ] Report links use the report Id from the target org.
- [ ] Merge tokens refer to fields readable on the current record.
- [ ] Fix Message still makes sense if the link is hidden.
- [ ] The Rule has a useful failure message before the action link.

## Related

- [Configure Check Sets and Rules](configure-check-sets-and-rules.md): every card and Check Set setting
- [Rule fields](../metadata/fields-rule.md): field definitions for `ActionLabel__c`, `ActionUrl__c`, and `FixMessage__c`
- [Field limits](../reference/reference-fields-limits.md): character limits for these fields
- [Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md): troubleshooting a Rule that fails to evaluate
