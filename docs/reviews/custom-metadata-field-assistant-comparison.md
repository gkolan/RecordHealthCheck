# Record Health Check field proposal decision review

This document compares the **final recommendation** from Claude, Cursor, and Codex for every current custom metadata field. It is designed for printing and decision-making—not as a transcript of the source proposals.

## Reading rules

- **KEEP** means the assistant proposes no API-name or label change. Any separate value/default change is called out explicitly.
- **RENAME** means the API name changes.
- **CHANGE LABEL/BEHAVIOR** means the API stays but the label, default, type, or picklist contract changes.
- **REMOVE** means the field is replaced by a standard field or eliminated.
- Later amendments in a proposal override its earlier tables.
- If a proposal does not give a field-specific reason, this document says so explicitly rather than guessing.

## Suggested decision test

Choose a change only if it makes the field clearer in both Salesforce Setup and code, remains valid outside the current UI, and does not introduce an unsafe default or unnecessary migration cost.

---

# Record Health Check Rule


## 1. Apex Class Name — `ApexClass__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApexClass__c` | Apex Class Name | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `ApexClass__c` | Apex Class | Text / default not stated here |
| **Cursor** | **KEEP** | `ApexClass__c` | Apex Class Name | No type/default change stated |
| **Codex** | **RENAME** | `Apex_Check_Class__c` | Apex Check Class | Text(255), required for Apex method / blank |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** Both are already clean. Help text for `ApexClass__c`: "Name of an Apex class that implements `RecordHealthCheckRule`." (Ties the field to the extension contract.)
- **Cursor — KEEP:** No change proposed. Cursor retains the current API name and label.
- **Codex — RENAME:** States that the class must implement the check plugin contract, not any arbitrary Apex class.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 2. Apex Settings (JSON) — `ApexParametersJson__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApexParametersJson__c` | Apex Settings (JSON) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `ApexParametersJson__c` | Apex Settings (JSON) | Long Text / default not stated here |
| **Cursor** | **RENAME** | `ApexParametersJson__c` | Apex Settings (JSON) | No type/default change stated |
| **Codex** | **RENAME** | `Apex_Check_Configuration_JSON__c` | Apex Check Configuration | Long Text / blank, normalized to empty object |

### Reasoning that matters

- **Claude — KEEP:** No change proposed. Claude retains the current API name and label.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Friendly label; API tells plugin authors that JSON is the stable wire/configuration format.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 3. Category — `Category__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `Category__c` | Category | Picklist | false | `None specified` |

**Current picklist contract:** `Data Quality` = Data Quality; `Compliance` = Compliance; `Sales Readiness` = Sales Readiness; `Support Readiness` = Support Readiness; `Renewal Risk` = Renewal Risk; `AI Readiness` = AI Readiness; `Integration Readiness` = Integration Readiness; `Completeness` = Required Field Completeness; `Activity` = Recent Activity; `Relationship Coverage` = Related Record Coverage; `Pipeline` = Sales Pipeline; `Data Freshness` = Recent or Current Data

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `Category__c` | Category | Picklist / default not stated here |
| **Cursor** | **KEEP** | `Category__c` | Category | Default: Blank (Uncategorized) |
| **Codex** | **KEEP** | `Category__c` | Category | Small restricted picklist / blank |

### Reasoning that matters

- **Claude — KEEP:** No change proposed. Claude retains the current API name and label.
- **Cursor — KEEP:** `Category__c` — Keep API field; fix picklist API values
- **Codex — KEEP:** Keep one familiar field. Simplify the values so they represent one classification level; do not add a relationship or secondary topic model yet.

**Decision focus:** All three assistants keep the API name and label. Only adopt a change if a value/default note above requires it.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 4. Check Type — `EvaluationType__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `EvaluationType__c` | Check Type | Picklist | true | `None specified` |

**Current picklist contract:** `Formula` = Check fields on this record; `Query` = Check records with a query; `CompareTwoQueries` = Compare two queries; `Apex` = Use custom Apex

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `EvaluationType__c` | Evaluation Type | Picklist / default not stated here |
| **Cursor** | **RENAME** | `EvaluationType__c` | How this check is evaluated | No type/default change stated |
| **Codex** | **RENAME** | `EvaluationType__c` | Evaluation Type | Picklist / no default |

### Reasoning that matters

- **Claude — RENAME:** Final amendment aligns the metadata field with the engine and extension contract term evaluatorType.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Align metadata with result/event vocabulary.

