/** Resolves scope selections and enforces request budgets. */
public with sharing class RecordHealthCheckScopePlanner {
  private static final Integer FORMULA_CALL_BUDGET = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;

  public RecordHealthCheckScopePipeline.SelectionContext resolveSelection(
    RecordHealthCheckSelection selection
  ) {
    if (selection == null) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'A qualified selection is required.'
      );
    }
    if (String.isNotBlank(selection.ruleQualifiedApiName)) {
      return resolveRule(selection.ruleQualifiedApiName);
    }
    return resolveCheckSet(selection.checkSetQualifiedApiName);
  }

  public RecordHealthCheckScopePipeline.SelectionContext resolveRule(
    String qualifiedApiName
  ) {
    List<Record_Health_Check_Rule__mdt> rules = queryRules(
      'QualifiedApiName = :qualifiedApiName',
      qualifiedApiName
    );
    if (rules.isEmpty()) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'Rule "' + qualifiedApiName + '" was not found.'
      );
    }
    RecordHealthCheckScopePipeline.SelectionContext context = contextFromRule(
      rules[0]
    );
    context.rules.add(rules[0]);
    return context;
  }

  public RecordHealthCheckScopePipeline.SelectionContext resolveCheckSet(
    String qualifiedApiName
  ) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata is framework configuration; the selected business records are loaded separately WITH USER_MODE.
    List<Record_Health_Check_Set__mdt> sets = [
      SELECT
        QualifiedApiName,
        DeveloperName,
        IsActive__c,
        ObjectApiName__c,
        ShowDiagnostics__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :qualifiedApiName
      LIMIT 2
    ];
    Record_Health_Check_Set__mdt checkSet = requireSingleCheckSet(
      sets,
      qualifiedApiName
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.checkSetQualifiedApiName = checkSet.QualifiedApiName;
    context.checkSetDeveloperName = checkSet.DeveloperName;
    context.checkSetActive = checkSet.IsActive__c;
    context.objectApiName = checkSet.ObjectApiName__c;
    context.showDiagnostics = checkSet.ShowDiagnostics__c == true;
    context.rules = queryRules(
      'Record_Health_Check_Set__r.QualifiedApiName = :qualifiedApiName AND IsActive__c = TRUE',
      qualifiedApiName
    );
    return context;
  }

  public Record_Health_Check_Set__mdt requireSingleCheckSet(
    List<Record_Health_Check_Set__mdt> checkSets,
    String qualifiedApiName
  ) {
    if (checkSets.isEmpty()) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'Check Set "' + qualifiedApiName + '" was not found.'
      );
    }
    if (checkSets.size() > 1) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'Check Set "' + qualifiedApiName + '" is ambiguous.'
      );
    }
    return checkSets[0];
  }

  public List<Record_Health_Check_Rule__mdt> queryRules(
    String predicate,
    String qualifiedApiName
  ) {
    List<String> ruleFields = new List<String>();
    for (
      Schema.SObjectField field : Schema.SObjectType.Record_Health_Check_Rule__mdt.fields
        .getMap()
        .values()
    ) {
      ruleFields.add(
        RecordHealthCheckDescribeCache.describeField(field).getName()
      );
    }
    ruleFields.sort();
    String query =
      'SELECT ' +
      String.join(ruleFields, ', ') +
      ', Record_Health_Check_Set__r.QualifiedApiName, ' +
      'Record_Health_Check_Set__r.DeveloperName, Record_Health_Check_Set__r.IsActive__c, ' +
      'Record_Health_Check_Set__r.ObjectApiName__c, Record_Health_Check_Set__r.ShowDiagnostics__c ' +
      'FROM Record_Health_Check_Rule__mdt WHERE ' +
      predicate +
      ' ORDER BY EvaluationOrder__c ASC NULLS LAST, DeveloperName ASC LIMIT ' +
      String.valueOf(RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS + 1);
    List<Record_Health_Check_Rule__mdt> rules = Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'qualifiedApiName' => qualifiedApiName },
      AccessLevel.USER_MODE
    );
    enforceRuleLimit(rules);
    return rules;
  }

  public void enforceRuleLimit(List<Record_Health_Check_Rule__mdt> rules) {
    if (rules.size() > RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'FRAMEWORK_MAX_CHECKS_EXCEEDED: suppliedCount=' +
          rules.size() +
          ', ceiling=' +
          RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS
      );
    }
  }

  public RecordHealthCheckScopePipeline.SelectionContext contextFromRule(
    Record_Health_Check_Rule__mdt rule
  ) {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    SObject parent = rule.getSObject('Record_Health_Check_Set__r');
    if (parent == null) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'The selected Rule has no owning Check Set.'
      );
    }
    context.checkSetQualifiedApiName = (String) parent.get('QualifiedApiName');
    context.checkSetDeveloperName = (String) parent.get('DeveloperName');
    context.checkSetActive = parent.get('IsActive__c') == true;
    context.objectApiName = (String) parent.get('ObjectApiName__c');
    context.showDiagnostics = parent.get('ShowDiagnostics__c') == true;
    return context;
  }

  public void validateScope(
    RecordHealthCheckScopePipeline.SelectionContext context,
    List<Id> recordIds
  ) {
    if (context == null || String.isBlank(context.objectApiName)) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'INVALID_OBJECT_API_NAME: the selected Check Set must name a valid object.'
      );
    }
    if (!RecordHealthCheckDescribeCache.containsObject(context.objectApiName)) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'INVALID_OBJECT_API_NAME: object "' +
          context.objectApiName +
          '" does not exist.'
      );
    }
    if (!context.checkSetActive) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'The selected Check Set is inactive.'
      );
    }
    for (Id recordId : recordIds) {
      if (recordId == null) {
        continue;
      }
      String actualObject = RecordHealthCheckDescribeCache.objectApiName(
        recordId
      );
      if (
        String.isBlank(actualObject) ||
        !context.objectApiName.equalsIgnoreCase(actualObject)
      ) {
        throw new RecordHealthCheckScopePipeline.ScopePipelineException(
          'The selected Check Set is for ' +
            context.objectApiName +
            ', not ' +
            actualObject +
            '.'
        );
      }
    }
  }

  public void enforceFormulaBudget(
    List<Record_Health_Check_Rule__mdt> rules,
    Integer recordCount
  ) {
    Integer plannedCalls = 0;
    for (Record_Health_Check_Rule__mdt rule : rules) {
      if (rule.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
        plannedCalls += recordCount;
      }
      if (rule.EvaluationType__c == 'FORMULA') {
        plannedCalls += recordCount;
        plannedCalls += plannedDisplayFormulaCalls(
          rule.DisplayFoundFormula__c,
          rule.FormulaResultType__c,
          recordCount
        );
        plannedCalls += plannedDisplayFormulaCalls(
          rule.DisplayExpectedFormula__c,
          rule.FormulaResultType__c,
          recordCount
        );
      } else if (rule.EvaluationType__c == 'QUERY') {
        plannedCalls += plannedDisplayFormulaCalls(
          rule.FindInListFormula__c,
          rule.FormulaResultType__c,
          recordCount
        );
        plannedCalls += plannedDisplayFormulaCalls(
          rule.ExpectedRecordFormula__c,
          rule.FormulaResultType__c,
          recordCount
        );
      }
    }
    Integer callsUsed = RecordHealthCheckFormulaEvaluator.callsUsed();
    Integer remainingCalls = Math.max(0, FORMULA_CALL_BUDGET - callsUsed);
    if (plannedCalls > remainingCalls) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'This request plans ' +
          plannedCalls +
          ' FormulaEval calls, but only ' +
          remainingCalls +
          ' remain in the safe transaction budget (' +
          callsUsed +
          ' already used). ' +
          'Reduce the record scope or selected Formula Rules.'
      );
    }
  }

  public void enforcePluginSavepointBudget(
    List<Record_Health_Check_Rule__mdt> rules
  ) {
    Integer requiredDmlStatements = 0;
    for (Record_Health_Check_Rule__mdt rule : rules) {
      if (rule.EvaluationType__c == 'APEX') {
        // Validation constructs the plugin under one savepoint; dispatch runs
        // it under a second. Both count against the DML statement limit.
        requiredDmlStatements += 2;
      }
    }
    Integer remainingDmlStatements =
      Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    if (requiredDmlStatements > remainingDmlStatements) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'PLUGIN_SAVEPOINT_BUDGET_EXCEEDED: required=' +
          requiredDmlStatements +
          ', remaining=' +
          remainingDmlStatements
      );
    }
  }

  /** Reserves transaction-wide query, DML/publication, and heap capacity. */
  public void enforceTransactionBudget(
    List<Record_Health_Check_Rule__mdt> rules,
    Integer recordCount,
    RecordHealthCheckEventPublication publication
  ) {
    Integer requiredQueries = recordCount > 0 ? 1 : 0;
    Integer requiredDml = 0;
    for (Record_Health_Check_Rule__mdt rule : rules) {
      if (rule.ApplicabilityMode__c == 'WHEN_COUNT_QUERY_MATCHES') {
        requiredQueries++;
      }
      if (rule.EvaluationType__c == 'QUERY') {
        requiredQueries++;
      } else if (rule.EvaluationType__c == 'COMPARE_TWO_QUERIES') {
        requiredQueries += 2;
      } else if (rule.EvaluationType__c == 'APEX') {
        requiredDml += 2;
      }
    }
    if (
      publication != null &&
      publication != RecordHealthCheckEventPublication.NONE
    ) {
      requiredDml += ceilingDivide(recordCount * rules.size(), 100);
      requiredDml += ceilingDivide(recordCount, 100);
    }
    Integer remainingQueries = Limits.getLimitQueries() - Limits.getQueries();
    Integer remainingDml =
      Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    if (requiredQueries > remainingQueries || requiredDml > remainingDml) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'TRANSACTION_BUDGET_EXCEEDED: queriesRequired=' +
          requiredQueries +
          ', queriesRemaining=' +
          remainingQueries +
          ', dmlRequired=' +
          requiredDml +
          ', dmlRemaining=' +
          remainingDml
      );
    }
    Integer projectedHeap = recordCount * rules.size() * 768;
    Integer remainingHeap = Limits.getLimitHeapSize() - Limits.getHeapSize();
    if (projectedHeap > remainingHeap) {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'HEAP_BUDGET_EXCEEDED: projected=' +
          projectedHeap +
          ', remaining=' +
          remainingHeap
      );
    }
  }

  private Integer ceilingDivide(Integer value, Integer divisor) {
    return value == 0 ? 0 : ((value - 1) / divisor) + 1;
  }

  public Integer plannedDisplayFormulaCalls(
    String expression,
    String declaredType,
    Integer recordCount
  ) {
    if (String.isBlank(expression) || recordCount == 0) {
      return 0;
    }
    return String.isBlank(declaredType) || declaredType == 'AUTO'
      ? recordCount + 7
      : recordCount;
  }
}
