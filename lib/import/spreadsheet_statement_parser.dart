import 'dart:io';

import 'package:excel_plus/excel_plus.dart';

import 'bank_statement_parser.dart';

/// Legge movimenti da file CSV o Excel (XLS/XLSX) esportati direttamente
/// dalla banca — molto più affidabile del PDF, perché i dati arrivano già
/// divisi per colonna invece di dover essere indovinati dal testo.
///
/// A differenza di [BankStatementParser] (che lavora su testo libero e
/// prova più schemi in cascata), qui ogni formato è riconosciuto con
/// certezza dall'intestazione delle colonne o dal nome del foglio Excel —
/// non c'è ambiguità da risolvere, e se il formato non combacia con
/// nessuno di quelli noti [parseFile] restituisce `null` invece di
/// inventare una lettura sbagliata.
///
/// Stato di verifica per banca (utile saperlo prima di fidarsi ciecamente
/// di un import):
/// - Poste Italiane / BancoPosta (CSV): formato verificato contro dati di
///   esempio reali del progetto open source da cui è stato preso.
/// - Revolut (CSV): formato confermato da più fonti indipendenti, logica
///   testata contro dati di esempio realistici, ma non ancora contro un
///   file vero — se il tuo Revolut è in italiano l'intestazione potrebbe
///   essere diversa da quella inglese qui riconosciuta.
/// - Fineco e Intesa Sanpaolo (XLS/XLSX): scritti leggendo il codice
///   sorgente verificato dei rispettivi progetti open source, ma non
///   ancora testati contro un file vero — la prima volta che arriva un
///   export reale di queste due banche va controllato con attenzione.
class SpreadsheetStatementParser {
  SpreadsheetStatementParser._();

  static Future<List<ImportedTransactionCandidate>?> parseFile(
    String filePath,
    List<String> availableCategoryNames,
  ) async {
    final extension = filePath.split('.').last.toLowerCase();

    if (extension == 'csv') {
      final content = await File(filePath).readAsString();
      return _parseBancoPostaCsv(content, availableCategoryNames) ??
          _parseRevolutCsv(content, availableCategoryNames);
    }

    if (extension == 'xls' || extension == 'xlsx') {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      return _parseFinecoExcel(excel, availableCategoryNames) ??
          _parseIntesaExcel(excel, availableCategoryNames);
    }

    return null;
  }

  // ---------------------------------------------------------------------
  // Poste Italiane / BancoPosta — export CSV
  // ---------------------------------------------------------------------
  // Formato verificato: separatore punto e virgola, intestazione
  // "Data;Valuta;Addebiti;Accrediti;Descrizione operazioni". Le righe di
  // saldo iniziale/finale hanno la colonna Valuta vuota e vanno scartate
  // (stesso principio già usato per i marcatori di stop nei PDF).

  static List<ImportedTransactionCandidate>? _parseBancoPostaCsv(
    String content,
    List<String> availableCategoryNames,
  ) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final header = lines.first.split(';').map((h) => h.trim()).toList();
    final dataIdx = header.indexOf('Data');
    final valutaIdx = header.indexOf('Valuta');
    final addebitiIdx = header.indexOf('Addebiti');
    final accreditiIdx = header.indexOf('Accrediti');
    final descIdx = header.indexOf('Descrizione operazioni');

    if (dataIdx == -1 ||
        valutaIdx == -1 ||
        addebitiIdx == -1 ||
        accreditiIdx == -1 ||
        descIdx == -1) {
      return null;
    }

