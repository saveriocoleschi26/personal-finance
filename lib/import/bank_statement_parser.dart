import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Tipo di documento importato: cambia come interpretare il segno degli
/// importi. Su un estratto carta di credito gli addebiti sono positivi
/// (sono spese) e gli storni/rimborsi sono negativi (sono "entrate" che
/// riducono il dovuto). Su un conto corrente è l'opposto: le entrate sono
/// positive, le uscite negative.
enum StatementDocumentType { creditCard, currentAccount }

/// Una riga individuata nell'estratto conto, prima che l'utente la
/// confermi. L'importo è sempre salvato come valore assoluto: il segno
/// letto sul documento originale resta in [statementAmountWasNegative],
/// così la schermata di revisione può ricalcolare entrata/uscita al volo
/// se l'utente cambia il tipo di documento.
class ImportedTransactionCandidate {
  DateTime date;
  String description;
  double amount;
  final bool statementAmountWasNegative;
  String category;
  bool looksLikeDuplicate;
  bool selected;

  ImportedTransactionCandidate({
    required this.date,
    required this.description,
    required this.amount,
    required this.statementAmountWasNegative,
    required this.category,
    this.looksLikeDuplicate = false,
    this.selected = true,
  });

  bool isIncomeFor(StatementDocumentType documentType) {
    return documentType == StatementDocumentType.creditCard
        ? statementAmountWasNegative
        : !statementAmountWasNegative;
  }
}

/// Parser generico per estratti conto PDF. Riconosce righe nella forma
/// "data [data] descrizione importo", lo schema più comune tra le banche
/// italiane, indipendentemente da come il testo viene spezzato in righe
/// dall'estrazione PDF (alcuni PDF restituiscono una riga di testo per
/// ogni riga di tabella, altri concatenano tutto: la scansione lavora
/// sul testo intero, non riga per riga, per reggere in entrambi i casi).
///
/// Limite onesto: non è un parser universale per qualunque formato di
/// estratto conto esistente. Copre lo schema "data, descrizione, importo"
/// (con eventuale seconda data e un'eventuale colonna di saldo finale che
/// viene ignorata). Un formato radicalmente diverso — ad esempio un PDF
/// scansionato/immagine anziché testo selezionabile — non verrà letto
/// correttamente.
class BankStatementParser {
  static final RegExp _datePattern = RegExp(
    r'\d{2}[\/\-.]\d{2}[\/\-.]\d{4}',
  );

  static final RegExp _rowPattern = RegExp(
    r'(\d{2}[\/\-.]\d{2}[\/\-.]\d{4})\s+'
    r'(?:(\d{2}[\/\-.]\d{2}[\/\-.]\d{4})\s+)?'
    r'(.+?)\s+'
    r'(-?\d{1,3}(?:\.\d{3})*,\d{2})\b',
  );

  // Una volta incontrata una riga che inizia con una di queste parole
  // (tipicamente un rigo di totale), la scansione si ferma: tutto quello
  // che segue è riepilogo/dettaglio secondario, non elenco movimenti, e
  // rischierebbe di essere letto come transazioni duplicate o inventate.
  static final RegExp _stopMarker = RegExp(
    r'^\s*(TOTALE|SALDO\s+(INIZIALE|FINALE)|RIEPILOGO\s+ACQUISTI)',
    caseSensitive: false,
    multiLine: true,
  );

