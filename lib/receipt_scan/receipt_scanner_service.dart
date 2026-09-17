import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../localization/app_language.dart';
import 'receipt_scan_result.dart';

/// Estrae testo da una foto di scontrino tramite OCR on-device (Google ML
/// Kit, nessuna chiamata di rete) e prova a riconoscerne importo, data ed
/// esercente con delle euristiche.
///
/// Il parsing è pensato per essere tollerante: uno scontrino può essere
/// lungo, sbiadito, o l'utente può averne fotografato solo una parte
/// (es. solo il fondo con il totale). Ogni campo viene cercato in modo
/// indipendente dagli altri: se uno manca, semplicemente resta `null`,
/// non blocca il riconoscimento degli altri.
///
/// Le euristiche coprono sia scontrini italiani sia americani: cambiano
/// l'ordine giorno/mese nelle date, il separatore decimale/migliaia negli
/// importi, e le parole chiave per individuare il totale.
class ReceiptScannerService {
  ReceiptScannerService._();

  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Analizza l'immagine allo [imagePath] e restituisce i dati estratti.
  static Future<ReceiptScanResult> scan(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final rawText = recognizedText.text;

    // Manteniamo l'ordine dall'alto verso il basso così come restituito
    // dall'OCR: è l'informazione più affidabile che abbiamo sulla
    // posizione del testo nello scontrino (es. l'esercente è in cima,
    // il totale in fondo).
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ReceiptScanResult(
      amount: _extractAmount(lines),
      date: _extractDate(lines),
      merchant: _extractMerchant(lines),
      rawText: rawText,
    );
  }

  static Future<void> dispose() => _recognizer.close();

  // ---------------------------------------------------------------------
  // Importo
  // ---------------------------------------------------------------------

  // Tre varianti, provate in ordine: migliaia USA (1,234.56), migliaia IT
  // (1.234,56), e formato semplice senza migliaia (12.99 o 12,99). Tenerle
  // separate evita di confondere una virgola delle migliaia con un
  // separatore decimale, o viceversa.
  static final RegExp _amountPattern = RegExp(
    r'\d{1,3}(?:,\d{3})+\.\d{2}'
    r'|\d{1,3}(?:\.\d{3})+,\d{2}'
    r'|\d+[.,]\d{2}',
  );

  static const List<String> _totalKeywords = [
    // Italiano
    'totale complessivo',
    'totale euro',
    'totale eur',
    'totale',
    'tot.',
    'tot ',
    'importo pagato',
    'importo',
    // Inglese (US)
    'grand total',
    'total due',
    'amount due',
    'balance due',
    'total',
  ];

  static double? _extractAmount(List<String> lines) {
    double? bestFromKeyword;
    double? largestOverall;

    for (final line in lines) {
      final lower = line.toLowerCase();
      final matches = _amountPattern.allMatches(line);

      for (final match in matches) {
        // Un numero seguito da '%' è quasi certamente un'aliquota
        // (IVA/tax), non un importo: lo scartiamo del tutto.
        final nextChar = match.end < line.length ? line[match.end] : '';
        if (nextChar == '%') continue;

        final value = _parseAmount(match.group(0)!);
        if (value == null) continue;

        if (largestOverall == null || value > largestOverall) {
          largestOverall = value;
        }

        final isTotalLine =
            _totalKeywords.any((keyword) => lower.contains(keyword));

        // Scartiamo righe che sembrano codici fiscali, numeri di
        // scontrino o percentuali IVA piuttosto che importi.
        final looksLikeNoise = lower.contains('iva %') ||
            lower.contains('n.') && !isTotalLine ||
            lower.contains('scontrino');

        if (isTotalLine && !looksLikeNoise) {
          // Tra più righe "totale" (capita con subtotali/resti),
          // teniamo l'importo più alto: il totale finale è quasi
          // sempre il valore più grande tra quelli etichettati.
          if (bestFromKeyword == null || value > bestFromKeyword) {
            bestFromKeyword = value;
          }
        }
      }
    }

    // Preferiamo un importo associato esplicitamente a una parola chiave
    // di totale; se non lo troviamo, ripieghiamo sul numero più grande
    // presente nel testo (euristica ragionevole: il totale è quasi
    // sempre l'importo maggiore su uno scontrino).
    return bestFromKeyword ?? largestOverall;
  }

  static double? _parseAmount(String rawMatch) {
    // Normalizza sia "1.234,56" (IT) sia "1,234.56" (USA) in "1234.56":
    // l'ultimo separatore presente è sempre quello decimale, l'altro
    // (se c'è) è il separatore delle migliaia e va rimosso.
    var normalized = rawMatch.replaceAll(' ', '');

    final lastComma = normalized.lastIndexOf(',');
    final lastDot = normalized.lastIndexOf('.');

    if (lastComma > lastDot) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma) {
      normalized = normalized.replaceAll(',', '');
    }