**Decision focus:** The assistants converge on the same API outcome; compare label and behavioral details before accepting it.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 5. Check Name (shown to users) — `CheckTitle__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `CheckTitle__c` | Check Name (shown to users) | Text | true | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `CheckTitle__c` | Check Name | Text / default not stated here |
| **Cursor** | **RENAME** | `RowTitle__c` | Row title (shown on record page) | Default: None (required) |
| **Codex** | **REMOVE** | `Remove; use `MasterLabel`` | Check Name | Standard Label / required |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** Also consider: custom metadata records have a built-in Label and DeveloperName. `CheckTitle__c` may duplicate the record's built-in Label. See §3 (Identity) — this is worth resolving before freezing the schema.
- **Cursor — RENAME:** Eliminates “two labels” confusion documented in rule-fields.md.
- **Codex — REMOVE:** Avoid duplicate names.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 6. Expected Value Comes From — `ExpectedValueSource__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ExpectedValueSource__c` | Expected Value Comes From | Picklist | false | `None specified` |

**Current picklist contract:** `FixedValue` = A fixed value; `RecordFormula` = A formula on this record; `AnotherQuery` = A second query result

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ExpectedValueSource__c` | Expected Value Comes From | Picklist / default not stated here |
| **Cursor** | **RENAME** | `ExpectedValueSource__c` | Expected Value Comes From | No type/default change stated |
| **Codex** | **RENAME** | `Expected_Value_Source__c` | Expected Value Comes From | Restricted picklist/radio group / inferred only when unambiguous |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Current label is good; proposed API name finally matches it.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 7. Second Query Field/Alias — `ComparisonQueryField__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ComparisonQueryField__c` | Second Query Field/Alias | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ComparisonQueryField__c` | Comparison Query Field | Text / default not stated here |
| **Cursor** | **RENAME** | `ComparisonQueryField__c` | Second Query Field/Alias | No type/default change stated |
| **Codex** | **RENAME** | `Comparison_Query_Field_Or_Alias__c` | Value to Use from the Comparison Query | Text(255), conditional / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Same human/API pattern as the first query.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 8. Second Query — `ComparisonQuery__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ComparisonQuery__c` | Second Query | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ComparisonQuery__c` | Comparison Query | Long Text / default not stated here |
| **Cursor** | **RENAME** | `ComparisonQuery__c` | Second Query | No type/default change stated |
| **Codex** | **RENAME** | `Comparison_Query__c` | Query to Compare With | Long Text, required for two-query method / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Semantic role survives layout reordering and is clear in metadata packages.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 9. Count Must Be — `ApplicabilityCountOperator__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApplicabilityCountOperator__c` | Count Must Be | Picklist | false | `None specified` |

**Current picklist contract:** `Equals` = Equal to; `NotEquals` = Not equal to; `GreaterThan` = Greater than; `GreaterThanOrEqual` = At least; `LessThan` = Less than; `LessThanOrEqual` = At most

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `ApplicabilityCountOperator__c` | Count Must Be | Picklist / default not stated here |
| **Cursor** | **RENAME** | `ApplicabilityApplicabilityCountOperator__c` | Count Must Be | No type/default change stated |
| **Codex** | **RENAME** | `Applicability_Count_ComparisonOperator__c` | The Query Count Must Be | Restricted picklist, conditional / none |

### Reasoning that matters

- **Claude — KEEP:** `ComparisonOperator__c` → `ComparisonComparisonOperator__c`. A bare `ComparisonOperator__c` next to `ApplicabilityCountOperator__c` invites "which operator?" The `Comparison…` prefix matches the label and distinguishes it from the count operator. - `ApplicabilityCountThreshold__c` → `CountValue__c`. Label already says "Count Value"; "Threshold" is a third synonym.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Prevents confusion with the main comparison operator in Apex, validation, and plugin contracts.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 10. Count Value — `ApplicabilityCountThreshold__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApplicabilityCountThreshold__c` | Count Value | Number | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `CountValue__c` | Count Value | Number / default not stated here |
| **Cursor** | **RENAME** | `ApplicabilityApplicabilityCountThreshold__c` | Count Value | No type/default change stated |
| **Codex** | **RENAME** | `Applicability_Count_Threshold__c` | Compared With | Number(18,0), conditional / none |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** In a guided sentence: “The query count must be—at least—compared with—1.” If this reads awkwardly, render operator and threshold as one grouped control labelled “Count condition.”

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 11. Primary Query (SOQL) — `SourceQuery__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `SourceQuery__c` | Primary Query (SOQL) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `PrimaryQuery__c` | Primary Query | Long Text / default not stated here |
| **Cursor** | **RENAME** | `SourceQuery__c` | Primary Query (SOQL) | No type/default change stated |
| **Codex** | **RENAME** | `Check_Query__c` | Query to Check | Long Text, required for query methods / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Admins think in outcomes (“when does this run?”, “what query?”, “what happens if no rows?”). The current schema mixes implementation verbs (`DataQuery`, `RunThisCheckWhen`, `PassFailFormula`) with user-facing labels that do not predict the API name (`Applies To` ↔ `ApplicabilityMode__c`, `Primary Query` ↔ `SourceQuery__c`).
- **Codex — RENAME:** “Data query” is too broad and “primary” is positional. The new label is everyday language and the API remains clear to plugins.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 12. Advanced: Expected Summary (Text) — `DisplayExpectedText__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `DisplayExpectedText__c` | Advanced: Expected Summary (Text) | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ExpectedSummaryText__c` | Expected Summary (Text) | Text / default not stated here |
| **Cursor** | **RENAME** | `MultiRowExpectedSummary__c` | Advanced: Expected Summary (Text) | No type/default change stated |
| **Codex** | **RENAME** | `Expected_Value_Summary__c` | Summary of the Expected Value | Text(255) / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Paired terminology and no “Advanced” or data type in label.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 13. Advanced: Expected Value (Formula) — `DisplayExpectedFormula__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `DisplayExpectedFormula__c` | Advanced: Expected Value (Formula) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `DisplayExpectedFormula__c` | Expected Value (Formula) | Long Text / default not stated here |
| **Cursor** | **RENAME** | `DisplayExpectedFormula__c` | Advanced: Expected Value (Formula) | No type/default change stated |
| **Codex** | **RENAME** | `DisplayDisplayExpectedFormula__c` | Display: Expected Value Formula | Long Text(8,192) / blank |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** `DisplayFoundFormula__c` / `DisplayExpectedFormula__c` affect only the displayed chips, never pass/fail. Beyond grouping them in the Advanced section, prefix the labels with "Display:" ("Display: Found value formula") so no one confuses them with `PassConditionFormula__c`. (A `Display…` API prefix is a reasonable option too, but the label prefix alone carries the signal without extra churn.)
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Clearly display-only.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 14. Primary Query Field/Alias — `SourceQueryField__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `SourceQueryField__c` | Primary Query Field/Alias | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `PrimaryQueryField__c` | Primary Query Field | Text / default not stated here |
| **Cursor** | **RENAME** | `SourceQueryField__c` | Primary Query Field/Alias | No type/default change stated |
| **Codex** | **RENAME** | `Check_Query_Field_Or_Alias__c` | Value to Use from the Query | Text(255), conditional / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Explains purpose without requiring knowledge of evaluator internals. API name documents valid field/alias input.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 15. Fix Instructions — `FixMessage__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `FixMessage__c` | Fix Instructions | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `FixMessage__c` | Fix Instructions | Long Text / default not stated here |
| **Cursor** | **KEEP** | `FixMessage__c` | Fix instructions | No type/default change stated |
| **Codex** | **RENAME** | `Resolution_Instructions__c` | How to Resolve It | Long Text / blank |

