final String CHECK_SET = 'Example_Account_Relationship_Risk';
Account acme = [
  SELECT Id, Name, Owner.IsActive, ParentId, Parent.ParentId, Industry, Parent.Industry, AnnualRevenue
  FROM Account
  WHERE Name = 'Acme Corporation'
  LIMIT 1
];

System.assertEquals(false, acme.Owner.IsActive, 'Acme must have an inactive owner.');
System.assertNotEquals(null, acme.ParentId, 'Acme must have a parent account.');
System.assertNotEquals(null, acme.Parent.ParentId, 'Acme must have a corporate grandparent.');
System.assertEquals(acme.Parent.Industry, acme.Industry, 'Parent and child industries must align.');
System.assertEquals(500000, acme.AnnualRevenue, 'Acme annual revenue must drive the 75% threshold.');
System.assertEquals(38, [SELECT COUNT() FROM Contact WHERE AccountId = :acme.Id]);
System.assertEquals(6, [SELECT COUNT() FROM Contact WHERE AccountId = :acme.Id AND Email = null]);
System.assertEquals(3, [
  SELECT COUNT()
  FROM OpportunityContactRole
  WHERE Opportunity.AccountId = :acme.Id AND Role = 'Executive Sponsor'
]);
AggregateResult pipelineResult = [
  SELECT SUM(Amount) total
  FROM Opportunity
  WHERE AccountId = :acme.Id AND IsClosed = false
];
System.assertEquals(70000, (Decimal) pipelineResult.get('total'));
System.assertEquals(4, [
  SELECT COUNT()
  FROM Case
  WHERE AccountId = :acme.Id AND IsClosed = false AND Priority = 'High'
]);
System.assertEquals(2, [
  SELECT COUNT()
  FROM Task
  WHERE WhatId = :acme.Id AND IsClosed = true AND ActivityDate = LAST_N_DAYS:90
]);

Map<String, String> expectedStatuses = new Map<String, String>{
  'Example_Executive_Sponsorship' => 'PASS',
  'Example_Account_Owner_Active' => 'FAIL',
  'Example_Industry_Aligns_With_Parent' => 'PASS',
  'Example_Contacts_Have_Email' => 'FAIL',
  'Example_Customer_Engagement_Current' => 'PASS',
  'Example_Pipeline_Protects_Revenue' => 'FAIL',
  'Example_No_High_Priority_Issues' => 'FAIL',
  'Example_Channel_Partner_Governance' => 'SKIPPED'
};

RecordHealthCheckDefinitionResponse definitions = new RecordHealthCheckConfigService()
  .getDefinitionResponse(CHECK_SET, acme.Id);
System.assertEquals(8, definitions.checks.size(), 'The demo must contain exactly eight rules.');

RecordHealthCheckEngine engine = new RecordHealthCheckEngine();
Integer passed = 0;
Integer failed = 0;
Integer skipped = 0;
for (RecordHealthCheckDefinition definition : definitions.checks) {
  RecordHealthCheckResult result = engine.evaluate(
    CHECK_SET,
    definition.developerName,
    acme.Id,
    'verify-v2-demo'
  );
  System.assertEquals(
    expectedStatuses.get(definition.developerName),
    result.status,
    'Unexpected status for ' + definition.developerName + ': ' + result.message
  );
  if (result.status == 'PASS') passed++;
  if (result.status == 'FAIL') failed++;
  if (result.status == 'SKIPPED') skipped++;
}

System.assertEquals(3, passed, 'The demo must contain three passing checks.');
System.assertEquals(4, failed, 'The demo must contain four failing checks.');
System.assertEquals(1, skipped, 'The demo must contain one intentional skip.');
System.debug('RHC_DEMO_VERIFIED pass=3 fail=4 skip=1 accountId=' + acme.Id);
