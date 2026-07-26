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
@isTest
private class RecordHealthCheckDisplayFormatTest {
  private static final String AUTO = 'AUTO';
  private static final String NUMBER_FORMAT = 'NUMBER';
  private static final String CURRENCY_FORMAT = 'CURRENCY';
  private static final String PERCENT_FORMAT = 'PERCENT';
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
  static void currencyHonoursSymbolIsoStyleAndMinorUnits() {
    // Rendering per currency code rather than only the org's own currency, so
    // the symbol table, the ISO fallback, and the minor-unit rules are all
    // exercised in a single-currency org.
    System.runAs(userWithLocale('en_US', 'rhciso')) {
      System.assertEquals(
        money('USD', '70,000.00'),
        RecordHealthCheckDisplayFormat.renderCurrency(70000, 'USD')
      );
      System.assertEquals(
        money('EUR', '1,234.56'),
        RecordHealthCheckDisplayFormat.renderCurrency(1234.56, 'EUR')
      );
      System.assertEquals(
        money('JPY', '70,000'),
        RecordHealthCheckDisplayFormat.renderCurrency(70000, 'JPY'),
        'Yen has no minor unit, so no decimal places are shown'
      );
      System.assertEquals(
        money('KRW', '1,500'),
        RecordHealthCheckDisplayFormat.renderCurrency(1500, 'KRW')
      );
      System.assertEquals(
        'SAR 70,000.00',
        RecordHealthCheckDisplayFormat.renderCurrency(70000, 'SAR'),
        'A currency with no symbol on file renders in ISO style'
      );
      System.assertEquals(
        'SAR 70,000.00',
        RecordHealthCheckDisplayFormat.renderCurrency(70000, ' sar '),
        'The currency code is trimmed and matched without regard to case'
      );
      System.assertEquals(
        money('USD', '-1,250.50'),
        RecordHealthCheckDisplayFormat.renderCurrency(-1250.5, 'USD'),
        'A negative amount keeps its minus sign'
      );
      System.assertEquals(
        money('USD', '0.00'),
        RecordHealthCheckDisplayFormat.renderCurrency(0, 'USD')
      );
      System.assertEquals(
        money('USD', '99.90'),
        RecordHealthCheckDisplayFormat.renderCurrency(99.9, 'USD'),
        'A short fraction is padded out to the minor unit'
      );
      System.assertEquals(
        money('USD', '1.24'),
        RecordHealthCheckDisplayFormat.renderCurrency(1.235, 'USD'),
        'A sub-cent amount is rounded for display only'
      );
      System.assertEquals(
        '70,000',
        RecordHealthCheckDisplayFormat.renderCurrency(70000, null),
        'With no currency to render in, the amount falls back to a plain number'
      );
      System.assertEquals(
        '(blank)',
        RecordHealthCheckDisplayFormat.renderCurrency(null, 'USD')
      );
    }
  }

  @isTest
  static void currencyFollowsTheRunningUserLocale() {
    System.runAs(userWithLocale('de_DE', 'rhccde')) {
      System.assertEquals(
        money('EUR', '1.234,56'),
        RecordHealthCheckDisplayFormat.renderCurrency(1234.56, 'EUR'),
        'A German (Germany) user sees the locale grouping and decimal mark'
      );
    }
  }

  @isTest
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

  @isTest
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

  // ─── Checkbox ─────────────────────────────────────────────────────────────

  @isTest
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
      '42',
      RecordHealthCheckDisplayFormat.render(42, BOOLEAN_FORMAT),
      'Checkbox on a number keeps the original spelling'
    );
  }

  // ─── Date and date/time ───────────────────────────────────────────────────

  @isTest
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

  // ─── Text and Raw ─────────────────────────────────────────────────────────

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

  @isTest
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

    // An aggregate row carries no currency field, so the running user currency
    // is used rather than the read failing.
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE Id = NULL
    ];
    System.assertEquals(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(
        totals.isEmpty() ? null : totals[0]
      ),
      'A summed total has no single record currency behind it'
    );
  }

  // ─── Display only ─────────────────────────────────────────────────────────

  @isTest
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
