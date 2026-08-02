import fs from "node:fs";
import path from "node:path";

const root = path.resolve("extensions/observability/force-app/main/default");
const xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
const ns = ' xmlns="http://soap.sforce.com/2006/04/metadata"';
const esc = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
const write = (relative, content) => {
  const target = path.join(root, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, xml + content.trim() + "\n");
};

const picklist = (values) =>
  `<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>${values.map((value, index) => `<value><fullName>${esc(value)}</fullName><default>${index === 0}</default><label>${esc(value.replaceAll("_", " "))}</label></value>`).join("")}</valueSetDefinition></valueSet>`;
const fieldBody = (field) => {
  const common = `<fullName>${field.name}</fullName><label>${esc(field.label)}</label><description>${esc(field.description)}</description><inlineHelpText>${esc(field.help)}</inlineHelpText>`;
  if (field.type === "Text")
    return `${common}<length>${field.length}</length>${field.external ? "<externalId>true</externalId>" : ""}${field.unique ? "<unique>true</unique>" : ""}<type>Text</type>`;
  if (field.type === "LongTextArea")
    return `${common}<length>${field.length}</length><visibleLines>${field.lines ?? 5}</visibleLines><type>LongTextArea</type>`;
  if (field.type === "Number")
    return `${common}<precision>${field.precision ?? 18}</precision><scale>0</scale><type>Number</type>`;
  if (field.type === "Checkbox")
    return `${common}<defaultValue>false</defaultValue><type>Checkbox</type>`;
  if (field.type === "DateTime") return `${common}<type>DateTime</type>`;
  if (field.type === "Url") return `${common}<type>Url</type>`;
  if (field.type === "Lookup")
    return `${common}<deleteConstraint>SetNull</deleteConstraint><referenceTo>${field.referenceTo}</referenceTo><relationshipLabel>${esc(field.relationshipLabel)}</relationshipLabel><relationshipName>${field.relationshipName}</relationshipName><required>false</required><type>Lookup</type>`;
  if (field.type === "MasterDetail")
    return `${common}<referenceTo>${field.referenceTo}</referenceTo><relationshipLabel>${esc(field.relationshipLabel)}</relationshipLabel><relationshipName>${field.relationshipName}</relationshipName><relationshipOrder>0</relationshipOrder><reparentableMasterDetail>false</reparentableMasterDetail><type>MasterDetail</type><writeRequiresMasterRead>false</writeRequiresMasterRead>`;
  if (field.type === "Picklist")
    return `${common}<type>Picklist</type>${picklist(field.values)}`;
  throw new Error(`Unsupported field type ${field.type}`);
};

