# Code coverage statistics

> [!NOTE]
> On this page, review separate product and integration-fixture source, test, and code coverage statistics used to assess release readiness.

The first section covers the installable source under `force-app`. The second measures the optional
fixtures under `integration-tests` without mixing them into product coverage. Deferred features,
generated coverage pages, build scripts, and other repository tooling remain outside both totals.

The Apex results come from package-only test runs in single-currency and multi-currency scratch
orgs on July 27, 2026. The table reports the multi-currency run; the floor section also records the
more conservative single-currency result. The JavaScript results come from the Jest coverage report
generated for the Lightning Web Component tests.

## `force-app` statistics

| Measure | Apex | JavaScript |
| --- | ---: | ---: |
| Production classes or modules | 42 | 4 |
| Test classes or files | 19 | 1 |
| Total classes or files | 61 | 5 |
| Production methods or functions | 382 | 137 |
| Test and helper methods | 283 | Not measured separately |
| Total declared methods | 665 | Not applicable |
| Test methods run | 230 | 129 |
| Test methods passed | 230 | 129 |
| Physical production lines | 12,207 | 1,920 |
| Physical test lines | 10,994 | 2,983 |
| Total physical lines | 23,201 | 4,903 |
| Executable lines | 6,142 | 754 |
| Covered executable lines | 5,960 | 722 |
| Uncovered executable lines | 182 | 32 |
| Line coverage | 97.04% | 95.75% |

The Apex method count includes declarations in production and test classes. Salesforce enqueued
and completed 230 test methods in each package run. Its JSON result also contains six test-setup
executions, producing 236 result rows. The JavaScript function count is the total reported by Jest.

## JavaScript coverage measures

| Measure | Covered | Total | Coverage |
| --- | ---: | ---: | ---: |
| Lines | 722 | 754 | 95.75% |
| Statements | 759 | 796 | 95.35% |
| Functions | 132 | 137 | 96.35% |
| Branches | 464 | 528 | 87.87% |

## Apex coverage floor

In the multi-currency package-only run, `RecordHealthCheckValueSource` has the lowest production
class coverage: 28 of 30 executable lines, or 93.33%.

The conservative floor across the latest verified single-currency and multi-currency runs is
89.98% for `RecordHealthCheckDisplayFormat` in the single-currency configuration (431 of 479
executable lines). Integration-only
classes do not affect this package floor.

The complete package has 96.71% line coverage in the single-currency org (5,940 of 6,142 executable
lines) and 97.04% in the multi-currency org (5,960 of 6,142). Both runs passed all 230 package test
methods.

## `integration-tests` statistics

The integration directory is deployed only after `force-app` in release scratch orgs. Its five
production-style fixtures are three Apex Rule plugins and two platform-event subscriber triggers.
The exhaustive Queueable runner is classified as a test helper because it exists only to launch
manual scratch-org smoke checks.

| Measure | Apex |
| --- | ---: |
| Production-style classes and triggers | 5 |
| Test and helper classes | 4 |
| Total classes and triggers | 9 |
| Production methods | 17 |
| Test and helper methods | 27 |
| Total declared methods | 44 |
| Test methods run | 18 |
| Test methods passed | 18 |
| Physical production lines | 547 |
| Physical test and helper lines | 721 |
| Total physical lines | 1,268 |
| Executable production lines | 290 |
| Covered executable production lines | 290 |
| Uncovered executable production lines | 0 |
| Production-style line coverage | 100.00% |

Both the single-currency and multi-currency integration-only runs passed 18 of 18 test methods. The
full local suites produced 253 result rows in each org and covered all 290 executable lines in the
three plugins and two subscriber triggers. Every measured production-style integration component
therefore has a 100% coverage floor.

`RecordHealthCheckExhaustiveSmoke` has 79 executable lines and no Apex-test coverage. It is an
operational test helper, not a production fixture: the maintained anonymous Apex scripts invoke it
in a scratch org so its queued work can run across transactions. Including it as product code would
produce 290 covered of 369 executable lines, or 78.59%, which is why this page states both the
classification and the unadjusted number explicitly.

The directory also contains 153 Custom Metadata fixture records, one helper object, ten runnable
anonymous Apex scripts, and related metadata. These are deployment and behavior fixtures rather
than executable classes, so Salesforce line coverage does not assign them a percentage.

## How to interpret line totals

Physical lines count every line stored in the source files, including comments, blank lines,
declarations, and test code. Executable lines are the statements that the Apex and Jest coverage
tools can mark as covered or uncovered. Coverage percentages therefore use executable lines rather
than physical lines.

Salesforce org-wide coverage can include unrelated classes and coverage left by earlier test runs.
For package reporting, use a run limited to the test classes in `force-app` and calculate the result
from the production classes in `force-app`. For integration reporting, deploy Core first, run the
three integration test classes separately, then confirm the subscribers again in the full local
suite.

## Related

- [CLI commands](cli-commands.md)
- [Documentation standard](documentation-standard.md)
- [Deployment readiness standard](deployment-readiness-standard.md)
- [Apex classes reference](../reference/reference-apex-classes.md)
- [Architecture reference](../reference/reference-architecture.md)
