/** Test-only hostile plugin whose constructor fails without mutating state. */
@IsTest
public class RecordHealthCheckConstructorFailureRule implements RecordHealthCheckRule {
  public RecordHealthCheckConstructorFailureRule() {
    throw new ConstructorFailureException('Expected constructor failure.');
  }

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    return new Map<Id, RecordHealthCheckOutcome>();
  }

  public class ConstructorFailureException extends Exception {
  }
}
