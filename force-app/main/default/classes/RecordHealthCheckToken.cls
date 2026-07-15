/** A parsed V2 merge token and its source span. */
public class RecordHealthCheckToken {
  public String expression;
  public String namespaceName;
  public String propertyPath;
  public Integer startIndex;
  public Integer endIndex;

  public RecordHealthCheckToken(
    String expression,
    String namespaceName,
    String propertyPath,
    Integer startIndex,
    Integer endIndex
  ) {
    this.expression = expression;
    this.namespaceName = namespaceName;
    this.propertyPath = propertyPath;
    this.startIndex = startIndex;
    this.endIndex = endIndex;
  }
}
