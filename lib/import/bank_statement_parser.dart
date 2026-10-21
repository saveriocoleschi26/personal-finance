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

  /// Se valorizzato, il movimento non è una vera spesa/entrata (es. un
  /// giroconto tra propri conti o un acquisto/vendita di titoli) e per
  /// questo parte deselezionato. Valori: 'transfer', 'investment'.
  final String? skipReason;

  ImportedTransactionCandidate({
    required this.date,
    required this.description,
    required this.amount,
    required this.statementAmountWasNegative,
    required this.category,
    this.looksLikeDuplicate = false,
    this.selected = true,
    this.skipReason,
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
    String rawText,
    List<String> availableCategoryNames,
  ) {
    // L'estrazione PDF può usare a capo Windows (\r\n) o vecchio stile Mac
    // (\r): si riporta tutto a \n, altrimenti le espressioni regolari qui
    // sotto (che ragionano riga per riga) non riconoscono le date su righe
    // separate e saltano i movimenti con descrizione su più righe.
    final fullText = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
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

    // Schema "a record": ogni movimento inizia con la/le date a inizio riga e
    // arriva fino al movimento successivo, anche su più righe. Serve quando
    // la descrizione va a capo e l'importo finisce su una riga diversa da
    // quella della data (es. carta di credito ING: "Operazione presso ...
    // Importo in divisa" / "estera=... USD" / "-10,65"), caso in cui lo schema
    // riga-per-riga qui sopra perde quei movimenti. Si usa solo se trova più
    // movimenti dello schema principale.
    final recordResults =
        _parseMultilineRecords(afterHeader, availableCategoryNames);
    if (recordResults.length > results.length) {
      results
        ..clear()
        ..addAll(recordResults);
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

    // Terzo schema, ultimo ripiego: conti con data scritta a lettere
    // ("24 ago 2026") e colonne separate entrata/uscita invece di un
    // unico importo con segno (es. Trade Republic). Ha una logica
    // abbastanza diversa dagli altri due (serve il saldo progressivo per
    // dedurre il segno) da meritare un metodo a parte invece di
    // riusare _buildCandidate.
    if (results.isEmpty) {
      results.addAll(
        _parseTextDateWithRunningBalance(fullText, availableCategoryNames),
      );
    }

    return results;
  }

  // Inizio di un movimento: una data (più una seconda data facoltativa) a
  // inizio riga. \f, \r e \v sono ammessi prima della data perché alcune
  // estrazioni PDF separano le pagine con un carattere di nuova pagina.
  //
  // Due varianti, perché l'estrazione del testo dal PDF cambia da file a
  // file: (1) la/le date sulla stessa riga della descrizione, (2) le due
  // date ciascuna su una riga propria, con descrizione e importo nelle
  // righe successive (ordine "a colonne", tipico dei PDF con tabelle).
  // La seconda variante richiede DUE date di fila: una data da sola su
  // una riga (es. nell'intestazione) non basta a far partire un movimento.
  static final RegExp _recordStartPattern = RegExp(
    r'^[ \t\f\r\v]*(\d{2}[\/\-.]\d{2}[\/\-.]\d{4})'
    r'(?:[ \t]+(?:\d{2}[\/\-.]\d{2}[\/\-.]\d{4}[ \t]*)?'
    r'|[ \t]*\n\s*\d{2}[\/\-.]\d{2}[\/\-.]\d{4}\s+)',
    multiLine: true,
  );

  // Piè di pagina (codice documento, "Pag. 1/2", dati legali della banca):
  // finisce nel testo tra l'ultimo movimento di una pagina e il primo della
  // successiva e, senza questa pulizia, si attacca alla descrizione
  // dell'ultimo movimento o gli fa leggere un importo sbagliato (es. il
  // capitale sociale della banca). Si toglie dalla riga col numero di
  // pagina fino alla prossima riga che inizia con una data.
  static final RegExp _pageFooterPattern = RegExp(
    r'(?:^[ \t]*[A-Z0-9]+_[A-Z0-9_.]+[ \t]*\r?\n)?'
    r'^[^\n]*Pag\.\s*\d+\s*/\s*\d+[^\n]*(?:\r?\n|$)'
    r'(?:(?![ \t\f\r\v]*\d{2}[\/\-.]\d{2}[\/\-.]\d{4})'
    r'(?:[^\n]+(?:\r?\n|$)|\r?\n))*',
    multiLine: true,
  );

  // Importo a fine riga (con segno facoltativo, eventuale "EUR" o "€" dopo).
  // Il carattere prima non può essere '=', cifra, '.', ',' o '-': evita di
  // scambiare per importo "estera=11,88" o parti di numeri più lunghi.
  static final RegExp _trailingAmountPattern = RegExp(
    r'(?:^|[^=\d.,\-])(-?\d{1,3}(?:\.\d{3})*,\d{2})[ \t]*(?:€|EUR)?[ \t]*$',
    multiLine: true,
  );

  // Righe di totale/saldo finale, da ignorare nello schema a record così che
  // il loro importo non venga attribuito all'ultimo movimento.
  static final RegExp _summaryLinePattern = RegExp(
    r'^[ \t]*(TOTALE|SALDO\s+FINALE|RIEPILOGO\s+ACQUISTI).*$',
    caseSensitive: false,
    multiLine: true,
  );

  static final RegExp _pageNumberPattern = RegExp(r'Pag\.\s*\d+\s*/\s*\d+');

  static final RegExp _foreignCurrencyDetailPattern = RegExp(
    r'\s*Importo in divisa.*$',
    caseSensitive: false,
  );

  // Taglia il testo alla riga di totale/saldo finale che sta DOPO l'ultimo
  // movimento. Serve perché l'importo del totale può trovarsi su una riga
  // diversa dalla parola "Totale" (ordine "a colonne") e verrebbe letto
  // come importo dell'ultimo movimento. Un "Totale" in mezzo ai movimenti
  // (dopo il quale ne seguono altri) non taglia nulla.
  static String _cutAtTrailingSummary(String text) {
    final starts = _recordStartPattern.allMatches(text).toList();
    if (starts.isEmpty) return text;
    final lastStart = starts.last.start;
    for (final stop in _stopMarker.allMatches(text)) {
      if (stop.start > lastStart) return text.substring(0, stop.start);
    }
    return text;
  }

  static List<ImportedTransactionCandidate> _parseMultilineRecords(
    String text,
    List<String> availableCategoryNames,
  ) {
    final cleaned = _cutAtTrailingSummary(
      text.replaceAll(_pageFooterPattern, ''),
    ).replaceAll(_summaryLinePattern, '');
    final starts = _recordStartPattern.allMatches(cleaned).toList();
    final results = <ImportedTransactionCandidate>[];

    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end =
          i + 1 < starts.length ? starts[i + 1].start : cleaned.length;
      final body = cleaned.substring(start.end, end);

      Match? amountMatch;
      for (final m in _trailingAmountPattern.allMatches(body)) {
        amountMatch = m;
      }
      if (amountMatch == null) continue;

      final amountText = amountMatch.group(1)!;
      final amountStart =
          amountMatch.start + amountMatch.group(0)!.indexOf(amountText);
      final amountEnd = amountStart + amountText.length;

      var description = '${body.substring(0, amountStart)} '
          '${body.substring(amountEnd)}';
      description = description
          .replaceAll(_pageNumberPattern, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll(_foreignCurrencyDetailPattern, '')
          .trim();

      final candidate = _buildCandidate(
        dateText: start.group(1)!,
        descriptionText: description,
        amountText: amountText,
        availableCategoryNames: availableCategoryNames,
      );
      if (candidate != null) results.add(candidate);
    }

    return results;
  }

  // Abbreviazioni italiane dei mesi, come compaiono negli estratti conto
  // che scrivono la data a lettere invece che in cifre (es. "24 ago 2026").
  static const Map<String, int> _italianMonthAbbreviations = {
    'gen': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mag': 5, 'giu': 6,
    'lug': 7, 'ago': 8, 'set': 9, 'ott': 10, 'nov': 11, 'dic': 12,
  };

  // Riga di un estratto con data a lettere e due colonne separate
  // (entrata/uscita) invece di un unico importo con segno: "giorno mese
  // anno · tipo · descrizione · importo · saldo dopo il movimento". La
  // descrizione può andare a capo su più righe (es. il dettaglio di
  // un'operazione di borsa), quindi qui il punto deve poter attraversare
  // gli "a capo" (dotAll) — a differenza degli altri due schemi, dove
  // invece è la cosa che tiene la ricerca dentro i confini di una riga.
  static final RegExp _rowPatternTextDateWithBalance = RegExp(
    r'(\d{1,2})\s+([A-Za-zÀ-ÿ]{3})\.?\s+(\d{4})\s+(\S+)\s+(.+?)\s+'
    r'([\d.,]+)\s*€\s+(-?[\d.,]+)\s*€',
    dotAll: true,
  );

  static final RegExp _accountStatementStart = RegExp(
    r'TRANSAZIONI\s+SUL\s+CONTO',
    caseSensitive: false,
  );

  static final RegExp _accountStatementStop = RegExp(
    r'PANORAMICA\s+DEL\s+SALDO',
    caseSensitive: false,
  );

  static final RegExp _openingBalancePattern = RegExp(
    r'Conto\s+corrente\s+([\d.,]+)\s*€',
    caseSensitive: false,
  );

  // A differenza degli altri due schemi, qui l'importo di ogni riga non
  // porta con sé il segno: sappiamo solo "quanto" è cambiato il saldo,
  // non se è entrata o uscita. Lo deduciamo confrontando il saldo dopo
  // ogni movimento con quello del movimento precedente (o con il saldo
  // iniziale, per il primo): se sale è un'entrata, se scende è
  // un'uscita. Per questo serve un metodo a parte — richiede uno stato
  // (il saldo corrente) che passa da una riga alla successiva, cosa che
  // _buildCandidate non gestisce.
  static List<ImportedTransactionCandidate> _parseTextDateWithRunningBalance(
    String fullText,
    List<String> availableCategoryNames,
  ) {
    final openingMatch = _openingBalancePattern.firstMatch(fullText);
    final openingBalanceValue = openingMatch != null
        ? double.tryParse(
            openingMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
          )
        : null;
    if (openingBalanceValue == null) return const [];
    double runningBalance = openingBalanceValue;

    final startMatch = _accountStatementStart.firstMatch(fullText);
    final afterHeader =
        startMatch != null ? fullText.substring(startMatch.end) : fullText;
    final stopMatch = _accountStatementStop.firstMatch(afterHeader);
    final searchableText = stopMatch != null
        ? afterHeader.substring(0, stopMatch.start)
        : afterHeader;

    // Intestazione del documento (titolare, IBAN...): serve a riconoscere i
    // giroconti verso se stessi, il cui nome compare anche lì.
    final headerText = startMatch != null
        ? fullText.substring(0, startMatch.start).toLowerCase()
        : '';

    final results = <ImportedTransactionCandidate>[];

    for (final match
        in _rowPatternTextDateWithBalance.allMatches(searchableText)) {
      final day = int.tryParse(match.group(1)!);
      final monthAbbr = match.group(2)!.toLowerCase();
      final year = int.tryParse(match.group(3)!);
      final month = _italianMonthAbbreviations[monthAbbr];
      // Ripulisce la descrizione: quando ha attraversato un "a capo"
      // (dotAll), può contenere spazi/ritorni a capo multipli di fila.
      final descriptionText = _cleanAccountMovementDescription(
        match.group(5)!.trim().replaceAll(RegExp(r'\s+'), ' '),
      );
      final amountText = match.group(6)!;
      final newBalanceText = match.group(7)!;

      if (day == null || month == null || year == null) continue;
      if (descriptionText.isEmpty || _isOnlyADate(descriptionText)) continue;

      final amount = double.tryParse(
        amountText.replaceAll('.', '').replaceAll(',', '.'),
      );
      final newBalance = double.tryParse(
        newBalanceText.replaceAll('.', '').replaceAll(',', '.'),
      );
      if (amount == null || amount == 0 || newBalance == null) continue;

      final isIncome = newBalance > runningBalance;
      runningBalance = newBalance;

      final skipReason = _skipReasonFor(descriptionText, headerText);

      results.add(
        ImportedTransactionCandidate(
          date: DateTime(year, month, day, 12),
          description: descriptionText,
          amount: amount,
          statementAmountWasNegative: !isIncome,
          category: guessCategory(descriptionText, availableCategoryNames),
          selected: skipReason == null,
          skipReason: skipReason,
        ),
      );
    }

    return results;
  }

  // Ripulisce la descrizione di un movimento di conto: toglie il resto del
  // tipo ("con carta"), i dettagli del cambio valuta ("31,00 $, exchange
  // rate: ...") e l'IBAN tra parentesi, lasciando solo il nome utile.
  static String _cleanAccountMovementDescription(String description) {
    var text = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceFirst(
      RegExp(r'^con carta\s+', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(
      RegExp(r',\s*[\d.,]+\s*\S{1,3}\s*,\s*exchange rate:.*$',
          caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\s*\([A-Z]{2}\d{2}[A-Z0-9]{10,30}\)'),
      '',
    );
    text = text.trim();
    return text.isEmpty ? description.trim() : text;
  }

  // Riconosce i movimenti che non sono vere spese o entrate:
  // - 'investment': acquisto/vendita di titoli o piano di accumulo;
  // - 'transfer': bonifico da/verso un nome che compare anche
  //   nell'intestazione del documento, cioè un giroconto fra propri conti.
  static String? _skipReasonFor(String description, String headerText) {
    if (RegExp(r'\b(buy|sell)\s+trade\b|savings\s+plan',
            caseSensitive: false)
        .hasMatch(description)) {
      return 'investment';
    }
    final transfer = RegExp(
      r'transfer\s+(?:for|from)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(description);
    if (transfer != null && headerText.isNotEmpty) {
      final name = transfer.group(1)!.trim().toLowerCase();
      if (name.length >= 5 && headerText.contains(name)) return 'transfer';
    }
    return null;
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
  //
  // Le parole chiave vengono cercate solo all'INIZIO di una parola (vedi
  // guessCategory): così "esso" non scatta più dentro "Operazione presso".
  // L'ordine conta: vince la prima categoria che trova una corrispondenza.
  static final List<MapEntry<String, List<String>>> _categoryKeywords = [
    // Consegna cibo: va prima di "Auto e trasporti", che ha "uber".
    MapEntry('Ristoranti e bar', [
      'uber eat', 'ubereats', 'doordash', 'deliveroo', 'glovo', 'just eat',
      'justeat',
    ]),
    MapEntry('Spesa alimentare', [
      'esselunga', 'coop', 'conad', 'carrefour', 'lidl', 'eurospin',
      'pam ', 'iper', 'supermerc', 'md discount', 'penny market',
      'famila', 'despar', 'crai', 'aldi', 'tigros', 'bennet', 'naturasi',
      'trader joe', 'whole foods', 'safeway', 'costco', 'walmart', 'kroger',
      'ralphs', 'grocery', 'supermarket',
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
      'uber', 'ubr*', 'lyft', 'taxi', 'shuttle', 'flixbus', 'blablacar',
      'amtrak', 'shell ', 'chevron',
    ]),
    MapEntry('Ristoranti e bar', [
      'trattoria', 'ristorante', 'pizzeria', 'osteria', 'hostaria',
      'ostaria', 'gelateria', 'cocktail', 'bar ', 'pub ', 'bistrot',
      'braceria', 'sushi', 'restaurant', 'coffee', 'cafe', 'caffe',
      'pizza', 'grill', 'tavern', 'diner', 'burger', 'bbq', 'bakery',
      'panificio', 'breakfast', 'brewing', 'brewery', 'taproom', 'tst*',
      'mcdonald', 'starbucks', 'panda express', 'in-n-out', 'chipotle',
      'moondoggies', 'frog & peach', "finney's", 'bistro', 'kitchen',
    ]),
    MapEntry('Shopping', [
      'zara', 'h&m', 'zalando', 'amazon', 'brandy melville', 'store',
      'boutique', 'outlet', 'target', 'tillys', 'world market',
      'whiz kids', 'toys', 'ikea', 'decathlon', 'mediaworld', 'unieuro',
      'best buy', 'nike', 'adidas',
    ]),
    MapEntry('Salute e benessere', [
      'farmacia', 'parafarmacia', 'ottica', 'dentist', 'palestra',
      'fisioterap', 'medic', 'pharmacy', 'cvs', 'walgreens',
    ]),
    MapEntry('Svago', [
      'cinema', 'teatro', 'concerto', 'ticketone', 'museo', 'museum',
      'theater', 'theatre',
    ]),
    MapEntry('Abbonamenti', [
      'netflix', 'spotify', 'disney', 'prime video', 'icloud',
      'amazon prime', 'youtube premium', 'pagam. rateale',
      'pagamento rateale', 'anthropic', 'openai', 'chatgpt', 'google one',
      'dropbox', 'adobe',
    ]),
    MapEntry('Viaggi', [
      'ryanair', 'easyjet', 'ita airways', 'booking.com', 'airbnb',
      'hotel', 'volo ', 'aeroporto', 'airlines', 'delta air', 'lufthansa',
      'motel', 'expedia',
    ]),
    MapEntry('Studio e formazione', [
      'universit', 'libreria', 'corso ', 'formazione',
    ]),
  ];

  static String guessCategory(
    String description,
    List<String> availableCategoryNames,
  ) {
    final normalized =
        description.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    for (final entry in _categoryKeywords) {
      if (!availableCategoryNames.contains(entry.key)) continue;
      for (final keyword in entry.value) {
        // Corrispondenza solo a inizio parola: evita falsi positivi come
        // "esso" dentro "pre-sso" ("Operazione presso ...").
        final pattern = RegExp('(?<![a-z0-9])${RegExp.escape(keyword)}');
        if (pattern.hasMatch(normalized)) {
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