const runFields = [
  {
    name: "Run_Id__c",
    label: "Run ID",
    type: "Text",
    length: 120,
    external: true,
    unique: true,
    description:
      "Stores the correlation identifier shared by every result and error from one execution.",
    help: "Use this value to correlate Framework logs, events, and captured observations."
  },
  {
    name: "Source__c",
    label: "Source",
    type: "Picklist",
    values: [
      "APEX",
      "FLOW",
      "QUEUEABLE",
      "BATCH",
      "USER_INITIATED",
      "SCHEDULED",
      "AGENT",
      "APEX_API",
      "UNKNOWN"
    ],
    description: "Identifies the entry path that initiated the health check.",
    help: "Use Source to separate interactive, declarative, and asynchronous execution."
  },
  {
    name: "Status__c",
    label: "Status",
    type: "Picklist",
    values: [
      "IN_PROGRESS",
      "PASS",
      "FAIL",
      "SKIPPED",
      "UNABLE_TO_EVALUATE",
      "ERROR"
    ],
    description: "Stores the aggregate terminal status for the captured run.",
    help: "ERROR and UNABLE TO EVALUATE require operational review."
  },
  {
    name: "Check_Set_Qualified_Api_Name__c",
    label: "Check Set Qualified API Name",
    type: "Text",
    length: 120,
    description:
      "Identifies the selected Check Set without relying on a subscriber label.",
    help: "Enter or filter by the Custom Metadata QualifiedApiName."
  },
  {
    name: "Async_Job_Id__c",
    label: "Async Job ID",
    type: "Text",
    length: 18,
    description:
      "Links Queueable and Batch captures to the originating AsyncApexJob.",
    help: "Copy this ID into Apex Jobs to inspect asynchronous execution."
  },
  {
    name: "Requested_By_User_Id__c",
    label: "Requested By User ID",
    type: "Text",
    length: 18,
    description: "Stores the user who initiated a directly captured run.",
    help: "Use this immutable ID when correlating the run to user activity."
  },
  {
    name: "Started_At__c",
    label: "Started At",
    type: "DateTime",
    description: "Records when the extension began the captured execution.",
    help: "Compare with Completed At to understand elapsed wall time."
  },
  {
    name: "Completed_At__c",
    label: "Completed At",
    type: "DateTime",
    description:
      "Records when response capture or lifecycle-event processing completed.",
    help: "Blank means the run has not received a terminal update."
  },
  {
    name: "Record_Count__c",
    label: "Record Count",
    type: "Number",
    precision: 9,
    description: "Counts records submitted in the request scope.",
    help: "Use this value to compare single-record and bulk behavior."
  },
  {
    name: "Rule_Count__c",
    label: "Rule Count",
    type: "Number",
    precision: 9,
    description: "Counts selected Rules reported by Framework.",
    help: "Use this with Record Count when reviewing total evaluation volume."
  },
  {
    name: "Passed_Count__c",
    label: "Passed Count",
    type: "Number",
    precision: 9,
    description: "Counts PASS outcomes in the response.",
    help: "This count includes every evaluated record and Rule pair."
  },
  {
    name: "Failed_Count__c",
    label: "Failed Count",
    type: "Number",
    precision: 9,
    description: "Counts FAIL outcomes in the response.",
    help: "Open related observations to inspect each failed outcome."
  },
  {
    name: "Skipped_Count__c",
    label: "Skipped Count",
    type: "Number",
    precision: 9,
    description: "Counts SKIPPED outcomes in the response.",
    help: "Review prerequisite and applicability reasons when unexpectedly high."
  },
  {
    name: "Unable_Count__c",
    label: "Unable Count",
    type: "Number",
    precision: 9,
    description: "Counts UNABLE_TO_EVALUATE outcomes in the response.",
    help: "Review related observations for configuration or access failures."
  },
  {
    name: "System_Error_Count__c",
    label: "System Error Count",
    type: "Number",
    precision: 9,
    description: "Counts ERROR outcomes in the response.",
    help: "Treat nonzero values as operational failures requiring investigation."
  },
  {
    name: "Contract_Version__c",
    label: "Contract Version",
    type: "Text",
    length: 10,
    description:
      "Stores the lifecycle or API contract version used by the run.",
    help: "Use this when reconciling payload changes across package upgrades."
  },
  {
    name: "Framework_Version__c",
    label: "Framework Version",
    type: "Text",
    length: 20,
    description:
      "Stores the Record Health Check Framework version reported by an event.",
    help: "Use this to identify the behavior version that produced the result."
  },
  {
    name: "Last_Event_Id__c",
    label: "Last Event ID",
    type: "Text",
    length: 80,
    description:
      "Stores the most recent lifecycle event identifier applied to the run.",
    help: "Use this identifier when diagnosing duplicate or delayed event delivery."
  }
];

