/**
 * Immutable XOR selection of one qualified Check Set or one qualified Rule.
 */
global class RecordHealthCheckSelection {
  /** Selected qualified Check Set identity, or null for Rule selection. */
  global String checkSetQualifiedApiName { get; private set; }
  /** Selected qualified Rule identity, or null for Check Set selection. */
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
    return new RecordHealthCheckSelection(
      normalizedIdentity(qualifiedApiName, 'Check Set'),
      null
    );
  }

  /**
   * @param qualifiedApiName Custom Metadata QualifiedApiName for a Rule.
   * @return A Rule selection.
   */
  global static RecordHealthCheckSelection forRule(String qualifiedApiName) {
    return new RecordHealthCheckSelection(
      null,
      normalizedIdentity(qualifiedApiName, 'Rule')
    );
  }

  private static String normalizedIdentity(
    String qualifiedApiName,
    String label
  ) {
    try {
      return RecordHealthCheckQualifiedIdentity.normalize(
        qualifiedApiName,
        label
      );
    } catch (IllegalArgumentException error) {
      throw new RecordHealthCheckSelectionException(error.getMessage());
    }
  }

  /** Invalid immutable-selection construction. */
  global class RecordHealthCheckSelectionException extends Exception {
  }
}
