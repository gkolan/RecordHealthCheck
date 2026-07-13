/** Stable, additive reason-code contract for non-pass/fail outcomes. */
public class RecordHealthCheckReasonCodes {
  public static final String CANNOT_EVALUATE = 'CANNOT_EVALUATE';
  public static final String FIELD_NOT_ACCESSIBLE = 'FIELD_NOT_ACCESSIBLE';
  public static final String RECORD_NOT_ACCESSIBLE = 'RECORD_NOT_ACCESSIBLE';
  public static final String NOT_APPLICABLE_BY_FORMULA = 'NOT_APPLICABLE_BY_FORMULA';
  public static final String NOT_APPLICABLE_BY_COUNT = 'NOT_APPLICABLE_BY_COUNT';
  public static final String PREREQUISITE_NOT_MET = 'PREREQUISITE_NOT_MET';

  public static final Set<String> DIAGNOSTICS_ONLY = new Set<String>{
    FIELD_NOT_ACCESSIBLE,
    RECORD_NOT_ACCESSIBLE
  };

  public static Boolean isDiagnosticsOnly(String reasonCode) {
    return DIAGNOSTICS_ONLY.contains(reasonCode);
  }
}