### Reasoning that matters

- **Claude — KEEP:** No change proposed. Claude retains the current API name and label.
- **Cursor — KEEP:** No change proposed. Cursor retains the current API name and label.
- **Codex — RENAME:** Plain label tells the configurator what to write. “Resolution” is neutral and works for notifications, work-item, and UI extensions.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 16. Expected Value (Fixed) — `ExpectedFixedValue__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ExpectedFixedValue__c` | Expected Value (Fixed) | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ExpectedExpectedFixedValue__c` | Expected Value (Fixed) | Text / default not stated here |
| **Cursor** | **RENAME** | `ExpectedLiteral__c` | Expected Value (Fixed) | No type/default change stated |
| **Codex** | **RENAME** | `Configured_Expected_Value__c` | Expected Value | Text(255), conditional / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** “Fixed” is misleading because metadata can change. API name distinguishes entered configuration from formula/query sources.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 17. Advanced: Found Summary (Text) — `DisplayFoundText__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `DisplayFoundText__c` | Advanced: Found Summary (Text) | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `FoundSummaryText__c` | Found Summary (Text) | Text / default not stated here |
| **Cursor** | **RENAME** | `MultiRowFoundSummary__c` | Advanced: Found Summary (Text) | No type/default change stated |
| **Codex** | **RENAME** | `Found_Value_Summary__c` | Summary of the Value Found | Text(255) / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Removes layout terms while retaining the product’s familiar Found/Expected vocabulary.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 18. Advanced: Found Value (Formula) — `DisplayFoundFormula__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `DisplayFoundFormula__c` | Advanced: Found Value (Formula) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `DisplayFoundFormula__c` | Found Value (Formula) | Long Text / default not stated here |
| **Cursor** | **RENAME** | `DisplayFoundFormula__c` | Advanced: Found Value (Formula) | No type/default change stated |
| **Codex** | **RENAME** | `DisplayDisplayFoundFormula__c` | Display: Found Value Formula | Long Text(8,192) / blank |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** `DisplayFoundFormula__c` / `DisplayExpectedFormula__c` affect only the displayed chips, never pass/fail. Beyond grouping them in the Advanced section, prefix the labels with "Display:" ("Display: Found value formula") so no one confuses them with `PassConditionFormula__c`. (A `Display…` API prefix is a reasonable option too, but the label prefix alone carries the signal without extra churn.)
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Clearly display-only.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 19. Active — `IsActive__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `IsActive__c` | Active | Checkbox | false | `true` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `IsActive__c` | Active | Checkbox / default not stated here |
| **Cursor** | **KEEP** | `IsActive__c` | Active | Default: `true` (checked) — new check sets should work immediately after deploy. |
| **Codex** | **RENAME** | `Is_Active__c` | Active | Checkbox / `true` |

### Reasoning that matters

- **Claude — KEEP:** is `IsActive__c`. A checkbox label is a state, not a question.
- **Cursor — KEEP:** Standard Salesforce pattern; label and API align.
- **Codex — RENAME:** Custom metadata needs a simple enabled state, not a record lifecycle.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 20. Max Rows (safety cap, max 2000) — `MaxQueryRows__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `MaxQueryRows__c` | Max Rows (safety cap, max 2000) | Number | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `MaxQueryRows__c` | Max Rows | Number / default not stated here |
| **Cursor** | **CHANGE LABEL/BEHAVIOR** | `MaxQueryRows__c` | Row limit (max 2,000) | Default: Blank (engine cap 2000) |
| **Codex** | **RENAME** | `Maximum_Query_Records__c` | Maximum Query Records | Number(4,0) / product-safe default |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — CHANGE LABEL/BEHAVIOR:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Label reads clearly without parenthetical instructions. API makes the limited resource explicit to extension authors.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 21. Message When Check Cannot Run — `UnableToEvaluateMessage__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `UnableToEvaluateMessage__c` | Message When Check Cannot Run | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `CannotEvaluateMessage__c` | Message When Cannot Run | Long Text / default not stated here |
| **Cursor** | **RENAME** | `UnavailableMessage__c` | Message when unable to check | Default: Blank — engine defaults apply. |
| **Codex** | **RENAME** | `Unable_To_Evaluate_Message__c` | Message When the Check Cannot Be Completed | Long Text / standard core message |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Separates an evaluation outcome from execution initiation. API term should match the result/event contract exactly.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 22. Message When Check Fails — `FailureMessage__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `FailureMessage__c` | Message When Check Fails | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `FailureMessage__c` | Message When Failed | Long Text / default not stated here |
| **Cursor** | **RENAME** | `FailureMessage__c` | Message when failed | Default: None (required) |
| **Codex** | **RENAME** | `Failure_Message__c` | Message When the Check Fails | Long Text, conditionally required / none |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** The visible label is conversational; API name is stable and compact for result plugins.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 23. Comparison Operator — `ComparisonOperator__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ComparisonOperator__c` | Comparison Operator | Picklist | false | `None specified` |

**Current picklist contract:** `Equals` = Equals; `NotEquals` = Does not equal; `GreaterThan` = Greater than; `GreaterThanOrEqual` = Greater than or equal; `LessThan` = Less than; `LessThanOrEqual` = Less than or equal; `Contains` = Contains text; `DoesNotContain` = Does not contain text; `IsBlank` = Is empty; `IsNotBlank` = Is not empty; `ListContainsAny` = List includes any of; `ListDoesNotContainAny` = List excludes all of; `ListsOverlap` = Lists share any value; `ListContainsAll` = List includes all of; `ExactListMatch` = Lists match exactly

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ComparisonComparisonOperator__c` | Comparison Operator | Picklist / default not stated here |
| **Cursor** | **RENAME** | `ComparisonComparisonOperator__c` | Compare using | No type/default change stated |
| **Codex** | **RENAME** | `Comparison_ComparisonOperator__c` | The Check Passes When the Value Found | Restricted picklist / none |

