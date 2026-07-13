# V2 source-to-org readback

## Scope

Section 9 Gate D for `force-app`, retrieved from scratch alias `rhc-v2-section4` on 2026-07-13 after a successful full deployment.

## Method

An isolated project under `/tmp/rhc-v2-readback` received the org source with:

```text
sf project retrieve start --source-dir force-app --target-org rhc-v2-section4 --wait 30 --ignore-conflicts --json
python3 releases/v2/tools/compare_source_readback.py force-app /tmp/rhc-v2-readback/force-app
```

The committed comparison tool normalizes final newlines, XML formatting/order, Custom Metadata filenames, omitted field defaults materialized by retrieve, and standard Metadata API default elements.

## Findings

| Item                     | Status | Evidence                                                                                                                                     | Owner            |
| ------------------------ | ------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| Retrieve                 | Pass   | Metadata API retrieve completed successfully                                                                                                 | Core maintainers |
| Deployable file presence | Pass   | 415 source files compared; none missing                                                                                                      | Core maintainers |
| Apex/LWC content         | Pass   | Code matches after final deployment; local LWC tests are correctly not retrieved                                                             | Core maintainers |
| Custom Metadata          | Pass   | 147 source records map to 147 retrieved records; retrieve materializes omitted null/default values                                           | Core maintainers |
| XML normalization        | Pass   | Remaining representational differences are platform-normalized layout defaults/checkbox edit behavior and report-folder access serialization | Core maintainers |

## Outstanding work

Rerun this artifact against the exact release commit if source changes after this audit.

## Verdict

Pass. No unexpected source-to-org drift was found.
