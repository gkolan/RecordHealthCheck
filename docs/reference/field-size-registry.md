# Record Health Check field-size registry

> Generated from shipped metadata by `releases/v2/tools/generate_field_size_registry.py`. Do not edit by hand.

Character limits are not byte guarantees. Post-resolution limits apply after merge-token resolution; fields marked N/A are never resolved.

| Custom metadata type | Field | Storage type | Stored maximum | Post-resolution maximum | Overflow behavior |
| --- | --- | --- | ---: | ---: | --- |
| Record_Health_Check_Set__mdt | CardRevealMode__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | CardRunMode__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | CardSubtitle__c | Text | 255 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Set__mdt | CardTitle__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | FoundExpectedDisplay__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | IsActive__c | Checkbox | true/false | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | ObjectApiName__c | Text | 80 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | PassedChecksDisplay__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | PublishRunEvent__c | Checkbox | true/false | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | ShowDiagnostics__c | Checkbox | true/false | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | SkippedChecksDisplay__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Set__mdt | StopOnSystemError__c | Checkbox | true/false | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ActionLabel__c | Text | 80 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Rule__mdt | ActionUrl__c | LongTextArea | 32768 | 2,000 | Error; resolved URL is sanitized and rejected when too long |
| Record_Health_Check_Rule__mdt | ApexClass__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ApexParametersJson__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ApplicabilityCountOperator__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ApplicabilityCountQuery__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ApplicabilityCountThreshold__c | Number | 4 digits, 0 decimal places | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ApplicabilityFormula__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ApplicabilityMode__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | Category__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | CheckDescription__c | Text | 255 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Rule__mdt | CheckTitle__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ComparisonOperator__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ComparisonQueryField__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ComparisonQuery__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | DisplayExpectedFormula__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | DisplayExpectedText__c | Text | 255 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Rule__mdt | DisplayFoundFormula__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | DisplayFoundText__c | Text | 255 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Rule__mdt | EmptyValueHandling__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | EvaluationOrder__c | Number | 4 digits, 0 decimal places | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | EvaluationType__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ExpectedFixedValue__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ExpectedRecordFormula__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | ExpectedValueSource__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | FailureMessage__c | LongTextArea | 32768 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Rule__mdt | FailureSeverity__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | FindInListFormula__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | FixMessage__c | LongTextArea | 32768 | 2,048 | Error; runtime never silently truncates resolved text |
| Record_Health_Check_Rule__mdt | FormulaResultType__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | IsActive__c | Checkbox | true/false | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | MaxQueryRows__c | Number | 4 digits, 0 decimal places | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | NoRowsResult__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | PassConditionFormula__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | PrerequisiteRule__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | PublishResultEvent__c | Checkbox | true/false | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | QueryResultHandling__c | Picklist | Restricted value set | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | Record_Health_Check_Set__c | MetadataRelationship | Metadata relationship | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | SourceQueryField__c | Text | 255 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | SourceQuery__c | LongTextArea | 32768 | N/A | Metadata API enforces the stored value; no runtime truncation |
| Record_Health_Check_Rule__mdt | UnableToEvaluateMessage__c | LongTextArea | 32768 | 2,048 | Error; runtime never silently truncates resolved text |

Total fields: **53**.
