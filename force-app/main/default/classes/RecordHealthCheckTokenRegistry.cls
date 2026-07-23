/** The complete allowlist for product-qualified Framework tokens. */
public class RecordHealthCheckTokenRegistry {
  public static final Set<String> NAMESPACES = new Set<String>{
    'record',
    'rhcRule',
    'rhcSet',
    'rhcResult',
    'rhcRun'
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
    'foundValuePluralSuffix',
    'expectedValue',
    'failedRecordCount',
    'totalRecordCount',
    'reasonCode'
  };
  public static final Set<String> RUN_PROPERTIES = new Set<String>{
    'runId',
    'source',
    'startedAt',
    'completedAt',
    'durationMs'
  };

  public static Boolean contains(String namespaceName, String property) {
    if (namespaceName == 'record')
      return String.isNotBlank(property);
    if (namespaceName == 'rhcRule')
      return RULE_PROPERTIES.contains(property);
    if (namespaceName == 'rhcSet')
      return SET_PROPERTIES.contains(property);
    if (namespaceName == 'rhcResult')
      return RESULT_PROPERTIES.contains(property);
    if (namespaceName == 'rhcRun')
      return RUN_PROPERTIES.contains(property);
    return false;
  }
}
