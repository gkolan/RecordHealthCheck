/** Durable run context carried on lifecycle events. (The `rhcRun` merge-token
 *  namespace that would expose this is deferred until it is wired — see
 *  RecordHealthCheckTokenRegistry, BLK-7.) */
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
