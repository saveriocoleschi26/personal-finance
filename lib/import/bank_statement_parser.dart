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

  // Secondo schema, usato quando il primo non trova nulla: alcune banche
  // (es. i conti correnti in stile "Movimenti Globali" di RelaxBanking)
  // mettono l'importo PRIMA della descrizione, non dopo: "data valuta
  // data contabile importo causale descrizione". A volte l'importo
  // negativo è attaccato alla parola successiva senza spazio (es.
  // "-397,14Pagamento utilizzo carte"), quindi qui il separatore dopo
  // l'importo è facoltativo (\s*), non obbligatorio.
  static final RegExp _rowPatternAmountFirst = RegExp(
    r'(\d{2}[\/\-.]\d{2}[\/\-.]\d{4})\s+'
    r'(\d{2}[\/\-.]\d{2}[\/\-.]\d{4})\s+'
    r'(-?\d{1,3}(?:\.\d{3})*,\d{2})\s*'
    r'([^\n]+)',
  );

  // Marcatore di inizio della tabella movimenti vera e propria. Prima di
  // questo punto c'è solo intestazione (titolare, plafond, totale spese
  // mensili, indirizzo...) che NON va scansionata: contiene campi tipo
  // "data + importo" che assomigliano a un movimento pur non essendolo
  // (es. "Data di addebito 10/09/2026" seguito da "Plafond concesso
  // 1.500,00" verrebbe letto come un movimento da 1.500€), e frasi come
  // "Totale spese mensili" che farebbero scattare troppo presto il
  // marcatore di fine qui sotto. Se non troviamo questa intestazione di
  // tabella (formato diverso da banca a banca), si ripiega sul testo
  // intero, per non perdere la capacità di leggere altri formati.
  static final RegExp _startMarker = RegExp(
    r'^\s*(RIEPILOGO\s+(OPERAZIONI|MOVIMENTI)|'
    r'(LISTA|ELENCO|DETTAGLIO)\s+MOVIMENTI)',
    caseSensitive: false,
    multiLine: true,
  );

  // Una volta incontrata, DOPO l'inizio della tabella, una riga che
  // inizia con una di queste parole (tipicamente un rigo di totale in
  // fondo al documento), la scansione si ferma: tutto quello che segue
  // è riepilogo/dettaglio secondario, non elenco movimenti, e
  // rischierebbe di essere letto come transazioni duplicate o inventate.
  //
  // "SALDO INIZIALE" è volutamente escluso da questo elenco: sugli
  // estratti conto italiani compare in testa al documento, prima della
  // lista movimenti, non in coda — usarlo come marcatore di stop
  // troncherebbe la scansione subito dopo l'intestazione, prima ancora
  // di arrivare ai movimenti veri.
  static final RegExp _stopMarker = RegExp(
    r'^\s*(TOTALE|SALDO\s+FINALE|RIEPILOGO\s+ACQUISTI)',
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
    final startMatch = _startMarker.firstMatch(fullText);
    final afterHeader =
        startMatch != null ? fullText.substring(startMatch.end) : fullText;

    final stopMatch = _stopMarker.firstMatch(afterHeader);
    final searchableText = stopMatch != null
        ? afterHeader.substring(0, stopMatch.start)
        : afterHeader;

    final results = <ImportedTransactionCandidate>[];

    for (final match in _rowPattern.allMatches(searchableText)) {
      final candidate = _buildCandidate(
        dateText: match.group(1)!,
        descriptionText: match.group(3)!.trim(),
        amountText: match.group(4)!,
        availableCategoryNames: availableCategoryNames,
      );
      if (candidate != null) results.add(candidate);
    }

    // Schema alternativo (importo prima della descrizione): si prova solo
    // se il primo non ha trovato nulla, per evitare di leggere due volte
    // lo stesso movimento su un documento che in teoria potrebbe
    // (raramente) far scattare entrambi gli schemi.
    if (results.isEmpty) {
      for (final match in _rowPatternAmountFirst.allMatches(searchableText)) {
        final candidate = _buildCandidate(
          dateText: match.group(1)!,
          descriptionText: match.group(4)!.trim(),
          amountText: match.group(3)!,
          availableCategoryNames: availableCategoryNames,
        );
        if (candidate != null) results.add(candidate);
      }
    }

    return results;
  }

  static ImportedTransactionCandidate? _buildCandidate({
    required String dateText,
    required String descriptionText,
    required String amountText,
    required List<String> availableCategoryNames,
  }) {
    final date = _parseDate(dateText);
    if (date == null) return null;

    // Scarta descrizioni vuote o composte ESCLUSIVAMENTE da una data: di
    // solito significa che la riga intercettata non è un vero movimento
    // (es. quando lo schema principale, pensato per "data descrizione
    // importo", finisce per leggere una seconda data di riga come se
    // fosse la descrizione). Il controllo richiede che la descrizione
    // combaci per intero con una data, non che la contenga soltanto: una
    // descrizione vera può benissimo menzionare una data al suo interno
    // (es. un riferimento tipo "INSTANT DEL 02/07/2026 ORE 08:14") senza
    // per questo essere scartata.
    if (descriptionText.isEmpty || _isOnlyADate(descriptionText)) {
      return null;
    }

    final isNegative = amountText.trim().startsWith('-');
    final normalizedAmount = amountText
        .replaceAll('-', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(normalizedAmount);
    if (amount == null || amount == 0) return null;

    return ImportedTransactionCandidate(
      date: date,
      description: descriptionText,
      amount: amount,
      statementAmountWasNegative: isNegative,
      category: guessCategory(descriptionText, availableCategoryNames),
    );
  }

  // Vero solo se l'intera stringa (spazi esclusi) è una singola data,
  // senza nient'altro intorno. Usato per scartare i pochi casi in cui lo
  // schema principale finisce per catturare una seconda data di riga
  // come se fosse la descrizione del movimento.
  static bool _isOnlyADate(String text) {
    final match = _datePattern.matchAsPrefix(text);
    return match != null && match.start == 0 && match.end == text.length;
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
