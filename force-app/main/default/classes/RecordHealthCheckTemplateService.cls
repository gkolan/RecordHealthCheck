/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared parser, validator, discovery, and resolver for namespaced merge tokens. */
public class RecordHealthCheckTemplateService {
  public static final String SURFACE_DISPLAY = 'DISPLAY';
  public static final String SURFACE_URL = 'URL';
  public static final String SURFACE_SOQL = 'SOQL';
  private static final Integer MAX_TOKENS = 100;
  private static final Integer MAX_RESOLVED_LENGTH = 20000;
  private static final Pattern TOKEN_PATTERN = Pattern.compile(
    '\\{!([^{}]+)\\}'
  );

  public class TemplateException extends Exception {
    public String reasonCode;
    public String token;
  }

  public static List<RecordHealthCheckToken> parse(String template) {
    List<RecordHealthCheckToken> tokens = new List<RecordHealthCheckToken>();
    if (String.isBlank(template))
      return tokens;
    Matcher matcher = TOKEN_PATTERN.matcher(template);
    while (matcher.find()) {
      String body = matcher.group(1);
      Integer fallbackSeparator = body.indexOf('|');
      String reference = fallbackSeparator >= 0
        ? body.substring(0, fallbackSeparator).trim()
        : body.trim();
      String fallbackValue = fallbackSeparator >= 0
        ? body.substring(fallbackSeparator + 1)
        : null;
      Integer dot = reference.indexOf('.');
      String namespaceName = dot > 0 ? reference.substring(0, dot) : null;
      String property = dot > 0 &&
        dot < reference.length() - 1
        ? reference.substring(dot + 1)
        : null;
      tokens.add(
        new RecordHealthCheckToken(
          matcher.group(0),
          namespaceName,
          property,
          fallbackValue,
          matcher.start(),
          matcher.end()
        )
      );
    }
    return tokens;
  }

  public static List<RecordHealthCheckTokenIssue> validate(
    String template,
    String surface
  ) {
    List<RecordHealthCheckTokenIssue> issues = new List<RecordHealthCheckTokenIssue>();
    if (String.isBlank(template))
      return issues;
    List<RecordHealthCheckToken> tokens = parse(template);
    if (containsStrayBrace(template, tokens)) {
      issues.add(
        issue(
          'MALFORMED_TOKEN',
          null,
          'Curly braces are reserved for complete merge tokens and cannot appear outside one.'
        )
      );
      return issues;
    }
    if (tokens.size() > MAX_TOKENS) {
      issues.add(
        issue(
          'TOKEN_LIMIT_EXCEEDED',
          null,
          'A template may contain at most 100 tokens.'
        )
      );
    }
    for (RecordHealthCheckToken token : tokens) {
      if (token.namespaceName == null || token.propertyPath == null) {
        issues.add(
          issue(
            'LEGACY_FLAT_TOKEN',
            token.expression,
            'Flat merge tokens are not supported. Use {!record.' +
              token.expression.substring(2, token.expression.length() - 1) +
              '}.'
          )
        );
      } else if (
        !RecordHealthCheckTokenRegistry.NAMESPACES.contains(token.namespaceName)
      ) {
        issues.add(
          issue(
            'UNSUPPORTED_TOKEN_NAMESPACE',
            token.expression,
            'Unsupported token namespace "' + token.namespaceName + '".'
          )
        );
      } else if (
        !RecordHealthCheckTokenRegistry.contains(
          token.namespaceName,
          token.propertyPath
        )
      ) {
        issues.add(
          issue(
            'UNKNOWN_TOKEN_PROPERTY',
            token.expression,
            'Unknown property "' +
              token.propertyPath +
              '" in namespace "' +
              token.namespaceName +
              '".'
          )
        );
      } else if (surface == SURFACE_SOQL && token.namespaceName != 'record') {
        issues.add(
          issue(
            'TOKEN_NOT_ALLOWED_ON_SURFACE',
            token.expression,
            'Only record tokens are allowed in SOQL templates.'
          )
        );
      } else if (surface == SURFACE_URL && token.namespaceName == 'rhcResult') {
        issues.add(
          issue(
            'TOKEN_NOT_ALLOWED_ON_SURFACE',
            token.expression,
            'Result tokens are not allowed in URL templates.'
          )
        );
      }
    }
    return issues;
  }

