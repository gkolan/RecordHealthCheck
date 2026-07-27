// Runnable Apex API demonstration for a scratch org containing force-app and
// integration-tests. The record is intentionally reusable between demo runs.
List<Account> demoAccounts = [
  SELECT Id, Name, BillingCity
  FROM Account
  WHERE Name = 'Record Health Check API Demo'
  ORDER BY CreatedDate DESC
  LIMIT 1
];
Account demoAccount;
if (demoAccounts.isEmpty()) {
  demoAccount = new Account(
    Name = 'Record Health Check API Demo',
    BillingCity = 'Chicago',
    Phone = '312-555-0142',
    Website = 'https://example.com'
  );
  insert demoAccount;
} else {
  demoAccount = demoAccounts[0];
}

RecordHealthCheckSetResult setResult = RecordHealthCheck.runSet(
  'Account_Data_Quality',
  demoAccount.Id,
  'demo-apex-set-' + String.valueOf(Datetime.now().getTime())
);
System.assertNotEquals(null, setResult, 'The Check Set API must return a result.');
System.assertNotEquals(null, setResult.status, 'The Check Set result must have a status.');
System.assert(!setResult.results.isEmpty(), 'The demo Check Set must run at least one Rule.');

RecordHealthCheckResult ruleResult = RecordHealthCheck.runRule(
  'Account_DQ_BillingCity',
  demoAccount.Id,
  'demo-apex-rule-' + String.valueOf(Datetime.now().getTime())
);
System.assertEquals('PASS', ruleResult.status, 'The seeded Billing City Rule should pass.');

System.debug(
  'RHC_APEX_API_DEMO=' +
    JSON.serialize(
      new Map<String, Object>{
        'accountId' => demoAccount.Id,
        'setStatus' => setResult.status,
        'passedCount' => setResult.passedCount,
        'failedCount' => setResult.failedCount,
        'unableCount' => setResult.unableCount,
        'ruleStatus' => ruleResult.status,
        'ruleReasonCode' => ruleResult.reasonCode
      }
    )
);
