/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Renders Found and Expected values as display text for the card chips.
 *
 * Three things decide the wording, in order. A format the Rule names (Currency,
 * Number, Percent, …) always wins. Otherwise, on "Auto", a queried field whose
 * Setup definition has a display shape of its own decides — a Currency field
 * reads as money. Failing both, the value is humanized from its Apex type, the
 * long-standing behavior.
 *
 * Formatting is display only: RecordHealthCheckComparisonEngine decides pass
 * and fail from the raw typed values, never from these strings. When a named
 * format cannot apply to a value — Currency on an Id, Number on free text — the
 * value is returned with its original spelling rather than raising an error, so
 * a display choice can never turn a passing check into an error.
 *
 * Callers reach this class through RecordHealthCheckComparisonEngine.formatValue
 * and its sibling describe methods; those stay the public entry points.
 */
public with sharing class RecordHealthCheckDisplayFormat {
  // ─── Format API names (Record_Health_Check_Rule__mdt.DisplayValueFormat__c) ──

  public static final String FORMAT_AUTO = 'AUTO';
  public static final String FORMAT_NUMBER = 'NUMBER';
  public static final String FORMAT_CURRENCY = 'CURRENCY';
  public static final String FORMAT_PERCENT = 'PERCENT';
  public static final String FORMAT_BOOLEAN = 'BOOLEAN';
  public static final String FORMAT_DATE = 'DATE';
  public static final String FORMAT_DATETIME = 'DATETIME';
  public static final String FORMAT_TEXT = 'TEXT';
  public static final String FORMAT_RAW = 'RAW';

  /**
   * Every format the Rule field accepts. A value outside this set is treated as
   * "Auto" so a future picklist entry falls back to today's behavior instead of
   * breaking a card. The restricted picklist blocks unknown values at deploy
   * time; this set is the runtime backstop.
   */
  private static final Set<String> KNOWN_FORMATS = new Set<String>{
    FORMAT_AUTO,
    FORMAT_NUMBER,
    FORMAT_CURRENCY,
    FORMAT_PERCENT,
    FORMAT_BOOLEAN,
    FORMAT_DATE,
    FORMAT_DATETIME,
    FORMAT_TEXT,
    FORMAT_RAW
  };

  public static final String BLANK_TEXT = '(blank)';

  // ─── Value shapes ─────────────────────────────────────────────────────────

  // A plain integer or decimal, optionally signed. Anything else — grouped text,
  // a currency string, a percent string, an Id — is left alone.
  private static final Pattern NUMERIC_PATTERN = Pattern.compile(
    '^-?\\d+(\\.\\d+)?$'
  );

  // ISO date (YYYY-MM-DD) and datetime (date + space/T + HH:MM:SS). Trailing
  // fractional seconds and zone offsets are tolerated but ignored; the captured
  // groups feed Date/Datetime.newInstance so parsing never depends on locale.
  private static final Pattern DATE_PATTERN = Pattern.compile(
    '^(\\d{4})-(\\d{2})-(\\d{2})$'
  );
  private static final Pattern DATETIME_PATTERN = Pattern.compile(
    '^(\\d{4})-(\\d{2})-(\\d{2})[ T](\\d{2}):(\\d{2}):(\\d{2}).*$'
  );

  // ─── Currency reference data ──────────────────────────────────────────────

  // Symbols for the currencies most likely to appear on a card. A code that is
  // not listed renders in ISO style ("SAR 70,000.00"), which is unambiguous and
  // needs no symbol table entry.
  private static final Map<String, String> CURRENCY_SYMBOLS = new Map<String, String>{
    'USD' => '$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    'CNY' => '¥',
    'INR' => '₹',
    'AUD' => 'A$',
    'CAD' => 'C$',
    'NZD' => 'NZ$',
    'SGD' => 'S$',
    'HKD' => 'HK$',
    'BRL' => 'R$',
    'MXN' => 'MX$',
    'KRW' => '₩',
    'RUB' => '₽',
    'TRY' => '₺',
    'ILS' => '₪',
    'PHP' => '₱',
    'THB' => '฿',
    'VND' => '₫',
    'NGN' => '₦',
    'PLN' => 'zł',
    'ZAR' => 'R'
  };

  // Currencies with no minor unit — an amount in these is shown without decimal
  // places. Everything else uses two, the ISO 4217 default.
  private static final Set<String> ZERO_DECIMAL_CURRENCIES = new Set<String>{
    'BIF',
    'CLP',
    'DJF',
    'GNF',
    'ISK',
    'JPY',
    'KMF',
    'KRW',
    'PYG',
    'RWF',
    'UGX',
    'VND',
    'VUV',
    'XAF',
    'XOF',
    'XPF'
  };

  // ─── Entry point ──────────────────────────────────────────────────────────

  /**
   * Renders one value using the Rule's chosen format, in the running user's
   * currency when the format is Currency.
   */
  public static String render(Object value, String format) {
    return render(value, format, null);
  }

  /**
   * Renders one value using the Rule's chosen format. A null or whitespace-only
   * value always reads "(blank)", including under Raw, so an empty chip is never
   * silently blank on the card.
   *
   * `isoCode` names the currency an amount belongs to, for a Currency Rule in a
   * multi-currency org. Leave it blank to use the running user's currency; it is
   * ignored by every other format.
   */
  public static String render(Object value, String format, String isoCode) {
    if (value == null) {
      return BLANK_TEXT;
    }

    String chosen = resolveFormat(format);

    if (chosen == FORMAT_RAW || chosen == FORMAT_TEXT) {
      return unchanged(value);
    }
    if (chosen == FORMAT_NUMBER) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount);
    }
    if (chosen == FORMAT_CURRENCY) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null
        ? unchanged(value)
        : renderCurrency(amount, resolveIsoCode(isoCode));
    }
    if (chosen == FORMAT_PERCENT) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount) + '%';
    }
    if (chosen == FORMAT_BOOLEAN) {
      String asBoolean = renderBoolean(value);
      return asBoolean == null ? unchanged(value) : asBoolean;
    }
    if (chosen == FORMAT_DATE) {
      String asDate = renderDate(value);
      return asDate == null ? unchanged(value) : asDate;
    }
    if (chosen == FORMAT_DATETIME) {
      String asDatetime = renderDatetime(value);
      return asDatetime == null ? unchanged(value) : asDatetime;
    }

    // FORMAT_AUTO, and anything resolveFormat sent here in its place.
    return renderAuto(value);
  }

  /** Blank Display: Value Format, or a value this release does not know, is "Auto". */
  private static String resolveFormat(String format) {
    if (String.isBlank(format)) {
      return FORMAT_AUTO;
    }
    String trimmed = format.trim().toUpperCase();
    return KNOWN_FORMATS.contains(trimmed) ? trimmed : FORMAT_AUTO;
  }

  /**
   * The value with its original spelling, used both for Text and Raw and as the
   * landing place when a named format does not fit the value. Whitespace-only
   * text still reads "(blank)".
   */
  private static String unchanged(Object value) {
    String s = String.valueOf(value);
    return (s == null || s.trim() == '') ? BLANK_TEXT : s;
  }

  // ─── Auto ─────────────────────────────────────────────────────────────────

  /**
   * Humanizes from the Apex type the value still carries. Typed values are
   * converted before String.valueOf flattens them. Boolean and ISO temporal text
   * is recognized by shape; a digit-only string is left alone because it may be a
   * postal code, a year, or an Id whose leading zeroes matter.
   */
  private static String renderAuto(Object value) {
    if (value instanceof Boolean) {
      return ((Boolean) value) ? 'Yes' : 'No';
    }
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      // .format() honors the running user's locale and time zone; String.valueOf
      // would return a raw GMT "2026-07-04 17:30:00".
      return ((Datetime) value).format();
    }
    if (isNumeric(value)) {
      return renderNumber(Decimal.valueOf(String.valueOf(value)));
    }

    String s = String.valueOf(value);
    if (s == null || s.trim() == '') {
      return BLANK_TEXT;
    }

    String asBoolean = renderBooleanText(s);
    if (asBoolean != null) {
      return asBoolean;
    }
    String asDateOrTime = renderDateOrTimeText(s);
    if (asDateOrTime != null) {
      return asDateOrTime;
    }
    String asMultiSelect = renderMultiSelect(s);
    return asMultiSelect == null ? s : asMultiSelect;
  }

  // ─── Numbers ──────────────────────────────────────────────────────────────

  /**
   * Groups a number for the running user's locale and drops a fractional part
   * that is all zeros, so a Decimal "70000.0" reads "70,000" for an English (US)
   * user and "70.000" for a German one. A real fraction keeps its digits.
   */
  private static String renderNumber(Decimal amount) {
    return amount.setScale(decimalPlacesToShow(amount)).format();
  }

  /**
   * A number at a fixed number of decimal places, grouped for the running
   * user's locale — "70000" at two places reads "$70,000.00" rather than
   * "$70,000".
   *
   * Decimal.format() drops a fractional part that is all zeros, which is what
   * a plain number wants but not what money wants. So the integer part is
   * grouped through format() and the decimals are appended with whatever
   * decimal mark this locale uses.
   */
  private static String renderFixedScale(Decimal amount, Integer places) {
    Decimal rounded = amount.setScale(places, System.RoundingMode.HALF_UP);
    Boolean negative = rounded < 0;
    String plain = rounded.abs().toPlainString();

    Integer dot = plain.indexOf('.');
    String intDigits = dot < 0 ? plain : plain.substring(0, dot);
    String fracDigits = dot < 0 ? '' : plain.substring(dot + 1);

    String grouped = Decimal.valueOf(intDigits).format();
    String body = (places > 0 &&
      fracDigits != '')
      ? grouped + localeDecimalMark() + fracDigits
      : grouped;
    return negative ? '-' + body : body;
  }

  /**
   * The decimal mark this locale uses, read back from the platform rather than
   * assumed — a period for English (US), a comma for German (Germany).
   */
  private static String localeDecimalMark() {
    String sample = Decimal.valueOf('1.5').format();
    return sample.length() >= 2 ? sample.substring(1, 2) : '.';
  }

  /** Decimal places left once trailing zeros are dropped. */
  private static Integer decimalPlacesToShow(Decimal amount) {
    String plain = amount.toPlainString();
    Integer dot = plain.indexOf('.');
    if (dot < 0) {
      return 0;
    }
    return plain.substring(dot + 1).replaceFirst('0+$', '').length();
  }

  /**
   * The value as a Decimal when it is safe to render as a number, otherwise null
   * so the caller keeps the original spelling.
   *
   * A numeric Apex type always qualifies. Text qualifies only when it is a plain
   * signed integer or decimal without leading zeros — grouping "00123" would
   * drop the zeros and change what the value means, so those stay as written.
   */
  private static Decimal toDisplayDecimal(Object value) {
    if (isNumeric(value)) {
      return Decimal.valueOf(String.valueOf(value));
    }
    if (!(value instanceof String)) {
      return null;
    }
    String s = ((String) value).trim();
    if (!NUMERIC_PATTERN.matcher(s).matches()) {
      return null;
    }
    String digits = s.startsWith('-') ? s.substring(1) : s;
    Integer dot = digits.indexOf('.');
    String intPart = dot < 0 ? digits : digits.substring(0, dot);
    if (intPart.length() > 1 && intPart.startsWith('0')) {
      return null;
    }
    return Decimal.valueOf(s);
  }

  private static Boolean isNumeric(Object value) {
    return value instanceof Integer ||
      value instanceof Long ||
      value instanceof Decimal ||
      value instanceof Double;
  }

  // ─── Currency ─────────────────────────────────────────────────────────────

  /**
   * The format that suits a field, worked out from how the field is defined in
   * Setup. A Currency field reads as money and a Percent field gains a percent
   * sign without the author naming a format. Returns null for field types that
   * Auto already handles well, so the caller leaves the format alone.
   *
   * Only the field types with a display shape of their own are mapped here.
   * Numbers, text, checkboxes, dates, and date/times keep their long-standing
   * Auto wording, which already reads correctly from the Apex type.
   */
  public static String formatForField(Schema.DescribeFieldResult field) {
    if (field == null) {
      return null;
    }
    Schema.DisplayType fieldType = field.getType();
    if (fieldType == Schema.DisplayType.CURRENCY) {
      return FORMAT_CURRENCY;
    }
    if (fieldType == Schema.DisplayType.PERCENT) {
      return FORMAT_PERCENT;
    }
    return null;
  }

  /**
   * The format to write a queried value with: the one the author named, or when
   * they left Display: Value Format on Auto, the one the field's own definition
   * suggests. A Currency field therefore reads as money with no Rule change.
   *
   * An author who named a format always wins — the field definition only fills
   * in for Auto.
   */
  public static String formatForRow(
    String authorFormat,
    SObject row,
    String fieldPath
  ) {
    if (resolveFormat(authorFormat) != FORMAT_AUTO) {
      return authorFormat;
    }
    String fromField = formatForField(describeQueryField(row, fieldPath));
    return fromField == null ? authorFormat : fromField;
  }

  /**
   * The Setup definition of the field a query read, or null when there is none
   * to describe: an aggregate result has no single source field, and a field
   * path that does not resolve is left alone rather than guessed at.
   */
  private static Schema.DescribeFieldResult describeQueryField(
    SObject row,
    String fieldPath
  ) {
    if (
      row == null ||
      String.isBlank(fieldPath) ||
      row instanceof AggregateResult
    ) {
      return null;
    }
    SObject current = row;
    List<String> parts = fieldPath.trim().split('\\.');
    // Walk any relationship steps so "Account.AnnualRevenue" describes the field
    // on Account, not a same-named field on the row's own object.
    for (Integer i = 0; i < parts.size() - 1; i++) {
      try {
        current = current.getSObject(parts[i]);
      } catch (System.SObjectException ex) {
        return null;
      }
      if (current == null) {
        return null;
      }
    }
    Schema.SObjectField token = RecordHealthCheckDescribeCache.fieldMap(
        current.getSObjectType()
      )
      .get(parts[parts.size() - 1]);
    return RecordHealthCheckDescribeCache.describeField(token);
  }

  /**
   * The currency a row's amounts belong to, for an org with more than one
   * currency. Returns null in a single-currency org, and for rows that do not
   * carry CurrencyIsoCode — an aggregate result, or a query that did not select
   * it — so the caller falls back to the running user's currency.
   *
   * Reading the row rather than the running user keeps an amount in its own
   * currency: a card should not relabel an amount in euros as dollars because
   * the person looking at it works in dollars.
   */
  public static String currencyIsoCodeFrom(SObject row) {
    if (row == null || !isMultiCurrencyOrg()) {
      return null;
    }
    if (row instanceof AggregateResult) {
      // Salesforce converts an aggregate such as SUM(Amount) into the corporate
      // currency, so the label has to say corporate too. Falling back to the
      // running user's currency would put their code on someone else's number.
      return corporateCurrency();
    }
    try {
      Object iso = row.get('CurrencyIsoCode');
      return iso == null ? null : String.valueOf(iso);
    } catch (System.SObjectException ex) {
      // The row did not select CurrencyIsoCode, or has no such field.
      return null;
    }
  }

  /**
   * The org's corporate currency, read once per transaction. Null when the org
   * has a single currency, or when the corporate row cannot be read — the caller
   * then falls back to the running user's currency.
   */
  private static Boolean corporateCurrencyLoaded = false;
  private static String corporateCurrencyCode;

  private static String corporateCurrency() {
    if (corporateCurrencyLoaded) {
      return corporateCurrencyCode;
    }
    corporateCurrencyLoaded = true;
    if (!isMultiCurrencyOrg()) {
      return null;
    }
    try {
      // CurrencyType only exists in an org with more than one currency, so the
      // query is built at run time rather than compiled against the type.
      // code-analyzer-suppress-next-line ApexCRUDViolation: CurrencyType is org configuration read for display only.
      List<SObject> corporate = Database.query(
        'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1'
      );
      if (!corporate.isEmpty()) {
        corporateCurrencyCode = String.valueOf(corporate[0].get('IsoCode'));
      }
    } catch (Exception ex) {
      // No read access, or no corporate row — the user's currency still applies.
      corporateCurrencyCode = null;
    }
    return corporateCurrencyCode;
  }

  /**
   * The currency an amount should be shown in: the one the record carries when
   * the Rule supplied it, otherwise the running user's currency. In a
   * single-currency org the user's currency is the org currency.
   */
  private static String resolveIsoCode(String isoCode) {
    return String.isBlank(isoCode) ? UserInfo.getDefaultCurrency() : isoCode;
  }

  /**
   * Whether this org has more than one currency. Read once per transaction
   * because it cannot change while a card is running.
   */
  private static Boolean multiCurrency;

  private static Boolean isMultiCurrencyOrg() {
    if (multiCurrency == null) {
      multiCurrency = UserInfo.isMultiCurrencyOrganization();
    }
    return multiCurrency;
  }

  /**
   * Money in a named currency, using the minor units that currency actually
   * uses — two places for US dollars, none for yen. An amount with no currency
   * to show it in falls back to a plain number rather than guessing a symbol.
   *
   * In an org with more than one currency the ISO code leads ("USD 70,000.00"),
   * because a bare symbol cannot tell US, Australian, and Canadian dollars
   * apart on the same card. An org with a single currency has no such ambiguity,
   * so the symbol reads better there ("$70,000.00"). A currency with no symbol
   * on file always uses the ISO code.
   */
  public static String renderCurrency(Decimal amount, String isoCode) {
    if (amount == null) {
      return BLANK_TEXT;
    }
    String iso = isoCode;
    if (String.isBlank(iso)) {
      return renderNumber(amount);
    }
    iso = iso.trim().toUpperCase();

    Integer places = ZERO_DECIMAL_CURRENCIES.contains(iso) ? 0 : 2;
    String rendered = renderFixedScale(amount, places);

    String symbol = CURRENCY_SYMBOLS.get(iso);
    if (symbol == null || isMultiCurrencyOrg()) {
      return iso + ' ' + rendered;
    }
    // Keep the minus sign ahead of the symbol: "-$70,000.00".
    return rendered.startsWith('-')
      ? '-' + symbol + rendered.substring(1)
      : symbol + rendered;
  }

  // ─── Booleans ─────────────────────────────────────────────────────────────

  /** Yes/No for a Boolean or boolean-shaped text; null when neither. */
  private static String renderBoolean(Object value) {
    if (value instanceof Boolean) {
      return ((Boolean) value) ? 'Yes' : 'No';
    }
    return value instanceof String
      ? renderBooleanText((String) value)
      : renderBooleanText(String.valueOf(value));
  }

  private static String renderBooleanText(String raw) {
    String s = raw.trim();
    if (s.equalsIgnoreCase('true')) {
      return 'Yes';
    }
    if (s.equalsIgnoreCase('false')) {
      return 'No';
    }
    return null;
  }

  // ─── Dates and date/times ─────────────────────────────────────────────────

  /** Locale date for a Date, a Datetime, or ISO text; null when the value is neither. */
  private static String renderDate(Object value) {
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).date().format();
    }
    Date parsed = parseDate(String.valueOf(value));
    return parsed == null ? null : parsed.format();
  }

  /**
   * Locale date/time for a Datetime or ISO datetime text. A Date has no time of
   * day, so it renders as a locale date rather than inventing midnight.
   *
   * Date is tested first on purpose: Apex reports a Date as an instance of
   * Datetime, so checking Datetime first would send a Date down the date/time
   * path and shift it by the user's time-zone offset.
   */
  private static String renderDatetime(Object value) {
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).format();
    }
    String s = String.valueOf(value);
    Datetime parsed = parseDatetime(s);
    if (parsed != null) {
      return parsed.format();
    }
    Date asDate = parseDate(s);
    return asDate == null ? null : asDate.format();
  }

  /** ISO date or datetime text in the running user's locale; null for other text. */
  private static String renderDateOrTimeText(String raw) {
    Datetime asDatetime = parseDatetime(raw);
    if (asDatetime != null) {
      return asDatetime.format();
    }
    Date asDate = parseDate(raw);
    return asDate == null ? null : asDate.format();
  }

  // Callers reach these parsers only with a non-null string: render returns the
  // blank placeholder before any parsing, and String.valueOf of a non-null value is
  // never null.
  /**
   * Whether the parts of an ISO string name a real point in time.
   *
   * Date.newInstance and Datetime.newInstance roll out-of-range parts over
   * instead of rejecting them, so "2026-13-40" would quietly become 9 February
   * 2027 — a date the record never held. Checking the range first means text
   * that only looks like a date keeps its original spelling.
   */
  private static Boolean isRealDate(Integer year, Integer month, Integer day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    Date candidate = Date.newInstance(year, month, day);
    return candidate.year() == year &&
      candidate.month() == month &&
      candidate.day() == day;
  }

  private static Boolean isRealTime(
    Integer hour,
    Integer minute,
    Integer second
  ) {
    return hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59 &&
      second >= 0 &&
      second <= 59;
  }

  private static Datetime parseDatetime(String raw) {
    Matcher m = DATETIME_PATTERN.matcher(raw.trim());
    if (!m.matches()) {
      return null;
    }
    Integer year = Integer.valueOf(m.group(1));
    Integer month = Integer.valueOf(m.group(2));
    Integer day = Integer.valueOf(m.group(3));
    Integer hour = Integer.valueOf(m.group(4));
    Integer minute = Integer.valueOf(m.group(5));
    Integer second = Integer.valueOf(m.group(6));
    if (!isRealDate(year, month, day) || !isRealTime(hour, minute, second)) {
      return null;
    }
    return Datetime.newInstance(year, month, day, hour, minute, second);
  }

  private static Date parseDate(String raw) {
    String s = raw.trim();
    Matcher m = DATE_PATTERN.matcher(s);
    if (m.matches()) {
      Integer year = Integer.valueOf(m.group(1));
      Integer month = Integer.valueOf(m.group(2));
      Integer day = Integer.valueOf(m.group(3));
      return isRealDate(year, month, day)
        ? Date.newInstance(year, month, day)
        : null;
    }
    Datetime asDatetime = parseDatetime(s);
    return asDatetime == null ? null : asDatetime.date();
  }

  // ─── Multi-select picklists ───────────────────────────────────────────────

  /**
   * Semicolon-delimited multi-select text as a comma-separated list
   * ("Hot;Warm;Cold" → "Hot, Warm, Cold"). Null when there is no delimiter, so
   * single values fall through unchanged.
   */
  private static String renderMultiSelect(String raw) {
    if (!raw.contains(';')) {
      return null;
    }
    List<String> cleaned = new List<String>();
    for (String part : raw.split(';')) {
      String trimmed = part.trim();
      if (trimmed != '') {
        cleaned.add(trimmed);
      }
    }
    return cleaned.isEmpty() ? null : String.join(cleaned, ', ');
  }

  // ─── Found / Expected symmetry ────────────────────────────────────────────

  /**
   * Restores an Expected operand to a number when the Found value is numeric, so
   * both chips group the same way. Fixed Custom Metadata operands arrive as text;
   * without this an Expected "100000" would sit next to a Found "100,000".
   *
   * Only applies while the format is Auto. A named format already decides how
   * both sides render, and Raw and Text ask for the original spelling.
   */
  public static Object alignExpectedToFound(
    Object comparison,
    Object found,
    String format
  ) {
    if (resolveFormat(format) != FORMAT_AUTO) {
      return comparison;
    }
    if (!isNumeric(found) || !(comparison instanceof String)) {
      return comparison;
    }
    // toDisplayDecimal applies the same leading-zero guard the Number format
    // uses, so "00100" stays as written on both paths rather than becoming 100.
    Decimal aligned = toDisplayDecimal(comparison);
    return aligned == null ? comparison : (Object) aligned;
  }
}
