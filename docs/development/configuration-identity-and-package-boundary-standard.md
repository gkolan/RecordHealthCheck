# Configuration identity and package boundary standard

> [!NOTE]
> On this page, preserve one exact Custom Metadata identity contract and keep optional business
> configuration outside the installable Framework.

Apply this standard whenever code, Flow, Lightning, events, tests, examples, or documentation
identifies a Check Set or Rule.

## Use Qualified API Name at every Framework boundary

Every external entry point accepts the exact `QualifiedApiName` returned by Salesforce. Do not ask
a caller to construct it, remove a namespace, or try multiple forms.

| Record ownership | `DeveloperName` | `QualifiedApiName` supplied to the Framework |
| --- | --- | --- |
| Subscriber-owned metadata | `Account_Readiness` | `Account_Readiness` |
| Metadata owned by the `rhc` package | `Account_Readiness` | `rhc__Account_Readiness` |
| Metadata owned by another package | `Account_Readiness` | `other__Account_Readiness` |

The namespace belongs to the package that owns the Custom Metadata record. It is not necessarily
the namespace of the Framework's Custom Metadata Type. Salesforce is the source of truth.

Discover the value instead of constructing it:

```sql
SELECT DeveloperName, QualifiedApiName
FROM Record_Health_Check_Set__mdt
ORDER BY QualifiedApiName
```

Use the corresponding Rule query for Rule entry points. Store or pass the returned
`QualifiedApiName` exactly.

## Prohibited identity behavior

Do not:

- prepend `rhc__` or any other namespace;
- strip a namespace;
- retry a failed `QualifiedApiName` lookup with `DeveloperName`;
- accept qualified or unqualified input and guess which the caller meant;
- substitute a label, display title, or Master Label for record identity;
- use `qualifiedApiName || developerName` at a client boundary; or
- describe a Developer Name as sufficient input for Apex, Flow, Lightning, or an integration.

Fail clearly when the exact identity is absent or unknown. A deterministic configuration error is
safer than selecting a different record whose short name happens to match.

`DeveloperName` still has legitimate internal uses: displaying a short name, resolving a
same-package Custom Metadata relationship, and keying dependencies within one already-loaded Check
Set. It is not the public selection contract.

## Keep the Framework free of business policy

`force-app` contains the engine, Lightning component, permissions, Custom Metadata Type
definitions, public APIs, and reusable evaluator code. It contains no Check Set or Rule records.

Optional starter configuration belongs in
[`RecordHealthCheck-Examples/core-examples`](https://github.com/gkolan/RecordHealthCheck-Examples/tree/main/core-examples).
The main repository keeps an identical fixture copy under `integration-tests` so Salesforce tests
can exercise realistic configurations without turning those records into customer install content.

Do not add example-only list views, manifest members, page assignments, or documentation claims to
the Framework package. A normal `force-app` deployment must succeed before integration fixtures
are deployed.

## Change procedure

When adding or changing optional starter metadata:

1. Change the installable record in `RecordHealthCheck-Examples/core-examples`.
2. Copy the same record into `integration-tests/main/default/customMetadata`.
3. Keep filenames and XML content identical between the two locations.
4. Update the examples manifest and verify exact manifest-to-file parity.
5. Confirm `force-app/main/default/customMetadata` contains no records.
6. Deploy `force-app` alone to a clean org and run package tests.
7. Deploy `integration-tests` separately and run the integration suite.
8. Test subscriber-owned, `rhc`-owned, and other-package identities when lookup behavior changes.

## Review checklist

Before accepting a change, answer yes to every question:

1. Does every public input say **Qualified API Name**?
2. Does each caller pass the exact value Salesforce returned?
3. Is namespace guessing absent from Apex and JavaScript?
4. Does a missing qualified identity fail closed with a useful error?
5. Does the Framework package contain zero Check Set and Rule records?
6. Are optional starter records isolated in the examples repository?
7. Does `integration-tests` retain the matching fixture copy?
8. Do manifests, documentation, setup scripts, and tests describe the same boundary?
9. Did a Framework-only deployment pass before fixture deployment?
10. Did the integration suite pass after fixture deployment?

Run `npm run check:configuration-identity` and `npm run check:package-boundary` for the repository
guards.

## Lessons retained

- A valid Apex parameter rename can still break Lightning when the JavaScript object key no longer
  matches the Apex argument. Test the serialized boundary, not only each side.
- `QualifiedApiName` is discovered from Salesforce; it is not a string-formatting convention.
- A convenience retry hides configuration mistakes and creates namespace-specific behavior. Reject
  ambiguity.
- Example records in the main package silently turn sample policy into installed customer policy.
  Separate packages make consent and ownership explicit.
- Moving files is incomplete until list views, manifests, demo scripts, generated inventories,
  tests, and public documentation agree with the new boundary.
- Automated documentation scores do not establish editorial quality. Human review and executable
  release gates answer different questions; keep both.

## Related

- [Salesforce naming and metadata writing standard](salesforce-naming-and-metadata-writing-standard.md)
- [Deployment readiness standard](deployment-readiness-standard.md)
- [Integration overview](../integration/README.md)
- [Flow actions](../integration/flow-actions.md)
