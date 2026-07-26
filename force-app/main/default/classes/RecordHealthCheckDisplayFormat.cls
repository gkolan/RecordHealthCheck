/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Renders Found and Expected values as display text for the card chips.
 *
 * Two layers decide the wording. When a Rule leaves Display: Value Format on
 * "Auto", values are humanized from their Apex type — the long-standing
 * behavior. When a Rule names a format (Currency, Number, Percent, …), that
 * choice wins and the value is rendered that way instead.
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
   * "Auto" so a future picklist entry degrades to today's behavior instead of
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

  public static final String BLANK_SENTINEL = '(blank)';

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
   * Renders one value using the Rule's chosen format. A null or whitespace-only
   * value always reads "(blank)", including under Raw, so an empty chip is never
   * silently blank on the card.
   */
  public static String render(Object value, String format) {
    if (value == null) {
      return BLANK_SENTINEL;
    }

    String chosen = normalize(format);

    if (chosen == FORMAT_RAW || chosen == FORMAT_TEXT) {
      return unchanged(value);
    }
    if (chosen == FORMAT_NUMBER) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount);
    }
    if (chosen == FORMAT_CURRENCY) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderCurrency(amount);
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

    // FORMAT_AUTO, and anything normalize sent here in its place.
    return renderAuto(value);
  }

  /** Blank Display: Value Format, or a value this release does not know, is "Auto". */
  private static String normalize(String format) {
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
    return (s == null || s.trim() == '') ? BLANK_SENTINEL : s;
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
      return BLANK_SENTINEL;
    }

    String asBoolean = renderBooleanText(s);
    if (asBoolean != null) {
      return asBoolean;
    }
    String asTemporal = renderTemporalText(s);
    if (asTemporal != null) {
      return asTemporal;
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
    return amount.setScale(significantScale(amount)).format();
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
    String probe = Decimal.valueOf('1.5').format();
    return probe.length() >= 2 ? probe.substring(1, 2) : '.';
  }

  /** Decimal places left once trailing zeros are dropped. */
  private static Integer significantScale(Decimal amount) {
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
   * Money in the running user's currency, which in a single-currency org is the
   * org currency.
   */
  private static String renderCurrency(Decimal amount) {
    return renderCurrency(amount, UserInfo.getDefaultCurrency());
  }

  /**
   * Money in a named currency: the symbol when one is on file, otherwise the ISO
   * code, and the minor units that currency actually uses — two places for US
   * dollars, none for yen. An amount with no currency to render in falls back to
   * a plain number rather than guessing a symbol.
   *
   * The currency is a parameter rather than read inline so an amount can be
   * shown in the currency it belongs to. Every caller passes the running user's
   * currency today; a value that carries its own CurrencyIsoCode can pass that
   * instead without reworking the renderer.
   */
  public static String renderCurrency(Decimal amount, String isoCode) {
    if (amount == null) {
      return BLANK_SENTINEL;
    }
    String iso = isoCode;
    if (String.isBlank(iso)) {
      return renderNumber(amount);
    }
    iso = iso.trim().toUpperCase();

    Integer places = ZERO_DECIMAL_CURRENCIES.contains(iso) ? 0 : 2;
    String rendered = renderFixedScale(amount, places);

    String symbol = CURRENCY_SYMBOLS.get(iso);
    if (symbol == null) {
      // No symbol on file — ISO style reads unambiguously ("SAR 70,000.00").
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
  private static String renderTemporalText(String raw) {
    Datetime asDatetime = parseDatetime(raw);
    if (asDatetime != null) {
      return asDatetime.format();
    }
    Date asDate = parseDate(raw);
    return asDate == null ? null : asDate.format();
  }

  // Callers reach these parsers only with a non-null string: render returns the
  // blank sentinel before any parsing, and String.valueOf of a non-null value is
  // never null.
  private static Datetime parseDatetime(String raw) {
    Matcher m = DATETIME_PATTERN.matcher(raw.trim());
    if (!m.matches()) {
      return null;
    }
    return Datetime.newInstance(
      Integer.valueOf(m.group(1)),
      Integer.valueOf(m.group(2)),
      Integer.valueOf(m.group(3)),
      Integer.valueOf(m.group(4)),
      Integer.valueOf(m.group(5)),
      Integer.valueOf(m.group(6))
    );
  }

  private static Date parseDate(String raw) {
    String s = raw.trim();
    Matcher m = DATE_PATTERN.matcher(s);
    if (m.matches()) {
      return Date.newInstance(
        Integer.valueOf(m.group(1)),
        Integer.valueOf(m.group(2)),
        Integer.valueOf(m.group(3))
      );
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
    if (normalize(format) != FORMAT_AUTO) {
      return comparison;
    }
    if (!isNumeric(found) || !(comparison instanceof String)) {
      return comparison;
    }
    String s = ((String) comparison).trim();
    return NUMERIC_PATTERN.matcher(s).matches()
      ? (Object) Decimal.valueOf(s)
      : comparison;
  }
}
