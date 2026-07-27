# Salesforce naming and metadata writing standard

> [!NOTE]
> On this page, use consistent rules to name Apex code and Salesforce metadata and to write labels, descriptions, and help text that remain clear in Setup, code, and automation.

Use this standard as a starting point for Salesforce projects. A project may add a terminology
appendix for its business domain, but that appendix should narrow these rules rather than silently
replace them.

This standard incorporates reusable guidance from the official Salesforce skills library. The
current Metadata API schema and official Salesforce documentation take precedence when platform
rules change. See the [Salesforce engineering standard](salesforce-engineering-standard.md) for
security, testing, metadata structure, and deployment requirements.

Salesforce labels and API names serve different readers:

- **Labels** help administrators and users understand a choice.
- **API names** give Apex, Flow, formulas, integrations, and deployment tools a stable identifier.
- **Descriptions** tell administrators why metadata exists and how it fits into the project.
- **Help text** helps a person enter or choose a value at the point of use.

Changing a label is a user-interface change. Changing an API name is a contract change and can
break code, automation, reports, permissions, integrations, and deployments.

## General naming rules

Use names that explain business purpose without requiring the reader to open the implementation.

- Prefer complete words: `ComparisonQuery`, not `CompQry`.
- Use an abbreviation only when Salesforce or the business uses it as the normal term, such as
  `Id`, `URL`, `API`, `SOQL`, or `SLA`.
- Use the same term for the same concept across labels, API names, Apex, tests, and documentation.
- Use different names for concepts that have different meanings.
- Prefer a business noun for stored information and a verb for an operation.
- Avoid names based on temporary implementation details, team names, ticket numbers, dates, or
  release numbers.
- Avoid vague names such as `Data`, `Info`, `Manager`, `Helper`, `Util`, `Misc`, `New`, and `Temp`
  unless a more specific name would be misleading.
- Keep names concise after they are clear. Do not remove meaningful words merely to shorten an API
  name.
- Check the name against existing Salesforce standard objects, fields, classes, namespaces, and
  installed packages before adopting it.

Maintain a short project terminology list for named business concepts, accepted abbreviations, and
words that the project does not use. Review a new public name against that list before deployment.

## Apex names

### Classes, interfaces, and enums

Use PascalCase for Apex types. Start with the business concept and end with a role only when the
role adds useful meaning.

| Type | Pattern | Example |
| --- | --- | --- |
| Service | `<Concept>Service` | `RecordHealthCheckTemplateService` |
| Controller | `<Concept>Controller` | `RecordHealthCheckController` |
| Evaluator | `<Concept>Evaluator` | `RecordHealthCheckFormulaEvaluator` |
| Selector or query owner | `<Concept>Selector` or a specific query name | `OpportunitySelector` |
| Flow action | `<Verb><Concept>FlowAction` | `RunHealthCheckFlowAction` |
| Scheduled job | `<Verb><Concept>Scheduled` | `ArchiveLogsScheduled` |
| Queueable job | `<Verb><Concept>Queueable` | `RecalculateScoresQueueable` |
| Batch job | `<Verb><Concept>Batch` | `ArchiveLogsBatch` |
| Schedulable job | `<Verb><Concept>Schedulable` | `ArchiveLogsSchedulable` |
| Abstract class | `Abstract<Concept>` | `AbstractEvaluationService` |
| REST resource | `<Concept>RestResource` | `AccountRestResource` |
| Trigger | `<Object>Trigger` | `AccountTrigger` |
| Exception | `<Concept>Exception` | `RecordHealthCheckEvaluatorException` |
| Test class | `<ClassUnderTest>Test` | `RecordHealthCheckDisplayFormatTest` |

Name an interface for the capability it promises. Do not add `I` merely to mark it as an interface.
For example, prefer `HealthCheckEvaluator` to `IHealthCheckEvaluator`.

The Salesforce Apex skill uses `I<Concept>` in its generic naming table. This standard deliberately
uses capability names without that prefix because the type declaration already identifies an
interface. A project that has already adopted `I<Concept>` may keep it consistently and record that
choice in its terminology appendix.

Name an enum as a singular concept because one variable holds one value. Use uppercase snake case
for enum values when they are stable values used by code or configuration.

```apex
public enum DisplayValueFormat {
    AUTO,
    CURRENCY,
    PERCENT
}
```

### Methods and properties

Use lower camel case for methods, parameters, local variables, and properties.

- Start a method name with a verb: `formatValue`, `findRule`, `validateConfiguration`.
- Use `is`, `has`, `can`, or `should` for a Boolean result: `isActive`, `hasAccess`.
- Use `get` only when the method returns information. Use `find` when no result is a normal outcome.
- Use `create` or `build` for a new value and `save`, `insert`, `update`, or `delete` when the method
  performs that database operation.
