# V2 capacity and event-volume audit

## Scope

Section 9 Gate H, covering Section 4.18 synchronous capacity and Sections 4.2/4.19 event publication.

## Method

```text
sf apex run --file integration-tests/scripts/facade_capacity.apex --target-org rhc-v2-section4
sf project deploy start --source-dir force-app/main/default/classes/RecordHealthCheckLifecyclePublisher.cls --source-dir force-app/main/default/classes/RecordHealthCheckLifecyclePublisherTest.cls --target-org rhc-v2-section4 --test-level RunSpecifiedTests --tests RecordHealthCheckLifecyclePublisherTest --wait 20 --json
```

## Findings

| Item                 | Status | Evidence                                                                                                 | Owner            |
| -------------------- | ------ | -------------------------------------------------------------------------------------------------------- | ---------------- |
| Façade measured load | Pass   | 10 records/evaluations: 20 queries, 20 rows, 299 ms CPU, 7,802 heap bytes, 6,560 response bytes          | Core maintainers |
| Synchronous cap      | Pass   | Hard 200-record input limit plus 15 total evaluations; Flow aggregate preflight rejects over-budget work | Core maintainers |
| Event chunks         | Pass   | Chunk size 100; 101-event test consumes exactly two DML statements                                       | Core maintainers |
| Publish failure      | Pass   | Mixed valid/invalid batch inspects one failure without throwing or mutating results                      | Core maintainers |
| Transaction rollback | Pass   | Publish After Commit subscriber receives committed marker only                                           | Core maintainers |
| Consumer proof       | Pass   | Task work-item and custom export-record consumers both receive the same Rule Result contract             | Core maintainers |

## Outstanding work

Monitor org-wide daily event allocation after administrators opt in; default-off switches prevent install-time consumption.

## Verdict

Pass within the documented synchronous and per-transaction limits.