const observationFields = [
  {
    name: "Run__c",
    label: "Run",
    type: "MasterDetail",
    referenceTo: "Record_Health_Check_Run__c",
    relationshipLabel: "Observations",
    relationshipName: "Observations",
    description:
      "Groups this outcome or framework error under its captured execution.",
    help: "Open the parent Run to review source, scope, and summary totals."
  },
  {
    name: "Capture_Key__c",
    label: "Capture Key",
    type: "Text",
    length: 255,
    external: true,
    unique: true,
    description:
      "Prevents redelivered events or repeated capture calls from creating duplicate observations.",
    help: "Generated by the extension; do not edit this idempotency key."
  },
  {
    name: "Event_Id__c",
    label: "Event ID",
    type: "Text",
    length: 80,
    description:
      "Stores the Framework lifecycle or log event identifier when event-backed.",
    help: "Use this identifier to reconcile an observation with Event Monitoring."
  },
  {
    name: "Observation_Type__c",
    label: "Observation Type",
    type: "Picklist",
    values: ["RULE_RESULT", "FRAMEWORK_ERROR"],
    description:
      "Distinguishes an actionable Rule outcome from a captured framework log error.",
    help: "Framework Error rows contain exception and stack information when available."
  },
  {
    name: "Source__c",
    label: "Source",
    type: "Text",
    length: 40,
    description: "Stores the exact direct or event-reported execution origin.",
    help: "Examples include FLOW, QUEUEABLE, BATCH, APEX, and USER_INITIATED."
  },
  {
    name: "Status__c",
    label: "Status",
    type: "Picklist",
    values: ["FAIL", "UNABLE_TO_EVALUATE", "ERROR"],
    description:
      "Stores the actionable terminal status represented by this observation.",
    help: "Only failed, unable, and system-error outcomes are persisted."
  },
  {
    name: "Severity__c",
    label: "Severity",
    type: "Text",
    length: 30,
    description: "Stores the configured failure severity for a Rule result.",
    help: "Use severity to prioritize business failures; framework errors may be blank."
  },
  {
    name: "Reason_Code__c",
    label: "Reason Code",
    type: "Text",
    length: 120,
    description:
      "Stores the stable machine-readable reason code from Framework.",
    help: "Filter and aggregate by reason code before relying on message wording."
  },
  {
    name: "Error_Code__c",
    label: "Error Code",
    type: "Text",
    length: 120,
    description: "Stores the framework log code for an error observation.",
    help: "Use this code to group recurring framework failures."
  },
  {
    name: "Check_Set_Qualified_Api_Name__c",
    label: "Check Set Qualified API Name",
    type: "Text",
    length: 120,
    description:
      "Identifies the Check Set associated with the outcome or error.",
    help: "This value remains stable when administrators change display labels."
  },
  {
    name: "Rule_Qualified_Api_Name__c",
    label: "Rule Qualified API Name",
    type: "Text",
    length: 120,
    description: "Identifies the Rule associated with the outcome or error.",
    help: "Blank is valid for run-level framework errors."
  },
  {
    name: "Record_Id__c",
    label: "Record ID",
    type: "Text",
    length: 18,
    description:
      "Stores the evaluated Salesforce record ID without creating a polymorphic lookup.",
    help: "Copy this ID to locate the affected business record."
  },
  {
    name: "Occurred_At__c",
    label: "Occurred At",
    type: "DateTime",
    description:
      "Records when Framework produced the outcome or framework error.",
    help: "Use this timestamp for incident timelines and retention policies."
  },
  {
    name: "Message__c",
    label: "Message",
    type: "LongTextArea",
    length: 32768,
    lines: 6,
    description:
      "Stores rendered user guidance or the framework error message.",
    help: "This field may contain restricted diagnostic detail; share carefully."
  },
  {
    name: "Fix_Instructions__c",
    label: "Fix Instructions",
    type: "LongTextArea",
    length: 32768,
    lines: 5,
    description: "Stores rendered remediation guidance supplied by the Rule.",
    help: "Use this guidance before escalating a business-data failure."
  },
  {
    name: "Found_Value_JSON__c",
    label: "Found Value JSON",
    type: "LongTextArea",
    length: 32768,
    lines: 4,
    description:
      "Stores the typed Found value exactly as returned by the evaluation contract.",
    help: "Review field access before sharing this potentially sensitive value."
  },
  {
    name: "Expected_Value_JSON__c",
    label: "Expected Value JSON",
    type: "LongTextArea",
    length: 32768,
    lines: 4,
    description:
      "Stores the typed Expected value exactly as returned by the evaluation contract.",
    help: "Compare this structured value with Found Value JSON during triage."
  },
  {
    name: "Found_Display_Value__c",
    label: "Found Display Value",
    type: "LongTextArea",
    length: 32768,
    lines: 3,
    description:
      "Stores the human-formatted Found value when display content was requested.",
    help: "Use this presentation value for administrator review, not integrations."
  },
  {
    name: "Expected_Display_Value__c",
    label: "Expected Display Value",
    type: "LongTextArea",
    length: 32768,
    lines: 3,
    description:
      "Stores the human-formatted Expected value when display content was requested.",
    help: "Use this presentation value for administrator review, not integrations."
  },
  {
    name: "Comparison_Operator__c",
    label: "Comparison Operator",
    type: "Text",
    length: 40,
    description: "Stores the comparison operator applied by the Rule.",
    help: "Interpret Found and Expected values using this operator."
  },
  {
    name: "Action_Label__c",
    label: "Action Label",
    type: "Text",
    length: 255,
    description: "Stores the label for the Rule remediation action.",
    help: "Displayed with Action URL when the failed Rule provides a safe link."
  },
  {
    name: "Action_URL__c",
    label: "Action URL",
    type: "Url",
    description: "Stores the sanitized remediation URL returned by Framework.",
    help: "Open only when you understand the affected record and remediation."
  },
  {
    name: "Exception_Type__c",
    label: "Exception Type",
    type: "Text",
    length: 120,
    description: "Stores the Apex exception type for framework errors.",
    help: "Use exception type with Error Code to group technical failures."
  },
  {
    name: "Stack_Trace__c",
    label: "Stack Trace",
    type: "LongTextArea",
    length: 32768,
    lines: 10,
    description:
      "Stores the Apex stack trace published by the enabled Framework error log.",
    help: "Restrict this field to administrators and support personnel."
  },
  {
    name: "Raw_Payload__c",
    label: "Raw Payload",
    type: "LongTextArea",
    length: 131072,
    lines: 10,
    description:
      "Stores the complete serialized response item or platform event for forensic review.",
    help: "This field can contain restricted diagnostics and should remain admin-only."
  },
  {
    name: "Contains_Restricted_Detail__c",
    label: "Contains Restricted Detail",
    type: "Checkbox",
    description:
      "Marks observations whose source says restricted diagnostic detail is present.",
    help: "Do not export or broadly share marked observations."
  },
  {
    name: "User_Id__c",
    label: "User ID",
    type: "Text",
    length: 18,
    description: "Stores the user associated with a Framework error log event.",
    help: "Use this immutable ID to identify the execution user."
  },
  {
    name: "Contract_Version__c",
    label: "Contract Version",
    type: "Text",
    length: 10,
    description: "Stores the Framework payload contract version.",
    help: "Use this during extension and Framework upgrade reconciliation."
  },
  {
    name: "Framework_Version__c",
    label: "Framework Version",
    type: "Text",
    length: 20,
    description:
      "Stores the Framework version that produced an event-backed observation.",
    help: "Use this to correlate failures with deployed Framework behavior."
  }
];