  private static Boolean containsStrayBrace(
    String template,
    List<RecordHealthCheckToken> tokens
  ) {
    Integer cursor = 0;
    for (RecordHealthCheckToken token : tokens) {
      String outsideToken = template.substring(cursor, token.startIndex);
      if (outsideToken.contains('{') || outsideToken.contains('}'))
        return true;
      cursor = token.endIndex;
    }
    String trailingText = template.substring(cursor);
    return trailingText.contains('{') || trailingText.contains('}');
  }

  private static RecordHealthCheckTokenIssue issue(
    String code,
    String token,
    String message
  ) {
    return new RecordHealthCheckTokenIssue(code, token, message);
  }

  public static Set<String> recordPaths(String template, String surface) {
    assertValid(template, surface);
    Set<String> paths = new Set<String>();
    for (RecordHealthCheckToken token : parse(template)) {
      if (token.namespaceName == 'record')
        paths.add(token.propertyPath);
    }
    return paths;
  }

  public static void assertValid(String template, String surface) {
    List<RecordHealthCheckTokenIssue> issues = validate(template, surface);
    if (!issues.isEmpty()) {
      TemplateException ex = new TemplateException(issues[0].message);
      ex.reasonCode = issues[0].reasonCode;
      ex.token = issues[0].token;
      throw ex;
    }
  }

  public static String resolveDisplay(
    String template,
    RecordHealthCheckMergeContext context
  ) {
    return resolve(template, context, false);
  }

  public static String resolveUrl(
    String template,
    RecordHealthCheckMergeContext context
  ) {
    return resolve(template, context, true);
  }

  private static String resolve(
    String template,
    RecordHealthCheckMergeContext context,
    Boolean urlEncode
  ) {
    if (String.isBlank(template))
      return template;
    assertValid(template, urlEncode ? SURFACE_URL : SURFACE_DISPLAY);
    String resolved = '';
    Integer lastEnd = 0;
    for (RecordHealthCheckToken token : parse(template)) {
      Object raw = valueFor(token, context);
      String value = raw == null ? '' : formatValue(raw);
      if (String.isBlank(value)) {
        if (token.fallbackValue != null) {
          value = token.fallbackValue;
        } else if (urlEncode) {
          TemplateException ex = new TemplateException(
            'A URL token resolved blank and has no explicit fallback. Token: ' +
            token.expression
          );
          ex.reasonCode = 'MISSING_TOKEN_VALUE';
          ex.token = token.expression;
          throw ex;
        }
      }
      if (urlEncode && String.isNotBlank(value))
        value = EncodingUtil.urlEncode(value, 'UTF-8');
      resolved += template.substring(lastEnd, token.startIndex) + value;
      lastEnd = token.endIndex;
    }
    resolved += template.substring(lastEnd);
    if (resolved.length() > MAX_RESOLVED_LENGTH) {
      TemplateException ex = new TemplateException(
        'The resolved template exceeds 20,000 characters.'
      );
      ex.reasonCode = 'RESOLVED_TEMPLATE_TOO_LONG';
      throw ex;
    }
    return resolved;
  }

  public static Object valueFor(
    RecordHealthCheckToken token,
    RecordHealthCheckMergeContext context
  ) {
    if (context == null)
      unavailable(token, 'Merge context is unavailable.');
    if (token.namespaceName == 'record') {
      if (context.record == null)
        unavailable(token, 'The record is not available.');
      return resolveFieldPath(context.record, token.propertyPath);
    }
    if (token.namespaceName == 'rhcRule') {
      if (context.rule == null)
        unavailable(token, 'Rule metadata is not available.');
      return ruleValue(context.rule, token.propertyPath);
    }
    if (token.namespaceName == 'rhcSet') {
      if (context.checkSet == null)
        unavailable(token, 'Check Set metadata is not available.');
      return setValue(context.checkSet, token.propertyPath);
    }
    if (token.namespaceName == 'rhcResult') {
      if (!context.resultFinalized || context.result == null)
        unavailable(token, 'The result is not finalized.');
      return resultValue(context, token.propertyPath);
    }
    if (token.namespaceName == 'rhcRun') {
      if (context.run == null)
        unavailable(token, 'The run context is not available.');
      return runValue(context.run, token.propertyPath);
    }
    unavailable(token, 'The token namespace is not supported.');
    return null;
  }

