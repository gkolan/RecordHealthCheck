/** Resolves one configured Apex Rule implementation and its parameters. */
public with sharing class RecordHealthCheckApexPluginResolver {
  /** Returns a validated plugin instance, reusing the configuration cache. */
  public static RecordHealthCheckRule resolve(
    Record_Health_Check_Rule__mdt rule
  ) {
    Type evaluatorType = configuredType(rule.ApexClass__c);
    Object instance = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      rule.ApexClass__c
    );
    if (instance == null) {
      instance = instantiatePlugin(evaluatorType);
    }
    return requireRule(instance);
  }

  /** Returns the configured JSON object, or an empty parameter map. */
  public static Map<String, Object> parameters(
    Record_Health_Check_Rule__mdt rule
  ) {
    if (String.isBlank(rule.ApexParametersJson__c)) {
      return new Map<String, Object>();
    }
    try {
      Object parsed = JSON.deserializeUntyped(rule.ApexParametersJson__c);
      if (!(parsed instanceof Map<String, Object>)) {
        throw configurationError(
          'INVALID_APEX_PARAMETERS',
          'ApexParametersJson__c must be a JSON object.'
        );
      }
      return (Map<String, Object>) parsed;
    } catch (JSONException ex) {
      throw configurationError('INVALID_APEX_PARAMETERS', ex.getMessage());
    }
  }

  private static Type configuredType(String className) {
    if (String.isBlank(className)) {
      throw configurationError(
        'APEX_CLASS_NOT_FOUND',
        'Apex Class Name is blank.'
      );
    }
    Type evaluatorType = Type.forName(className);
    if (evaluatorType == null) {
      throw configurationError(
        'APEX_CLASS_NOT_FOUND',
        'Class "' + className + '" was not found.'
      );
    }
    return evaluatorType;
  }

  private static Object instantiatePlugin(Type evaluatorType) {
    try {
      return RecordHealthCheckPluginDispatch.instantiate(evaluatorType);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      throw configurationError('APEX_CLASS_NOT_FOUND', ex.getMessage());
    }
  }

  private static RecordHealthCheckRule requireRule(Object instance) {
    if (!(instance instanceof RecordHealthCheckRule)) {
      throw configurationError(
        'APEX_CLASS_NOT_FOUND',
        'The configured class does not implement RecordHealthCheckRule.'
      );
    }
    return (RecordHealthCheckRule) instance;
  }

  private static PluginConfigurationException configurationError(
    String reasonCode,
    String message
  ) {
    PluginConfigurationException error = new PluginConfigurationException(
      message
    );
    error.reasonCode = reasonCode;
    return error;
  }

  /** Stable configuration failure consumed by the Apex adapter. */
  public class PluginConfigurationException extends Exception {
    public String reasonCode;
  }
}
