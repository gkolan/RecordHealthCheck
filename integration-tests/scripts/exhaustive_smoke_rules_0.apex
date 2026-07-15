List<Account> targets = [
  SELECT Id
  FROM Account
  WHERE Name = 'Acme Corporation'
  LIMIT 1
];
if (targets.isEmpty()) {
  targets.add(new Account(Name = 'Acme Corporation'));
  insert targets;
}
Account target = targets[0];
List<Id> jobs = RecordHealthCheckExhaustiveSmoke.startRules(target.Id, 0);
System.debug(LoggingLevel.INFO, 'RHC_EXHAUSTIVE_RULE_JOBS_0=' + jobs.size());