### Reasoning that matters

- **Claude — RENAME:** `ComparisonOperator__c` → `ComparisonComparisonOperator__c`. A bare `ComparisonOperator__c` next to `ApplicabilityCountOperator__c` invites "which operator?" The `Comparison…` prefix matches the label and distinguishes it from the count operator. - `ApplicabilityCountThreshold__c` → `CountValue__c`. Label already says "Count Value"; "Threshold" is a third synonym.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** In a guided editor, values finish the sentence: “equals the expected value.” Standard layout can retain “Comparison Operator.”

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 24. Pass Condition (Formula) — `PassConditionFormula__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `PassConditionFormula__c` | Pass Condition (Formula) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `PassConditionFormula__c` | Pass Condition | Long Text / default not stated here |
| **Cursor** | **RENAME** | `PassConditionFormula__c` | Pass condition formula | Default: Blank (required when type = Formula) |
| **Codex** | **RENAME** | `Pass_Condition_Formula__c` | The Check Passes When This Formula Is True | Long Text, required for record-formula method / blank |

### Reasoning that matters

- **Claude — RENAME:** `PassConditionFormula__c` → `PassConditionFormula__c`. "Pass/Fail" doesn't say which boolean means what. "Pass Condition" states the semantics: the formula is the condition under which the check passes (true = pass). The `…Formula` suffix keeps the family stem with the other formula fields.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Makes Boolean result semantics obvious without opening documentation.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 25. Action Button Label — `ActionLabel__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ActionLabel__c` | Action Button Label | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ActionLabel__c` | Action Label | Text / default not stated here |
| **Cursor** | **RENAME** | `RemediationLinkLabel__c` | Remediation link label | No type/default change stated |
| **Codex** | **RENAME** | `Action_Label__c` | Action Label | Text(80) / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Removes button rendering and “primary” when only one action exists. Plugins may render a link, button, or work item.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 26. Action Button URL — `ActionUrl__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ActionUrl__c` | Action Button URL | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ActionUrl__c` | Action URL | Long Text / default not stated here |
| **Cursor** | **RENAME** | `RemediationLinkUrl__c` | Remediation link URL | No type/default change stated |
| **Codex** | **RENAME** | `Action_URL__c` | Action URL | URL-capable text/Long Text / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Removes rendering detail and uses the familiar Salesforce/API term URL. Label and URL must be configured together.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 27. Expected Formula (on this record) — `ExpectedRecordFormula__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ExpectedRecordFormula__c` | Expected Formula (on this record) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ExpectedRecordFormula__c` | Expected Value (Formula) | Long Text / default not stated here |
| **Cursor** | **RENAME** | `ExpectedRecordFormula__c` | Expected Formula (on this record) | No type/default change stated |
| **Codex** | **RENAME** | `Expected_Value_Record_Formula__c` | Formula for the Expected Value | Long Text, conditional / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Natural label and unambiguous API name distinguish record formula from display formula.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 28. Check Set — `Record_Health_Check_Set__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `Record_Health_Check_Set__c` | Check Set | MetadataRelationship | true | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `Check_Set__c` | Check Set | Metadata Relationship / default not stated here |
| **Cursor** | **KEEP** | `Record_Health_Check_Set__c` | Check Set | No type/default change stated |
| **Codex** | **RENAME** | `Check_Set__c` | Check Set | Metadata relationship, required / none |

### Reasoning that matters

- **Claude — RENAME:** `Record_Health_Check_Set__c` → `Check_Set__c`. The full-object-name prefix is redundant on a field that already lives on the check; `Check_Set__c` matches the label exactly. - `FailureSeverity__c` (keep). Label stays "Failure Severity" — the qualifier is meaningful (severity only applies to a failed check). See §7 for the recommended default.
- **Cursor — KEEP:** No change proposed. Cursor retains the current API name and label.
- **Codex — RENAME:** The parent type already supplies the full domain name. Shorter API name is clear in Apex and package metadata.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 29. Prerequisite Check (Developer Name) — `PrerequisiteRule__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `PrerequisiteRule__c` | Prerequisite Check (Developer Name) | Text | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `PrerequisiteCheck__c` | Prerequisite Check | Text / default not stated here |
| **Cursor** | **RENAME** | `PrerequisiteRule__c` | Prerequisite rule | Default: Blank |
| **Codex** | **RENAME** | `Prerequisite_Check_Developer_Name__c` | Check That Must Pass First | Text(255) / blank |

