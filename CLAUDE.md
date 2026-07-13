# RecordHealthCheck — instructions for Claude

Project-wide guidance for Claude Code sessions in this repo. The V2 release workspace has its
own rules in [`releases/v2/CLAUDE.md`](releases/v2/CLAUDE.md); read that when working under
`releases/v2/`.

## Salesforce CLI network access — read before running any `sf` command

`sf` commands (org create, deploy, retrieve, apex run test, org open, …) reach the Salesforce
API and the macOS credential store. Claude Code's **default Bash sandbox blocks that network
access**, which surfaces as a DNS error, e.g.:

```
Error (ENOTFOUND): request to https://gkdomain-dev-ed.my.salesforce.com/... failed,
reason: getaddrinfo ENOTFOUND gkdomain-dev-ed.my.salesforce.com
```

This is **environmental (the sandbox), not a Salesforce outage.** The DevHub `gkSfdcDevHub`
(instance `gkdomain-dev-ed.my.salesforce.com`, API `67.0`) is normally reachable. To avoid it:

1. **Run `sf` commands with the sandbox disabled** — set `dangerouslyDisableSandbox: true` on the
   Bash tool call (this is the actual fix for `ENOTFOUND`; the env vars below do not repair a real
   OS-level failure).
2. **Quiet the CLI and skip its preflight DNS check** by exporting:
   - `SF_DISABLE_LOG_FILE=true`
   - `SFDX_DISABLE_DNS_CHECK=true` — bypasses only the CLI's _preliminary_ DNS check, not the real
     request.

Command pattern:

```bash
SF_DISABLE_LOG_FILE=true SFDX_DISABLE_DNS_CHECK=true \
  sf org create scratch \
    --definition-file config/project-scratch-def.json \
    --alias <alias> --target-dev-hub gkSfdcDevHub \
    --duration-days 1 --wait 30 --json
```

If `ENOTFOUND` still appears from the _actual_ API request after disabling the sandbox, the
network/DNS is genuinely down — retry, then wait for recovery. Do **not** conclude "Salesforce
outage" from a sandboxed run alone; re-run unsandboxed first.

Scratch orgs expire quickly (often same-day/1–7 days). If a previously-used alias is unreachable,
recreate it from `config/project-scratch-def.json` rather than assuming the product is broken.
