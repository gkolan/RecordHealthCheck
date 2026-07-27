/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Covers Display: Value Format rendering for Found and Expected values.
 *
 * Assertions that involve grouping separators run as a user with a pinned
 * locale, so the suite reads the same way in an org whose default locale is not
 * English (US).
 */
@IsTest
private class RecordHealthCheckDisplayFormatTest {
  private static final String AUTO = 'AUTO';
  private static final String NUMBER_FORMAT = 'NUMBER';
  private static final String CURRENCY_FORMAT = 'CURRENCY';
  private static final String PERCENT_FORMAT = 'PERCENT';
  private static final String RATIO_PERCENT_FORMAT = 'RATIO_PERCENT';
  private static final String BOOLEAN_FORMAT = 'BOOLEAN';
  private static final String DATE_FORMAT = 'DATE';
  private static final String DATETIME_FORMAT = 'DATETIME';
  private static final String TEXT_FORMAT = 'TEXT';
  private static final String RAW_FORMAT = 'RAW';

  /** A user pinned to a locale so separator assertions are deterministic. */
  private static User userWithLocale(String locale, String alias) {
    return RecordHealthCheckTestDataFactory.createUserWithLocale(locale, alias);
  }

  /**
   * How an amount reads in this org: an org with more than one currency leads
   * with the ISO code because a bare symbol would be ambiguous, and a
   * single-currency org uses the symbol. Building the expectation the same way
   * the renderer decides keeps these assertions true in both kinds of org.
   */
  private static String money(String isoCode, String amount) {
    Map<String, String> symbols = new Map<String, String>{
      'USD' => '$',
      'EUR' => '€',
      'JPY' => '¥',
      'KRW' => '₩'
    };
    String symbol = symbols.get(isoCode);
    if (symbol == null || UserInfo.isMultiCurrencyOrganization()) {
      return isoCode + ' ' + amount;
    }
    return amount.startsWith('-')
      ? '-' + symbol + amount.substring(1)
      : symbol + amount;
  }

  // ─── Auto ─────────────────────────────────────────────────────────────────

  @IsTest
  static void autoKeepsTheShippedHumanizeBehavior() {
    System.runAs(userWithLocale('en_US', 'rhcus')) {
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, AUTO),
        'A null value should read as the blank placeholder'
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render('   ', AUTO),
        'Whitespace-only text should read as the blank placeholder'
      );
      System.assertEquals(
        'Technology',
        RecordHealthCheckDisplayFormat.render('Technology', AUTO)
      );
      System.assertEquals(
        'Yes',
        RecordHealthCheckDisplayFormat.render(true, AUTO)
      );
      System.assertEquals(
        'No',
        RecordHealthCheckDisplayFormat.render(false, AUTO)
      );
      System.assertEquals(
        'Yes',
        RecordHealthCheckDisplayFormat.render('true', AUTO),
        'Boolean-shaped text is recognized on Auto'
      );
      System.assertEquals(
        'No',
        RecordHealthCheckDisplayFormat.render('False', AUTO),
        'Boolean text match is case-insensitive'
      );
      System.assertEquals(
        '70,000',
        RecordHealthCheckDisplayFormat.render(70000.0, AUTO),
        'An all-zero fractional part is dropped'
      );
      System.assertEquals(
        '70,000.5',
        RecordHealthCheckDisplayFormat.render(70000.5, AUTO),
        'A real fraction keeps its digits'
      );
      System.assertEquals(
        '-1,234,567',
        RecordHealthCheckDisplayFormat.render(-1234567, AUTO)
      );
      System.assertEquals('1', RecordHealthCheckDisplayFormat.render(1, AUTO));
      System.assertEquals('0', RecordHealthCheckDisplayFormat.render(0, AUTO));
      System.assertEquals(
        '1',
        RecordHealthCheckDisplayFormat.render('1', AUTO),
        'Auto must preserve numeric text that could be a count'
      );
      System.assertEquals(
        '0',
        RecordHealthCheckDisplayFormat.render('0', AUTO),
        'Auto must preserve numeric text that could be a count'
      );
      System.assertEquals(
        'Hot, Warm, Cold',
        RecordHealthCheckDisplayFormat.render('Hot;Warm;Cold', AUTO),
        'Multi-select text becomes a comma-separated list'
      );