### Reasoning that matters

- **Claude — RENAME:** `PrerequisiteRule__c` → `PrerequisiteCheck__c`. "Requires Check" is ambiguous (requires a check? requires checking?); "Prerequisite Check" states it. Help text: "Developer Name of another check in this set that must pass before this one runs."
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Keep the simple current deployment model, make the stored identifier explicit, and validate that it resolves within the Check Set.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 30. Run Order (lower runs first) — `EvaluationOrder__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `EvaluationOrder__c` | Run Order (lower runs first) | Number | true | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `EvaluationOrder__c` | Run Order | Number / default not stated here |
| **Cursor** | **RENAME** | `EvaluationOrder__c` | Evaluation order | Default: None (required) — author must set intentionally. |
| **Codex** | **RENAME** | `Check_Order__c` | Check Order | Number(9,2), required / `100` |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** “Run order” conflates with check set “when checks run”. “Evaluation order” is precise.
- **Codex — RENAME:** Label is immediately understandable; ordering instructions move to guided UI/help. “Check” clarifies scope when the API name appears alone.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 31. Applies To — `ApplicabilityMode__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApplicabilityMode__c` | Applies To | Picklist | true | `None specified` |

**Current picklist contract:** `Always` = All records (default); `Formula` = Only records where a formula is true; `SOQL` = Only records where a count query matches

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `AppliesTo__c` | Applies To | Picklist / default not stated here |
| **Cursor** | **RENAME** | `ApplicabilityMode__c` | Run this check for | No type/default change stated |
| **Codex** | **RENAME** | `Applicability_Rule__c` | Which Records Should Be Checked? | Restricted picklist/radio group / `ALL_RECORDS` |

### Reasoning that matters

- **Claude — RENAME:** `ApplicabilityMode__c` → "Applies To", picklist value `SOQL` → "count query matches"). This is a full field-by-field redesign with the reasoning for each choice, plus recommended defaults and a picklist value convention, so you can judge each call.
- **Cursor — RENAME:** Admins think in outcomes (“when does this run?”, “what query?”, “what happens if no rows?”). The current schema mixes implementation verbs (`DataQuery`, `RunThisCheckWhen`, `PassFailFormula`) with user-facing labels that do not predict the API name (`Applies To` ↔ `ApplicabilityMode__c`, `Primary Query` ↔ `SourceQuery__c`).
- **Codex — RENAME:** Natural question for daily Salesforce configuration; API uses the established extension-contract term applicability.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 32. Applies When Count Query Matches — `ApplicabilityCountQuery__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApplicabilityCountQuery__c` | Applies When Count Query Matches | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `AppliesWhenCountQuery__c` | Applies When (Count Query) | Long Text / default not stated here |
| **Cursor** | **RENAME** | `ApplicabilityCountQuery__c` | Applies When Count Query Matches | No type/default change stated |
| **Codex** | **RENAME** | `Applicability_Count_Query__c` | Query Used to Decide Which Records Are Checked | Long Text, conditional / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Makes purpose clear before the user writes SOQL. API specifies that the result is a count.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 33. Applies When Formula Is True — `ApplicabilityFormula__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ApplicabilityFormula__c` | Applies When Formula Is True | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `AppliesWhenFormula__c` | Applies When (Formula) | Long Text / default not stated here |
| **Cursor** | **RENAME** | `ApplicabilityFormula__c` | Applies When Formula Is True | No type/default change stated |
| **Codex** | **RENAME** | `Applicability_Formula__c` | Check Records Where This Formula Is True | Long Text, conditional / blank |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Label explains the behavior directly. API is concise and consistent.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 34. Advanced: Formula Result Type — `FormulaResultType__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `FormulaResultType__c` | Advanced: Formula Result Type | Picklist | false | `None specified` |

**Current picklist contract:** `Auto` = Auto (detect type) (default); `Boolean` = Checkbox (true/false); `Number` = Number / Currency / Percent; `Date` = Date; `DateTime` = Date/Time; `Text` = Text

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `FormulaResultType__c` | Formula Result Type | Picklist / default not stated here |
| **Cursor** | **RENAME** | `DisplayFormulaDataType__c` | Advanced: Formula Result Type | No type/default change stated |
| **Codex** | **RENAME** | `DisplayFormulaDataType__c` | Display Formula Data Type | Picklist / `Auto` |

### Reasoning that matters

- **Claude — RENAME:** `FormulaResultType__c` → `FormulaResultType__c`. "Scalar" is engine jargon; the label already says "Formula Result Type." - `PrimaryAction…` → `Action…`. There is no secondary action; the `Primary` qualifier implies one and adds nothing.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Removes scalar jargon and groups display fields.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 35. Failure Severity — `FailureSeverity__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `FailureSeverity__c` | Failure Severity | Picklist | true | `None specified` |

**Current picklist contract:** `Error` = Error; `Warning` = Warning (default); `Info` = Info

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `FailureSeverity__c` | Failure Severity | Picklist / default not stated here |
| **Cursor** | **CHANGE LABEL/BEHAVIOR** | `FailureSeverity__c` | Severity when failed | Default: `Warning` — sensible middle ground for new rules. |
| **Codex** | **RENAME** | `Failure_FailureSeverity__c` | If This Check Fails, Show It As | Restricted picklist / `WARNING` |

### Reasoning that matters

- **Claude — KEEP:** Keep the field, but replace severity value Error with Critical (or High) so Error remains reserved for the system ERROR status.
- **Cursor — CHANGE LABEL/BEHAVIOR:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Guided-editor label completes a sentence; API name remains concise and makes clear that severity applies only to failures. Standard layout may use the shorter label “Failure Severity.”

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 36. Description (hover tooltip) — `CheckDescription__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `CheckDescription__c` | Description (hover tooltip) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `Description__c` | Description | Long Text / default not stated here |
| **Cursor** | **RENAME** | `RowDescription__c` | Row description (tooltip) | Default: Blank |
| **Codex** | **RENAME** | `Check_Description__c` | Check Description | Long Text / blank |

