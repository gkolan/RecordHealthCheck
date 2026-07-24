# Reference: Architecture

> [!NOTE]
> On this page, understand why Record Health Check exists, how the Framework is layered, how a check runs safely, and which classes own each concern.

Record Health Check is a metadata-driven Framework for advisory, read-time evaluation on a Salesforce
record. Field definitions and Evaluation Type operators are in the
[related references](#related-references).

## 1. The problem

Salesforce already answers “may this change be saved?” (Validation Rules, Flow, triggers) and
“where are the patterns?” (reports, dashboards). It does not answer, at **record read time**:

> Is this record ready to act on?

That gap has three properties that force a separate design:

| Property | Meaning |
| --- | --- |
| Retroactive | Rules must judge data that was saved before the Rule existed. Save-time tools cannot. |
| Contextual | Answers often need related records, totals, and time windows, not only the current record. |
| Advisory | Guidance must not update the record and must not block unrelated saves. |

Record Health Check fills that gap with a **metadata-driven, read-only Framework** on the Lightning
record page. The same engine is also available from Apex and Flow.

## 2. Principles

| # | Principle | Consequence |
| --- | --- | --- |
| 1 | Configuration over code | Business meaning lives in Custom Metadata; the engine stays generic |
| 2 | Fail visible, never silent | Every failure returns a clear status and a stable reason code |
| 3 | Security is not optional | SOQL runs `WITH USER_MODE`; `WITH SYSTEM_MODE` is rejected |
| 4 | Hard limits by design | Rules per Set, query rows, merge tokens, and message size all have fixed maximums |
| 5 | One source of truth per fact | Allowed values and limits are shared by runtime checks and deploy-time validation |
| 6 | Stable versioned responses | Integrations key on reason codes and version fields, not on display wording |
| 7 | Plain language | Public names and messages use Salesforce Setup vocabulary |

A misconfigured Rule should produce a clear card outcome, never stop someone from saving an
unrelated edit. That is why administrator-authored formulas and SOQL are acceptable here, and why
the same flexibility would be unsafe in a Validation Rule or trigger.

## 3. What the Framework includes

| Surface | Role |
| --- | --- |
| Custom Metadata Check Sets and Rules | Define what to evaluate and how to explain results |
| Apex engine and evaluators | Run Formula, Query, Compare two queries, or Apex Rules |
| Lightning Web Component | Record-page card that shows results as each Rule finishes |
| Public Apex API and Flow actions | Same engine for automation |
| Opt-in platform events | Set run and Rule result signals after deliberate runs |
| Diagnostics log event | ERROR details published through `RecordHealthCheckLogger.flush()` |
| User and Admin permission sets | Run checks vs configure and troubleshoot |

The Framework evaluates and explains. Storing, retaining, and reporting on events is the job of
subscribers (including any extension package), not the Framework.

Three version numbers stay independent on purpose: the **product** version, the **Apex and Flow
response** version, and the **platform event** version.

## 4. Layers

Higher layers call lower layers. Lower layers do not call back up. Entry points do not contain
evaluation logic. Result and definition classes do not depend on services.

```text
L5  Entry points
    RecordHealthCheck · Flow actions · RecordHealthCheckController
    Limits, run ids, platform event publication

L4  Engine
    RecordHealthCheckEngine
    Applicability, prerequisites, evaluator choice, result shaping, diagnostics access

L3  Evaluators
    Formula · SOQL · Compare two queries · Apex
    Plus QueryEvaluatorSupport for shared query execution

L2  Shared services
    Config, SOQL template, comparison, value handling, merge tokens,
    describe cache, logger, access, constants, validators

L1  Results and definitions
    Result, SetResult, Definition, Context, Rule interface, AdminDetail, …
```

The Lightning controller and the public Apex and Flow entry points all call the same engine. There
is no separate “UI-only” evaluation path.

## 5. How a check runs

At a high level the engine:

1. Loads the Check Set and Rule (a Rule cannot be run outside its Set).
2. Applies applicability and prerequisites.
3. Sends the Rule to the matching Evaluation Type.
4. Shapes Found/Expected, severity, messages, and reason codes.
5. Shows diagnostics detail only when the user is allowed to see it.

**Record page:** the component loads definitions, then evaluates one Rule at a time so results can
appear as they finish. When Rule result events are enabled, each evaluate can publish one. After a
**user-started** run, `completeRun` may publish the Set completed event. Pass/Fail/Skipped counts
for that event are calculated again on the server. The browser does not supply those totals.

**Apex and Flow:** `runRule` / `runSet` (and the packaged Flow actions) use the same engine. When
enabled, they may publish lifecycle events, then flush any buffered ERROR log events.

Evaluation is read-only (`with sharing`, `WITH USER_MODE`). Publishing lifecycle and log platform
events is the intentional write on that path.

## 6. Results and versions

Each Rule returns one of: **Pass**, **Fail**, **Skipped**, **Unable to evaluate**, or **Error**,
with a stable **reason code** when applicable. Display text can change; reason codes are what
integrations should rely on. See [Reason Codes](reference-reason-codes.md).

Apex and Flow responses use `contractVersion` **1.0**. Lifecycle events use their own **1.0**
version fields. New codes and fields may appear later; existing ones keep their meaning.

Configuration is checked in two places that share the same allowed values: **when a check runs**
(ConfigService / RuleValidator) and **at deploy or CI time** (MetadataValidator), so those checks
cannot silently disagree.

## 7. Security and safety

| Concern | Approach |
| --- | --- |
| Data access | Running user’s object and field access via `WITH USER_MODE` |
| Administrator SOQL | Template checks; DML keywords rejected; `SYSTEM_MODE` rejected |
| Merge tokens | Namespaced tokens only; message size and token-count maximums |
| Fix links | Same-org relative or `https://` only; length limit; unsafe URLs dropped |
| Diagnostics | Extra detail requires `Record_Health_Check_View_Diagnostics` |
| Lifecycle trust | Server recalculates Set counts in `completeRun`; LWC `source` is checked on the server |

## 8. Hard limits

Exact numbers live in [Field limits](reference-fields-limits.md) and shared constants. In short:

- Rules per Check Set, query rows, concurrent Apex work, merge tokens, and finished message length
  all have fixed maximums.
- A badly written Rule should return a reason code, not quietly hit Salesforce governor limits.
- The card evaluates Rules one at a time for responsiveness. When publishing the Set completed
  event, `completeRun` may run the Set again on the server so totals are trustworthy.

## 9. Extending and monitoring

| Extension | Use when |
| --- | --- |
| Formula / Query / Compare Rules | Most business questions |
| Custom Apex evaluators (`RecordHealthCheckRule`) | Logic those types cannot express cleanly |
| Flow actions / Apex API | Automation and integrations |
| Platform event subscribers | Follow-on automation after deliberate runs |

Monitoring:

- Structured `[RHC]` debug lines for operators.
- `Record_Health_Check_Log__e` for ERROR details (`flush()` at the end of the Apex transaction).
- Opt-in Set Run and Rule Result events for integrators.

## 10. Ownership map

Use this when changing code. If responsibility moves, update this table in the same change.

### Entry points

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheck` | Public Apex `runRule` / `runSet`, limits, lifecycle publish |
| `RecordHealthCheckRunRuleFlowAction` / `…RunSetFlowAction` | Packaged Flow actions |
| `RecordHealthCheckController` | LWC: availability, definitions, `evaluateCheck`, `completeRun` |
| `RecordHealthCheckEngine` | One-Rule evaluation path |
| `RecordHealthCheckLifecyclePublisher` | Opt-in Set/Rule platform events |
| `RecordHealthCheckRunContext` | Values carried for one run |

### Config and validation

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckConfigService` | Load Sets/Rules; definition and availability responses |
| `RecordHealthCheckRuleValidator` | Per-Rule checks when a Rule runs |
| `RecordHealthCheckMetadataValidator` | Deploy and CI metadata audit |
| `RecordHealthCheckConfigValidator` / `RecordHealthCheckConstants` | Shared helpers and allowed values |
| `RecordHealthCheckReasonCodes` | Restricted reason-code helpers |
| `RecordHealthCheckSetAvailability` | Active/inactive Sets for an object |

### Evaluators and shared services

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckFormulaEvaluator` | FormulaEval checks |
| `RecordHealthCheckSoqlEvaluator` | Single-query checks |
| `RecordHealthCheckCompareQueriesEvaluator` | Dual-query checks |
| `RecordHealthCheckQueryEvaluatorSupport` | Shared query execution and empty-result handling |
| `RecordHealthCheckApexEvaluator` | Custom Apex evaluator dispatch |
| `RecordHealthCheckComparisonEngine` | Operators and Found/Expected formatting |
| `RecordHealthCheckSoqlTemplate` | SOQL safety checks and cleanup |
| `RecordHealthCheckValueResolver` | Convert values and compare them safely |
| `RecordHealthCheckDescribeCache` | Describe results reused within one transaction |
| `AccountHasRecentActivityCheck` | Shipped example Apex evaluator |

### Merge tokens

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckTemplateService` | Resolve tokens; enforce size limits |
| `RecordHealthCheckTokenRegistry` / `Token` / `TokenIssue` | Allowed tokens and parse results |
| `RecordHealthCheckMergeContext` | Values available while resolving a message |

### Logging, access, and responses

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckLogger` | `[RHC]` logs; ERROR buffer; `flush()` → log event |
| `RecordHealthCheckAccess` | Diagnostics permission check |
| `RecordHealthCheckValueSource` | Comparison diagnostic detail |
| `RecordHealthCheckSetPicklist` | App Builder Check Set picker |
| `RecordHealthCheckResult` / `SetResult` | Apex and Flow responses (`1.0`) |
| `RecordHealthCheckDefinition` / `DefinitionResponse` | Definition payload for the LWC |
| `RecordHealthCheckAdminDetail` | Structured diagnostics |
| `RecordHealthCheckContext` / `RecordHealthCheckRule` | Custom Apex evaluator input / interface |
| `RecordHealthCheckEvaluatorException` | Evaluator failure with a reason code |

### Lightning Web Component

One bundle, four modules: `recordHealthCheck`, `healthCheckRunner`, `healthCheckModel`,
`healthCheckPresentation`. Keep them as one component.

## Related references

| Need | Doc |
| --- | --- |
| Fields and limits | [Check Set fields](../metadata/fields-check-set.md), [Rule fields](../metadata/fields-check-rule.md), [Field limits](reference-fields-limits.md) |
| Merge tokens | [Merge tokens](reference-merge-tokens.md) |
| Apex / Flow / LWC | [Apex API](reference-apex-api.md), [Flow actions](../integration/flow-actions.md), [Lightning component](../integration/lightning-component.md) |
| Events | [Lifecycle events](../integration/lifecycle-events.md), [Log event](../metadata/event-log.md) |
| Reason codes | [Reason Codes](reference-reason-codes.md) |
| Concepts | [How it works](../installation/01-how-it-works.md) |
| Upgrade | [Upgrading](../installation/04-upgrading.md) |

## Related

- [Documentation index](../README.md)
- [Integration overview](../integration/README.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
