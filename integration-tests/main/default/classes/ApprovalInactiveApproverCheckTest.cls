/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for ApprovalInactiveApproverCheck.
 * The Advanced Approvals managed package is not assumed to be installed, so the
 * package-dependent dynamic query is exercised against a standard object
 * (Account configured as the "approval" object) and the inactive-user logic is
 * exercised directly with real inactive User records.
 */
@IsTest
private class ApprovalInactiveApproverCheckTest {
  @IsTest
  static void missingApprovalObjectReturnsUnableToEvaluate() {
    Id recordId = UserInfo.getUserId();
    RecordHealthCheckOutcome outcome = evaluateOne(
      recordId,
      'User',
      new Map<String, Object>{
        'approvalObject' => 'sbaa__Definitely_Not_Installed__c'
      }
    );

    System.assertEquals(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      outcome.status
    );
    System.assertEquals('OBJECT_NOT_FOUND', outcome.reasonCode);
  }

  @IsTest
  static void badFieldNameReturnsUnableToEvaluate() {
    Account account = new Account(Name = 'RHC Approval Bad Field');
    insert account;

    RecordHealthCheckOutcome outcome = evaluateOne(
      account.Id,
      'Account',
      new Map<String, Object>{
        'approvalObject' => 'Account',
        'targetField' => 'Id',
        'userField' => 'Not_A_Real_Field__c',
        'statusField' => 'Name',
        'pendingStatuses' => new List<Object>{ account.Name }
      }
    );

    System.assertEquals(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      outcome.status
    );
    System.assertEquals('INVALID_SOQL_TEMPLATE', outcome.reasonCode);
  }

  @IsTest
  static void dynamicQueryAgainstActiveOwnerPasses() {
    // Drive the dynamic query path without the managed package by treating
    // Account as the approval object: the owner (running, active user) stands in
    // for the assigned approver, so the check passes.
    Account account = new Account(Name = 'RHC Approval Active Owner');
    insert account;

    RecordHealthCheckOutcome outcome = evaluateOne(
      account.Id,
      'Account',
      new Map<String, Object>{
        'approvalObject' => 'Account',
        'targetField' => 'Id',
        'userField' => 'OwnerId',
        'statusField' => 'Name',
        'pendingStatuses' => new List<Object>{ account.Name }
      }
    );

    System.assertEquals(
      RecordHealthCheckStatus.PASS,
      outcome.status,
      'An active assigned user should pass.'
    );
    System.assertEquals(
      0,
      outcome.found.storedValues.size(),
      'No inactive approvers were found.'
    );
  }

  /** The check is bulk, so a single-record assertion is a scope of one. */
  private static RecordHealthCheckOutcome evaluateOne(
    Id recordId,
    String objectApiName,
    Map<String, Object> parameters
  ) {
    return new ApprovalInactiveApproverCheck()
      .evaluate(
        new RecordHealthCheckScope(
          objectApiName,
          new List<Id>{ recordId },
          parameters,
          'Approval_Has_No_Inactive_Approver',
          null,
          null
        )
      )
      .get(recordId);
  }

  @IsTest
  static void emptyAssignedUsersPasses() {
    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();
    ApprovalInactiveApproverCheck.Settings settings = check.resolveSettings(
      null
    );
    Map<Id, String> noneInactive = new Map<Id, String>();

    RecordHealthCheckOutcome passNull = check.buildOutcome(
      null,
      noneInactive,
      settings
    );
    System.assertEquals(RecordHealthCheckStatus.PASS, passNull.status);
    System.assertEquals(0, passNull.found.storedValues.size());

    RecordHealthCheckOutcome passEmpty = check.buildOutcome(
      new Set<Id>(),
      noneInactive,
      settings
    );
    System.assertEquals(RecordHealthCheckStatus.PASS, passEmpty.status);
    System.assertEquals(0, passEmpty.found.storedValues.size());
  }