    return double.tryParse(normalized);
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  // Formato numerico: gg/mm/aaaa (IT) o mm/gg/aaaa (USA) — l'ordine si
  // decide in _extractDate in base alla lingua dell'app, con fallback
  // automatico se una delle due letture non è un mese/giorno valido.
  static final RegExp _numericDatePattern = RegExp(
    r'\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b',
  );

  // Formato con mese in lettere, comune sugli scontrini/ricevute USA:
  // "Sep 17, 2026", "September 17 2026".
  static final RegExp _monthNameDatePattern = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+'
    r'(\d{1,2}),?\s+(\d{4})\b',
    caseSensitive: false,
  );

  static const List<String> _monthAbbreviations = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  // Un match di data "generico" (usato da _extractMerchant per escludere
  // righe che sono chiaramente una data, indipendentemente dal formato).
  static bool _looksLikeDateLine(String line) {
    return _numericDatePattern.hasMatch(line) ||
        _monthNameDatePattern.hasMatch(line);
  }

  static DateTime? _extractDate(List<String> lines) {
    final now = DateTime.now();

    for (final line in lines) {
      final candidate = _parseMonthNameDate(line) ?? _parseNumericDate(line);
      if (candidate == null) continue;

      // Scartiamo date palesemente sbagliate (OCR che confonde un altro
      // numero con una data) o future: uno scontrino non può essere
      // datato nel futuro.
      final isTooOld = candidate.year < now.year - 5;
      final isFuture = candidate.isAfter(
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      if (!isTooOld && !isFuture) {
        return candidate;
      }
    }

    return null;
  }

  static DateTime? _parseMonthNameDate(String line) {
    final match = _monthNameDatePattern.firstMatch(line);
    if (match == null) return null;

    final monthAbbr = match.group(1)!.toLowerCase();
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    final month = _monthAbbreviations.indexOf(monthAbbr) + 1;

    if (day == null || year == null || month == 0) return null;
    if (day < 1 || day > 31) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseNumericDate(String line) {
    final match = _numericDatePattern.firstMatch(line);
    if (match == null) return null;

    final first = int.tryParse(match.group(1)!);
    final second = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);

    if (first == null || second == null || year == null) return null;
    if (year < 100) {
      year += year <= 79 ? 2000 : 1900;
    }

    // L'app usa mm/gg quando la lingua è inglese (convenzione USA), gg/mm
    // altrimenti. Se la lettura preferita non è un mese/giorno valido
    // (es. "17/09" letto come mm/gg darebbe mese 17), proviamo lo
    // scambio: capita spesso che un solo ordine sia effettivamente
    // valido, il che toglie l'ambiguità.
    final preferMonthFirst = AppLanguageController.instance.isEnglish;

    int? day;
    int? month;

    final primaryMonth = preferMonthFirst ? first : second;
    final primaryDay = preferMonthFirst ? second : first;

    if (primaryMonth >= 1 && primaryMonth <= 12 && primaryDay >= 1 && primaryDay <= 31) {
      month = primaryMonth;
      day = primaryDay;
    } else {
      final altMonth = preferMonthFirst ? second : first;
      final altDay = preferMonthFirst ? first : second;
      if (altMonth >= 1 && altMonth <= 12 && altDay >= 1 && altDay <= 31) {
        month = altMonth;
        day = altDay;
      }
    }

    if (day == null || month == null) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Esercente
  // ---------------------------------------------------------------------

  static final RegExp _merchantNoisePattern = RegExp(
    r'(p\.?\s*iva|partita iva|c\.?f\.?|codice fiscale|via\s|viale\s|corso\s|'
    r'piazza\s|cap\s|tel\.?|scontrino|ricevuta|'
    r'phone|receipt|invoice|street\s|avenue|blvd|suite\s|'
    r'\d{5,})',
    caseSensitive: false,
  );

  static String? _extractMerchant(List<String> lines) {
    // L'esercente è quasi sempre in una delle prime righe, in genere in
    // maiuscolo. Se l'utente ha fotografato solo il fondo dello
    // scontrino, queste righe non ci saranno: in quel caso restituiamo
    // semplicemente null, senza inventare nulla.
    for (final line in lines.take(5)) {
      if (line.length < 3) continue;
      if (_merchantNoisePattern.hasMatch(line)) continue;
      if (_looksLikeDateLine(line)) continue;
      if (_amountPattern.hasMatch(line)) continue;

      // Una riga plausibile per il nome dell'esercente: contiene
      // prevalentemente lettere.
      final letterCount = line.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length;
      if (letterCount < line.length * 0.5) continue;

      return line;
    }

    return null;
  }
}

