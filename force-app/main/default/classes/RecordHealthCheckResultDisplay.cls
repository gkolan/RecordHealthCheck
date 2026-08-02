/**
 * Optional human-facing rendering derived from an Evaluation Result.
 */
global class RecordHealthCheckResultDisplay {
  @AuraEnabled
  global String renderedMessage;
  @AuraEnabled
  global String renderedFix;
  @AuraEnabled
  global String foundDisplayValue;
  @AuraEnabled
  global String expectedDisplayValue;
  @AuraEnabled
  global String foundDisplayFormat;
  @AuraEnabled
  global String expectedDisplayFormat;
  @AuraEnabled
  global String foundCurrencyIsoCode;
  @AuraEnabled
  global String expectedCurrencyIsoCode;
  @AuraEnabled
  global String actionLabel;
  @AuraEnabled
  global String actionUrl;
  @AuraEnabled
  global RecordHealthCheckAdminDetail adminDetail;
}
