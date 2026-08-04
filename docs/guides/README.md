# Configuration and troubleshooting guides

> [!NOTE]
> On this page, choose a task-focused guide for designing Record Health Check configuration, improving the card experience, drafting with AI, or investigating an unexpected result.

Use these guides after you understand the basic Check Set and Rule model. Each guide owns one
administrator or implementation task and links to the exact metadata or Evaluation Type reference
when you need field-level detail.

## Choose a guide

| What you need to do | Guide | What you will accomplish |
| --- | --- | --- |
| Design a complete readiness review | [Configure Check Sets and Rules](configure-check-sets-and-rules.md) | Turn a Salesforce business question into a Check Set, ordered Rules, outcomes, and release checklist |
| Decide RHC vs Validation Rules or Flow | [Compare to native Salesforce](compare-to-native-salesforce.md) | Choose advisory health checks versus blocking native tools |
| Answer a common Framework question | [FAQ](faq.md) | Find short answers on saves, editions, install paths, events, and Demo Check Sets |
| Run Record Health Check in production | [Operate in production](operate-in-production.md) | Keep events, diagnostics, backups, and subscribers healthy after go-live |
| Give users a corrective next step | [Configure action links](configure-action-links.md) | Pair Fix Message with a safe Action Label and Action URL |
| Match the card to a Lightning page | [Understand adaptive card styling](choose-card-design-system.md) | Use one placement across established Lightning styling and Cosmos without manual configuration |
| Draft configuration with an AI assistant | [Draft configuration with AI](draft-configuration-with-ai.md) | Provide Framework terms, constraints, and a reviewable output format |
| Investigate a result safely | [Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md) | Reveal authorized card and browser-console evidence, then turn it off |

## Recommended path

1. Start with **Configure Check Sets and Rules** when designing a new health review.
2. Add action guidance only when a failed Rule has a clear destination or corrective instruction.
3. Choose the card design system for each Lightning record-page placement.
4. Use AI-assisted drafting as a starting point, then verify every value against the metadata references.
5. Enable Show Diagnostics temporarily only when an authorized user needs runtime evidence.

## Related

- [Documentation home](../README.md)
- [Examples library](../examples/README.md)
- [Technical references](../reference/README.md)
- [Create your first Rule](../installation/03-create-your-first-rule.md)