      Date july4 = Date.newInstance(2026, 7, 4);
      Datetime july4Evening = Datetime.newInstance(2026, 7, 4, 17, 30, 0);
      System.assertEquals(
        july4.format(),
        RecordHealthCheckDisplayFormat.render(july4, AUTO),
        'A typed Date renders in the running user locale'
      );
      System.assertEquals(
        july4Evening.format(),
        RecordHealthCheckDisplayFormat.render(july4Evening, AUTO),
        'A typed Datetime renders in the running user locale and time zone'
      );
      System.assertEquals(
        july4.format(),
        RecordHealthCheckDisplayFormat.render('2026-07-04', AUTO),
        'ISO date text is recognized on Auto'
      );
      System.assertEquals(
        july4Evening.format(),
        RecordHealthCheckDisplayFormat.render('2026-07-04 17:30:00', AUTO),
        'ISO date/time text is recognized on Auto'
      );
    }
  }

  @IsTest
  static void autoLeavesIdentifierShapedTextAlone() {
    System.runAs(userWithLocale('en_US', 'rhcid')) {
      // Digit-only text may be a postal code, a year, or an Id. Grouping it or
      // dropping leading zeros would change what the value means.
      System.assertEquals(
        '500000',
        RecordHealthCheckDisplayFormat.render('500000', AUTO)
      );
      System.assertEquals(
        '0012345',
        RecordHealthCheckDisplayFormat.render('0012345', AUTO)
      );
      System.assertEquals(
        '90210',
        RecordHealthCheckDisplayFormat.render('90210', AUTO)
      );
      System.assertEquals(
        '1-800-CALL',
        RecordHealthCheckDisplayFormat.render('1-800-CALL', AUTO)
      );
      System.assertEquals(
        'ACM-0092',
        RecordHealthCheckDisplayFormat.render('ACM-0092', AUTO)
      );
    }
  }

  @IsTest
  static void blankAndUnrecognizedFormatsFallBackToAuto() {
    System.runAs(userWithLocale('en_US', 'rhcfb')) {
      System.assertEquals(
        '70,000',
        RecordHealthCheckDisplayFormat.render(70000.0, null),
        'A blank format renders on Auto'
      );
      System.assertEquals(
        '70,000',
        RecordHealthCheckDisplayFormat.render(70000.0, '   ')
      );
      System.assertEquals(
        'Yes',
        RecordHealthCheckDisplayFormat.render(true, 'PICKLIST_LABEL'),
        'A format this release does not implement falls back to Auto'
      );
      System.assertEquals(
        '70,000',
        RecordHealthCheckDisplayFormat.render(70000.0, 'number'),
        'Format matching is case-insensitive'
      );
    }
  }

  // ─── Number ───────────────────────────────────────────────────────────────

  @IsTest
  static void numberGroupsOptedInDigitStrings() {
    System.runAs(userWithLocale('en_US', 'rhcnum')) {
      System.assertEquals(
        '500,000',
        RecordHealthCheckDisplayFormat.render('500000', NUMBER_FORMAT),
        'Naming Number opts a digit string into grouping'
      );
      System.assertEquals(
        '90,210',
        RecordHealthCheckDisplayFormat.render('90210', NUMBER_FORMAT)
      );
      System.assertEquals(
        '1,234.5',
        RecordHealthCheckDisplayFormat.render('1234.50', NUMBER_FORMAT),
        'Trailing zeros are dropped but a real fraction survives'
      );
      System.assertEquals(
        '1,000',
        RecordHealthCheckDisplayFormat.render(1000, NUMBER_FORMAT)
      );
    }
  }

  @IsTest
  static void numberKeepsValuesItCannotSafelyGroup() {
    System.runAs(userWithLocale('en_US', 'rhcnumf')) {
      System.assertEquals(
        '0012345',
        RecordHealthCheckDisplayFormat.render('0012345', NUMBER_FORMAT),
        'Grouping would drop the leading zeros, so the value stays as written'
      );
      System.assertEquals(
        'Technology',
        RecordHealthCheckDisplayFormat.render('Technology', NUMBER_FORMAT),
        'Number on free text keeps the original spelling'
      );
      System.assertEquals(
        'true',
        RecordHealthCheckDisplayFormat.render(true, NUMBER_FORMAT),
        'Number on a checkbox keeps the original spelling, it does not read Yes'
      );
      System.assertEquals(
        '12,345',
        RecordHealthCheckDisplayFormat.render('12,345', NUMBER_FORMAT),
        'Already-grouped text is not parsed and regrouped'
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, NUMBER_FORMAT)
      );
    }
  }

  @IsTest
  static void groupingSeparatorsFollowTheRunningUserLocale() {
    // The headline of the number work: separators come from the running user's
    // locale rather than a hardcoded comma.
    System.runAs(userWithLocale('de_DE', 'rhcde')) {
      String rendered = RecordHealthCheckDisplayFormat.render(
        70000.0,
        NUMBER_FORMAT
      );
      System.assertEquals(
        '70.000',
        rendered,
        'A German (Germany) user should see a period as the grouping separator'
      );
      System.assertEquals(
        '70.000,5',
        RecordHealthCheckDisplayFormat.render(70000.5, NUMBER_FORMAT),
        'A German (Germany) user should see a comma as the decimal mark'
      );
    }
  }

  // ─── Currency ─────────────────────────────────────────────────────────────

  @IsTest
  static void currencyRendersSymbolAndMinorUnits() {
    System.runAs(userWithLocale('en_US', 'rhccur')) {
      String iso = UserInfo.getDefaultCurrency();
      String rendered = RecordHealthCheckDisplayFormat.render(
        70000,
        CURRENCY_FORMAT
      );

      System.assertEquals(
        true,
        rendered.contains('70,000'),
        'The amount should still be grouped for the locale: ' + rendered
      );
      System.assertEquals(
        money(iso, '70,000.00'),
        rendered,
        'An amount shows the org currency and its two minor units'
      );
      System.assertEquals(
        money(iso, '-1,250.50'),
        RecordHealthCheckDisplayFormat.render(-1250.5, CURRENCY_FORMAT),
        'A negative amount keeps its minus sign'
      );
      System.assertEquals(
        money(iso, '0.00'),
        RecordHealthCheckDisplayFormat.render(0, CURRENCY_FORMAT)
      );
      System.assertEquals(
        money(iso, '50,000.00'),
        RecordHealthCheckDisplayFormat.render('50000', CURRENCY_FORMAT),
        'A fixed metadata operand renders as money too'
      );
    }
  }

  @IsTest
  static void currencyHonoursSymbolIsoStyleAndMinorUnits() {
    // Rendering per currency code rather than only the org's own currency, so
    // the symbol table, the ISO fallback, and the minor-unit rules are all
    // exercised in a single-currency org.
    System.runAs(userWithLocale('en_US', 'rhciso')) {
      System.assertEquals(
        money('USD', '70,000.00'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, 'USD')
      );
      System.assertEquals(
        money('EUR', '1,234.56'),
        RecordHealthCheckDisplayFormat.render(1234.56, CURRENCY_FORMAT, 'EUR')
      );
      System.assertEquals(
        money('JPY', '70,000'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, 'JPY'),
        'Yen has no minor unit, so no decimal places are shown'
      );
      System.assertEquals(
        money('KRW', '1,500'),
        RecordHealthCheckDisplayFormat.render(1500, CURRENCY_FORMAT, 'KRW')
      );
      System.assertEquals(
        'SAR 70,000.00',
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, 'SAR'),
        'A currency with no symbol on file renders in ISO style'
      );
      System.assertEquals(
        'SAR 70,000.00',
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, ' sar '),
        'The currency code is trimmed and matched without regard to case'
      );
      System.assertEquals(
        money('USD', '-1,250.50'),
        RecordHealthCheckDisplayFormat.render(-1250.5, CURRENCY_FORMAT, 'USD'),
        'A negative amount keeps its minus sign'
      );
      System.assertEquals(
        money('USD', '0.00'),
        RecordHealthCheckDisplayFormat.render(0, CURRENCY_FORMAT, 'USD')
      );
      System.assertEquals(
        money('USD', '99.90'),
        RecordHealthCheckDisplayFormat.render(99.9, CURRENCY_FORMAT, 'USD'),
        'A short fraction is padded out to the minor unit'
      );
      System.assertEquals(
        money('USD', '1.24'),
        RecordHealthCheckDisplayFormat.render(1.235, CURRENCY_FORMAT, 'USD'),
        'A sub-cent amount is rounded for display only'
      );
      System.assertEquals(
        money(UserInfo.getDefaultCurrency(), '70,000.00'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, null),
        'A blank currency input uses the running user currency'
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, CURRENCY_FORMAT, 'USD')
      );
    }
  }

  @IsTest
  static void currencyFollowsTheRunningUserLocale() {
    System.runAs(userWithLocale('de_DE', 'rhccde')) {
      System.assertEquals(
        money('EUR', '1.234,56'),
        RecordHealthCheckDisplayFormat.render(1234.56, CURRENCY_FORMAT, 'EUR'),
        'A German (Germany) user sees the locale grouping and decimal mark'
      );
    }
  }

  @IsTest
  static void currencyKeepsValuesThatAreNotAmounts() {
    System.runAs(userWithLocale('en_US', 'rhccurf')) {
      System.assertEquals(
        '001A2B3C4D5E6F7G',
        RecordHealthCheckDisplayFormat.render(
          '001A2B3C4D5E6F7G',
          CURRENCY_FORMAT
        ),
        'Currency on an Id keeps the original spelling'
      );
      System.assertEquals(
        'true',
        RecordHealthCheckDisplayFormat.render(true, CURRENCY_FORMAT)
      );
      System.assertEquals(
        '$70,000',
        RecordHealthCheckDisplayFormat.render('$70,000', CURRENCY_FORMAT),
        'An already-formatted amount is not formatted a second time'
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, CURRENCY_FORMAT)
      );
    }
  }

  // ─── Percent ──────────────────────────────────────────────────────────────

  @IsTest
  static void percentAddsTheSymbolWithoutDoublingIt() {
    System.runAs(userWithLocale('en_US', 'rhcpct')) {
      System.assertEquals(
        '12.5%',
        RecordHealthCheckDisplayFormat.render(12.5, PERCENT_FORMAT)
      );
      System.assertEquals(
        '80%',
        RecordHealthCheckDisplayFormat.render(80, PERCENT_FORMAT)
      );
      System.assertEquals(
        '0%',
        RecordHealthCheckDisplayFormat.render(0, PERCENT_FORMAT)
      );
      System.assertEquals(
        '-5%',
        RecordHealthCheckDisplayFormat.render(-5, PERCENT_FORMAT)
      );
      System.assertEquals(
        '12%',
        RecordHealthCheckDisplayFormat.render(12.0, PERCENT_FORMAT),
        'An all-zero fractional part is dropped before the symbol'
      );
      System.assertEquals(
        '12.5%',
        RecordHealthCheckDisplayFormat.render('12.5%', PERCENT_FORMAT),
        'Text that already ends in a percent sign is left alone'
      );
      System.assertEquals(
        'Technology',
        RecordHealthCheckDisplayFormat.render('Technology', PERCENT_FORMAT)
      );
    }
  }

  @IsTest
  static void ratioPercentMultipliesForDisplayOnly() {
    System.runAs(userWithLocale('en_US', 'rhcratio')) {
      System.assertEquals(
        '75%',
        RecordHealthCheckDisplayFormat.render(0.75, RATIO_PERCENT_FORMAT)
      );
      System.assertEquals(
        '100%',
        RecordHealthCheckDisplayFormat.render(1, RATIO_PERCENT_FORMAT)
      );
      System.assertEquals(
        '-5%',
        RecordHealthCheckDisplayFormat.render(-0.05, RATIO_PERCENT_FORMAT)
      );
      System.assertEquals(
        '125%',
        RecordHealthCheckDisplayFormat.render(1.25, RATIO_PERCENT_FORMAT)
      );
      System.assertEquals(
        'already formatted',
        RecordHealthCheckDisplayFormat.render(
          'already formatted',
          RATIO_PERCENT_FORMAT
        )
      );
      System.assertEquals(
        false,
        RecordHealthCheckComparisonEngine.valuesEqual(0.75, 75),
        'Ratio formatting never changes comparison operands'
      );
    }
  }

  // ─── Checkbox ─────────────────────────────────────────────────────────────

  @IsTest
  static void checkboxForcesYesAndNo() {
    System.assertEquals(
      'Yes',
      RecordHealthCheckDisplayFormat.render(true, BOOLEAN_FORMAT)
    );
    System.assertEquals(
      'No',
      RecordHealthCheckDisplayFormat.render(false, BOOLEAN_FORMAT)
    );
    System.assertEquals(
      'Yes',
      RecordHealthCheckDisplayFormat.render('TRUE', BOOLEAN_FORMAT)
    );
    System.assertEquals(
      'No',
      RecordHealthCheckDisplayFormat.render(' false ', BOOLEAN_FORMAT),
      'Surrounding whitespace does not stop the match'
    );
    System.assertEquals(
      'Technology',
      RecordHealthCheckDisplayFormat.render('Technology', BOOLEAN_FORMAT),
      'Checkbox on text that is not boolean keeps the original spelling'
    );
    System.assertEquals(
      '(blank)',
      RecordHealthCheckDisplayFormat.render(null, BOOLEAN_FORMAT),
      'A null checkbox reads blank, not No'
    );
    System.assertEquals(
      'Yes',
      RecordHealthCheckDisplayFormat.render(1, BOOLEAN_FORMAT),
      'A numeric true value reads like a checkbox'
    );
    System.assertEquals(
      'No',
      RecordHealthCheckDisplayFormat.render(0, BOOLEAN_FORMAT),
      'A numeric false value reads like a checkbox'
    );
    System.assertEquals(
      'Yes',
      RecordHealthCheckDisplayFormat.render('1', BOOLEAN_FORMAT),
      'Explicit Checkbox opts numeric text into Yes/No rendering'
    );
    System.assertEquals(
      'No',
      RecordHealthCheckDisplayFormat.render('0', BOOLEAN_FORMAT),
      'Explicit Checkbox opts numeric text into Yes/No rendering'
    );
    System.assertEquals(
      '42',
      RecordHealthCheckDisplayFormat.render(42, BOOLEAN_FORMAT),
      'Other numbers keep their original spelling'
    );
  }

  @IsTest
  static void aListPassedToTheSingleValueRendererUsesTheListContract() {
    System.assertEquals(
      '[1, 2, 3]',
      RecordHealthCheckDisplayFormat.render(
        new List<Object>{ 1, 2, 3 },
        NUMBER_FORMAT
      ),
      'A defensive list value is rendered entry by entry, not as Apex syntax'
    );
    Datetime typedDatetime = Datetime.newInstance(2026, 7, 4, 17, 30, 0);
    System.assertEquals(
      '[' + typedDatetime.format() + ']',
      RecordHealthCheckDisplayFormat.render(
        new List<Object>{ typedDatetime },
        DATETIME_FORMAT
      ),
      'A plugin list keeps typed date/time values and the running user time zone'
    );
  }

  // ─── Date and date/time ───────────────────────────────────────────────────

  @IsTest
  static void dateAndDatetimeRenderInTheUserLocale() {
    Date july4 = Date.newInstance(2026, 7, 4);
    Datetime july4Evening = Datetime.newInstance(2026, 7, 4, 17, 30, 0);

    System.assertEquals(
      july4.format(),
      RecordHealthCheckDisplayFormat.render(july4, DATE_FORMAT)
    );
    System.assertEquals(
      july4.format(),
      RecordHealthCheckDisplayFormat.render('2026-07-04', DATE_FORMAT),
      'ISO date text renders like a typed Date'
    );
    System.assertEquals(
      july4.format(),
      RecordHealthCheckDisplayFormat.render('2026-07-04 17:30:00', DATE_FORMAT),
      'Naming Date on a date/time shows just the date part'
    );
    System.assertEquals(
      july4Evening.format(),
      RecordHealthCheckDisplayFormat.render(july4Evening, DATETIME_FORMAT)
    );
    System.assertEquals(
      july4Evening.format(),
      RecordHealthCheckDisplayFormat.render(
        '2026-07-04T17:30:00',
        DATETIME_FORMAT
      ),
      'A T separator is accepted'
    );
    System.assertEquals(
      july4.format(),
      RecordHealthCheckDisplayFormat.render(july4, DATETIME_FORMAT),
      'A Date has no time of day, so it renders as a date'
    );
    System.assertEquals(
      july4.format(),
      RecordHealthCheckDisplayFormat.render(july4Evening, DATE_FORMAT),
      'Naming Date on a typed Datetime shows just the date part'
    );
    System.assertEquals(
      july4.format(),
      RecordHealthCheckDisplayFormat.render('2026-07-04', DATETIME_FORMAT),
      'Date-only text under Date/Time has no time of day to show'
    );
    System.assertEquals(
      'Technology',
      RecordHealthCheckDisplayFormat.render('Technology', DATE_FORMAT),
      'Date on text that is not a date keeps the original spelling'
    );
    System.assertEquals(
      'Technology',
      RecordHealthCheckDisplayFormat.render('Technology', DATETIME_FORMAT)
    );
  }

  @IsTest
  static void dateShapedTextThatIsNotARealDateStaysAsWritten() {
    // Date.newInstance rolls out-of-range parts over, so without a range check
    // "2026-13-40" would read as 9 February 2027 — a date the record never held.
    for (
      String format : new List<String>{ AUTO, DATE_FORMAT, DATETIME_FORMAT }
    ) {
      System.assertEquals(
        '2026-13-40',
        RecordHealthCheckDisplayFormat.render('2026-13-40', format),
        format + ' should leave an impossible month and day as written'
      );
      System.assertEquals(
        '2026-02-30',
        RecordHealthCheckDisplayFormat.render('2026-02-30', format),
        format + ' should leave 30 February as written'
      );
      System.assertEquals(
        '2026-07-04 99:99:99',
        RecordHealthCheckDisplayFormat.render('2026-07-04 99:99:99', format),
        format + ' should leave an impossible time as written'
      );
    }

    // A real leap day still renders.
    System.assertEquals(
      Date.newInstance(2028, 2, 29).format(),
      RecordHealthCheckDisplayFormat.render('2028-02-29', AUTO),
      '29 February in a leap year is a real date'
    );
    System.assertEquals(
      '2027-02-29',
      RecordHealthCheckDisplayFormat.render('2027-02-29', AUTO),
      '29 February outside a leap year is not'
    );
  }

  @IsTest
  static void alignedOperandsKeepLeadingZeros() {
    System.assertEquals(
      '00100',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '00100',
        5.0,
        AUTO
      ),
      'Aligning must not drop leading zeros, matching the Number format'
    );
    System.assertEquals(
      true,
      RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '100',
        5.0,
        AUTO
      ) instanceof Decimal,
      'A plain numeric operand still aligns'
    );
  }

  @IsTest
  static void aggregateAmountsAreLabelledWithTheCorporateCurrency() {
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE Id = NULL
    ];
    SObject aggregate = totals.isEmpty() ? null : totals[0];
    String iso = RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(aggregate);

    if (!UserInfo.isMultiCurrencyOrganization()) {
      System.assertEquals(
        null,
        iso,
        'A single-currency org has one currency, so there is nothing to resolve'
      );
      return;
    }

    // Salesforce converts an aggregate into the corporate currency, so the chip
    // has to say corporate rather than whichever currency the reader uses.
    List<SObject> corporate = Database.query(
      'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1'
    );
    System.assertEquals(
      String.valueOf(corporate[0].get('IsoCode')),
      iso,
      'An aggregate is labelled with the corporate currency'
    );
  }

  // ─── Text and Raw ─────────────────────────────────────────────────────────

  @IsTest
  static void textAndRawKeepTheOriginalSpelling() {
    for (String format : new List<String>{ TEXT_FORMAT, RAW_FORMAT }) {
      System.assertEquals(
        'true',
        RecordHealthCheckDisplayFormat.render(true, format),
        format + ' should not turn a checkbox into Yes'
      );
      System.assertEquals(
        '2026-07-04',
        RecordHealthCheckDisplayFormat.render('2026-07-04', format),
        format + ' should not reformat text that looks like a date'
      );
      System.assertEquals(
        'Hot;Warm;Cold',
        RecordHealthCheckDisplayFormat.render('Hot;Warm;Cold', format),
        format + ' should not rewrite multi-select delimiters'
      );
      System.assertEquals(
        '0012345',
        RecordHealthCheckDisplayFormat.render('0012345', format)
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, format),
        format + ' still uses the blank placeholder'
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.render('  ', format)
      );
    }
  }

  // ─── Found / Expected symmetry ────────────────────────────────────────────

  @IsTest
  static void expectedAlignsWithFoundOnAuto() {
    // A fixed metadata operand arrives as text. When Found is numeric, Expected
    // is parsed back to a number so the two chips group the same way.
    Object aligned = RecordHealthCheckDisplayFormat.alignExpectedToFound(
      '100000',
      70000.0,
      AUTO
    );
    System.assertEquals(
      true,
      aligned instanceof Decimal,
      'A numeric operand should align to a number when Found is numeric'
    );

    System.assertEquals(
      '90210',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '90210',
        'text found',
        AUTO
      ),
      'A text Found value leaves the operand alone'
    );
    System.assertEquals(
      'Technology',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        'Technology',
        70000.0,
        AUTO
      ),
      'An operand that is not a number is left alone even beside a numeric Found'
    );
    System.assertEquals(
      '100000',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '100000',
        70000.0,
        RAW_FORMAT
      ),
      'Raw asks for the original spelling, so no alignment happens'
    );
    System.assertEquals(
      '100000',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '100000',
        70000.0,
        CURRENCY_FORMAT
      ),
      'A named format already renders both sides the same way'
    );
  }

  @IsTest
  static void foundAndExpectedReadInTheSameUnits() {
    System.runAs(userWithLocale('en_US', 'rhcsym')) {
      String found = RecordHealthCheckComparisonEngine.formatValue(
        70000.0,
        CURRENCY_FORMAT
      );
      String expected = RecordHealthCheckComparisonEngine.describeExpectedForActual(
        'GREATER_THAN_OR_EQUAL',
        '50000',
        70000.0,
        CURRENCY_FORMAT
      );
      System.assertEquals(
        true,
        expected.startsWith('at least '),
        'The operator phrase still leads the Expected chip: ' + expected
      );
      String iso = UserInfo.getDefaultCurrency();
      System.assertEquals(money(iso, '70,000.00'), found);
      System.assertEquals(
        'at least ' + money(iso, '50,000.00'),
        expected,
        'Both chips read in the same currency'
      );

      System.assertEquals(
        '100,000',
        RecordHealthCheckComparisonEngine.formatValue(100000.0, AUTO)
      );
      System.assertEquals(
        'to equal 100,000',
        RecordHealthCheckComparisonEngine.describeExpectedForActual(
          'EQUALS',
          '100000',
          100000.0,
          AUTO
        ),
        'On Auto a numeric operand groups like the Found value beside it'
      );
      System.assertEquals(
        'to be blank',
        RecordHealthCheckComparisonEngine.describeExpected(
          'IS_BLANK',
          null,
          CURRENCY_FORMAT
        ),
        'A unary operator has no operand to format'
      );
    }
  }

  // ─── Lists ────────────────────────────────────────────────────────────────

  @IsTest
  static void listsRenderEveryEntryWithTheSameFormat() {
    System.runAs(userWithLocale('en_US', 'rhclist')) {
      System.assertEquals(
        '(none)',
        RecordHealthCheckComparisonEngine.formatList(
          new List<Object>(),
          CURRENCY_FORMAT
        )
      );
      System.assertEquals(
        '(none)',
        RecordHealthCheckComparisonEngine.formatList(null, CURRENCY_FORMAT)
      );
      System.assertEquals(
        '[1,000, 2,000]',
        RecordHealthCheckComparisonEngine.formatList(
          new List<Object>{ 1000, 2000 },
          NUMBER_FORMAT
        )
      );
      System.assertEquals(
        '[Hot, Warm]',
        RecordHealthCheckComparisonEngine.formatList(
          new List<Object>{ 'Hot', 'Warm' },
          AUTO
        )
      );

      List<Object> big = new List<Object>();
      for (Integer i = 0; i < 12; i++) {
        big.add('V' + i);
      }
      String rendered = RecordHealthCheckComparisonEngine.formatList(
        big,
        RAW_FORMAT
      );
      System.assertEquals(
        true,
        rendered.contains('(12 total)'),
        'A long list is capped and reports the full count: ' + rendered
      );
      System.assertEquals(
        false,
        rendered.contains('V11'),
        'Entries past the preview cap are not listed: ' + rendered
      );

      System.assertEquals(
        'to be one of [Hot, Warm]',
        RecordHealthCheckComparisonEngine.describeExpectedList(
          'LIST_CONTAINS_ANY',
          new List<Object>{ 'Hot', 'Warm' },
          AUTO
        )
      );
    }
  }

  // ─── Format from the field definition ─────────────────────────────────────

  @IsTest
  static void currencyAndPercentFieldsSuggestTheirOwnFormat() {
    Map<String, Schema.SObjectField> opportunityFields = RecordHealthCheckDescribeCache.fieldMap(
      Opportunity.SObjectType
    );

    System.assertEquals(
      CURRENCY_FORMAT,
      RecordHealthCheckDisplayFormat.formatForField(
        RecordHealthCheckDescribeCache.describeField(
          opportunityFields.get('Amount')
        )
      ),
      'A Currency field should suggest Currency'
    );
    System.assertEquals(
      PERCENT_FORMAT,
      RecordHealthCheckDisplayFormat.formatForField(
        RecordHealthCheckDescribeCache.describeField(
          opportunityFields.get('Probability')
        )
      ),
      'A Percent field should suggest Percent'
    );
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.formatForField(
        RecordHealthCheckDescribeCache.describeField(
          opportunityFields.get('Name')
        )
      ),
      'A text field has no format of its own, so Auto keeps its wording'
    );
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.formatForField(null)
    );
  }

  @IsTest
  static void autoTakesTheFormatFromTheQueriedField() {
    Opportunity row = new Opportunity(Amount = 70000, Probability = 25);

    System.assertEquals(
      CURRENCY_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, row, 'Amount'),
      'On Auto a Currency field renders as money without a Rule change'
    );
    System.assertEquals(
      PERCENT_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(null, row, 'Probability'),
      'A blank format is Auto, so the field still decides'
    );
    System.assertEquals(
      RAW_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(RAW_FORMAT, row, 'Amount'),
      'A format the author named always wins over the field definition'
    );
    System.assertEquals(
      NUMBER_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(NUMBER_FORMAT, row, 'Amount'),
      'Naming Number on a Currency field drops the symbol, as asked'
    );
  }

  @IsTest
  static void fieldLookupLeavesTheFormatAloneWhenThereIsNothingToDescribe() {
    Opportunity row = new Opportunity(Amount = 70000);

    System.assertEquals(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, null, 'Amount'),
      'No row means no field definition to read'
    );
    System.assertEquals(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, row, null),
      'No field path means nothing to describe'
    );
    System.assertEquals(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, row, 'NotAField__c'),
      'An unknown field is left alone rather than guessed at'
    );
    System.assertEquals(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(
        AUTO,
        row,
        'Account.AnnualRevenue'
      ),
      'A relationship that was not queried yields no describe'
    );
    System.assertEquals(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(
        AUTO,
        row,
        'NotARelation__r.Amount'
      ),
      'A relationship name that does not exist is left alone'
    );

    // An aggregate row has no single source field behind the value.
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE Id = NULL
    ];
    System.assertEquals(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(
        AUTO,
        totals.isEmpty() ? null : totals[0],
        'total'
      ),
      'An aggregate result has no field definition to read'
    );
  }

  @IsTest
  static void recordCurrencyIsReadOnlyWhenTheOrgHasMoreThanOne() {
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(null),
      'No row means no currency to read'
    );

    if (!UserInfo.isMultiCurrencyOrganization()) {
      System.assertEquals(
        null,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(
          new Opportunity(Amount = 70000)
        ),
        'With one currency in the org there is no per-record currency to read'
      );
      return;
    }

    // With more than one currency, an amount is shown in the currency its own
    // record carries rather than the currency the reader happens to work in.
    SObject row = (SObject) Type.forName('Opportunity').newInstance();
    row.put('Amount', 70000);
    row.put('CurrencyIsoCode', 'EUR');

    System.assertEquals(
      'EUR',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(row),
      'The row currency is read from CurrencyIsoCode'
    );
    System.assertEquals(
      'EUR 70,000.00',
      RecordHealthCheckDisplayFormat.render(
        70000,
        CURRENCY_FORMAT,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(row)
      ),
      'A euro record reads in euros even for a user whose currency is different'
    );
    System.assertEquals(
      UserInfo.getDefaultCurrency() + ' 70,000.00',
      RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, null),
      'With no record currency the running user currency is used'
    );

    // An aggregate is covered by aggregateAmountsAreLabelledWithTheCorporateCurrency.
  }

  // ─── A currency for each side ─────────────────────────────────────────────

  /** The org's corporate currency, or null when the org has a single currency. */
  private static String corporateIsoCode() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return null;
    }
    List<SObject> corporate = Database.query(
      'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1'
    );
    return corporate.isEmpty()
      ? null
      : String.valueOf(corporate[0].get('IsoCode'));
  }

  @IsTest
  static void eachSideBorrowsTheCardRecordCurrencyOnlyForItsOwnObject() {
    Account card = new Account(Name = 'Card record');

    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(null, card),
      'No row means no currency to read'
    );
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        new Account(Name = 'Queried'),
        null
      ),
      'No card record means there is nothing to fall back to'
    );

    if (!UserInfo.isMultiCurrencyOrganization()) {
      System.assertEquals(
        null,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          new Account(Name = 'Queried'),
          card
        ),
        'With one currency in the org there is no per-record currency to read'
      );
      return;
    }

    SObject cardRecord = (SObject) Type.forName('Account').newInstance();
    cardRecord.put('Name', 'Card record');
    cardRecord.put('CurrencyIsoCode', 'EUR');

    // A query over the same record the card is on did not have to select
    // CurrencyIsoCode for the amount to be in that record's currency.
    SObject sameObjectRow = (SObject) Type.forName('Account').newInstance();
    sameObjectRow.put('AnnualRevenue', 50000);
    System.assertEquals(
      'EUR',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        sameObjectRow,
        cardRecord
      ),
      'The card record supplies the currency for a query over that same record'
    );

    // A row that names its own currency keeps it.
    SObject ownCurrencyRow = (SObject) Type.forName('Account').newInstance();
    ownCurrencyRow.put('CurrencyIsoCode', 'JPY');
    System.assertEquals(
      'JPY',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        ownCurrencyRow,
        cardRecord
      ),
      'A row currency wins over the card record currency'
    );

    // A query over a different object is left on the running user's currency
    // rather than borrowing an unrelated record's.
    SObject otherObjectRow = (SObject) Type.forName('Opportunity')
      .newInstance();
    otherObjectRow.put('Amount', 70000);
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        otherObjectRow,
        cardRecord
      ),
      'A different object does not borrow the card record currency'
    );
  }

  @IsTest
  static void relationshipFieldCurrencyComesFromTheRelatedRow() {
    Contact outerRow = new Contact(LastName = 'Outer');
    Account related = new Account(Name = 'Related', AnnualRevenue = 70000);
    outerRow.putSObject('Account', related);

    if (!UserInfo.isMultiCurrencyOrganization()) {
      System.assertEquals(
        null,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          outerRow,
          null,
          'Account.AnnualRevenue'
        )
      );
      return;
    }

    related.put('CurrencyIsoCode', 'EUR');
    outerRow.put('CurrencyIsoCode', 'USD');
    System.assertEquals(
      'EUR',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        outerRow,
        null,
        'Account.AnnualRevenue'
      ),
      'The outer row currency must not relabel a related record amount'
    );
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        new Contact(LastName = 'Relationship not selected'),
        null,
        'Account.AnnualRevenue'
      ),
      'A missing relationship safely falls back instead of borrowing the outer row'
    );
  }

  @IsTest
  static void compareTwoQueriesLabelsEachSideWithItsOwnCurrency() {
    Account card = RecordHealthCheckTestDataFactory.createAccount(
      'DVF Compare Queries Account'
    );
    RecordHealthCheckTestDataFactory.createOpportunity(
      card.Id,
      'DVF Compare Queries Opportunity',
      70000
    );

    // Found: an aggregate, which Salesforce converts to the corporate currency.
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE AccountId = :card.Id
    ];
    List<SObject> primaryRows = new List<SObject>{ totals[0] };

    // Expected: a row carrying its own currency, which is not the corporate one.
    Boolean multiCurrency = UserInfo.isMultiCurrencyOrganization();
    SObject comparisonRow;
    if (multiCurrency) {
      comparisonRow = (SObject) Type.forName('Account').newInstance();
      comparisonRow.put('AnnualRevenue', 50000);
      comparisonRow.put('CurrencyIsoCode', 'EUR');
    } else {
      comparisonRow = new Account(AnnualRevenue = 50000);
    }

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'DVF_Compare_Queries_Currency',
      MasterLabel = 'DVF_Compare_Queries_Currency',
      CheckTitle__c = 'Pipeline covers revenue',
      EvaluationType__c = 'COMPARE_TWO_QUERIES',
      SourceQueryField__c = 'total',
      ComparisonQueryField__c = 'AnnualRevenue',
      ComparisonOperator__c = 'GREATER_THAN_OR_EQUAL',
      QueryResultHandling__c = 'ONE_RESULT',
      DisplayValueFormat__c = CURRENCY_FORMAT
    );

    RecordHealthCheckResult result = new RecordHealthCheckResult();
    new RecordHealthCheckCompareQueriesEvaluator()
      .setComparisonValues(
        rule,
        card,
        result,
        primaryRows,
        new List<SObject>{ comparisonRow },
        'ONE_RESULT'
      );

    String foundIsoCode = multiCurrency ? corporateIsoCode() : null;
    String expectedIsoCode = multiCurrency ? 'EUR' : null;

    System.assertEquals(
      RecordHealthCheckDisplayFormat.render(
        70000,
        CURRENCY_FORMAT,
        foundIsoCode
      ),
      result.actualValue,
      'The Found side keeps the currency the aggregate is in'
    );
    System.assertEquals(
      true,
      result.expectedValue.contains(
        RecordHealthCheckDisplayFormat.render(
          50000,
          CURRENCY_FORMAT,
          expectedIsoCode
        )
      ),
      'The Expected side keeps its own row currency: ' + result.expectedValue
    );
  }

  @IsTest
  static void aComparisonQueryLabelsTheExpectedSideWithItsOwnCurrency() {
    Account card = RecordHealthCheckTestDataFactory.createAccount(
      new Account(Name = 'DVF Query Account', AnnualRevenue = 100000)
    );
    RecordHealthCheckTestDataFactory.createOpportunity(
      card.Id,
      'DVF Query Opportunity',
      70000
    );
    Account record = [
      SELECT Id, Name, AnnualRevenue
      FROM Account
      WHERE Id = :card.Id
    ];

    Record_Health_Check_Rule__mdt rule = new Record_Health_Check_Rule__mdt(
      DeveloperName = 'DVF_Query_Comparison_Currency',
      MasterLabel = 'DVF_Query_Comparison_Currency',
      CheckTitle__c = 'Revenue covers pipeline',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}',
      SourceQueryField__c = 'AnnualRevenue',
      QueryResultHandling__c = 'ONE_RESULT',
      ComparisonOperator__c = 'GREATER_THAN_OR_EQUAL',
      ExpectedValueSource__c = 'COMPARISON_QUERY',
      ComparisonQuery__c = 'SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = {!record.Id}',
      ComparisonQueryField__c = 'total',
      NoRowsResult__c = 'FAIL',
      EmptyValueHandling__c = 'SKIP_RECORD',
      DisplayValueFormat__c = CURRENCY_FORMAT
    );

    RecordHealthCheckResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(rule, card.Id, record);

    System.assertEquals(
      'PASS',
      result.status,
      'The check should evaluate: ' + result.detailMessage
    );
    // The Found side is the card record's own amount; the Expected side is an
    // aggregate, so it carries the corporate currency rather than the Found
    // side's. Sharing one currency across both sides would mislabel it.
    System.assertEquals(
      RecordHealthCheckDisplayFormat.render(100000, CURRENCY_FORMAT, null),
      result.actualValue,
      'The Found side reads in the record currency'
    );
    System.assertEquals(
      true,
      result.expectedValue.contains(
        RecordHealthCheckDisplayFormat.render(
          70000,
          CURRENCY_FORMAT,
          corporateIsoCode()
        )
      ),
      'The Expected side keeps the comparison query currency: ' +
      result.expectedValue
    );
  }

  @IsTest
  static void listEntriesKeepTheCurrencyOfTheRowTheyCameFrom() {
    System.runAs(userWithLocale('en_US', 'rhciso')) {
      String mixed = RecordHealthCheckComparisonEngine.formatList(
        new List<Object>{ 70000, 50000 },
        CURRENCY_FORMAT,
        new List<String>{ 'EUR', 'JPY' }
      );
      System.assertEquals(
        '[' + money('EUR', '70,000.00') + ', ' + money('JPY', '50,000') + ']',
        mixed,
        'Each entry is labelled with its own row currency, minor units included'
      );

      // A row with no currency of its own falls back to the running user's,
      // the same as a single value.
      System.assertEquals(
        '[' +
          money('EUR', '70,000.00') +
          ', ' +
          RecordHealthCheckDisplayFormat.render(50000, CURRENCY_FORMAT, null) +
          ']',
        RecordHealthCheckComparisonEngine.formatList(
          new List<Object>{ 70000, 50000 },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR', null }
        ),
        'An entry with no currency reads in the running user currency'
      );

      System.assertEquals(
        'at least ' +
        RecordHealthCheckComparisonEngine.formatList(
          new List<Object>{ 70000 },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR' }
        ),
        RecordHealthCheckComparisonEngine.describeExpectedList(
          'GREATER_THAN_OR_EQUAL',
          new List<Object>{ 70000 },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR' }
        ),
        'The Expected list carries per-row currencies through the operator phrase'
      );

      System.assertEquals(
        '[' +
          money('EUR', '70,000.00') +
          ', ' +
          RecordHealthCheckDisplayFormat.render(
            '50000',
            CURRENCY_FORMAT,
            null
          ) +
          ']',
        RecordHealthCheckComparisonEngine.formatList(
          new List<Object>{ 70000, '50000' },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR' }
        ),
        'A short ISO list safely falls back to the running user currency'
      );

      List<Object> elevenValues = new List<Object>();
      List<String> elevenIsoCodes = new List<String>();
      for (Integer i = 0; i < 11; i++) {
        elevenValues.add(i == 1 ? null : i + 1);
        elevenIsoCodes.add(i == 0 ? 'JPY' : 'EUR');
      }
      String capped = RecordHealthCheckComparisonEngine.formatList(
        elevenValues,
        CURRENCY_FORMAT,
        elevenIsoCodes
      );
      System.assertEquals(
        true,
        capped.startsWith('[' + money('JPY', '1') + ', (blank), '),
        'Row order, a null entry, and its currency position survive list formatting'
      );
      System.assertEquals(
        true,
        capped.endsWith(' … (11 total)]'),
        'Per-row currency lists keep the shared ten-entry preview cap'
      );
    }
  }

  @IsTest
  static void rowCurrencyListsFollowRowOrder() {
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(null, null),
      'No rows means there is nothing to read a currency from'
    );
    System.assertEquals(
      2,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(
          new List<SObject>{
            new Account(Name = 'One'),
            new Account(Name = 'Two')
          },
          null
        )
        .size(),
      'One entry per row, so the list lines up with the values'
    );
  }

  // ─── Picklist labels ──────────────────────────────────────────────────────

  @IsTest
  static void autoUsesPicklistLabelsWithoutChangingStoredValues() {
    Record_Health_Check_Set__mdt row = new Record_Health_Check_Set__mdt(
      FoundExpectedDisplay__c = 'ON_DEMAND'
    );

    System.assertEquals(
      'On demand',
      RecordHealthCheckDisplayFormat.valueForDisplay(
        'ON_DEMAND',
        AUTO,
        row,
        'FoundExpectedDisplay__c'
      ),
      'Auto shows the translated label from the field definition'
    );
    System.assertEquals(
      'ON_DEMAND',
      RecordHealthCheckDisplayFormat.valueForDisplay(
        'ON_DEMAND',
        TEXT_FORMAT,
        row,
        'FoundExpectedDisplay__c'
      ),
      'A named format wins and keeps the stored API value'
    );
    System.assertEquals(
      'RETIRED_VALUE',
      RecordHealthCheckDisplayFormat.valueForDisplay(
        'RETIRED_VALUE',
        AUTO,
        row,
        'FoundExpectedDisplay__c'
      ),
      'A stored value absent from describe falls back to its API spelling'
    );
    System.assertEquals(
      'ON_DEMAND',
      row.FoundExpectedDisplay__c,
      'Resolving a label never mutates the value used by comparison'
    );

    List<Object> labels = RecordHealthCheckDisplayFormat.valuesForDisplay(
      new List<Object>{ 'ON_DEMAND', 'FAILURES_ONLY', 'UNKNOWN' },
      AUTO,
      new List<SObject>{ row, row },
      'FoundExpectedDisplay__c'
    );
    System.assertEquals(
      new List<Object>{ 'On demand', 'Failed checks only', 'UNKNOWN' },
      labels,
      'Lists preserve order, resolve known labels, and tolerate a short row list'
    );
  }

  @IsTest
  static void listDisplayWorkStopsAtTheVisiblePreview() {
    Record_Health_Check_Set__mdt row = new Record_Health_Check_Set__mdt(
      FoundExpectedDisplay__c = 'ON_DEMAND'
    );
    List<Object> values = new List<Object>();
    List<SObject> rows = new List<SObject>();
    for (
      Integer i = 0; i < RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS; i++
    ) {
      values.add(
        i < RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP
          ? 'ON_DEMAND'
          : 'FAILURES_ONLY'
      );
      rows.add(row);
    }

    List<Object> displayed = RecordHealthCheckDisplayFormat.valuesForDisplay(
      values,
      AUTO,
      rows,
      'FoundExpectedDisplay__c'
    );

    System.assertEquals(
      values.size(),
      displayed.size(),
      'The true list total is retained'
    );
    System.assertEquals(
      'On demand',
      displayed[9],
      'Every visible entry uses its label'
    );
    System.assertEquals(
      'FAILURES_ONLY',
      displayed[10],
      'Hidden entries are not needlessly converted'
    );
    System.assertEquals(
      RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(rows, null).size(),
      'Only visible entries need a parallel currency lookup'
    );
  }

  // ─── Time ─────────────────────────────────────────────────────────────────

  @IsTest
  static void timeFieldsReadAsAClockTime() {
    // String.valueOf on a Time writes the storage form 17:30:00.000Z, which
    // reads as machine output on a card.
    System.assertEquals(
      '17:30',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 0, 0),
        AUTO
      ),
      'A whole minute drops the seconds'
    );
    System.assertEquals(
      '09:05',
      RecordHealthCheckDisplayFormat.render(Time.newInstance(9, 5, 0, 0), AUTO),
      'Single digits are padded so times line up'
    );
    System.assertEquals(
      '17:30:45',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 45, 0),
        AUTO
      ),
      'Seconds are kept when the value has them'
    );
    System.assertEquals(
      '17:30',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 0, 0),
        DATETIME_FORMAT
      ),
      'Naming Date/Time on a Time field reads the time of day'
    );
    System.assertEquals(
      '17:30:00.000Z',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 0, 0),
        RAW_FORMAT
      ),
      'Raw still shows the stored value'
    );
  }

  // ─── Long decimals ────────────────────────────────────────────────────────

  @IsTest
  static void highScaleNumbersAreRoundedForTheChip() {
    System.runAs(userWithLocale('en_US', 'rhcscl')) {
      System.assertEquals(
        '1.123457',
        RecordHealthCheckDisplayFormat.render(1.123456789, NUMBER_FORMAT),
        'A chip shows at most six decimal places'
      );
      System.assertEquals(
        '1.123457',
        RecordHealthCheckDisplayFormat.render(1.123456789, AUTO),
        'Auto caps the same way'
      );
      System.assertEquals(
        '1.12345',
        RecordHealthCheckDisplayFormat.render(1.12345, NUMBER_FORMAT),
        'A number inside the cap keeps every digit it has'
      );
      // Display only: the comparison still reads the full value.
      System.assertEquals(
        false,
        RecordHealthCheckComparisonEngine.valuesEqual(1.123456789, 1.123457),
        'Rounding for the chip does not make two different numbers equal'
      );
    }
  }

  // ─── Display only ─────────────────────────────────────────────────────────

  @IsTest
  static void formatChoiceDoesNotChangeTheComparison() {
    // The whole feature is display only. The operator core reads the raw typed
    // values, so no format can move a check between pass and fail.
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        70000.0,
        50000.0
      )
    );
    System.assertEquals(
      false,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        40000.0,
        50000.0
      )
    );
    System.assertEquals(
      true,
      RecordHealthCheckComparisonEngine.valuesEqual(70000.0, 70000),
      'Value equality is unaffected by how the values would be written'
    );
  }
}