  @IsTest
  static void allAssignedUsersActivePasses() {
    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();
    ApprovalInactiveApproverCheck.Settings settings = check.resolveSettings(
      null
    );

    // The running user is active, so they are absent from the inactive lookup.
    RecordHealthCheckOutcome outcome = check.buildOutcome(
      new Set<Id>{ UserInfo.getUserId() },
      new Map<Id, String>(),
      settings
    );

    System.assertEquals(
      RecordHealthCheckStatus.PASS,
      outcome.status,
      'The running user is active, so there are no inactive approvers.'
    );
    System.assertEquals(0, outcome.found.storedValues.size());
  }

  @IsTest
  static void inactiveAssignedUserFailsAndNamesTheUser() {
    User inactive = createInactiveUser();
    // Name is a derived field, set on the persisted record (FirstName +
    // LastName), so read it back to compare against the reported value.
    String inactiveName = [SELECT Name FROM User WHERE Id = :inactive.Id].Name;

    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();
    ApprovalInactiveApproverCheck.Settings settings = check.resolveSettings(
      null
    );

    RecordHealthCheckOutcome outcome = check.buildOutcome(
      new Set<Id>{ inactive.Id, UserInfo.getUserId() },
      new Map<Id, String>{ inactive.Id => inactiveName },
      settings
    );

    System.assertEquals(RecordHealthCheckStatus.FAIL, outcome.status);
    // The names are the finding, carried as typed data rather than a sentence
    // the check wrote. The engine turns them into prose.
    System.assertEquals(1, outcome.found.storedValues.size());
    System.assertEquals(inactiveName, outcome.found.storedValues[0]);
    System.assertEquals(0, outcome.expected.storedValues.size());
  }

  @IsTest
  static void resolveSettingsReadsAllOverrides() {
    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();

    ApprovalInactiveApproverCheck.Settings defaults = check.resolveSettings(
      new Map<String, Object>()
    );
    System.assertEquals(
      ApprovalInactiveApproverCheck.DEFAULT_APPROVAL_OBJECT,
      defaults.approvalObject
    );
    System.assertEquals(1, defaults.pendingStatuses.size());

    ApprovalInactiveApproverCheck.Settings custom = check.resolveSettings(
      new Map<String, Object>{
        'approvalObject' => 'My_Approval__c',
        'targetField' => 'My_Target__c',
        'userField' => 'My_User__c',
        'statusField' => 'My_Status__c',
        'pendingStatuses' => new List<Object>{ 'Requested', 'Pending', '  ' },
        'maxNames' => '3'
      }
    );
    System.assertEquals('My_Approval__c', custom.approvalObject);
    System.assertEquals('My_Target__c', custom.targetField);
    System.assertEquals('My_User__c', custom.userField);
    System.assertEquals('My_Status__c', custom.statusField);
    System.assertEquals(2, custom.pendingStatuses.size());
    System.assertEquals(3, custom.maxNames);

    // Blank strings and out-of-range / unparseable maxNames keep defaults.
    ApprovalInactiveApproverCheck.Settings fallback = check.resolveSettings(
      new Map<String, Object>{
        'approvalObject' => '   ',
        'maxNames' => 'not-a-number',
        'pendingStatuses' => new List<Object>{}
      }
    );
    System.assertEquals(
      ApprovalInactiveApproverCheck.DEFAULT_APPROVAL_OBJECT,
      fallback.approvalObject
    );
    System.assertEquals(5, fallback.maxNames);
    System.assertEquals(1, fallback.pendingStatuses.size());

    ApprovalInactiveApproverCheck.Settings outOfRange = check.resolveSettings(
      new Map<String, Object>{ 'maxNames' => '999' }
    );
    System.assertEquals(5, outOfRange.maxNames);
  }

  private static User createInactiveUser() {
    List<Profile> standardProfiles = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    Profile standard = standardProfiles.isEmpty()
      ? [SELECT Id FROM Profile LIMIT 1]
      : standardProfiles[0];
    String unique = 'rhc.inactive.' + DateTime.now().getTime();
    User inactive = new User(
      FirstName = 'Inactive',
      LastName = 'Approver',
      Alias = 'rhcinact',
      Email = 'rhc.inactive.approver@example.com',
      Username = unique + '@example.com.invalid',
      ProfileId = standard.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      IsActive = false
    );
    insert inactive;
    return inactive;
  }
}
