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
    final localizedValue = useDecimalComma
        ? fixed.replaceAll('.', ',')
        : fixed;

    if (currencyCode == usDollar) {
      return value < 0
          ? '-\$$localizedValue'
          : '\$$localizedValue';
    }

    return value < 0
        ? '€ -$localizedValue'
        : '€ $localizedValue';
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
