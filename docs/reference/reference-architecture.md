# Reference: Architecture

> [!NOTE]
> On this page, review the whole Record Health Check architecture: where it sits relative to save-time automation, the configuration model, the runtime path of a single Rule, the security and limit model, the contracts other systems bind to, and which class owns each behavior.

Record Health Check evaluates Custom Metadata Rules against one Salesforce record at read time and
returns a status, a reason code, and display text per Rule. Rules are grouped into a **Check Set**
bound to one object. Evaluation is read-only and runs in the calling user's context. The same Apex
engine serves the Lightning Web Component, the public Apex API, and two Flow actions.

Field-level detail, operator behavior, and configuration procedure live in the pages listed under
[Related references](#related-references).

## 1. Position in the platform

Save-time automation evaluates a record only when that record is saved, in the transaction that
saves it, with the authority to reject the DML. Three properties of read-time evaluation put it
outside that model:

| Property | Design consequence |
| --- | --- |
| Retroactive | Rules must evaluate records committed before the Rule existed, so evaluation cannot be bound to a DML event |
| Contextual | Inputs include related records, aggregates, and time windows, so evaluation needs SOQL beyond the record being viewed |
| Advisory | Evaluation performs no DML on the evaluated record and cannot fail a save, so a Rule failure has no transactional effect |

| Mechanism | Evaluates | Failure effect |
| --- | --- | --- |
| Validation Rule, record-triggered Flow, Apex trigger | The record being saved, in the save transaction | Blocks the DML |
| Report, dashboard, list view | Many records, asynchronously to any one record | None |
| Record Health Check | One record on read, per Check Set | Returns `FAIL` at the configured severity, with no transactional effect |

The advisory boundary is what makes administrator-authored formulas and SOQL tolerable in this
Framework: a malformed Rule becomes a documented status on one card, while the same input inside
a Validation Rule or trigger would block saves org-wide.

## 2. Design principles

| # | Principle | Consequence in the code |
| --- | --- | --- |
| 1 | Configuration over code | Rule semantics live in Custom Metadata; the Apex engine stays generic |
| 2 | Fail visible, never silent | Every failure returns a documented status and a stable reason code |
| 3 | Security is not optional | SOQL runs `WITH USER_MODE`; `WITH SYSTEM_MODE` is rejected before execution |
| 4 | Hard limits by design | Rules per Check Set, query rows, merge tokens, and message size all have fixed maximums |
| 5 | One source of truth per fact | Allowed values and caps are shared by runtime checks and deploy-time validation |
| 6 | Stable versioned responses | Integrations key on reason codes and version fields, never on display wording |
| 7 | Plain language | Public names and messages use Salesforce Setup terms |

## 3. What ships in the package

| Surface | Role |
| --- | --- |
| `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` | Rule definitions, display settings, optional lifecycle publication, and default-on error publication |
| Apex engine and four evaluators | Formula, Query, Compare two queries, and Apex evaluation |
| Lightning Web Component | Record-page card, one Apex call per Rule, progressive reveal |
| Public Apex API and two invocable Flow actions | The same engine for automation and integrations |
| `Record_Health_Check_Set_Run__e` and `Record_Health_Check_Rule_Result__e` | Optional lifecycle events after deliberate runs |
| `Record_Health_Check_Log__e` | `ERROR` detail published through `RecordHealthCheckLogger.flush()` |
| Two Permission Sets and one Custom Permission | Separate execution access from diagnostics access |

The Framework returns results and publishes events. It persists nothing: retention, reporting, and
follow-on automation belong to platform event subscribers.

## 4. The configuration model

Configuration is Custom Metadata, so it deploys as metadata, consumes no record storage, and its
SOQL does not count against the query governor limits that Rule queries do.

```text
Record_Health_Check_Set__mdt          one card on one object
  ObjectApiName__c                    which object the card belongs to
  IsActive__c, CardRunMode__c         whether it runs, and on load or on request
  ShowDiagnostics__c                  whether troubleshooting detail may be shown
  PublishRunEvent__c                  whether a completed run publishes an event
  PublishErrorLogEvent__c             whether ERROR logs publish events (default on)
      |
      | one Check Set has many Rules (metadata relationship)
      v
Record_Health_Check_Rule__mdt         one row on the card
  EvaluationType__c                   FORMULA | QUERY | COMPARE_TWO_QUERIES | APEX
  ApplicabilityMode__c                whether this Rule applies to this record at all
  PrerequisiteRule__c                 another Rule that must pass first
  ComparisonOperator__c               how Found is compared to Expected
  FailureSeverity__c                  CRITICAL | WARNING | INFO
  CheckTitle__c, FailureMessage__c    what the user reads
```

A Rule always belongs to a Check Set, and the server enforces that relationship on every call. A
caller cannot evaluate a Rule by name outside its Check Set, and cannot evaluate a Rule whose Check
Set is inactive or points at a different object.

| Evaluation Type | Input | Evaluation mechanism |
| --- | --- | --- |
| `FORMULA` | Fields on the record and fields reachable by Salesforce formula syntax | `FormulaEval` against the loaded record, then the configured operator |
| `QUERY` | One administrator-authored SOQL query | Rows or an aggregate reduced by `QueryResultHandling__c`, then the operator |
| `COMPARE_TWO_QUERIES` | Two administrator-authored SOQL queries | One field extracted from each result set and compared as lists |
| `APEX` | A class implementing `RecordHealthCheckRule` | The class returns its own result inside the engine path |

## 5. Layers

Higher layers call lower layers, and lower layers never call back up. Entry points hold no
evaluation logic. Result and definition classes depend on nothing else in the Framework.

```text
L5  Entry points
    RecordHealthCheck (Apex API) | Flow actions | RecordHealthCheckController (LWC)
    Owns: request limits, run ids, source values, platform event publication

L4  Engine
    RecordHealthCheckEngine
    Owns: rule loading, prerequisites, applicability, evaluator choice,
          result shaping, diagnostics visibility

L3  Evaluators
    Formula | SOQL | Compare two queries | Apex
    Plus RecordHealthCheckQueryEvaluatorSupport for shared query execution

L2  Shared services
    Config, SOQL template safety, comparison, display formatting, value handling,
    merge tokens, describe cache, logger, access, constants, validators

L1  Results and definitions
    Result, SetResult, Definition, Context, Rule interface, AdminDetail
```

The Lightning controller, the public Apex API, and the Flow actions all call the same engine. There
is no separate evaluation path for the user interface, so a result seen on the card and a result
returned to Flow come from the same code.

## 6. How one Rule is evaluated

Every surface ends up in `RecordHealthCheckEngine.evaluate`, which returns exactly one result and is
designed never to throw. Catchable failures become a status and a reason code. Only Apex governor
limit exceptions remain uncatchable, as they do for any Apex API.

1. **Normalize the request.** Check Set name, Rule name, and run id are trimmed and length-capped
   before anything else uses them. A missing record id returns `UNABLE_TO_EVALUATE` with
   `NO_RECORD_CONTEXT`.
2. **Load the Rule inside its Check Set.** Inactive Rules are loaded too, so the result can say
   `RULE_INACTIVE` rather than the misleading `RULE_NOT_FOUND`.
3. **Confirm the Check Set context.** The Check Set must be active and must target the object of the
   record being evaluated, otherwise the result is `CONFIG_INACTIVE` or `OBJECT_MISMATCH`. This step
   also reads `ShowDiagnostics__c` for the run.
4. **Apply the prerequisite Rule.** If the Rule names a prerequisite, that Rule is evaluated first. A
   prerequisite that does not pass produces `SKIPPED` with `PREREQUISITE_NOT_MET`. A loop in the
   configuration produces `CIRCULAR_DEPENDENCY` instead of recursing.
5. **Validate the Rule for this run.** Runtime validation confirms the Rule's fields are complete and
   consistent for its Evaluation Type, and returns `INVALID_CONFIG` when they are not.
6. **Load the record.** The query runs `WITH USER_MODE` and selects only the fields the Rule needs,
   including fields found by walking formula dependencies. No access produces
   `RECORD_NOT_ACCESSIBLE`, not a thrown exception.
7. **Apply the applicability check.** `ALL_RECORDS`, `WHEN_FORMULA_TRUE`, or
   `WHEN_COUNT_QUERY_MATCHES` decides whether this Rule applies to this record right now. A Rule that
   does not apply is `SKIPPED` with the administrator's configured message.
8. **Route to the evaluator.** Formula, SOQL, Compare two queries, or Apex produces Found, Expected,
   and a status.
9. **Format Found and Expected.** The selected display format is applied without changing the raw
   values used for the comparison. Each side and each list row keeps its own currency where one is
   available.
10. **Resolve merge tokens in the messages.** A bad token changes how the message is handled, never
   the status.
11. **Attach the fix link on failure only.** The action URL is token-resolved against the record, then
    cleaned up before it can become a link.
12. **Log the outcome.** `PASS` and `SKIPPED` log at debug level, `FAIL` at info, and anything else at
    warn, all through the shared logger.
13. **Apply Check Set flags.** Diagnostics detail is attached only when the Check Set enables it and
    the running user holds the diagnostics permission.

Two caches keep a single transaction efficient without leaking between runs. Describe results are
reused for the whole transaction. Rule results are reused only while one top-level evaluation walks
its prerequisite chain, then cleared, so a later call in the same transaction never sees a stale
result.

## 7. Entry points

| Entry point | Used by | What it adds around the engine |
| --- | --- | --- |
| `RecordHealthCheck.runRule` and `runSet` | Apex, batch, scheduled jobs, tests | Run ids, request limits, event publication, log flush |
| `RecordHealthCheckRunRuleFlowAction` | Flow Builder | Invocable inputs and a versioned response, including result JSON |
| `RecordHealthCheckRunSetFlowAction` | Flow Builder | The same for a whole Check Set |
| `RecordHealthCheckController` | The Lightning card | Availability, definitions, one evaluate call per Rule, and `completeRun` |

Each entry point supplies a **source** value that travels with the run. `APEX_API`, `FLOW`,
`USER_INITIATED`, `SCHEDULED`, and `BATCH` are publishable. Automatic card loads carry
`RUN_ON_LOAD`, which is not publishable, so page views generate no event volume. The browser may
request only the two Lightning values, and the server substitutes `RUN_ON_LOAD` for anything else.

**Lightning record page:** the component calls `getCheckDefinitions` once, then `evaluateCheck` once
per Rule, at most five calls in flight, so each Rule is its own Apex transaction. On a
`USER_INITIATED` run, `completeRun` re-evaluates the Check Set server-side and publishes the Set
completed event with counts computed from that re-evaluation, not from browser-supplied results.

**Apex and Flow:** `runRule` and `runSet` evaluate in one transaction, defer publication until the
outermost call returns, then flush held `ERROR` log events.

Evaluation itself is read-only, with `with sharing` classes and `WITH USER_MODE` queries. Publishing
lifecycle and log platform events is the one intentional write on that path.

## 8. Results and contracts

Every Rule returns exactly one status, with a stable reason code where one applies.

| Status | Meaning |
| --- | --- |
| `PASS` | The configured comparison held |
| `FAIL` | The comparison did not hold, carrying the `FailureSeverity__c` value |
| `SKIPPED` | The applicability check excluded the record, or a prerequisite Rule did not pass |
| `UNABLE_TO_EVALUATE` | Configuration, access, or input data prevented a determinate answer |
| `ERROR` | An unhandled evaluator or platform failure, normalized at the boundary |

Three version numbers move independently.

| Version | Applies to | Current value |
| --- | --- | --- |
| Response contract | Apex and Flow results, in `contractVersion` | `1.0` |
| Event contract | The `ContractVersion__c` field on each platform event | `1.0` |
| Product version | The release itself, reported as `CoreVersion__c` on events | Independent of both |

Additive fields may appear inside a contract version, so consumers must ignore fields they do not
recognize. Removing or renaming a public operation, field, status, or reason value requires a new
contract version. Branch automation on statuses and [reason codes](reference-reason-codes.md), never
on administrator-authored display text.

## 9. Security model

| Concern | Approach |
| --- | --- |
| Record and field access | The running user's own access, enforced by `WITH USER_MODE` on every query |
| Administrator-authored SOQL | Template checks reject DML keywords and `WITH SYSTEM_MODE`, then inject `WITH USER_MODE` in the correct position |
| Rule scope | A Rule is always loaded through its Check Set, so no caller can evaluate an arbitrary or inactive Rule by name |
| Merge tokens | Only known tokens resolve, with caps on token count and completed message size |
| Fix links | Same-org relative paths or `https://` only, length-capped, and checked again in the component before use as a link |
| Diagnostics detail | Requires the `Record_Health_Check_View_Diagnostics` Custom Permission and a Check Set that enables Show Diagnostics |
| Event trust | The server recalculates Set counts in `completeRun`, and the browser-supplied source value is validated server-side |
| Error messages | Public boundaries return a safe message and a reason code; raw exception text stays in diagnostics |

Access is split into two Permission Sets. `Record_Health_Check_User` grants the ability to run
checks. `Record_Health_Check_Admin` adds the diagnostics Custom Permission and the metadata
validation surface for troubleshooting sessions.

## 10. Limits and governor safety

Stored field capacities live in [Field limits](reference-fields-limits.md); runtime caps live in
`RecordHealthCheckConstants`.

| What is capped | Cap | Enforcement point |
| --- | --- | --- |
| Rules per Check Set | 25 | `RecordHealthCheckConfigService` truncates and logs a warning; the deploy-time audit reports it |
| Rows returned by one Rule query | 2,000 | `RecordHealthCheckSoqlTemplate` rewrites the outer `LIMIT` |
| Evaluations per Apex or Flow request | 15 | `RecordHealthCheck` before the first evaluation |
| Records per Flow request | 200 | Both invocable actions before dispatch |
| Merge tokens in one message | 100 | `RecordHealthCheckTemplateService`, returning `TOKEN_LIMIT_EXCEEDED` |
| Resolved message length | 20,000 characters | `RecordHealthCheckTemplateService`, returning `RESOLVED_TEMPLATE_TOO_LONG` |
| Fix link length | 2,000 characters | Apex safe-link handling, then `healthCheckPresentation` before binding an `href` |
| `FormulaEval` calls per transaction | The platform's 100, minus a safety margin | `RecordHealthCheckFormulaEvaluator`, returning `FORMULA_EVAL_LIMIT` |
| Evaluate calls in flight from the card | 5 | `healthCheckRunner` queue |

Each cap converts a limit that would otherwise surface as an uncatchable governor exception into a
documented reason code. The `FormulaEval` counter accumulates across the whole transaction rather
than resetting per Rule, because the platform limit is transaction-wide: a per-Rule counter would let
a loop in Flow or batch Apex drive the Framework count to zero while the real count kept climbing.

## 11. Validation happens twice

The same allowed values and caps are checked at two different moments, and both read them from
`RecordHealthCheckConstants` so they cannot get out of sync.

| When | Class | What happens on failure |
| --- | --- | --- |
| A Rule runs | `RecordHealthCheckConfigService` with `RecordHealthCheckRuleValidator` | The Rule returns `UNABLE_TO_EVALUATE` with `INVALID_CONFIG` |
| Deploy or CI | `RecordHealthCheckMetadataValidator` | The audit reports the misconfigured Rule before anyone sees the card |

## 12. Observability

| Signal | Where it surfaces | Notes |
| --- | --- | --- |
| Structured `[RHC]` debug lines | Salesforce debug logs | Every line carries the run id and the running user |
| `Record_Health_Check_Log__e` | Platform event subscribers and monitoring tools | `ERROR` detail held during the run and published by `flush()` |
| `Record_Health_Check_Set_Run__e` | Platform event subscribers | Published after a deliberate run when the Check Set enables publication |
| `Record_Health_Check_Rule_Result__e` | Platform event subscribers | Published per Rule when that Rule enables publication |
| Show Diagnostics on the card | The Lightning record page | Requires the diagnostics Custom Permission |

Publication is optional per Check Set and per Rule, limited to deliberate runs, and best effort. Events
publish in chunks of 100, and a failed publish is logged as a warning rather than failing the run. A
subscriber cannot cause a loop, because a run happening inside a subscriber context does not publish
again.

## 13. Extension points

| Extension | Applies when |
| --- | --- |
| Formula, Query, or Compare two queries Rules | The condition is expressible in Custom Metadata with the shipped operators |
| A class implementing `RecordHealthCheckRule` | The condition needs Apex control flow, multiple queries, or a callout-backed lookup |
| Flow actions and the Apex API | Evaluation is driven by automation rather than a record page |
| Platform event subscribers | Results must be persisted, forwarded, or acted on after the run |

A custom Apex evaluator receives a `RecordHealthCheckContext` and returns a
`RecordHealthCheckResult`. It executes inside the engine path, after applicability and prerequisites
and before merge-token resolution, so it inherits result shaping, diagnostics checks, and error
normalization rather than reimplementing them.

## 14. Delivery and environments

The Framework is delivered as source metadata with no managed namespace, deployed from `force-app`
through `manifest/package.xml`. Every class, object, and component stays readable in the org, and
API names appear exactly as documented, with no namespace prefix.

Operational consequences:

- Upgrades are metadata deployments. The shipped `Example_` Check Set, Rules, and Apex evaluator
  deploy with the Framework and are sample configuration, not production configuration.
- Check Sets and Rules are Custom Metadata, so they deploy between orgs and version control
  alongside the classes they configure.
- Developer Names are contract identifiers. `PrerequisiteRule__c`, the Apex API, the Flow actions,
  and the event bodies all reference them, so renaming one is a breaking change.
- `npm run check:manifest` compares every packageable source member with `manifest/package.xml`.
  `npm run check:permission-sets` checks permission-set component references and keeps descriptions
  within a 200-character project budget, below Salesforce's 255-character limit. CI runs both
  checks before creating the scratch org.

### Multi-currency boundary

Multi-currency support applies wherever the Framework renders money. Formula, Query, Compare two
queries, and typed Apex plugin results can carry a currency for each side; list entries can carry a
currency per row. Aggregate amounts use the corporate currency Salesforce uses for the aggregate.
Single-currency orgs show a symbol, while orgs with multiple currencies lead with the ISO code.

The Framework does not convert currencies or normalize cross-currency comparisons. Comparisons use
the typed values Salesforce returns. Currency conversion, dated exchange rates, and business rules
for comparing unlike currencies remain the responsibility of the Rule query, formula, or Apex
plugin. See [Display value format](reference-display-value-format.md#currency).

## 15. Design decisions

| Decision | Rationale |
| --- | --- |
| One Rule per Apex call from the card | Isolates each Rule in its own transaction and lets results render as they complete |
| Counts recomputed server-side in `completeRun` | Event data a subscriber acts on cannot depend on values supplied by the browser |
| Automatic card loads cannot publish events | Page views would otherwise generate unbounded event volume from no deliberate action |
| The engine never throws | Every surface consumes one result shape instead of implementing its own exception handling |
| Allowed values in one constants class | Runtime and deploy-time validation previously duplicated them and could diverge silently |
| Administrator SOQL is templated, not executed as authored | `WITH USER_MODE` injection, DML rejection, and the row limit must happen before execution |
| Rule results cached only inside one top-level run | Prerequisite chains avoid re-evaluation without leaking stale results into a later run in the same transaction |

## 16. Out of scope

- No DML on the evaluated record, and no participation in save-time validation.
- No result persistence. History requires a platform event subscriber that writes its own storage.
- No scheduling. Runs originate from a card load, a user request, a Flow, or Apex that the org
  schedules.
- No mass evaluation. The bulk paths exist for automation within governor limits, not for scanning
  large record volumes.
- No REST API. Apex, Flow, the Lightning Web Component, and platform events are the supported
  surfaces, and the documentation standard rules out publishing an OpenAPI document for them.

## 17. Class ownership map

Use this when changing code. If a responsibility moves, update this table in the same change.
For longer per-class descriptions, see [Reference: Apex classes](reference-apex-classes.md).

### Entry points

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheck` | Public Apex `runRule` and `runSet`, request limits, lifecycle publication |
| `RecordHealthCheckRunRuleFlowAction` and `RecordHealthCheckRunSetFlowAction` | Packaged Flow actions |
| `RecordHealthCheckController` | Lightning card: availability, definitions, `evaluateCheck`, `completeRun` |
| `RecordHealthCheckEngine` | The one-Rule evaluation path |
| `RecordHealthCheckLifecyclePublisher` | Optional Set and Rule platform events |
| `RecordHealthCheckRunContext` | Values carried for the duration of one run |

### Configuration and validation

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckConfigService` | Load Check Sets and Rules; build definition and availability responses |
| `RecordHealthCheckRuleValidator` | Per-Rule checks at the moment a Rule runs |
| `RecordHealthCheckMetadataValidator` | Deploy-time and CI metadata audit |
| `RecordHealthCheckConfigValidator` and `RecordHealthCheckConstants` | Shared helpers, allowed values, and caps |
| `RecordHealthCheckReasonCodes` | Restricted reason-code helpers |
| `RecordHealthCheckSetAvailability` | Active and inactive Check Sets for an object |

### Evaluators and shared services

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckFormulaEvaluator` | Formula checks, including the transaction formula budget |
| `RecordHealthCheckSoqlEvaluator` | Single-query checks |
| `RecordHealthCheckCompareQueriesEvaluator` | Two-query checks |
| `RecordHealthCheckQueryEvaluatorSupport` | Shared query execution and empty-result handling |
| `RecordHealthCheckApexEvaluator` | Custom Apex evaluator dispatch |
| `RecordHealthCheckComparisonEngine` | Operators, equality, expected-value wording, and list previews |
| `RecordHealthCheckDisplayFormat` | Typed display values, picklist labels, locale formatting, and per-side or per-row currency |
| `RecordHealthCheckSoqlTemplate` | SOQL safety checks, row limit, and `WITH USER_MODE` injection |
| `RecordHealthCheckValueResolver` | Convert and compare values safely |
| `RecordHealthCheckDescribeCache` | Describe results reused within one transaction |
| `AccountHasRecentActivityCheck` | The shipped example Apex evaluator |

### Merge tokens

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckTemplateService` | Resolve tokens and enforce token count and length caps |
| `RecordHealthCheckTokenRegistry`, `RecordHealthCheckToken`, and `RecordHealthCheckTokenIssue` | Allowed tokens and parse results |
| `RecordHealthCheckMergeContext` | Values available while a message is resolved |

### Logging, access, and responses

| Class | Responsibility |
| --- | --- |
| `RecordHealthCheckLogger` | `[RHC]` log lines, held `ERROR` entries, and `flush()` to the log event |
| `RecordHealthCheckAccess` | The diagnostics permission check |
| `RecordHealthCheckValueSource` | Comparison diagnostic detail |
| `RecordHealthCheckSetPicklist` | Check Set picker in Lightning App Builder |
| `RecordHealthCheckResult` and `RecordHealthCheckSetResult` | Apex and Flow responses at contract `1.0` |
| `RecordHealthCheckScope` | The records a custom Rule is asked about, plus its parameters. Read-only |
| `RecordHealthCheckOutcome` | What a custom Rule returns for one record: a verdict and its values |
| `RecordHealthCheckValue` | A typed Found or Expected value with one stored format per data type |
| `RecordHealthCheckStatus` | The status vocabulary: PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR |
| `RecordHealthCheckResultMode` | Selects how much data a result carries |
| `RecordHealthCheckEventPublication` | Whether a programmatic run publishes lifecycle Platform Events |
| `RecordHealthCheckPluginDispatch` | Runs a custom Rule and holds it to its contract, including the side-effect fence |
| `RecordHealthCheckContractDemo` | Runnable tour of the extension contract for a scratch org |
| `RecordHealthCheckDefinition` and `RecordHealthCheckDefinitionResponse` | Definition response for the Lightning card |
| `RecordHealthCheckAdminDetail` | Structured diagnostics detail |
| `RecordHealthCheckContext` and `RecordHealthCheckRule` | Custom Apex evaluator input and interface |
| `RecordHealthCheckEvaluatorException` | Evaluator failure carrying a reason code |

### Lightning Web Component

One bundle, four modules. Keep them together as one component.

| Module | Responsibility |
| --- | --- |
| `recordHealthCheck` | The component itself: wires, rendering, and user interaction |
| `healthCheckRunner` | Run lifecycle: prerequisite checks, capped concurrency, progressive reveal |
| `healthCheckModel` | Result normalization, error parsing, run ids, dependency loop detection |
| `healthCheckPresentation` | Display shaping, summary counts, and link safety |

## Related references

| What you need | Where to look |
| --- | --- |
| Field definitions and caps | [Check Set fields](../metadata/fields-check-set.md), [Rule fields](../metadata/fields-check-rule.md), [Field limits](reference-fields-limits.md) |
| Evaluation Type contracts | [Formula](reference-formula.md), [Query](reference-query.md), [Compare two queries](reference-compare-two-queries.md), [Apex](reference-apex.md) |
| Calling surfaces | [Apex API](reference-apex-api.md), [Flow actions](../integration/flow-actions.md), [Lightning component](../integration/lightning-component.md) |
| Events | [Lifecycle events](../integration/lifecycle-events.md), [Log event](../metadata/event-log.md) |
| Result terms and codes | [Reason codes](reference-reason-codes.md), [Merge tokens](reference-merge-tokens.md) |
| Class-by-class guide | [Apex classes](reference-apex-classes.md) |
| Concepts and installation | [How it works](../installation/01-how-it-works.md), [Install and verify](../installation/02-install-and-verify.md), [Upgrading](../installation/04-upgrading.md) |

## Related

- [Documentation index](../README.md)
- [Integration overview](../integration/README.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
- [Troubleshoot with Show Diagnostics](../guides/troubleshoot-with-show-diagnostics.md)
