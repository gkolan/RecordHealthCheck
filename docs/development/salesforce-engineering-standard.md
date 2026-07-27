# Salesforce engineering standard

> [!NOTE]
> On this page, apply reusable Apex, metadata, security, testing, and deployment rules that help Salesforce projects remain safe, portable, and deployable.

Use this standard with the
[documentation standard](documentation-standard.md) and the
[naming and metadata writing standard](salesforce-naming-and-metadata-writing-standard.md).
Use the [code analysis standard](code-analysis-standard.md) for release checks, rule exceptions,
and the meaning of a clean scan.
It captures reusable guidance from the official Salesforce skills library while leaving commands,
tool routing, and product-specific workflows in the skills themselves.

## Order of trust

When sources disagree, use this order:

1. The current Salesforce Metadata API schema and official Salesforce documentation.
2. Metadata retrieved from the target org when behavior depends on that org.
3. The project's explicit architecture, security, naming, and compatibility decisions.
4. Salesforce skill guidance and examples.

Skills are maintained guidance, not a replacement for the current platform schema. Verify an
element name, allowed value, required field, limit, or API-version behavior before making it a
long-lived project rule.

## Apex production rules

### Security

- Declare a sharing keyword on every class that accesses records. Use `with sharing` by default.
- Document the reason for `inherited sharing` or `without sharing`.
- Keep elevated-access work in a small dedicated class and require an appropriate Custom
  Permission before it runs.
- Enforce object and field access for queries and data changes. Prefer `WITH USER_MODE` and
  user-mode `Database` operations when their behavior fits the use case.
- Validate dynamic object names, field names, sort directions, and operators against describe
  information or an explicit list of allowed values.
- Bind user-supplied values in dynamic SOQL. Never join unchecked input into a query.
- Store external credentials in Named Credentials. Never place credentials, access tokens, or
  private keys in Apex, metadata, logs, or examples.
- Keep personal and sensitive information out of debug logs, exception messages, events, and
  responses unless the contract and access model explicitly require it.
- Return user-safe messages from `@AuraEnabled` methods without exposing internal implementation
  details.

### Governor-limit safety

- Keep SOQL, DML, and callouts outside loops.
- Design public operations that may receive records to accept collections. A single-record method
  may call the collection method.
- Query only the fields needed and use selective filters where possible.
- Bound result sets when the business operation does not require every matching record.
- Use maps for ID-based lookups, sets for unique IDs and membership checks, and grouped maps for
  parent-to-child processing.
- Use aggregate SOQL for counts, sums, minimums, and maximums when the database can perform the
  calculation.
- Change only records whose stored values need to change.
- Use partial-success database operations when one failed record should not reject an entire bulk
  request, and inspect every returned result.
- For complex work, test and monitor query, DML, row, heap, and CPU consumption.

### Structure

- Give each class one clear responsibility.
- Keep triggers limited to event routing; place business behavior in testable classes.
- Keep queries and data changes separate from business decisions when the project uses service,
  selector, or domain layers.
- Prefer small methods. Extract a private method when a method combines several distinct decisions
  or becomes difficult to test.
- Pass replaceable collaborators through constructors or method parameters when tests need to
  substitute an external boundary.
- Prefer a small capability interface and composition over a deep inheritance tree.
- Use `Queueable` for new asynchronous Apex unless Batch, Scheduled Flow, Schedulable, or another
  platform feature better matches the volume and timing. Do not introduce new `@future` methods.
- Guard Queueable chaining so a configuration or data issue cannot create an endless chain.

### Errors and null values

- Catch only code that can throw and catch a specific exception before `Exception`.
- Log, return, recover from, or rethrow an exception deliberately. Never discard it silently.
- Preserve the original cause when wrapping an exception.
- Check public inputs at the beginning of a method and return or throw a documented outcome.
- Return an empty collection instead of `null`.
- Check a map entry before dereferencing it unless the method has already proved that it exists.
- Prefer `String.isBlank`, safe navigation, and null coalescing where they make the behavior clearer.

### Configuration and messages

- Use Custom Metadata Types for deployable configuration such as thresholds, mappings, and feature
  switches.
- Use Custom Labels for translated user-facing messages.
- Do not hardcode Salesforce record IDs, org URLs, credentials, or environment-specific values.
- Use enums for a closed code-owned set. Use uppercase snake case for stable enum values.
- Add ApexDoc to classes and every public or global method. Document parameters, return values,
  thrown exceptions, access expectations, and an example when it clarifies use.

## Apex test rules

- Keep tests independent of customer data and hardcoded IDs. Use `SeeAllData=false` behavior.
- Create reusable records through a test data factory when several test classes need the same
  setup.
- Test one observable behavior per method. Separate success, missing-input, invalid-input, bulk,
  access, and exception cases when they prove different behavior.
- Use `Test.startTest()` and `Test.stopTest()` around the operation being measured, especially for
  asynchronous work and governor-limit verification.
- Use the `Assert` class and include a useful failure message.
- Assert exact outcomes when the expected value is deterministic.
- Test collection sizes that cross the platform's 200-record processing boundary when the code can
  run in trigger or bulk contexts. Choose a smaller focused size when the code cannot encounter that
  boundary or another governor limit makes the larger case invalid.