### Reasoning that matters

- **Claude — RENAME:** they read as unrelated (`EvaluationType__c` → "Check Type", `CheckDescription__c` → "Description", `ApplicabilityMode__c` → "Applies To", picklist value `SOQL` → "count query matches"). This is a full field-by-field redesign with the reasoning for each choice, plus recommended defaults and a picklist value convention, so you can judge each call.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Does not couple the content to hover behavior; works for mobile, accessibility, cards, APIs, and future presentation plugins.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 37. Value To Test (list checks only) — `FindInListFormula__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `FindInListFormula__c` | Value To Test (list checks only) | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `FindInListFormula__c` | Value To Test | Long Text / default not stated here |
| **Cursor** | **RENAME** | `ListTestValueFormula__c` | Value To Test (list checks only) | No type/default change stated |
| **Codex** | **RENAME** | `Configured_List_Values__c` | Values to Find in the List | Long Text using one documented delimiter / blank |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** The current singular name and parenthetical are unclear. Keep one field; do not add JSON or child metadata unless a demonstrated requirement needs richer structure.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 38. How To Interpret Query Results — `QueryResultHandling__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `QueryResultHandling__c` | How To Interpret Query Results | Picklist | false | `None specified` |

**Current picklist contract:** `OneResult` = Expect one row or aggregate result (default); `AnyRowPasses` = At least one record must pass; `AllRowsPass` = Every record must pass; `CompareAsLists` = Compare query results as lists

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `QueryResultHandling__c` | How To Read Query Results | Picklist / default not stated here |
| **Cursor** | **RENAME** | `QueryResultMode__c` | Query result interpretation | No type/default change stated |
| **Codex** | **RENAME** | `Query_Record_Evaluation__c` | When the Query Returns Records | Restricted picklist/radio group / `EXPECT_ONE_RESULT` |

### Reasoning that matters

- **Claude — RENAME:** `QueryResultHandling__c` → `QueryResultHandling__c`. The field governs how all results are read (one row, any-row-passes, all-rows-pass, compare-as-lists), not only the multi-row case. The label "How To Read Query Results" is plainer than "Interpret." - `ComparisonOperator__c` → `ComparisonComparisonOperator__c`. A bare `ComparisonOperator__c` next to `ApplicabilityCountOperator__c` invites "which operator?" The `Comparison…` prefix matches the label and distinguishes it from the count operator. - `ApplicabilityCountThreshold__c` → `CountValue__c`. Label already says "Count Value"; "Threshold" is a third synonym.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Current API describes only multiple rows though the field defines the overall evaluation mode. Label/value pair explains any/each/list behavior.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 39. If Query Field Value Is Empty — `EmptyValueHandling__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `EmptyValueHandling__c` | If Query Field Value Is Empty | Picklist | false | `None specified` |

**Current picklist contract:** `SkipRecordsWithMissingValue` = Ignore records with empty values (default); `TreatMissingAsBlank` = Treat empty values as blank; `MissingMeansNoMatch` = Treat empty values as not matching

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `EmptyValueHandling__c` | If Field Value Is Empty | Picklist / default not stated here |
| **Cursor** | **RENAME** | `NullValueBehavior__c` | If a row’s field value is empty | No type/default change stated |
| **Codex** | **RENAME** | `Blank_Query_Value_Behavior__c` | If a Query Value Is Blank | Restricted picklist/radio group / none |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Uses Salesforce-friendly “blank,” separates returned value from zero rows, and requires an intentional semantic choice.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 40. If Query Finds No Records — `NoRowsResult__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `NoRowsResult__c` | If Query Finds No Records | Picklist | false | `None specified` |

**Current picklist contract:** `Pass` = Pass the check; `Fail` = Fail the check; `Skip` = Skip the check; `UnableToEvaluate` = Show cannot check

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `NoRowsResult__c` | If Query Finds No Records | Picklist / no default; require an explicit choice |
| **Cursor** | **RENAME** | `EmptyQueryBehavior__c` | If the query returns no rows | No type/default change stated |
| **Codex** | **RENAME** | `No_Records_Behavior__c` | If the Query Finds No Records | Restricted picklist/radio group / none |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Current label is already strong. Proposed API states it is configurable behavior, not a timestamp-like “when.” Explicit choice prevents inverted business meaning.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

# Record Health Check Set


## 41. Found/Expected Display — `FoundExpectedDisplay__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `FoundExpectedDisplay__c` | Found/Expected Display | Picklist | true | `None specified` |

**Current picklist contract:** `OnDemand` = On demand (default); `FailuresOnly` = Failed checks only; `AllRows` = Show on every check

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `FoundExpectedDisplay__c` | Found/Expected Display | Picklist / default not stated here |
| **Cursor** | **RENAME** | `FoundExpectedVisibility__c` | When to show Found and Expected | No type/default change stated |
| **Codex** | **RENAME** | `Comparison_Detail_Display__c` | Show Comparison Details | Restricted picklist / `WHEN_REQUESTED` |