    final results = <ImportedTransactionCandidate>[];
    for (final line in lines.skip(1)) {
      final fields = line.split(';');
      if (fields.length <= descIdx) continue;

      final valutaText = fields[valutaIdx].trim();
      if (valutaText.isEmpty) continue; // riga di saldo iniziale/finale

      final date = _parseItalianDate(fields[dataIdx].trim());
      if (date == null) continue;

      final addebito = _parseItalianAmount(fields[addebitiIdx]);
      final accredito = _parseItalianAmount(fields[accreditiIdx]);
      final amount = accredito ?? addebito;
      if (amount == null || amount == 0) continue;

      // Alcuni export includono un carattere "|" come artefatto di
      // formattazione accanto a Accrediti/Descrizione: non fa parte del
      // testo vero e va tolto.
      final description = fields[descIdx].replaceAll('|', '').trim();
      if (description.isEmpty) continue;

      results.add(ImportedTransactionCandidate(
        date: date,
        description: description,
        amount: amount,
        statementAmountWasNegative: accredito == null,
        category: BankStatementParser.guessCategory(
          description,
          availableCategoryNames,
        ),
      ));
    }
    return results;
  }

  // ---------------------------------------------------------------------
  // Revolut — export CSV
  // ---------------------------------------------------------------------
  // Formato verificato su più fonti indipendenti (non ho ancora un file
  // vero da testare): CSV separato da virgola, intestazione
  // "Type,Product,Started Date,Completed Date,Description,Amount,Fee,
  // Currency,State,Balance". A differenza delle banche italiane, l'importo
  // usa il punto come separatore decimale (formato internazionale), non
  // la virgola. Si tengono solo le righe con Stato "COMPLETED": quelle in
  // sospeso, rifiutate o revocate non sono movimenti reali e ancora
  // possono cambiare.
  //
  // Se il tuo Revolut è impostato in italiano e l'intestazione risulta
  // diversa da quella inglese, questo parser non troverà le colonne e
  // restituirà null: mandami un paio di righe del file vero (anche con
  // dati anonimizzati) e sistemo le intestazioni riconosciute.

  static List<ImportedTransactionCandidate>? _parseRevolutCsv(
    String content,
    List<String> availableCategoryNames,
  ) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final header = _parseCsvLine(lines.first)
        .map((h) => h.trim())
        .toList();
    final startedIdx = header.indexOf('Started Date');
    final completedIdx = header.indexOf('Completed Date');
    final descIdx = header.indexOf('Description');
    final amountIdx = header.indexOf('Amount');
    final stateIdx = header.indexOf('State');

    if (startedIdx == -1 || descIdx == -1 || amountIdx == -1) {
      return null; // non è un export Revolut in inglese
    }

    final results = <ImportedTransactionCandidate>[];
    for (final line in lines.skip(1)) {
      final fields = _parseCsvLine(line);
      if (fields.length <= amountIdx) continue;

      if (stateIdx != -1 &&
          fields.length > stateIdx &&
          fields[stateIdx].trim().toUpperCase() != 'COMPLETED') {
        continue;
      }

      final dateText = completedIdx != -1 && fields.length > completedIdx
          ? fields[completedIdx].trim()
          : fields[startedIdx].trim();
      final date = _parseIsoDate(dateText);
      if (date == null) continue;

      final amount = double.tryParse(fields[amountIdx].trim());
      if (amount == null || amount == 0) continue;

      final description = fields[descIdx].trim();
      if (description.isEmpty) continue;

      results.add(ImportedTransactionCandidate(
        date: date,
        description: description,
        amount: amount.abs(),
        statementAmountWasNegative: amount < 0,
        category: BankStatementParser.guessCategory(
          description,
          availableCategoryNames,
        ),
      ));
    }
    return results;
  }


  static const _finecoSavingsHeader = [
    'Data', 'Entrate', 'Uscite', 'Descrizione', 'Descrizione_Completa', 'Stato',
  ];
  static const _finecoCardsHeader = [
    'Intestatario carta', 'Numero carta', 'Data operazione',
    'Data registrazione', 'Descrizione', 'Stato operazione',
    'Tipo operazione', 'Circuito', 'Tipo rimborso', 'Importo',
  ];

  static List<ImportedTransactionCandidate>? _parseFinecoExcel(
    Excel excel,
    List<String> availableCategoryNames,
  ) {
    for (final sheetName in excel.tables.keys) {
      final rows = excel.tables[sheetName]?.rows;
      if (rows == null) continue;

      for (var i = 0; i < rows.length; i++) {
        final rowText = _rowAsText(rows[i]);
        if (_matchesHeader(rowText, _finecoSavingsHeader)) {
          return _readFinecoSavings(rows, i + 1, availableCategoryNames);
        }
        if (_matchesHeader(rowText, _finecoCardsHeader)) {
          return _readFinecoCards(rows, i + 1, availableCategoryNames);
        }
      }
    }
    return null;
  }

  static List<ImportedTransactionCandidate> _readFinecoSavings(
    List<List<Data?>> rows,
    int startRow,
    List<String> availableCategoryNames,
  ) {
    final results = <ImportedTransactionCandidate>[];
    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      final dateText = _cellText(row, 0);
      if (dateText == null || dateText.trim().isEmpty) break; // fine tabella
      if (dateText.trim().toLowerCase().startsWith('totale')) break;

      final date = _parseItalianDate(dateText) ?? _cellDate(row, 0);
      if (date == null) continue;

      final entrate = _parseItalianAmount(_cellText(row, 1) ?? '');
      final uscite = _parseItalianAmount(_cellText(row, 2) ?? '');
      final amount = entrate ?? uscite;
      if (amount == null || amount == 0) continue;

      final description = (_cellText(row, 4) ?? _cellText(row, 3) ?? '')
          .replaceAll('°', '.')
          .trim();
      if (description.isEmpty) continue;

      results.add(ImportedTransactionCandidate(
        date: date,
        description: description,
        amount: amount,
        statementAmountWasNegative: entrate == null,
        category: BankStatementParser.guessCategory(
          description,
          availableCategoryNames,
        ),
      ));
    }
    return results;
  }

  static List<ImportedTransactionCandidate> _readFinecoCards(
    List<List<Data?>> rows,
    int startRow,
    List<String> availableCategoryNames,
  ) {
    final results = <ImportedTransactionCandidate>[];
    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      final dateText = _cellText(row, 2); // Data operazione
      if (dateText == null || dateText.trim().isEmpty) break;

      final date = _parseItalianDate(dateText) ?? _cellDate(row, 2);
      if (date == null) continue;

      final amount = _parseItalianAmount(_cellText(row, 9) ?? '');
      if (amount == null || amount == 0) continue;

      final description =
          (_cellText(row, 4) ?? '').replaceAll('°', '.').trim();
      if (description.isEmpty) continue;

      results.add(ImportedTransactionCandidate(
        date: date,
        description: description,
        amount: amount.abs(),
        statementAmountWasNegative: amount < 0,
        category: BankStatementParser.guessCategory(
          description,
          availableCategoryNames,
        ),
      ));
    }
    return results;
  }

  // ---------------------------------------------------------------------
  // Intesa Sanpaolo — export Excel ("Lista Movimenti" o "Lista Operazione")
  // ---------------------------------------------------------------------

  static List<ImportedTransactionCandidate>? _parseIntesaExcel(
    Excel excel,
    List<String> availableCategoryNames,
  ) {
    for (final sheetName in excel.tables.keys) {
      final rows = excel.tables[sheetName]?.rows;
      if (rows == null) continue;

      for (var i = 0; i < rows.length; i++) {
        final firstCell = _cellText(rows[i], 0)?.trim();
        if (firstCell == 'Data Operazione' || firstCell == 'Data') {
          // "Lista Operazione" (V2): Data | Operazione | Dettagli |
          // Conto_Carta | Contabilizzazione | Categoria | Valuta | Importo
          return _readIntesaListaOperazione(
              rows, i + 1, availableCategoryNames);
        }
        if (firstCell == 'Data Contabile') {
          // "Lista Movimenti" (V1): Data Contabile | Data Valuta |
          // Descrizione | Accrediti | Addebiti | Descrizione estesa | Mezzo
          return _readIntesaListaMovimenti(
              rows, i + 1, availableCategoryNames);
        }
      }
    }
    return null;
  }

  static List<ImportedTransactionCandidate> _readIntesaListaMovimenti(
    List<List<Data?>> rows,
    int startRow,
    List<String> availableCategoryNames,
  ) {
    final results = <ImportedTransactionCandidate>[];
    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      final dateText = _cellText(row, 0);
      if (dateText == null || dateText.trim().isEmpty) break;

      final date = _parseItalianDate(dateText) ?? _cellDate(row, 0);
      if (date == null) continue;

      final descrizione = (_cellText(row, 2) ?? '').trim();
      final accrediti = _parseItalianAmount(_cellText(row, 3) ?? '');
      final addebiti = _parseItalianAmount(_cellText(row, 4) ?? '');
      final amount = accrediti ?? addebiti;
      if (amount == null || amount == 0) continue;

      final descrizioneEstesa = (_cellText(row, 5) ?? '').trim();
      final description = descrizioneEstesa.isNotEmpty
          ? '$descrizione — $descrizioneEstesa'
          : descrizione;
      if (description.isEmpty) continue;

      results.add(ImportedTransactionCandidate(
        date: date,
        description: description,
        amount: amount,
        statementAmountWasNegative: accrediti == null,
        category: BankStatementParser.guessCategory(
          description,
          availableCategoryNames,
        ),
      ));
    }
    return results;
  }

  static List<ImportedTransactionCandidate> _readIntesaListaOperazione(
    List<List<Data?>> rows,
    int startRow,
    List<String> availableCategoryNames,
  ) {
    final results = <ImportedTransactionCandidate>[];
    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      final dateText = _cellText(row, 0);
      if (dateText == null || dateText.trim().isEmpty) break;

      // "NON CONTABILIZZATO" (non ancora addebitato) va scartato: non è
      // ancora un movimento definitivo.
      final contabilizzazione = _cellText(row, 4)?.trim().toUpperCase();
      if (contabilizzazione == 'NON CONTABILIZZATO') continue;

      final date = _parseItalianDate(dateText) ?? _cellDate(row, 0);
      if (date == null) continue;

      final amount = _parseItalianAmount(_cellText(row, 7) ?? '');
      if (amount == null || amount == 0) continue;

      final operazione = (_cellText(row, 1) ?? '').trim();
      final dettagli = (_cellText(row, 2) ?? '').trim();
      final description = dettagli.isNotEmpty ? dettagli : operazione;
      if (description.isEmpty) continue;

      results.add(ImportedTransactionCandidate(
        date: date,
        description: description,
        amount: amount.abs(),
        statementAmountWasNegative: amount < 0,
        category: BankStatementParser.guessCategory(
          description,
          availableCategoryNames,
        ),
      ));
    }
    return results;
  }

  // ---------------------------------------------------------------------
  // Helper condivisi
  // ---------------------------------------------------------------------

  /// Divide una riga CSV rispettando i campi tra virgolette (che possono
  /// contenere la virgola separatore al loro interno, es. una descrizione
  /// tipo "Negozio, Srl"). A differenza di BancoPosta (punto e virgola,
  /// mai tra virgolette nei file visti finora), qui serve un parsing più
  /// attento perché il separatore è la virgola stessa.
  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var insideQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == ',' && !insideQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  /// Riconosce una data in formato ISO ("2026-08-14" o
  /// "2026-08-14 09:12:03"), come usata da Revolut.
  static DateTime? _parseIsoDate(String text) {
    final match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text.trim());
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static bool _matchesHeader(List<String?> rowText, List<String> expected) {
    if (rowText.isEmpty) return false;
    for (var i = 0; i < expected.length; i++) {
      final cell = i < rowText.length ? rowText[i]?.trim() : null;
      if (cell == null || cell.toLowerCase() != expected[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  static List<String?> _rowAsText(List<Data?> row) {
    return List.generate(row.length, (i) => _cellText(row, i));
  }

  /// Estrae il testo di una cella, qualunque sia il tipo di valore
  /// sottostante (testo, numero, data...).
  static String? _cellText(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    if (value == null) return null;
    return value.toString();
  }

  /// Prova a leggere una cella come data, per il caso in cui Excel la
  /// memorizzi come valore data/numero invece che come testo formattato
  /// (capita spesso con le colonne data nei file .xlsx/.xls).
  static DateTime? _cellDate(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }
    return null;
  }

  static DateTime? _parseItalianDate(String text) {
    final cleaned = text.trim();
    final match = RegExp(r'^(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})')
        .firstMatch(cleaned);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Converte un importo in formato italiano ("1.234,56") in double.
  /// Restituisce null per celle vuote — non zero, per poter distinguere
  /// "questa colonna non riguarda questo movimento" da "importo zero".
  static double? _parseItalianAmount(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}
