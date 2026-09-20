import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../localization/app_language.dart';

class AppCurrencyController extends ChangeNotifier {
  AppCurrencyController._();

  static final AppCurrencyController instance =
      AppCurrencyController._();

  static const String euro = 'EUR';
  static const String usDollar = 'USD';
  static const String britishPound = 'GBP';
  static const String swissFranc = 'CHF';
  static const String japaneseYen = 'JPY';
  static const String chineseYuan = 'CNY';
  static const String brazilianReal = 'BRL';
  static const String russianRuble = 'RUB';
  static const String canadianDollar = 'CAD';
  static const String australianDollar = 'AUD';
  static const String indianRupee = 'INR';

  static const List<String> supportedCurrencies = [
    euro,
    usDollar,
    britishPound,
    swissFranc,
    japaneseYen,
    chineseYuan,
    brazilianReal,
    russianRuble,
    canadianDollar,
    australianDollar,
    indianRupee,
  ];

  // Etichetta mostrata nel selettore valuta. Passa dal dizionario
  // centrale di app_language.dart (stessa logica del resto dell'app):
  // oggi è tradotta solo in inglese, le altre lingue mostrano
  // l'italiano finché non arrivano le traduzioni.
  static String displayLabel(String currencyCode) {
    return l(_italianLabels[currencyCode] ?? currencyCode);
  }

  static const Map<String, String> _italianLabels = {
    euro: 'Euro (€)',
    usDollar: r'Dollaro statunitense ($)',
    britishPound: 'Sterlina britannica (£)',
    swissFranc: 'Franco svizzero (CHF)',
    japaneseYen: 'Yen giapponese (¥)',
    chineseYuan: 'Yuan cinese (¥)',
    brazilianReal: r'Real brasiliano (R$)',
    russianRuble: 'Rublo russo (₽)',
    canadianDollar: r'Dollaro canadese (C$)',
    australianDollar: r'Dollaro australiano (A$)',
    indianRupee: 'Rupia indiana (₹)',
  };

  String _currencyCode = euro;

  String get currencyCode => _currencyCode;

  String get symbol => _formats[_currencyCode]?.symbol ?? _formats[euro]!.symbol;

  // Usato come prefisso nei campi di inserimento importo: per semplicità
  // e coerenza visiva mostriamo sempre il simbolo prima del numero anche
  // per le valute che nella formattazione finale lo mettono dopo
  // (es. franco svizzero, rublo).
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

    final format = _formats[currencyCode] ?? _formats[euro]!;
    final separator = format.spaced ? ' ' : '';
    final sign = value < 0 ? '-' : '';

    if (format.symbolAfter) {
      return '$sign$localizedValue$separator${format.symbol}';
    }

    if (format.signBeforeSymbol) {
      return '$sign${format.symbol}$separator$localizedValue';
    }

    // Solo l'euro segue questo stile (mantenuto identico a prima della
    // Fase 2): simbolo, spazio, poi il segno meno davanti al numero.
    return '${format.symbol}$separator$sign$localizedValue';
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

    if (saved != null && supportedCurrencies.contains(saved)) {
      _currencyCode = saved;
    }
  }

  Future<void> setCurrencyCode(String value) async {
    if (!supportedCurrencies.contains(value)) return;
    if (_currencyCode == value) return;

    _currencyCode = value;
    notifyListeners();

    await DatabaseService.instance.setSetting(
      'currency_code',
      value,
    );
  }
}

class _CurrencyFormat {
  final String symbol;
  final bool symbolAfter;
  final bool spaced;
  final bool signBeforeSymbol;

  const _CurrencyFormat(
    this.symbol, {
    this.symbolAfter = false,
    this.spaced = false,
    this.signBeforeSymbol = true,
  });
}

const Map<String, _CurrencyFormat> _formats = {
  AppCurrencyController.euro:
      _CurrencyFormat('€', spaced: true, signBeforeSymbol: false),
  AppCurrencyController.usDollar: _CurrencyFormat(r'$'),
  AppCurrencyController.britishPound: _CurrencyFormat('£'),
  AppCurrencyController.swissFranc:
      _CurrencyFormat('CHF', symbolAfter: true, spaced: true),
  AppCurrencyController.japaneseYen: _CurrencyFormat('¥'),
  AppCurrencyController.chineseYuan: _CurrencyFormat('¥'),
  AppCurrencyController.brazilianReal:
      _CurrencyFormat(r'R$', spaced: true),
  AppCurrencyController.russianRuble:
      _CurrencyFormat('₽', symbolAfter: true, spaced: true),
  AppCurrencyController.canadianDollar: _CurrencyFormat(r'C$'),
  AppCurrencyController.australianDollar: _CurrencyFormat(r'A$'),
  AppCurrencyController.indianRupee: _CurrencyFormat('₹'),
};
