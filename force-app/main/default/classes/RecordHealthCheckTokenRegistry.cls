/** The complete allowlist for product-qualified V2 framework tokens. */
public class RecordHealthCheckTokenRegistry {
  public static final Set<String> NAMESPACES = new Set<String>{
    'record',
    'rhcRule',
    'rhcSet',
    'rhcResult'
  };
  public static final Set<String> RULE_PROPERTIES = new Set<String>{
    'developerName',
    'masterLabel',
    'checkTitle',
    'checkDescription',
    'category',
    'evaluationType',
    'failureSeverity',
    'evaluationOrder'
  };
  public static final Set<String> SET_PROPERTIES = new Set<String>{
    'developerName',
    'masterLabel',
    'cardTitle',
    'cardSubtitle',
    'objectApiName'
  };
  public static final Set<String> RESULT_PROPERTIES = new Set<String>{
    'status',
    'foundValue',
    'expectedValue',
    'failedRecordCount',
    'totalRecordCount',
    'reasonCode'
  };
  // NOTE: the `rhcRun` token namespace is deferred until run context is
  // populated on the evaluate/runSet paths (BLK-7). It is intentionally absent
  // from NAMESPACES so config validation rejects `{!rhcRun.*}` rather than
  // accepting a token that would always fail at runtime. Re-add the namespace
  // and its property allowlist together with the wiring.

  public static Boolean contains(String namespaceName, String property) {
    if (namespaceName == 'record')
      return String.isNotBlank(property);
    if (namespaceName == 'rhcRule')
      return RULE_PROPERTIES.contains(property);
    if (namespaceName == 'rhcSet')
      return SET_PROPERTIES.contains(property);
    if (namespaceName == 'rhcResult')
      return RESULT_PROPERTIES.contains(property);
    return false;
  }
}
