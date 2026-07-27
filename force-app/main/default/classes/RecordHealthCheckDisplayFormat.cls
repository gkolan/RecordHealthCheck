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
  public static final String FORMAT_RATIO_PERCENT = 'RATIO_PERCENT';
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
    FORMAT_RATIO_PERCENT,
    FORMAT_BOOLEAN,
    FORMAT_DATE,
    FORMAT_DATETIME,
    FORMAT_TEXT,
    FORMAT_RAW
  };

  public static final String BLANK_TEXT = '(blank)';

  private static final Integer MAX_DECIMAL_PLACES = 6;
  private static Boolean corporateCurrencyLoaded = false;
  private static String corporateCurrencyCode;
  private static Boolean multiCurrency;

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
    if (value instanceof DisplayLiteral) {
      return ((DisplayLiteral) value).text;
    }
    // Apex can lose generic-list type information after a value crosses an
    // Object boundary. Confirm its Apex shape, then cast without a JSON
    // round-trip so typed Date, Datetime, and Time entries keep their types.
    String apexShape = String.valueOf(value);
    if (apexShape.startsWith('[') || apexShape.startsWith('(')) {
      try {
        return RecordHealthCheckComparisonEngine.formatList(
          (List<Object>) value,
          format,
          isoCode
        );
      } catch (System.TypeException ignored) {
        // A strongly typed list that Apex will not widen is left unchanged.
        // Returning a misleading, timezone-shifted value would be worse than
        // preserving the plugin's original representation.
      }
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
    if (chosen == FORMAT_RATIO_PERCENT) {
      Decimal ratio = toDisplayDecimal(value);
      return ratio == null ? unchanged(value) : renderNumber(ratio * 100) + '%';
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

  /** True only for a canonical uppercase Display: Value Format API name. */
  public static Boolean isFormatApiName(String format) {
    return String.isNotBlank(format) && KNOWN_FORMATS.contains(format);
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
      return ((Boolean) value) ? System.Label.RHC_Yes : System.Label.RHC_No;
    }
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      // .format() honors the running user's locale and time zone; String.valueOf
      // would return a raw GMT "2026-07-04 17:30:00".
      return ((Datetime) value).format();
    }
    if (value instanceof Time) {
      return renderTime((Time) value);
    }
    if (isNumeric(value)) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount);
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
   * user and "70.000" for a German one. A real fraction keeps its digits, up to
   * the display cap.
   *
   * The digits are laid out by renderFixedScale rather than Decimal.format(),
   * which keeps only three decimal places: "1.12345" would read "1.123", losing
   * digits the record holds well inside the cap.
   */
  private static String renderNumber(Decimal amount) {
    return renderFixedScale(amount, decimalPlacesToShow(amount));
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

  /**
   * True when display text represents exactly one in the running user's
   * locale. This is used for grammar after a rendered count: the same text can
   * mean one in one locale and one thousand in another.
   */
  public static Boolean isDisplayedNumberOne(String raw) {
    if (String.isBlank(raw)) {
      return false;
    }

    String normalized = raw.trim();
    String groupingMarks = Decimal.valueOf('1000')
      .format()
      .replaceAll('[0-9]', '');
    if (groupingMarks != '') {
      normalized = normalized.replace(groupingMarks.substring(0, 1), '');
    }

    String decimalMark = localeDecimalMark();
    if (decimalMark != '.') {
      normalized = normalized.replace(decimalMark, '.');
    }
    try {
      return Decimal.valueOf(normalized) == 1;
    } catch (Exception ignored) {
      return false;
    }
  }

  /**
   * The most decimal places a chip shows. A Decimal field can hold far more
   * than a card row can carry, and a number that runs past the chip is harder
   * to read than a rounded one. Rounding here is display only: the comparison
   * has already been made on the full value.
   */
  /**
   * Decimal places left once trailing zeros are dropped, capped so a
   * high-scale number does not run off the chip.
   */
  private static Integer decimalPlacesToShow(Decimal amount) {
    String plain = amount.toPlainString();
    Integer dot = plain.indexOf('.');
    if (dot < 0) {
      return 0;
    }
    Integer places = plain.substring(dot + 1).replaceFirst('0+$', '').length();
    return places > MAX_DECIMAL_PLACES ? MAX_DECIMAL_PLACES : places;
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
      try {
        return Decimal.valueOf(String.valueOf(value));
      } catch (Exception ignored) {
        // A Double can carry a value Decimal cannot represent (for example a
        // non-finite value). Display formatting must never change check status.
        return null;
      }
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
    try {
      return Decimal.valueOf(s);
    } catch (Exception ignored) {
      return null;
    }
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
   * Replaces a stored picklist API value with the label visible to the running
   * user when Auto has the queried field definition available. Multi-select
   * values keep their stored order. Their labels are marked as final display
   * text so a semicolon that belongs to a translated label is not mistaken for
   * another stored-value delimiter.
   *
   * A named format, a non-picklist field, or a value absent from the field
   * definition keeps its original spelling. Comparison code continues to use
   * the untouched value; this method is only for the display copy.
   */
  public static Object valueForDisplay(
    Object value,
    String authorFormat,
    SObject row,
    String fieldPath
  ) {
    if (value == null || resolveFormat(authorFormat) != FORMAT_AUTO) {
      return value;
    }
    Schema.DescribeFieldResult field = describeQueryField(row, fieldPath);
    return valueForDisplay(value, field);
  }

  /** Display copy of a value using a field definition already read by the caller. */
  private static Object valueForDisplay(
    Object value,
    Schema.DescribeFieldResult field
  ) {
    if (field == null) {
      return value;
    }
    Schema.DisplayType fieldType = field.getType();
    if (
      fieldType != Schema.DisplayType.PICKLIST &&
      fieldType != Schema.DisplayType.MULTIPICKLIST
    ) {
      return value;
    }

    Map<String, String> labelsByValue = new Map<String, String>();
    for (Schema.PicklistEntry entry : field.getPicklistValues()) {
      labelsByValue.put(entry.getValue(), entry.getLabel());
    }

    String stored = String.valueOf(value);
    if (fieldType == Schema.DisplayType.PICKLIST) {
      return labelsByValue.containsKey(stored)
        ? labelsByValue.get(stored)
        : value;
    }

    List<String> labels = new List<String>();
    for (String part : stored.split(';')) {
      String apiValue = part.trim();
      if (apiValue == '') {
        continue;
      }
      labels.add(
        labelsByValue.containsKey(apiValue)
          ? labelsByValue.get(apiValue)
          : apiValue
      );
    }
    return labels.isEmpty()
      ? value
      : new DisplayLiteral(String.join(labels, ', '));
  }

  /** Text already prepared for display and therefore not subject to Auto sniffing. */
  private class DisplayLiteral {
    private String text;
    private DisplayLiteral(String value) {
      text = value;
    }
  }

  /** Display-only picklist labels for values and rows that run in parallel. */
  public static List<Object> valuesForDisplay(
    List<Object> values,
    String authorFormat,
    List<SObject> rows,
    String fieldPath
  ) {
    if (values == null) {
      return null;
    }
    Integer previewSize = Math.min(
      values.size(),
      RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP
    );
    Schema.DescribeFieldResult field;
    if (resolveFormat(authorFormat) == FORMAT_AUTO && rows != null) {
      for (Integer i = 0; i < previewSize && i < rows.size(); i++) {
        field = describeQueryField(rows[i], fieldPath);
        if (field != null) {
          break;
        }
      }
    }
    // Keep the full list so the renderer can report its true total, but prepare
    // only the entries it can display.
    List<Object> displayed = new List<Object>();
    displayed.addAll(values);
    for (Integer i = 0; i < previewSize; i++) {
      displayed.set(i, valueForDisplay(values[i], field));
    }
    return displayed;
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
   * currency. An aggregate row reports the corporate currency, because that is
   * what Salesforce converts aggregate amounts into. Returns null in a
   * single-currency org, and for a row that does not carry CurrencyIsoCode
   * because the query did not select it, so the caller falls back to the
   * running user's currency.
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
    Map<String, Object> populated = row.getPopulatedFieldsAsMap();
    if (!populated.containsKey('CurrencyIsoCode')) {
      // The row did not select CurrencyIsoCode, or its object has no such field.
      return null;
    }
    Object iso = populated.get('CurrencyIsoCode');
    return iso == null ? null : String.valueOf(iso);
  }

  /**
   * The currency for each row of a list, in row order, so a list of amounts in
   * different currencies is labelled entry by entry rather than all in the
   * first row's currency. Returns null when there are no rows to read, and a
   * list of nulls in a single-currency org, where every entry uses the running
   * user's currency.
   */
  public static List<String> currencyIsoCodesFor(
    List<SObject> rows,
    SObject record
  ) {
    return currencyIsoCodesFor(rows, record, null);
  }

  /** Currency for each row, resolved from the object owning the field path. */
  public static List<String> currencyIsoCodesFor(
    List<SObject> rows,
    SObject record,
    String fieldPath
  ) {
    if (rows == null) {
      return null;
    }
    List<String> isoCodes = new List<String>();
    Integer previewSize = Math.min(
      rows.size(),
      RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP
    );
    for (Integer i = 0; i < previewSize; i++) {
      isoCodes.add(currencyIsoCodeFor(rows[i], record, fieldPath));
    }
    return isoCodes;
  }

  /**
   * The currency for one side of a comparison: the queried row's own currency,
   * or the card record's currency when the query read that same record without
   * selecting CurrencyIsoCode. A query over a different object stays on the
   * running user's currency rather than borrowing an unrelated record's.
   */
  public static String currencyIsoCodeFor(SObject row, SObject record) {
    return currencyIsoCodeFor(row, record, null);
  }

  /**
   * Currency for a queried value. A relationship path reads the currency from
   * the related row that owns its terminal field, never from the outer row.
   */
  public static String currencyIsoCodeFor(
    SObject row,
    SObject record,
    String fieldPath
  ) {
    SObject valueRow = rowForFieldPath(row, fieldPath);
    String isoCode = currencyIsoCodeFrom(valueRow);
    if (
      String.isBlank(isoCode) &&
      valueRow != null &&
      record != null &&
      valueRow.getSObjectType() == record.getSObjectType()
    ) {
      isoCode = currencyIsoCodeFrom(record);
    }
    return isoCode;
  }

  /** Row that owns the terminal field; null when a relationship was not loaded. */
  private static SObject rowForFieldPath(SObject row, String fieldPath) {
    if (
      row == null ||
      String.isBlank(fieldPath) ||
      row instanceof AggregateResult
    ) {
      return row;
    }
    SObject current = row;
    List<String> parts = fieldPath.trim().split('\\.');
    for (Integer i = 0; i < parts.size() - 1; i++) {
      try {
        current = current.getSObject(parts[i]);
      } catch (System.SObjectException ignored) {
        return null;
      }
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  /**
   * The org's corporate currency, read once per transaction. Null when the org
   * has a single currency, or when the corporate row cannot be read — the caller
   * then falls back to the running user's currency.
   */
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
      List<SObject> corporate = Database.query(
        'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1',
        AccessLevel.USER_MODE
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
  private static String renderCurrency(Decimal amount, String isoCode) {
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
      return ((Boolean) value) ? System.Label.RHC_Yes : System.Label.RHC_No;
    }
    String raw = value instanceof String
      ? (String) value
      : String.valueOf(value);
    String normalized = raw.trim();
    if (normalized == '1') {
      return System.Label.RHC_Yes;
    }
    if (normalized == '0') {
      return System.Label.RHC_No;
    }
    return renderBooleanText(raw);
  }

  private static String renderBooleanText(String raw) {
    String s = raw.trim();
    if (s.equalsIgnoreCase('true')) {
      return System.Label.RHC_Yes;
    }
    if (s.equalsIgnoreCase('false')) {
      return System.Label.RHC_No;
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
    if (value instanceof Time) {
      // A Time field carries a time of day and no date.
      return renderTime((Time) value);
    }
    String s = String.valueOf(value);
    Datetime parsed = parseDatetime(s);
    if (parsed != null) {
      return parsed.format();
    }
    Date asDate = parseDate(s);
    return asDate == null ? null : asDate.format();
  }

  /**
   * A Time field as a 24-hour clock reading, `17:30` or `17:30:45` when there
   * are seconds. `String.valueOf` on a Time writes the storage form
   * `17:30:00.000Z`, which reads as machine output on a card.
   *
   * The clock is 24-hour for every locale. Apex can format a time of day only
   * as part of a date, and inventing a date to borrow its locale format would
   * shift the reading by the running user's time-zone offset.
   */
  private static String renderTime(Time value) {
    String reading = twoDigits(value.hour()) + ':' + twoDigits(value.minute());
    if (value.second() == 0 && value.millisecond() == 0) {
      return reading;
    }
    return reading + ':' + twoDigits(value.second());
  }

  private static String twoDigits(Integer part) {
    return part < 10 ? '0' + part : String.valueOf(part);
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
