/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared validation helpers used at runtime and in CI; they do not change org data. */
public with sharing class RecordHealthCheckConfigValidator {
  private static Map<String, RecordHealthCheckRule> validatedPluginInstances = new Map<String, RecordHealthCheckRule>();
  public static RecordHealthCheckTokenIssue firstTemplateIssue(
    Record_Health_Check_Rule__mdt rule
  ) {
    if (rule == null) {
      return null;
    }
    List<List<Object>> templates = new List<List<Object>>{
      new List<Object>{
        rule.FailureMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.UnableToEvaluateMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.ApplicabilityNotMetMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.FixMessage__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.ActionLabel__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.DisplayFoundText__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.DisplayExpectedText__c,
        RecordHealthCheckTemplateService.SURFACE_DISPLAY
      },
      new List<Object>{
        rule.ActionUrl__c,
        RecordHealthCheckTemplateService.SURFACE_URL
      },
      new List<Object>{
        rule.SourceQuery__c,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      },
      new List<Object>{
        rule.ComparisonQuery__c,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      },
      new List<Object>{
        rule.ApplicabilityCountQuery__c,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      }
    };
    for (List<Object> entry : templates) {
      List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
        (String) entry[0],
        (String) entry[1]
      );
      if (!issues.isEmpty()) {
        return issues[0];
      }
    }
    return null;
  }

  public static Boolean isValidObjectApiName(String objectApiName) {
    return String.isNotBlank(objectApiName) &&
      RecordHealthCheckDescribeCache.containsObject(objectApiName);
  }

  public static Boolean isValidApexPlugin(String className) {
    if (String.isBlank(className)) {
      return false;
    }
    try {
      Type pluginType = Type.forName(className);
      if (pluginType == null) {
        return false;
      }
      RecordHealthCheckRule instance = RecordHealthCheckPluginDispatch.instantiate(
        pluginType
      );
      if (instance == null) {
        return false;
      }
      validatedPluginInstances.put(className, instance);
      return true;
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      return false;
    }
  }

  public static RecordHealthCheckRule takeValidatedPlugin(String className) {
    RecordHealthCheckRule instance = validatedPluginInstances.get(className);
    validatedPluginInstances.remove(className);
    return instance;
  }

  /** Releases a validated plugin instance when later validation rejects its Rule. */
  public static void discardValidatedPlugin(String className) {
    if (String.isNotBlank(className)) {
      validatedPluginInstances.remove(className);
    }
  }

  @TestVisible
  private static void cachePluginForTest(
    String className,
    RecordHealthCheckRule instance
  ) {
    validatedPluginInstances.put(className, instance);
  }

  public static Boolean isJsonObject(String jsonText) {
    if (String.isBlank(jsonText)) {
      return true;
    }
    try {
      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        jsonText
      );
      return parsed != null;
    } catch (Exception ex) {
      return false;
    }
  }
}