  static Future<String> extractTextFromPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  static List<ImportedTransactionCandidate> parseText(
    String fullText,
    List<String> availableCategoryNames,
  ) {
    final stopMatch = _stopMarker.firstMatch(fullText);
    final searchableText = stopMatch != null
        ? fullText.substring(0, stopMatch.start)
        : fullText;

    final results = <ImportedTransactionCandidate>[];

    for (final match in _rowPattern.allMatches(searchableText)) {
      final dateText = match.group(1)!;
      final descriptionText = match.group(3)!.trim();
      final amountText = match.group(4)!;

      final date = _parseDate(dateText);
      if (date == null) continue;

      // Scarta descrizioni vuote o composte solo da altri numeri: di
      // solito significa che la riga intercettata non è un vero
      // movimento (es. intestazioni di colonna spezzate diversamente).
      if (descriptionText.isEmpty || _datePattern.hasMatch(descriptionText)) {
        continue;
      }

      final isNegative = amountText.trim().startsWith('-');
      final normalizedAmount = amountText
          .replaceAll('-', '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final amount = double.tryParse(normalizedAmount);
      if (amount == null || amount == 0) continue;

      results.add(
        ImportedTransactionCandidate(
          date: date,
          description: descriptionText,
          amount: amount,
          statementAmountWasNegative: isNegative,
          category: guessCategory(descriptionText, availableCategoryNames),
        ),
      );
    }

    return results;
  }

  static DateTime? _parseDate(String text) {
    final parts = text.split(RegExp(r'[\/\-.]'));
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    return DateTime(year, month, day, 12);
  }

  // Corrispondenza per parole chiave tra il testo del movimento e le
  // categorie predefinite dell'app. È un aiuto, non una scienza esatta:
  // l'utente rivede e corregge nella schermata di importazione prima di
  // confermare.
  static final List<MapEntry<String, List<String>>> _categoryKeywords = [
    MapEntry('Spesa alimentare', [
      'esselunga', 'coop', 'conad', 'carrefour', 'lidl', 'eurospin',
      'pam ', 'iper', 'supermerc', 'md discount', 'penny market',
      'famila', 'despar', 'crai',
    ]),
    MapEntry('Casa e bollette', [
      'enel energia', 'eni gas', 'a2a', 'hera', 'acea', 'iren',
      'tim ', 'vodafone', 'windtre', 'wind tre', 'fastweb', 'condominio',
      'affitto', 'iren luce', 'sorgenia',
    ]),
    MapEntry('Auto e trasporti', [
      'eni ', 'q8', 'ip carburanti', 'esso', 'agip', 'total erg',
      'aspit', 'autostrade', 'telepass', 'atac', 'gtt', 'trenitalia',
      'italo', 'parcheggio', 'parking', 'benzina', 'gasolio',
    ]),
    MapEntry('Ristoranti e bar', [
      'trattoria', 'ristorante', 'pizzeria', 'osteria', 'hostaria',
      'ostaria', 'gelateria', 'cocktail', 'bar ', 'pub ', 'bistrot',
      'braceria', 'sushi',
    ]),
    MapEntry('Shopping', [
      'zara', 'h&m', 'zalando', 'amazon', 'brandy melville', 'store',
      'boutique', 'outlet',
    ]),
    MapEntry('Salute e benessere', [
      'farmacia', 'parafarmacia', 'ottica', 'dentist', 'palestra',
      'fisioterap', 'medic',
    ]),
    MapEntry('Svago', [
      'cinema', 'teatro', 'concerto', 'ticketone', 'museo',
    ]),
    MapEntry('Abbonamenti', [
      'netflix', 'spotify', 'disney', 'prime video', 'icloud',
      'amazon prime', 'youtube premium', 'pagam. rateale',
      'pagamento rateale',
    ]),
    MapEntry('Viaggi', [
      'ryanair', 'easyjet', 'ita airways', 'booking.com', 'airbnb',
      'hotel', 'volo ', 'aeroporto',
    ]),
    MapEntry('Studio e formazione', [
      'universit', 'libreria', 'corso ', 'formazione',
    ]),
  ];

  static String guessCategory(
    String description,
    List<String> availableCategoryNames,
  ) {
    final normalized = description.toLowerCase();

    for (final entry in _categoryKeywords) {
      if (!availableCategoryNames.contains(entry.key)) continue;
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return availableCategoryNames.contains('Altro')
        ? 'Altro'
        : (availableCategoryNames.isNotEmpty
            ? availableCategoryNames.first
            : 'Altro');
  }
}
