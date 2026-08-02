/** Test-only hostile plugin whose constructor attempts a database mutation. */
@IsTest
public class RecordHealthCheckConstructorMutationRule implements RecordHealthCheckRule {
  public RecordHealthCheckConstructorMutationRule() {
    RecordHealthCheckTestDataFactory.createAccount('Constructor mutation');
  }

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
