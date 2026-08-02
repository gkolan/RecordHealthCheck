/**
 * Immutable XOR selection of one qualified Check Set or one qualified Rule.
 */
global class RecordHealthCheckSelection {
  global String checkSetQualifiedApiName { get; private set; }
  global String ruleQualifiedApiName { get; private set; }

  private RecordHealthCheckSelection(
    String checkSetQualifiedApiName,
    String ruleQualifiedApiName
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.ruleQualifiedApiName = ruleQualifiedApiName;
  }

  /**
   * @param qualifiedApiName Custom Metadata QualifiedApiName for a Check Set.
   * @return A Check Set selection.
   */
  global static RecordHealthCheckSelection forCheckSet(
    String qualifiedApiName
  ) {
    requireIdentity(qualifiedApiName, 'Check Set');
    return new RecordHealthCheckSelection(qualifiedApiName.trim(), null);
  }

  /**
   * @param qualifiedApiName Custom Metadata QualifiedApiName for a Rule.
   * @return A Rule selection.
   */
  global static RecordHealthCheckSelection forRule(String qualifiedApiName) {
    requireIdentity(qualifiedApiName, 'Rule');
    return new RecordHealthCheckSelection(null, qualifiedApiName.trim());
  }

  private static void requireIdentity(String qualifiedApiName, String label) {
    if (String.isBlank(qualifiedApiName)) {
      throw new RecordHealthCheckSelectionException(
        label + ' QualifiedApiName is required.'
      );
    }
  }

  global class RecordHealthCheckSelectionException extends Exception {
  }
}