- Name collections with a plural noun: `rules`, `recordIds`, `fieldsByObject`.
- Name a map `<values>By<key>`, such as `accountsById`, and a set of IDs `<concept>Ids`.
- Include units in a name when the unit is not evident: `timeoutSeconds`, `sizeInBytes`.
- Avoid repeating the class name in every method. `TemplateService.applyText` is clearer than
  `TemplateService.applyTemplateServiceText`.

Use uppercase snake case for constants:

```apex
private static final Integer MAX_DISPLAY_SCALE = 6;
```

### Apex tests

Name each test class after the production class it primarily verifies. Use a separate test class
for a large, distinct behavior only when that division makes the suite easier to understand.

Name test methods for observable behavior and conditions:

```apex
@IsTest
static void currencyFormatUsesRecordCurrency() {
    // Test body
}
```

- Prefer `conditionProducesOutcome` or `operationWhenCondition`.
- Do not start every method with `test`; the `@IsTest` annotation already identifies it.
- Do not include ticket numbers as the only explanation of behavior.
- Use `TestDataFactory` only for a class whose main purpose is reusable test data.
- Prefer `should<Outcome>When<Condition>` or `<Action>_<Condition>_<Outcome>` when a project needs a
  uniform test-method pattern.

## Salesforce metadata names

### Labels and API names

Use title case for short Setup labels and sentence case for complete instructions. Preserve official
Salesforce and business capitalization.

| Metadata part | Human-facing form | API form |
| --- | --- | --- |
| Custom object label | Singular title case: `Health Check Result` | PascalCase with underscores inserted by Salesforce: `Health_Check_Result__c` |
| Custom object plural label | Natural plural: `Health Check Results` | Not applicable |
| Custom metadata type label | Singular title case: `Health Check Rule` | `Health_Check_Rule__mdt` |
| Field label | Concise title case: `Display Value Format` | PascalCase: `DisplayValueFormat__c` |
| Checkbox field label | Positive state: `Show Diagnostics` | Positive Boolean name: `ShowDiagnostics__c` |
| Custom metadata record label | Readable title case | Separate from Developer Name |
| Record Developer Name | Stable identifier | PascalCase or project-approved underscores |
| Permission Set | Readable role or purpose | Descriptive words separated by underscores: `Sales_Manager_Access` |
| Global Value Set | Readable plural concept | Bare developer name: `Priority_Levels` |
| Validation Rule | Short business rule | Letter first, alphanumeric and underscores, no `__c` suffix |

Salesforce supplies the `__c` and `__mdt` suffixes. Do not include those suffixes when discussing a
label, and always include them when showing an API name in code or a metadata contract.

Choose a natural plural label. Do not create a plural by adding `s` when the word requires a
different form.

### Custom objects and Custom Metadata Types

Name a custom object for the business record it stores. Name a Custom Metadata Type for the
configuration concept it defines, not for the screen or class that happens to use it.

- Use a singular label and API name.
- Supply a natural plural label for custom objects.
- Keep the API name stable after release.
- Avoid `Config`, `Setting`, or `Data` when a more specific business concept is available.
- Prefix example metadata records with `Example_` when they ship only as samples and must remain
  easy to distinguish from customer configuration.
- Use Developer Names for automation and relationships. Do not branch on an administrator-editable
  record label.
- Name a junction object from the two business concepts it connects, in the project's chosen order.

### Fields

Name a field for the value it stores, not for the page section that displays it.

- Use a noun or noun phrase for text, number, date, time, picklist, and relationship fields.
- Use a positive statement for a checkbox: `Publish Events`, not `Do Not Suppress Events`.
- Add a unit when a number has one: `Retention Days`, `Timeout Seconds`.
- Use `Date`, `Time`, or `Date/Time` in the label when the distinction matters.
- End a lookup label with the related record concept rather than `Lookup`.
- Use `Count` only for a whole-number quantity and `Amount` only for money.
- Use `Percent` when the stored value is a percentage. Document whether the stored value is a ratio
  such as `0.75` or a percentage number such as `75`.
- Keep paired fields parallel: `Found Text` and `Expected Text`.

Do not put a type in the API name merely because Salesforce already records that type. Include it
only when it distinguishes the business meaning.

Use a plural relationship name that describes the child collection. Verify that it is unique on
the parent object and valid for the target API version.

### Picklists, statuses, and other stored values

Treat the label and stored API value as separate decisions.

| Label | Stored API value | Purpose |
| --- | --- | --- |
| `Currency` | `CURRENCY` | Display choice |
| `Percent` | `PERCENT` | Display choice |
| `Unable to Evaluate` | `UNABLE_TO_EVALUATE` | Result status |

- Use concise title case for labels.
- Use uppercase snake case for stable values that act as codes.
- Keep stored values language-neutral and stable after release.
- Never use the label as an automation contract when administrators or translations can change it.
- Do not create two stored values that differ only by capitalization.
- Document the label, stored API value, default, and behavior together.

