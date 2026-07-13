/** Durable lifecycle context exposed through the rhcRun token namespace. */
public class RecordHealthCheckRunContext {
  public String runId;
  public String source;
  public Datetime startedAt;
  public Datetime completedAt;
  public Long durationMs;

  public RecordHealthCheckRunContext(String runId, String source) {
    this.runId = runId;
    this.source = source;
    this.startedAt = System.now();
  }

  public void complete() {
    if (completedAt == null) {
      completedAt = System.now();
      durationMs = completedAt.getTime() - startedAt.getTime();
    }
  }
}