const objects = [
  {
    api: "Record_Health_Check_Run__c",
    label: "Record Health Check Run",
    plural: "Record Health Check Runs",
    format: "RHC-RUN-{000000}",
    nameLabel: "Run Number",
    sharing: "Private",
    description:
      "The Record Health Check Run object groups one evaluation request and its outcome totals. It captures source, Check Set identity, correlation and async job identifiers, timing, record and Rule counts, and status totals. Commonly used for operational monitoring, failure triage, and bulk-run reporting.",
    fields: runFields
  },
  {
    api: "Record_Health_Check_Observation__c",
    label: "Record Health Check Observation",
    plural: "Record Health Check Observations",
    format: "RHC-OBS-{000000}",
    nameLabel: "Observation Number",
    sharing: "ControlledByParent",
    description:
      "The Record Health Check Observation object stores actionable Rule outcomes and framework errors under a Run. It captures record and Rule identity, source, reason, severity, messages, values, remediation, exceptions, stack traces, and raw payloads. Commonly used for triage, support, compliance evidence, and error-log retention.",
    fields: observationFields
  }
];

for (const object of objects) {
  write(
    `objects/${object.api}/${object.api}.object-meta.xml`,
    `<CustomObject${ns}><deploymentStatus>Deployed</deploymentStatus><description>${esc(object.description)}</description><enableHistory>true</enableHistory><enableReports>true</enableReports><enableSearch>true</enableSearch><label>${object.label}</label><nameField><displayFormat>${object.format}</displayFormat><label>${object.nameLabel}</label><type>AutoNumber</type></nameField><pluralLabel>${object.plural}</pluralLabel><sharingModel>${object.sharing}</sharingModel><visibility>Public</visibility></CustomObject>`
  );
  for (const field of object.fields)
    write(
      `objects/${object.api}/fields/${field.name}.field-meta.xml`,
      `<CustomField${ns}>${fieldBody(field)}</CustomField>`
    );
}

const listView = (object, name, label, columns, filters = []) =>
  write(
    `objects/${object}/listViews/${name}.listView-meta.xml`,
    `<ListView${ns}><fullName>${name}</fullName><filterScope>Everything</filterScope><label>${label}</label>${columns.map((column) => `<columns>${column}</columns>`).join("")}${filters.map((filter) => `<filters><field>${filter.field}</field><operation>${filter.operation}</operation><value>${filter.value}</value></filters>`).join("")}</ListView>`
  );