- Mock HTTP callouts and other external boundaries.
- Test negative paths, user access, sort order, partial failures, and asynchronous completion where
  they are part of the contract.
- Start with the narrow failing test, then run the relevant suite, then the release-level test run.
- Treat 75% as Salesforce's deployment minimum, not a quality target. Set a project coverage target
  and require direct tests for critical behavior.

## Metadata authoring rules

### Schema-first authoring

Before creating or editing metadata:

1. Identify the Metadata API type and target API version.
2. Read the current fields and required/conditional rules for that type.
3. Check a current sample when schema-required flags do not capture practical deployment needs.
4. Inspect related metadata and the target org when a value or dependency is org-specific.
5. Generate the smallest complete XML with the correct file name, source directory, root element,
   declaration, and Metadata API namespace.

Every metadata XML file uses the exact namespace:

```xml
xmlns="http://soap.sforce.com/2006/04/metadata"
```

The filename supplies the component name for metadata types whose root does not accept
`<fullName>`. Do not copy a `<fullName>` pattern from one metadata type into another.

### Objects and fields

- Give every custom object a singular label, natural plural label, name field, description,
  deployment status, sharing model, and visibility required by the current API contract.
- Choose a text Name field for a naturally named business record and Auto Number for transactions,
  logs, and generated references. Auto Number requires a display format and starting number.
- A detail object with a master-detail field uses parent-controlled sharing when required by the
  platform.
- A master-detail field does not declare lookup-only properties such as a delete constraint or
  lookup filter. It is inherently required.
- An object can have no more than the platform-supported number of master-detail relationships.
  Verify the current limit before design approval.
- A roll-up summary belongs on the master record and references the child object and master-detail
  field using fully qualified API names.
- Formula metadata uses the formula's result type. Do not invent a `Formula` field type or a
  `returnType` metadata element.
- Numeric precision includes every digit; scale is the number of decimal digits. Scale cannot
  exceed precision.
- Check field-type-specific allowed and forbidden elements before deployment.

### Picklists and value sets

- Use a restricted picklist unless the business process deliberately accepts values outside the
  configured list.
- A field uses either an inline value-set definition or a value-set reference, never both.
- Use a Global Value Set when multiple fields share one managed list. Deploy it before fields that
  reference it.
- Reference a Global Value Set by the developer name required by the current Metadata API. Do not
  add an org-display suffix to the metadata name.
- Treat Standard Value Sets as org- and platform-defined catalogs. Verify the exact set name and
  value before editing it, and deploy only the intended changes.
- Allow at most one default value and require every stored value to be unique.
- Keep controlling and dependent picklists restricted and use the current dependency metadata
  structure.
- Configure record-type value visibility on the Record Type, not on the field.

### Permission sets

- Follow least privilege. Grant only the object, field, class, application, tab, record type, and
  system access required by the role.
- Set a clear label and a concise Description that identifies purpose and intended audience.
- Verify every object, field, Apex class, application, tab, record type, and permission name before
  adding it.
- Omit field-permission entries that Salesforce does not accept, including required fields where
  the current platform contract forbids them.
- Formula and other calculated fields are never editable.
- Use fully qualified field references such as `Account.Customer_Tier__c`.
- Give broad permissions such as `ViewAllData`, `ModifyAllData`, and user administration a separate
  security review.
- Deploy referenced objects and fields before the permission sets that grant access to them.

## Deployment and release rules

1. Confirm the target org, authentication, API version, package directory, and exact deployment
   scope.
2. Verify that the manifest contains every required component and dependency.
3. Run static analysis and fix release-blocking findings.
4. Validate the smallest complete deployment with a dry run.
5. Run the required tests and coverage checks.
6. Deploy dependencies in order: configuration schemas and fields, permissions, Apex, inactive
   automation, then activation and post-deployment setup.
7. Read the final deployment report instead of relying only on the command exit message.
8. Verify permission assignment, automation state, example data, and a user-visible smoke test.
9. For a distributable package, repeat the full manifest installation in a fresh org with the
   supported feature configurations, such as single-currency and multi-currency.

Use Salesforce CLI v2 commands. Give every deploy or retrieve command an explicit source,
metadata, or manifest scope when source tracking does not supply it.

## Review checklist

Before release, confirm:

1. Does every record-accessing Apex class declare and justify its sharing behavior?
2. Are object access, field access, dynamic SOQL, secrets, and sensitive information handled safely?
3. Are queries, data changes, and callouts outside loops and tested in bulk?
4. Are errors deliberate, useful, and free of internal or sensitive details?
5. Do tests prove success, failure, access, bulk, and asynchronous behavior where applicable?
6. Was every metadata element checked against the current API type and version?
7. Are labels, API names, descriptions, help text, and stored values compliant with the naming
   standard?
8. Are permission sets complete, least-privilege, and free of invalid field permissions?
9. Does the manifest include all dependencies in a safe deployment order?
10. Did static analysis, deployment validation, tests, coverage gates, and fresh-org verification
    pass?

## Related

- [Deployment readiness standard](deployment-readiness-standard.md)
- [Documentation standard](documentation-standard.md)
- [Salesforce naming and metadata writing standard](salesforce-naming-and-metadata-writing-standard.md)
- [Code coverage statistics](code-coverage-statistics.md)
- [Code analysis standard](code-analysis-standard.md)
- [Architecture reference](../reference/reference-architecture.md)
