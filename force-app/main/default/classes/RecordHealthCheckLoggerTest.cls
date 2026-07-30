/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckLoggerTest {
  // The logger writes to the Apex debug log (something we cannot read back in
  // a test context), so these tests exercise every branch for coverage and assert
  // that no path throws. The rendered output is verified by reading debug logs in
  // the org; here we guarantee the logging API is exception-safe for all inputs.

  @IsTest
  static void instanceLevelsAllExecuteWithoutError() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-123',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    Test.startTest();
    logger.debug(
      'Some_Check',
      'START',
      new Map<String, Object>{ 'type' => 'FORMULA', 'showDiagnostics' => true }
    );
    logger.info(
      'Some_Check',
      'RESULT',
      new Map<String, Object>{ 'status' => 'FAIL' }
    );
    logger.warn('Some_Check', 'METADATA_INVALID', null);
    logger.error(
      'Some_Check',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );
    Test.stopTest();

    System.assert(true, 'All instance log levels executed without throwing.');
  }

  @IsTest
  static void staticEntryPointExecutesWithoutError() {
    Test.startTest();
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'run-456',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId(),
      null,
      'CONFIG_UNEXPECTED',
      null,
      new System.NullPointerException()
    );
    Test.stopTest();

    System.assert(true, 'Static log entry point executed without throwing.');
  }

  @IsTest
  static void blankRunIdAndNullRecordAreHandled() {
    // Defensive paths: missing correlation id and no record context must not throw.
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      null,
      null,
      null
    );

    Test.startTest();
    logger.info(null, 'NO_CONTEXT', new Map<String, Object>());
    Test.stopTest();

    System.assert(
      true,
      'Logger tolerated blank runId, null config, and null record.'
    );
  }

  // ─── Platform-event ERROR destination (Record_Health_Check_Log__e) ───────────

  @IsTest
  static void errorBuffersEventWithReproContext() {
    Id recordId = UserInfo.getUserId();
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-err-1',
      'Example_Account_Relationship_Risk',
      recordId
    );

    logger.error(
      'Owner_Is_Active',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );

    List<Record_Health_Check_Log__e> pending = RecordHealthCheckLogger.pendingEventsForTest();
    System.assertEquals(1, pending.size(), 'One ERROR event should buffer.');
    Record_Health_Check_Log__e evt = pending[0];
    System.assertEquals('ERROR', evt.Level__c, 'Level is ERROR.');
    System.assertEquals('run-err-1', evt.RunId__c, 'RunId correlates the run.');
    System.assertEquals(
      String.valueOf(recordId),
      evt.RecordId__c,
      'RecordId identifies where the error happened.'
    );
    System.assertEquals(
      'Example_Account_Relationship_Risk',
      evt.CheckSetDeveloperName__c,
      'Check Set context is the canonical contract name.'
    );
    System.assertEquals(
      'Owner_Is_Active',
      evt.RuleDeveloperName__c,
      'Rule context is the canonical contract name.'
    );
    System.assertEquals(
      'UNHANDLED_EXCEPTION',
      evt.Code__c,
      'Code is the event.'
    );
    System.assert(
      evt.ExceptionType__c.contains('NullPointer'),
      'Exception type is captured for reproduction.'
    );
    System.assertNotEquals(null, evt.StackTrace__c, 'Stack trace is captured.');
    System.assertEquals('1.0', evt.ContractVersion__c, 'Versioned contract.');
    System.assertNotEquals(null, evt.EventId__c, 'Event has a dedupe id.');
    System.assertEquals(
      UserInfo.getUserId(),
      evt.UserId__c,
      'Running user is attributed authoritatively.'
    );

    Test.startTest();
    RecordHealthCheckLogger.flush();
    Test.stopTest();

    System.assertEquals(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'flush() clears the buffer.'
    );
  }

  @IsTest
  static void nonErrorLevelsDoNotBuffer() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-noise',
      'Account_Compliance_Audit',
      UserInfo.getUserId()
    );

    logger.debug('C', 'START', null);
    logger.info('C', 'RESULT', new Map<String, Object>{ 'status' => 'FAIL' });
    logger.warn('C', 'METADATA_INVALID', null);

    System.assertEquals(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'Only ERROR buffers a durable event; WARN/INFO/DEBUG do not.'
    );
  }

  @IsTest
  static void messageFallsBackToFieldsWhenNoException() {
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'run-nofields',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId(),
      'Owner_Is_Active',
      'RULE_ERROR',
      new Map<String, Object>{ 'reasonCode' => 'APEX_EVALUATOR_ERROR' },
      null
    );

    List<Record_Health_Check_Log__e> pending = RecordHealthCheckLogger.pendingEventsForTest();
    System.assertEquals(1, pending.size(), 'Static ERROR path buffers.');
    System.assertEquals(
      null,
      pending[0].ExceptionType__c,
      'No exception type when ex is null.'
    );
    System.assert(
      pending[0].Message__c.contains('reasonCode=APEX_EVALUATOR_ERROR'),
      'Message falls back to a compact field summary.'
    );
  }

  @IsTest
  static void checkSetOptOutSuppressesBuffering() {
    RecordHealthCheckLogger.publishErrorEventSettingOverride = false;
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-off',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    logger.error(
      'C',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );

    System.assertEquals(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'The Check Set opt-out suppresses the durable event (System.debug still fires).'
    );
  }

  @IsTest
  static void missingCheckSetDefaultsToPublishing() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-missing-config',
      'Check_Set_That_Does_Not_Exist',
      UserInfo.getUserId()
    );

    logger.error(
      null,
      'CONFIG_NOT_FOUND',
      null,
      new System.NullPointerException()
    );

    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'A missing Check Set must preserve default-on error publication.'
    );
  }

  @IsTest
  static void configuredCheckSetPublishesWhenDefaultOn() {
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-configured',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    logger.error(
      null,
      'CONFIGURED_SET_ERROR',
      null,
      new System.NullPointerException()
    );

    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'A configured Check Set with the default-on field must publish.'
    );
  }

  @IsTest
  static void subscriberContextPreventsFeedbackLoop() {
    RecordHealthCheckLogger.enterSubscriberContext();
    RecordHealthCheckLogger logger = new RecordHealthCheckLogger(
      'run-sub',
      'Example_Account_Relationship_Risk',
      UserInfo.getUserId()
    );

    logger.error(
      'C',
      'UNHANDLED_EXCEPTION',
      null,
      new System.NullPointerException()
    );

    System.assertEquals(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'A subscriber logging an error must not republish onto the same bus.'
    );
  }

  @IsTest
  static void flushIsSafeWhenBufferEmpty() {
    Test.startTest();
    RecordHealthCheckLogger.flush();
    Test.stopTest();

    System.assertEquals(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'flush() on an empty buffer is a no-op and does not throw.'
    );
  }

  @IsTest
  static void debugAndResetHooksRestoreLoggerState() {
    RecordHealthCheckLogger.debugEnabled = true;
    new RecordHealthCheckLogger('run-debug', 'Set', null)
      .debug('Rule', 'DEBUG_BRANCH', null);
    RecordHealthCheckLogger.publishErrorEventSettingOverride = false;
    RecordHealthCheckLogger.enterSubscriberContext();

    RecordHealthCheckLogger.resetLogSinkForTest();

    System.assertEquals(
      null,
      RecordHealthCheckLogger.publishErrorEventSettingOverride
    );
    System.assertEquals(false, RecordHealthCheckLogger.inSubscriberContext);
    System.assertEquals(0, RecordHealthCheckLogger.pendingEventCount());
    RecordHealthCheckLogger.debugEnabled = false;
  }
}