listView("Record_Health_Check_Run__c", "Recent_Runs", "Recent Runs", [
  "NAME",
  "Source__c",
  "Status__c",
  "Check_Set_Qualified_Api_Name__c",
  "Completed_At__c"
]);
listView(
  "Record_Health_Check_Run__c",
  "Runs_Needing_Attention",
  "Runs Needing Attention",
  [
    "NAME",
    "Source__c",
    "Status__c",
    "Check_Set_Qualified_Api_Name__c",
    "Failed_Count__c",
    "Unable_Count__c",
    "System_Error_Count__c"
  ],
  [{ field: "Status__c", operation: "notEqual", value: "PASS" }]
);
listView(
  "Record_Health_Check_Run__c",
  "Async_Runs",
  "Batch and Queueable Runs",
  [
    "NAME",
    "Source__c",
    "Status__c",
    "Async_Job_Id__c",
    "Record_Count__c",
    "Completed_At__c"
  ],
  [{ field: "Source__c", operation: "equals", value: "BATCH,QUEUEABLE" }]
);
listView(
  "Record_Health_Check_Observation__c",
  "All_Failures",
  "All Captured Failures",
  [
    "NAME",
    "Observation_Type__c",
    "Source__c",
    "Status__c",
    "Severity__c",
    "Reason_Code__c",
    "Occurred_At__c"
  ]
);
listView(
  "Record_Health_Check_Observation__c",
  "Framework_Errors",
  "Framework Errors",
  [
    "NAME",
    "Source__c",
    "Error_Code__c",
    "Exception_Type__c",
    "Check_Set_Qualified_Api_Name__c",
    "Occurred_At__c"
  ],
  [
    {
      field: "Observation_Type__c",
      operation: "equals",
      value: "FRAMEWORK_ERROR"
    }
  ]
);
listView(
  "Record_Health_Check_Observation__c",
  "Unable_To_Evaluate",
  "Unable to Evaluate",
  [
    "NAME",
    "Source__c",
    "Reason_Code__c",
    "Check_Set_Qualified_Api_Name__c",
    "Rule_Qualified_Api_Name__c",
    "Record_Id__c"
  ],
  [{ field: "Status__c", operation: "equals", value: "UNABLE_TO_EVALUATE" }]
);

const item = (field, behavior = "Readonly") =>
  `<layoutItems><behavior>${behavior}</behavior><field>${field}</field></layoutItems>`;
const section = (label, left, right) =>
  `<layoutSections><customLabel>true</customLabel><detailHeading>true</detailHeading><editHeading>true</editHeading><label>${esc(label)}</label><layoutColumns>${left.map((field) => item(field)).join("")}</layoutColumns><layoutColumns>${right.map((field) => item(field)).join("")}</layoutColumns><style>TwoColumnsLeftToRight</style></layoutSections>`;
write(
  "layouts/Record_Health_Check_Run__c-Record Health Check Run Layout.layout-meta.xml",
  `<Layout${ns}>${section("Execution", ["Run_Id__c", "Source__c", "Status__c", "Check_Set_Qualified_Api_Name__c"], ["Async_Job_Id__c", "Requested_By_User_Id__c", "Started_At__c", "Completed_At__c"])}${section("Scope and Outcomes", ["Record_Count__c", "Rule_Count__c", "Passed_Count__c", "Failed_Count__c"], ["Skipped_Count__c", "Unable_Count__c", "System_Error_Count__c"])}${section("Contract", ["Contract_Version__c", "Framework_Version__c"], ["Last_Event_Id__c"])}<relatedLists><fields>NAME</fields><fields>Observation_Type__c</fields><fields>Status__c</fields><fields>Severity__c</fields><fields>Reason_Code__c</fields><fields>Occurred_At__c</fields><relatedList>Record_Health_Check_Observation__c.Run__c</relatedList></relatedLists><showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>true</showHighlightsPanel><showInteractionLogPanel>false</showInteractionLogPanel></Layout>`
);
write(
  "layouts/Record_Health_Check_Observation__c-Record Health Check Observation Layout.layout-meta.xml",
  `<Layout${ns}>${section("Outcome", ["Observation_Type__c", "Status__c", "Severity__c", "Reason_Code__c", "Error_Code__c"], ["Source__c", "Occurred_At__c", "Contains_Restricted_Detail__c", "Event_Id__c"])}${section("Evaluation Context", ["Run__c", "Check_Set_Qualified_Api_Name__c", "Rule_Qualified_Api_Name__c"], ["Record_Id__c", "User_Id__c", "Comparison_Operator__c"])}${section("Guidance and Values", ["Message__c", "Fix_Instructions__c", "Action_Label__c", "Action_URL__c"], ["Found_Display_Value__c", "Expected_Display_Value__c", "Found_Value_JSON__c", "Expected_Value_JSON__c"])}${section("Technical Detail", ["Exception_Type__c", "Stack_Trace__c"], ["Raw_Payload__c", "Capture_Key__c", "Contract_Version__c", "Framework_Version__c"])}<showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>true</showHighlightsPanel><showInteractionLogPanel>false</showInteractionLogPanel></Layout>`
);

