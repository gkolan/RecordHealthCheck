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
List<Id> jobs = new List<Id>();
jobs.addAll(RecordHealthCheckExhaustiveSmoke.startSets(target.Id));
System.debug(LoggingLevel.INFO, 'RHC_EXHAUSTIVE_SET_JOBS=' + jobs.size());
