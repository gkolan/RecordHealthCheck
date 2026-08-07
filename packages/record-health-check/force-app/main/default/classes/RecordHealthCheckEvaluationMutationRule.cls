/** Test-only hostile plugin that mutates data during evaluation. */
@IsTest
public class RecordHealthCheckEvaluationMutationRule implements RecordHealthCheckRule {
  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    RecordHealthCheckTestDataFactory.createAccount('Evaluation mutation');
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
