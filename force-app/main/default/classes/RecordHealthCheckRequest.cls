/**
 * Immutable selection and record scope for one Record Health Check evaluation.
 */
global class RecordHealthCheckRequest {
  global RecordHealthCheckSelection selection { get; private set; }
  global RecordHealthCheckOptions options { get; private set; }

  private List<Id> recordIdsInternal;

  global List<Id> recordIds {
    get {
      return new List<Id>(recordIdsInternal);
    }
  }

  private RecordHealthCheckRequest(
    RecordHealthCheckSelection selection,
    List<Id> recordIds,
    RecordHealthCheckOptions options
  ) {
    if (recordIds == null) {
      throw new RecordHealthCheckRequestException('Record IDs are required.');
    }
    this.selection = selection;
    this.recordIdsInternal = new List<Id>(recordIds);
    this.options = options;
  }

  global static RecordHealthCheckRequest forCheckSet(
    String qualifiedApiName,
    Id recordId
  ) {
    return forCheckSet(qualifiedApiName, new List<Id>{ recordId });
  }

  global static RecordHealthCheckRequest forCheckSet(
    String qualifiedApiName,
    List<Id> recordIds
  ) {
    return new RecordHealthCheckRequest(
      RecordHealthCheckSelection.forCheckSet(qualifiedApiName),
      recordIds,
      RecordHealthCheckOptions.defaults()
    );
  }

  global static RecordHealthCheckRequest forRule(
    String qualifiedApiName,
    Id recordId
  ) {
    return forRule(qualifiedApiName, new List<Id>{ recordId });
  }

  global static RecordHealthCheckRequest forRule(
    String qualifiedApiName,
    List<Id> recordIds
  ) {
    return new RecordHealthCheckRequest(
      RecordHealthCheckSelection.forRule(qualifiedApiName),
      recordIds,
      RecordHealthCheckOptions.defaults()
    );
  }

  global RecordHealthCheckRequest withResultMode(
    RecordHealthCheckResultMode value
  ) {
    return copyWith(options.withResultMode(value));
  }

  global RecordHealthCheckRequest withEventPublication(
    RecordHealthCheckEventPublication value
  ) {
    return copyWith(options.withEventPublication(value));
  }

  global RecordHealthCheckRequest withRunId(String value) {
    return copyWith(options.withRunId(value));
  }

  /**
   * @param value Caller context attributed to lifecycle events.
   * @return A copied request carrying the execution origin.
   */
  global RecordHealthCheckRequest withExecutionOrigin(
    RecordHealthCheckExecutionOrigin value
  ) {
    return copyWith(options.withExecutionOrigin(value));
  }

  private RecordHealthCheckRequest copyWith(RecordHealthCheckOptions value) {
    return new RecordHealthCheckRequest(selection, recordIdsInternal, value);
  }

  global class RecordHealthCheckRequestException extends Exception {
  }
}