### Reasoning that matters

- **Claude — RENAME:** `FoundExpectedDisplay__c` → `FoundExpectedDisplay__c`. Matches the label and the Found/Expected vocabulary used throughout the checks. - `ShowDiagnostics__c` → `ShowTroubleshootingDetails__c`. The label is already the plain effect; the API should match it (principle 5/6). "diagnostics mode" is developer jargon on an admin field.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** Removes project jargon from the label and names the general detail contract consumed by core UI or presentation plugins.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 42. Show Troubleshooting Details — `ShowDiagnostics__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ShowDiagnostics__c` | Show Troubleshooting Details | Checkbox | false | `false` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ShowTroubleshootingDetails__c` | Show Troubleshooting Details | Checkbox / default not stated here |
| **Cursor** | **RENAME** | `TroubleshootingEnabled__c` | Troubleshooting mode | Default: `false` — troubleshooting is opt-in per check set. |
| **Codex** | **RENAME** | `Show_Diagnostic_Details__c` | Show Diagnostic Details | Checkbox / `false` |

### Reasoning that matters

- **Claude — RENAME:** `ShowDiagnostics__c` → `ShowTroubleshootingDetails__c`. The label is already the plain effect; the API should match it (principle 5/6). "diagnostics mode" is developer jargon on an admin field.
- **Cursor — RENAME:** Label and API both say “troubleshooting”; avoid “debug” in Setup (implies developer-only).
- **Codex — RENAME:** The setting controls visible details, not a broad diagnostics mode. This prevents plugins from interpreting it as permission to change logging or execution.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 43. Active — `IsActive__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `IsActive__c` | Active | Checkbox | false | `true` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `IsActive__c` | Active | Checkbox / default not stated here |
| **Cursor** | **KEEP** | `IsActive__c` | Active | Default: `true` (checked) — new check sets should work immediately after deploy. |
| **Codex** | **RENAME** | `Is_Active__c` | Active | Checkbox / `true` |

### Reasoning that matters

- **Claude — KEEP:** is `IsActive__c`. A checkbox label is a state, not a question.
- **Cursor — KEEP:** Standard Salesforce pattern; label and API align.
- **Codex — RENAME:** Custom metadata needs a simple enabled state, not a record lifecycle.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 44. Record Object API Name — `ObjectApiName__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `ObjectApiName__c` | Record Object API Name | Text | true | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **CHANGE LABEL/BEHAVIOR** | `ObjectApiName__c` | Object API Name | Text / default not stated here |
| **Cursor** | **RENAME** | `TargetObject__c` | Object | Default: None (required) — force explicit choice during authoring. |
| **Codex** | **RENAME** | `Record_Object_API_Name__c` | Object to Check | Text(255), required / none |

### Reasoning that matters

- **Claude — CHANGE LABEL/BEHAVIOR:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** “Target” signals runtime scope; label “Object” is sufficient with help text for API name format. Shorter than “Record Object API Name”.
- **Codex — RENAME:** The label says what the selection means in ordinary language. The API name remains precise for plugins that need the evaluated object.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 45. Card Title — `CardTitle__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `CardTitle__c` | Card Title | Text | true | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `PanelTitle__c` | Card Title | Text / default not stated here |
| **Cursor** | **RENAME** | `CardTitle__c` | Card title | Default: None (required) |
| **Codex** | **RENAME** | `DisplayHeading__c` | Display Heading | Text(255) |

### Reasoning that matters

- **Claude — RENAME:** `CardTitle__c`/`CardSubtitle__c` → `PanelTitle__c`/`PanelSubtitle__c`. Labels already say "Title"/"Subtitle"; "Heading"/"Subheading" is a synonym drift. - `CardRunMode__c` → `StartMode__c`. The values are `Automatic`/`Manual` — it's a start mode. Label stays plain ("Start Checks"). - `FoundExpectedDisplay__c` → `FoundExpectedDisplay__c`. Matches the label and the Found/Expected vocabulary used throughout the checks. - `ShowDiagnostics__c` → `ShowTroubleshootingDetails__c`. The label is already the plain effect; the API should match it (principle 5/6). "diagnostics mode" is developer jargon on an admin field.
- **Cursor — RENAME:** Matches Lightning “card” metaphor used in LWC and docs.
- **Codex — RENAME:** Presentation-neutral and compact.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 46. Card Subtitle — `CardSubtitle__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `CardSubtitle__c` | Card Subtitle | LongTextArea | false | `None specified` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `PanelSubtitle__c` | Card Subtitle | Long Text / default not stated here |
| **Cursor** | **RENAME** | `CardSubtitle__c` | Card subtitle | Default: Blank |
| **Codex** | **RENAME** | `DisplayDescription__c` | Display Description | Long Text(2,048) |

### Reasoning that matters

- **Claude — RENAME:** `CardTitle__c`/`CardSubtitle__c` → `PanelTitle__c`/`PanelSubtitle__c`. Labels already say "Title"/"Subtitle"; "Heading"/"Subheading" is a synonym drift. - `CardRunMode__c` → `StartMode__c`. The values are `Automatic`/`Manual` — it's a start mode. Label stays plain ("Start Checks"). - `FoundExpectedDisplay__c` → `FoundExpectedDisplay__c`. Matches the label and the Found/Expected vocabulary used throughout the checks. - `ShowDiagnostics__c` → `ShowTroubleshootingDetails__c`. The label is already the plain effect; the API should match it (principle 5/6). "diagnostics mode" is developer jargon on an admin field.
- **Cursor — RENAME:** Pairs with `CardTitle__c`.
- **Codex — RENAME:** Presentation-neutral explanatory text.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 47. Passed Checks — `PassedChecksDisplay__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `PassedChecksDisplay__c` | Passed Checks | Picklist | true | `None specified` |