write(
  "tabs/Record_Health_Check_Run__c.tab-meta.xml",
  `<CustomTab${ns}><customObject>true</customObject><motif>Custom48: Trophy</motif><description>Browse captured Record Health Check execution summaries.</description></CustomTab>`
);
write(
  "tabs/Record_Health_Check_Observation__c.tab-meta.xml",
  `<CustomTab${ns}><customObject>true</customObject><motif>Custom57: Building Block</motif><description>Investigate captured Rule failures and framework errors.</description></CustomTab>`
);
write(
  "applications/Record_Health_Check_Observability.app-meta.xml",
  `<CustomApplication${ns}><brand><headerColor>#16325C</headerColor><shouldOverrideOrgTheme>true</shouldOverrideOrgTheme></brand><description>Investigate Record Health Check runs, failed outcomes, and framework errors.</description><formFactors>Large</formFactors><isNavAutoTempTabsDisabled>false</isNavAutoTempTabsDisabled><isNavPersonalizationDisabled>false</isNavPersonalizationDisabled><label>Record Health Check Observability</label><navType>Standard</navType><tabs>Record_Health_Check_Run__c</tabs><tabs>Record_Health_Check_Observation__c</tabs><tabs>standard-report</tabs><tabs>standard-Dashboard</tabs><uiType>Lightning</uiType></CustomApplication>`
);

const sensitive = new Set([
  "Message__c",
  "Fix_Instructions__c",
  "Found_Value_JSON__c",
  "Expected_Value_JSON__c",
  "Found_Display_Value__c",
  "Expected_Display_Value__c",
  "Stack_Trace__c",
  "Raw_Payload__c"
]);
const permissionSet = (name, label, admin) => {
  const classes = [
    "RecordHealthCheckCaptureService",
    "RecordHealthCheckCaptureFlowAction",
    "RecordHealthCheckCaptureQueueable",
    "RecordHealthCheckCaptureBatch"
  ];
  const fieldPermissions = objects
    .flatMap((object) =>
      object.fields
        .filter(
          (field) =>
            field.type !== "MasterDetail" &&
            (admin || !sensitive.has(field.name))
        )
        .map(
          (field) =>
            `<fieldPermissions><editable>${admin}</editable><field>${object.api}.${field.name}</field><readable>true</readable></fieldPermissions>`
        )
    )
    .join("");
  const objectPermissions = objects
    .map(
      (object) =>
        `<objectPermissions><allowCreate>${admin}</allowCreate><allowDelete>${admin}</allowDelete><allowEdit>${admin}</allowEdit><allowRead>true</allowRead><modifyAllRecords>${admin}</modifyAllRecords><object>${object.api}</object><viewAllRecords>true</viewAllRecords></objectPermissions>`
    )
    .join("");
  const classAccess = admin
    ? classes
        .map(
          (apexClass) =>
            `<classAccesses><apexClass>${apexClass}</apexClass><enabled>true</enabled></classAccesses>`
        )
        .join("")
    : "";
  write(
    `permissionsets/${name}.permissionset-meta.xml`,
    `<PermissionSet${ns}>${classAccess}<description>${admin ? "Run captured health checks and administer all observability records, including restricted values, raw payloads, messages, and stack traces." : "Read captured health check runs and operational outcome fields without restricted values, messages, raw payloads, or stack traces."}</description>${fieldPermissions}<hasActivationRequired>false</hasActivationRequired><label>${label}</label>${objectPermissions}<tabSettings><tab>Record_Health_Check_Run__c</tab><visibility>Visible</visibility></tabSettings><tabSettings><tab>Record_Health_Check_Observation__c</tab><visibility>Visible</visibility></tabSettings></PermissionSet>`
  );
};
permissionSet(
  "Record_Health_Check_Observability_Admin",
  "Record Health Check Observability Admin",
  true
);
permissionSet(
  "Record_Health_Check_Observability_Viewer",
  "Record Health Check Observability Viewer",
  false
);
