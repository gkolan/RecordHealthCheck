# Reference: Display value format

> [!NOTE]
> On this page, learn how Record Health Check formats Found and Expected values for display: the
> **Display: Value Format** choices on a Rule, and the automatic handling of blanks, numbers,
> currency, Booleans, dates, multi-select picklists, and list previews.
>
> **Reference**
>
> - This page is the source of truth for readable Found and Expected formatting on the card and in
>   evaluator results.
> - Formatting is implemented by
>   [`RecordHealthCheckDisplayFormat`](reference-apex-classes.md#recordhealthcheckdisplayformat),
>   reached through
>   [`RecordHealthCheckComparisonEngine.formatValue`](reference-apex-classes.md#recordhealthcheckcomparisonengine).
>   Merge-token substitution uses a different path; see
>   [Reference: Merge tokens](reference-merge-tokens.md).

When a Formula, Query, or Compare two queries Rule finishes, the Framework turns the raw Found and
Expected values into short display text for the card chips. The goal is readable comparison values
without changing how the Rule decides pass or fail.

Apex Rules set their own Found and Expected strings. Those plugin strings are shown as written and
are not passed through this formatter.

## Choosing a format

**Display: Value Format** (`DisplayValueFormat__c`) on the Rule sets how both Found and Expected are
written. Leave it on **Auto** and the Framework works the format out from the value's type, which is
what every Rule did before this field existed. Name a format and that choice is used instead.

| Format | What it does | Example |
| --- | --- | --- |
| Auto | Works the format out from the field's definition in Setup, then the value's type | a Currency field reads as money; see [Auto: Typed values](#auto-typed-values) |
| Number | Groups digits for the running user's locale | `2500` → `2,500` |
| Currency | Money with the currency symbol and its minor units | `70000` → `$70,000.00` |
| Percent | The number followed by a percent sign | `12.5` → `12.5%` |
| Checkbox | Yes or No | `true` → `Yes` |
| Date | Locale date | `2026-07-04` → `7/4/2026` |
| Date/Time | Locale date and time | → `7/4/2026, 5:30 PM` |
| Text | The value exactly as written | `true` → `true` |
| Raw | The value exactly as written | `0012345` → `0012345` |

One format covers both sides of the comparison, so Found and Expected always read in the same units.
A Rule that names Currency shows `$70,000.00` against `at least $50,000.00`, never one of each.

Text and Raw behave the same way today: both return the value as written and neither humanizes
anything. They are kept apart so a Rule records why the author chose it - Text for names and free
text, Raw for identifiers, external keys, and codes.

The format applies to list entries and to the operator phrase as well, and it never affects whether
a Rule passes or fails. Pass and fail are decided from the raw typed values before any of this runs.

### When a format does not fit the value

Naming a format that cannot apply is not an error. The value is shown with its original spelling
instead, so a display choice can never break a card:

| Rule sets | Value | Display text |
| --- | --- | --- |
| Currency | `001A2B3C4D5E6F7G` | `001A2B3C4D5E6F7G` |
| Number | `Technology` | `Technology` |
| Number | `0012345` | `0012345` - grouping would drop the leading zeros |
| Percent | `12.5%` | `12.5%` - no second percent sign is added |
| Currency | `$70,000` | `$70,000` - not formatted a second time |
| Checkbox | `Technology` | `Technology` |

Naming Number on a digit string is a deliberate choice, so `90210` becomes `90,210`. Use Raw for postal codes
and other codes that must keep their exact spelling.

## Blank and empty values

| Input | Display text |
| --- | --- |
| `null` | `(blank)` |
| Empty or whitespace-only text | `(blank)` |

Values are not wrapped in quotes. The card chip already separates them from surrounding prose.

## Auto: The field's own definition

On **Auto**, a queried field that has a display shape of its own decides the format:

| Field type in Setup | Renders as | Example |
| --- | --- | --- |
| Currency | Money | `AnnualRevenue` `70000` → `$70,000.00` |
| Percent | A percentage | `Probability` `10` → `10%` |

Naming a format on the Rule always wins over the field definition, so Number on a Currency field
drops the symbol as asked. Field types without a shape of their own - Number, Text, Checkbox, Date,
Date/Time - fall through to the type rules below.

A value with no single source field behind it, such as `SUM(Amount)`, has no definition to read, so
it uses the type rules below. Name Currency on the Rule when an aggregate should read as money.

## Auto: Typed values

When there is no field definition to read, and the Framework still has the Apex type, it formats
from that type:

| Type | Display rule | Example |
| --- | --- | --- |
| Boolean | `Yes` or `No` | `true` → `Yes` |
| Date | Running user's locale date format | `2026-07-04` typed Date → locale date such as `7/4/2026` |
| Datetime | Running user's locale and time zone | typed Datetime → locale datetime such as `7/4/2026, 5:30 PM` |
| Integer, Long, Decimal, or Double | Grouping separators for the running user's locale; drop an all-zero fractional part | `70000.0` → `70,000`; `70000.5` → `70,000.5`; `-1234567` → `-1,234,567` |

Only values that keep a numeric Apex type are grouped. A digit-only string is left alone so postal
codes, years, and Ids with leading zeroes keep their exact spelling. To group one anyway, set
Display: Value Format to Number.

## Auto: Text values without a retained type

Fixed Custom Metadata operands and other flattened strings are recognized in this order:

| Shape | Display rule | Example |
| --- | --- | --- |
| Boolean text | Case-insensitive `true` / `false` → `Yes` / `No` | `False` → `No` |
| ISO date `YYYY-MM-DD` | Same locale date format as a typed Date | `2026-07-04` → locale date |
| ISO datetime `YYYY-MM-DD HH:MM:SS` or `YYYY-MM-DDTHH:MM:SS…` | Same locale datetime format as a typed Datetime | `2026-07-04 17:30:00` → locale datetime |
| Semicolon-delimited multi-select | Comma-separated list after trimming each part | `Hot;Warm;Cold` → `Hot, Warm, Cold` |
| Ordinary text | Unchanged | `Technology`, `0012345`, `90210`, `1-800-CALL` |

A digit-only string such as `500000` stays `500000` when Found is also text. When Found is a typed
number and Expected is a numeric string from Custom Metadata, Expected is parsed as a number so both
sides use the same grouping (for example Expected `100000` becomes `100,000` next to Found
`100,000`). This alignment only happens on Auto; a named format already renders both sides the same
way.

## Locale

Numbers, currency, dates, and date/times follow the **running user's** locale and time zone, read at
the moment the Rule is evaluated:

| Running user's locale | `70000.0` on Number | `1234.56` in euros |
| --- | --- | --- |
| English (US) | `70,000` | `€1,234.56` |
| German (Germany) | `70.000` | `€1.234,56` |

Two users can therefore see the same Rule write the same value differently. That is expected: the
underlying value and the pass or fail outcome are identical.

## Currency

| Behavior | Detail |
| --- | --- |
| Which currency | The record's own currency when it has one, otherwise the running user's currency |
| Symbol | Used in a single-currency org, for example `$70,000.00` |
| ISO style | Used in an org with more than one currency, for example `USD 70,000.00`, and for any currency with no symbol on file such as `SAR 70,000.00` |
| Minor units | Two decimal places, or none for currencies that have no minor unit such as yen and won |
| Negative amounts | The minus sign leads: `-$1,250.50`, or `USD -1,250.50` in ISO style |
| Rounding | Sub-unit amounts are rounded for display only; the compared value is untouched |
| No currency available | Falls back to a plain grouped number |

An org with more than one currency leads with the ISO code because a bare `$` cannot tell US,
Australian, and Canadian dollars apart on the same card.

An amount is shown in its own currency rather than converted, so a euro record reads in euros for a
reader who works in dollars. Converting values for a comparison is a separate concern from writing
them on a card.

### Which record's currency is used

| Where the value came from | Currency used |
| --- | --- |
| A query over the record the card is on | That record's currency |
| A query whose rows carry `CurrencyIsoCode` | Each row's own currency |
| A Formula Rule | The record's currency |
| An aggregate such as `SUM(Amount)` | Salesforce converts an aggregate to the corporate currency, and the chip follows |
| A query over a different object without `CurrencyIsoCode` | The running user's currency, rather than borrowing an unrelated record's |

## List previews

List comparisons render through `formatList`:

| Input | Display text |
| --- | --- |
| Empty or null list | `(none)` |
| Up to 10 values | `[value1, value2, …]` with each entry formatted like a single value |
| More than 10 values | First 10 entries, then `… (N total)` inside the brackets |

Every entry uses the Rule's Display: Value Format, so a list of amounts reads consistently.

## What this formatter does not change

- Pass and fail decisions still use the raw typed values and operators. No Display: Value Format
  choice can move a Rule between pass and fail.
- Ordinary text, Salesforce Ids, postal codes, phone-style strings, and other non-matching shapes
  keep their exact characters.
- Administrator-authored **Display: Found Text** and **Display: Expected Text** templates are merge
  token templates; they are not re-run through this formatter after tokens resolve.
- Merge tokens in messages and Action URLs use
  [merge-token resolution](reference-merge-tokens.md), not `formatValue`.
- **Formula Result Type** (`FormulaResultType__c`) is a different setting. It declares the type a
  formula returns so the Rule can calculate with it; Display: Value Format only decides how the
  result is written. A Formula Rule can set Formula Result Type to Number and Display: Value Format
  to Currency at the same time.

## Not covered in this release

| Not yet | What happens today |
| --- | --- |
| Picklist API values shown as their labels | The stored API value is shown |
| A different format for Found than for Expected | One format covers both sides; use Display Text or a Display Formula per side when they must differ |
| Percent for ratios such as `0.8` meaning 80% | Percent follows Salesforce Percent field semantics, so `0.8` reads `0.8%` |
| Format filters inside merge tokens, such as `\|currency` | `\|` already means fallback text in a merge token; use Display: Value Format instead |

## Related

- [Reference: Apex classes](reference-apex-classes.md#recordhealthcheckdisplayformat):
  `RecordHealthCheckDisplayFormat` rendering rules and `formatValue` / `formatList` ownership
- [Reference: Query](reference-query.md): Found and Expected on Query Rules
- [Reference: Formula](reference-formula.md): optional Found and Expected display formulas
- [Reference: Compare two queries](reference-compare-two-queries.md): two-sided Found and Expected
- [Reference: Apex](reference-apex.md): plugin-authored Found and Expected strings
