/** Test-only scratch-org harness that runs each Check Set or Rule separately. */
public class RecordHealthCheckExhaustiveSmoke implements Queueable {
  private Id recordId;
  private String itemName;
  private String mode;

  public static List<Id> startSets(Id recordId) {
    List<Id> jobs = new List<Id>();
    for (Record_Health_Check_Set__mdt item : [
      SELECT DeveloperName
      FROM Record_Health_Check_Set__mdt
      ORDER BY DeveloperName
    ]) {
      jobs.add(
        System.enqueueJob(
          new RecordHealthCheckExhaustiveSmoke(
            recordId,
            item.DeveloperName,
            'SET'
          )
        )
      );
    }
    return jobs;
  }

  public static List<Id> startRules(Id recordId, Integer batchOffset) {
    List<Id> jobs = new List<Id>();
    for (Record_Health_Check_Rule__mdt item : [
      SELECT DeveloperName
      FROM Record_Health_Check_Rule__mdt
      ORDER BY DeveloperName
      LIMIT 50
      OFFSET :batchOffset
    ]) {
      jobs.add(
        System.enqueueJob(
          new RecordHealthCheckExhaustiveSmoke(
            recordId,
            item.DeveloperName,
            'RULE'
          )
        )
      );
    }
    return jobs;
  }

  private RecordHealthCheckExhaustiveSmoke(
    Id recordId,
    String itemName,
    String mode
  ) {
    this.recordId = recordId;
    this.itemName = itemName;
    this.mode = mode;
  }

  public void execute(QueueableContext context) {
    Map<String, Object> outcome = new Map<String, Object>{
      'mode' => mode,
      'name' => itemName
    };
    try {
      if (mode == 'SET') {
        RecordHealthCheckSetResult result = RecordHealthCheck.runSet(
          itemName,
          recordId
        );
        outcome.put('status', result.status);
        outcome.put('passed', result.passedCount);
        outcome.put('failed', result.failedCount);
        outcome.put('skipped', result.skippedCount);
        outcome.put('unable', result.unableCount);
        outcome.put('systemErrors', result.systemErrorCount);
        outcome.put('results', summarize(result.results));
      } else {
        RecordHealthCheckResult result = RecordHealthCheck.runRule(
          itemName,
          recordId
        );
        outcome.put('status', result.status);
        outcome.put('reasonCode', result.reasonCode);
        outcome.put('message', result.message);
      }
    } catch (Exception ex) {
      outcome.put('threw', true);
      outcome.put('exceptionType', ex.getTypeName());
      outcome.put('exceptionMessage', ex.getMessage());
      outcome.put('stackTrace', ex.getStackTraceString());
    }
    upsert new RHC_Event_Export__c(
      EventId__c = mode + ':' + itemName,
      Payload__c = JSON.serialize(outcome)
    )
      RHC_Event_Export__c.EventId__c;
  }

  private static List<Object> summarize(List<RecordHealthCheckResult> results) {
    List<Object> summary = new List<Object>();
    for (RecordHealthCheckResult result : results) {
      summary.add(
        new Map<String, Object>{
          'name' => result.ruleDeveloperName,
          'status' => result.status,
          'reasonCode' => result.reasonCode,
          'message' => result.message
        }
      );
    }
    return summary;
  }

  public static void report() {
    List<RHC_Event_Export__c> rows = [
      SELECT EventId__c, Payload__c
      FROM RHC_Event_Export__c
      WHERE EventId__c LIKE 'SET:%' OR EventId__c LIKE 'RULE:%'
      ORDER BY EventId__c
    ];
    Integer concerningRows = 0;
    for (RHC_Event_Export__c row : rows) {
      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        row.Payload__c
      );
      Boolean concerning =
        payload.get('threw') == true ||
        payload.get('status') == 'ERROR' ||
        payload.get('status') == 'UNABLE_TO_EVALUATE';
      if (concerning) {
        concerningRows++;
        System.debug(
          LoggingLevel.ERROR,
          'RHC_EXHAUSTIVE_RESULT=' + row.EventId__c + '|' + row.Payload__c
        );
      }
    }
    System.debug(LoggingLevel.ERROR, 'RHC_EXHAUSTIVE_ROWS=' + rows.size());
    System.debug(
      LoggingLevel.ERROR,
      'RHC_EXHAUSTIVE_CONCERNING_ROWS=' + concerningRows
    );
  }
}
