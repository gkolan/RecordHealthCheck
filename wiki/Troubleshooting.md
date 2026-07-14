# Troubleshooting

Start with the message shown on the card. Use **Show Diagnostics** only when the standard message
does not provide enough information.

| What you see                                   | What to check                                                                                                                                  |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Health Check Needs Setup**                   | In Lightning App Builder, select an active Check Set for the page object, then save and activate the page.                                     |
| **No active checks**                           | Activate at least one Rule in the selected Check Set.                                                                                          |
| **Skipped**                                    | Review the Rule's applicability settings and Prerequisite Rule. A prerequisite must be in the first 25 active Rules.                           |
| **Unable to Check**                            | Review the reason code, Rule fields, object access, field access, and query or formula.                                                        |
| **System Error**                               | Review the custom Apex class and Salesforce debug logs. Enable diagnostics for authorized administrators if needed.                            |
| Results did not change after an edit           | Select **Rerun** or refresh the record page. V2 does not rerun automatically after save.                                                       |
| No platform event was received                 | Confirm the publishing checkbox is selected, the check ran from Apex or Flow, and the transaction committed. Record-page checks never publish. |
| A Check Set works for one user but not another | Compare permission sets, record access, object access, and field access. Checks run with the current user's access.                            |

## Show more detail safely

An administrator needs both of these settings:

1. Select **Show Diagnostics** on the Check Set.
2. Assign the `Record_Health_Check_Admin` permission set, which includes
   `Record_Health_Check_View_Details`.

Do not place queries, stack traces, credentials, or confidential field values in user-facing
messages. See the full
[Show Diagnostics guide](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/guides/show-diagnostics.md).

## Validate Custom Metadata

Developers can run the included validator after deployment:

```bash
sf apex run --file scripts/apex/validateMetadata.apex --target-org <your-org-alias>
```

For exact reason-code meanings, use the
[reason-code reference](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/v2/reference/reason-codes.md).

## Still blocked?

Open a GitHub issue with the Core version, Salesforce API version, Evaluation Type, reason code,
sanitized Rule settings, and repeatable steps. Do not include record data, access tokens, session
IDs, or full Salesforce org IDs.