**Current picklist contract:** `Show` = Show each check (default); `Hide` = Hide checks, show count only

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `PassedChecksDisplay__c` | Passed Checks | Picklist / default not stated here |
| **Cursor** | **RENAME** | `PassedRowVisibility__c` | Passed checks in list | Default: `ShowInList` |
| **Codex** | **RENAME** | `Passed_Check_Display__c` | Show Passed Checks | Restricted picklist / `EACH_CHECK` |

### Reasoning that matters

- **Claude — KEEP:** No change proposed. Claude retains the current API name and label.
- **Cursor — RENAME:** Parallel naming with skipped field; “display” → “visibility” aligns with enum.
- **Codex — RENAME:** The value is not truly show/hide because a count remains visible. The new values state what is shown and are safe for extension/UI consumers.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 48. How checks appear — `CardRevealMode__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `CardRevealMode__c` | How checks appear | Picklist | true | `None specified` |

**Current picklist contract:** `AllAtOnce` = Show all checks at once; `OneAtATime` = Reveal checks one at a time (default)

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `ChecksAppearance__c` | How Checks Appear | Picklist / default not stated here |
| **Cursor** | **RENAME** | `RowRevealMode__c` | How rows appear on the card | No type/default change stated |
| **Codex** | **RENAME** | `Check_Display_Timing__c` | When to Show Checks | Restricted picklist / `AS_EVALUATION_PROGRESSSES` |

### Reasoning that matters

- **Claude — RENAME:** Claude proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** The current option controls when rows become visible, not how completed results look. The new label and values state the exact timing.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 49. Start Checks — `CardRunMode__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `CardRunMode__c` | Start Checks | Picklist | true | `None specified` |

**Current picklist contract:** `Automatic` = Run automatically when the page opens; `Manual` = Wait for the user to click Run (default)

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **RENAME** | `StartMode__c` | Start Checks | Picklist / default not stated here |
| **Cursor** | **RENAME** | `RunTrigger__c` | When checks run | No type/default change stated |
| **Codex** | **RENAME** | `Execution_Trigger__c` | Run Checks | Restricted picklist / `WHEN_REQUESTED` |

### Reasoning that matters

- **Claude — RENAME:** `CardRunMode__c` → `StartMode__c`. The values are `Automatic`/`Manual` — it's a start mode. Label stays plain ("Start Checks"). - `FoundExpectedDisplay__c` → `FoundExpectedDisplay__c`. Matches the label and the Found/Expected vocabulary used throughout the checks. - `ShowDiagnostics__c` → `ShowTroubleshootingDetails__c`. The label is already the plain effect; the API should match it (principle 5/6). "diagnostics mode" is developer jargon on an admin field.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** The label and options form natural sentences: Run Checks—When requested. “Trigger” is familiar Salesforce vocabulary and says the stored choice controls initiation.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 50. Skipped Checks — `SkippedChecksDisplay__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `SkippedChecksDisplay__c` | Skipped Checks | Picklist | true | `None specified` |

**Current picklist contract:** `Show` = Show each check (default); `Hide` = Hide checks, show count only

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `SkippedChecksDisplay__c` | Skipped Checks | Picklist / default not stated here |
| **Cursor** | **RENAME** | `SkippedRowVisibility__c` | Skipped checks in list | Default: `ShowInList` |
| **Codex** | **RENAME** | `Not_Run_Check_Display__c` | Show Checks That Did Not Run | Restricted picklist / `EACH_CHECK` |

### Reasoning that matters

- **Claude — KEEP:** No change proposed. Claude retains the current API name and label.
- **Cursor — RENAME:** Cursor proposes the change shown above but does not provide a separate field-specific reason in its final summary. Review the naming principle before accepting it.
- **Codex — RENAME:** “Skipped” can be technical and can hide several causes. The visible label explains the experience. Final API terminology must match the chosen result status (`NOT_APPLICABLE` or `SKIPPED`).

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---

## 51. Stop After System Error — `StopOnSystemError__c`

### Current definition

| API name | Label | Type | Required | Default |
|---|---|---|---:|---|
| `StopOnSystemError__c` | Stop After System Error | Checkbox | false | `false` |

### Proposal comparison

| Source | Decision | Proposed API name | Proposed label | Type/default position |
|---|---|---|---|---|
| **Claude** | **KEEP** | `StopOnSystemError__c` | Stop After System Error | Checkbox / default not stated here |
| **Cursor** | **RENAME** | `StopOnEngineError__c` | Stop after engine error | Default: `false` — most check sets should complete all rules unless explicitly debugging engine issues. |
| **Codex** | **RENAME** | `OnUnexpectedError__c` | After an Unexpected Error | Picklist / `ContinueChecks` |

### Reasoning that matters

- **Claude — KEEP:** No change proposed. Claude retains the current API name and label.
- **Cursor — RENAME:** “System” is ambiguous (Salesforce platform vs product). Card shows “System Error” to users; metadata should say “engine”.
- **Codex — RENAME:** Both policies are explicit.

**Decision focus:** The assistants disagree on the API contract. This is a naming decision, not consensus; choose the vocabulary that should remain stable in code and extensions.

**Final decision:** ☐ Keep current  ☐ Claude  ☐ Cursor  ☐ Codex  ☐ Custom decision

**Notes:** ____________________________________________________________________________

---