Uppercase is for the stored API value, not the user-facing label. For example, use the label
`Currency` with the stored value `CURRENCY`.

Salesforce permits spaces in many picklist-value API names and existing standard values often use
them. Preserve an existing stored value exactly. For a new project-owned configuration code, this
standard prefers uppercase snake case so automation can distinguish the stable value from its
translated or administrator-facing label.

Use a Global Value Set developer name without `__c` or an org-display `__gvs` suffix in Metadata
API source. Use the exact Standard Value Set name supplied by Salesforce; do not create a new name
that resembles a standard set.

## Descriptions and help text

### Description

A Description explains purpose and ownership to an administrator reviewing Setup or source
metadata. Write one or two short sentences that answer:

1. What does this metadata control or store?
2. When does it matter?
3. What important dependency or consequence might be missed?

Use a period for a complete sentence. Avoid change history, ticket numbers, implementation notes,
marketing claims, and instructions that belong in help text or documentation.

Every shipped custom object, custom field, and Permission Set has a meaningful Description. Review
an object's Description when its fields or validation rules change so it does not describe behavior
that is no longer true. Preserve useful business context from an existing Description instead of
replacing it with a generated inventory of metadata.

Example:

> Controls how Found and Expected values are displayed. `AUTO` uses the Salesforce field type when
> a field definition is available.

### Inline help text

Help text tells a person what to enter or choose before saving. Start with the action or decision,
then state a default, unit, format, or dependency when it affects the choice.

Example:

> Choose how Found and Expected values are displayed. Auto uses the Salesforce field type when one
> is available.

- Use plain language and active voice.
- Explain accepted formats with a short example when necessary.
- State units and whether a limit is inclusive.
- Explain a dependency next to the field that depends on it.
- Do not repeat the field label as the opening phrase.
- Do not use help text as the only place where a required behavior is documented.
- Give every shipped custom field useful inline help unless the metadata type does not support it or
  the project records a clear reason that the label is sufficient.

### Length and deployment safety

Salesforce length limits vary by metadata type and can change between platform versions. Check the
current Metadata API definition for the exact component before release.

Use these project rules even when Salesforce permits more text:

- Keep a short label under 40 characters whenever the business meaning remains clear.
- Keep inline help text to one or two short sentences.
- Keep descriptions concise enough to scan in Setup.
- Treat 255 characters as the default maximum for a metadata Description until the component's
  current limit has been verified.
- Add an automated length check for every shipped Description and help-text field.
- Validate the complete deployment manifest in a fresh org before release. A successful partial
  deployment does not prove that every metadata component is valid.

Do not shorten text by removing the words that explain meaning. Move extended guidance into the
documentation and link it from the nearest Setup or reference page when the metadata supports a
useful link.

## Names for public and internal behavior

Treat a name as public when customers, administrators, integrations, Flow, formulas, permission
assignments, reports, or subscriber code can depend on it.

Before renaming a public identifier:

1. Find references in Apex, Lightning Web Components, Flow, formulas, permissions, metadata,
   documentation, tests, manifests, and integration examples.
2. Decide whether the change requires a compatibility plan and release note.
3. Deploy and test the complete package in a fresh org.

An internal identifier still follows the same clarity rules, but it may be renamed with all of its
callers in one change.

## Review checklist

Before accepting a new name or metadata text, confirm:

1. Does the name describe one business concept?
2. Does it use the project's established term for that concept?
3. Are the label and API name visibly distinct and both documented?
4. Is capitalization correct for a label, Apex identifier, or stored API value?
5. Is a Boolean label positive and unambiguous?
6. Will the API name still make sense if the implementation changes?
7. Are Description and help text serving different purposes?
8. Are units, defaults, accepted formats, and dependencies clear where needed?
9. Are all text values within the current metadata limits?
10. Have permissions, manifests, tests, reference pages, and examples been updated?
11. Has the full package been validated in a fresh org?
12. Were metadata element names and limits checked against the current API schema rather than copied
    from a different metadata type?

## Project terminology appendix

Each project should maintain a short appendix containing:

- Official product and business terms.
- Approved abbreviations and their capitalization.
- Reserved prefixes and namespaces.
- Stable status, reason, and picklist API values.
- Example-record prefixes.
- Terms that must not be used because they conflict with Salesforce or have a different business
  meaning.

Keep the appendix close to this standard so code reviewers, documentation authors, and automated
checks use the same terms.

## Related

- [Documentation standard](documentation-standard.md)
- [Salesforce engineering standard](salesforce-engineering-standard.md)
- [Apex classes reference](../reference/reference-apex-classes.md)
- [Metadata reference](../metadata/README.md)
- [Architecture reference](../reference/reference-architecture.md)
