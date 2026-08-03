# Record Health Check Observability

Optional extension package for durable operational capture. Framework remains read-only. This package
stores execution envelopes, actionable Rule outcomes, and enabled framework-error events.

Capture paths:

- `RecordHealthCheckCaptureService` for synchronous Apex;
- `RecordHealthCheckCaptureFlowAction` for Flow;
- `RecordHealthCheckCaptureQueueable` and `RecordHealthCheckCaptureBatch` for asynchronous work;
- platform-event subscribers for Framework lifecycle and error-log events.

Assign `Record Health Check Observability Admin` to operators who run captures and inspect restricted
payloads. Assign the Viewer permission set for read-only operational summaries without values,
messages, raw payloads, or stack traces.
