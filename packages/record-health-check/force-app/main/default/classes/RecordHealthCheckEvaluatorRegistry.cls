/** Dispatches framework evaluation types through one scope-level contract. */
public with sharing class RecordHealthCheckEvaluatorRegistry {
  private interface ScopeEvaluator {
    Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check_Rule__mdt rule,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    );
  }

  private Map<String, ScopeEvaluator> evaluatorsByType;

  /** Builds the default framework evaluator registry. */
  public RecordHealthCheckEvaluatorRegistry() {
    evaluatorsByType = new Map<String, ScopeEvaluator>{
      'QUERY' => new QueryAdapter(),
      'COMPARE_TWO_QUERIES' => new CompareQueriesAdapter(),
      'FORMULA' => new FormulaAdapter(),
      'APEX' => new ApexAdapter()
    };
  }

  /** Evaluates one Rule against its applicable scope. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check_Rule__mdt rule,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    RecordHealthCheckScopePipeline.SelectionContext context,
    String runId
  ) {
    ScopeEvaluator evaluator = evaluatorsByType.get(rule.EvaluationType__c);
    if (evaluator == null) {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_CHECK_TYPE',
        'No framework evaluator is registered for ' +
          rule.EvaluationType__c +
          '.'
      );
    }
    return evaluator.evaluate(rule, recordIds, recordsById, context, runId);
  }

  private class QueryAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check_Rule__mdt rule,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      return new RecordHealthCheckSoqlEvaluator()
        .evaluateScope(rule, recordIds, recordsById);
    }
  }

  private class CompareQueriesAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check_Rule__mdt rule,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      return new RecordHealthCheckCompareQueriesEvaluator()
        .evaluateScope(rule, recordIds, recordsById);
    }
  }

  private class FormulaAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check_Rule__mdt rule,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
      RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          evaluator.evaluate(rule, recordId, recordsById.get(recordId))
        );
      }
      return results;
    }
  }

  private class ApexAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check_Rule__mdt rule,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      return new RecordHealthCheckApexEvaluator()
        .evaluateScope(
          rule,
          recordIds,
          recordsById,
          context.objectApiName,
          context.checkSetDeveloperName,
          runId
        );
    }
  }
}
