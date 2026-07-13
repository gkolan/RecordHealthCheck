/** Structured validation failure for an admin-authored token template. */
public class RecordHealthCheckTokenIssue {
  public String reasonCode;
  public String token;
  public String message;

  public RecordHealthCheckTokenIssue(
    String reasonCode,
    String token,
    String message
  ) {
    this.reasonCode = reasonCode;
    this.token = token;
    this.message = message;
  }
}