  private static void unavailable(
    RecordHealthCheckToken token,
    String message
  ) {
    TemplateException ex = new TemplateException(
      message + ' Token: ' + token.expression
    );
    ex.reasonCode = 'TOKEN_NOT_AVAILABLE_IN_PHASE';
    ex.token = token.expression;
    throw ex;
  }

  public static Object resolveFieldPath(SObject record, String fieldPath) {
    List<String> parts = fieldPath.split('\\.');
    if (parts.size() > 6)
      unavailable(
        new RecordHealthCheckToken(
          '{!record.' + fieldPath + '}',
          'record',
          fieldPath,
          0,
          0
        ),
        'Record relationship depth exceeds five.'
      );
    SObject current = record;
    for (Integer i = 0; i < parts.size() - 1; i++) {
      current = current.getSObject(parts[i]);
      if (current == null)
        return null;
    }
    return current.get(parts[parts.size() - 1]);
  }

  private static Object ruleValue(
    Record_Health_Check_Rule__mdt rule,
    String property
  ) {
    if (property == 'developerName')
      return rule.DeveloperName;
    if (property == 'masterLabel')
      return rule.MasterLabel;
    if (property == 'checkTitle')
      return rule.CheckTitle__c;
    if (property == 'checkDescription')
      return rule.CheckDescription__c;
    if (property == 'category')
      return displayLabel(String.valueOf(dynamicGet(rule, 'Category__c')));
    if (property == 'evaluationType')
      return displayLabel(String.valueOf(rule.EvaluationType__c));
    if (property == 'failureSeverity')
      return displayLabel(String.valueOf(rule.FailureSeverity__c));
    if (property == 'evaluationOrder')
      return rule.EvaluationOrder__c;
    return null;
  }

  private static Object setValue(SObject checkSet, String property) {
    if (property == 'developerName')
      return dynamicGet(checkSet, 'DeveloperName');
    if (property == 'masterLabel')
      return dynamicGet(checkSet, 'MasterLabel');
    if (property == 'cardTitle')
      return dynamicGet(checkSet, 'CardTitle__c');
    if (property == 'cardSubtitle')
      return dynamicGet(checkSet, 'CardSubtitle__c');
    if (property == 'objectApiName')
      return dynamicGet(checkSet, 'ObjectApiName__c');
    return null;
  }

  private static Object resultValue(
    RecordHealthCheckMergeContext context,
    String property
  ) {
    if (property == 'status')
      return context.result.status;
    if (property == 'foundValue')
      return context.result.actualValue;
    if (property == 'foundValuePluralSuffix') {
      try {
        Decimal foundNumber = Decimal.valueOf(
          context.result.actualValue.replace(',', '').trim()
        );
        return foundNumber == 1 ? '' : 's';
      } catch (Exception ignored) {
        return 's';
      }
    }
    if (property == 'expectedValue')
      return context.result.expectedValue;
    if (property == 'failedRecordCount')
      return context.failedRecordCount;
    if (property == 'totalRecordCount')
      return context.totalRecordCount;
    if (property == 'reasonCode')
      return context.result.reasonCode;
    return null;
  }

  private static Object runValue(
    RecordHealthCheckRunContext run,
    String property
  ) {
    if (property == 'runId')
      return run.runId;
    if (property == 'source')
      return run.source;
    if (property == 'startedAt')
      return run.startedAt;
    if (property == 'completedAt')
      return run.completedAt;
    if (property == 'durationMs')
      return run.durationMs;
    return null;
  }

  private static Object dynamicGet(SObject source, String fieldName) {
    try {
      return source.get(fieldName);
    } catch (Exception ex) {
      return null;
    }
  }

  private static String displayLabel(String stored) {
    if (String.isBlank(stored) || stored == 'null')
      return '';
    List<String> words = stored.toLowerCase().replace('_', ' ').split(' ');
    List<String> labels = new List<String>();
    for (String word : words) {
      if (String.isNotBlank(word))
        labels.add(word.left(1).toUpperCase() + word.substring(1));
    }
    return String.join(labels, ' ');
  }

  private static String formatValue(Object raw) {
    if (raw instanceof Datetime)
      return ((Datetime) raw).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    return String.valueOf(raw) == 'null' ? '' : String.valueOf(raw);
  }
}
