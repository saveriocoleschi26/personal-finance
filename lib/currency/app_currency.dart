import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../localization/app_language.dart';

class AppCurrencyController extends ChangeNotifier {
  AppCurrencyController._();

  static final AppCurrencyController instance =
      AppCurrencyController._();

  static const String euro = 'EUR';
  static const String usDollar = 'USD';

  String _currencyCode = euro;

  String get currencyCode => _currencyCode;

  String get symbol => _currencyCode == usDollar ? r'$' : '€';

  String get inputPrefix => '$symbol ';

  String format(double value) {
    return formatAmount(
      value,
      currencyCode: _currencyCode,
      useDecimalComma: !AppLanguageController.instance.isEnglish,
    );
  }

  static String formatAmount(
    double value, {
    required String currencyCode,
    required bool useDecimalComma,
  }) {
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final thousandsSeparator = useDecimalComma ? '.' : ',';
    final decimalSeparator = useDecimalComma ? ',' : '.';
    final groupedIntegerPart = _groupThousands(
      parts[0],
      thousandsSeparator,
    );
    final localizedValue = '$groupedIntegerPart$decimalSeparator${parts[1]}';

    if (currencyCode == usDollar) {
      return value < 0
          ? '-\$$localizedValue'
          : '\$$localizedValue';
    }

    return value < 0
        ? '€ -$localizedValue'
        : '€ $localizedValue';
  }

  // Inserisce un separatore ogni tre cifre partendo da destra, es.
  // "1234567" con separatore "." diventa "1.234.567".
  static String _groupThousands(String digits, String separator) {
    final buffer = StringBuffer();
    final length = digits.length;

    for (var i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write(separator);
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  Future<void> load() async {
    final saved = await DatabaseService.instance.getSetting(
      'currency_code',
    );

    if (saved == euro || saved == usDollar) {
      _currencyCode = saved!;
    }
  }

  Future<void> setCurrencyCode(String value) async {
    if (value != euro && value != usDollar) return;
    if (_currencyCode == value) return;

    _currencyCode = value;
    notifyListeners();

    await DatabaseService.instance.setSetting(
      'currency_code',
      value,
    );
  }
}
