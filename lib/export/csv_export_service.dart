import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../database/database_service.dart';

/// Esporta l'intero contenuto del database di Liblo in una serie di file
/// CSV (uno per tabella), pronti per essere condivisi o salvati dall'utente.
class CsvExportService {
  CsvExportService._();

  static final CsvExportService instance = CsvExportService._();

  /// Genera un file CSV per ciascuna tabella rilevante e restituisce la
  /// lista dei [File] creati in una cartella temporanea.
  Future<List<File>> exportAll() async {
    final db = await DatabaseService.instance.database;
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportDir = Directory('${dir.path}/liblo_export_$timestamp');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final files = <File>[];

    files.add(
      await _writeTable(
        exportDir,
        fileName: 'transazioni.csv',
        rows: await db.query('transactions', orderBy: 'date ASC'),
        columns: const [
          'id',
          'date',
          'description',
          'category',
          'is_income',
          'amount',
        ],
        headers: const [
          'ID',
          'Data',
          'Descrizione',
          'Categoria',
          'Entrata',
          'Importo',
        ],
      ),
    );

    files.add(
      await _writeTable(
        exportDir,
        fileName: 'categorie.csv',
        rows: await db.query('categories', orderBy: 'sort_order ASC'),
        columns: const ['id', 'name', 'icon_key', 'is_active'],
        headers: const ['ID', 'Nome', 'Icona', 'Attiva'],
      ),
    );

    files.add(
      await _writeTable(
        exportDir,
        fileName: 'spese_ricorrenti.csv',
        rows: await db.query('recurring_expenses', orderBy: 'name ASC'),
        columns: const [
          'id',
          'name',
          'amount',
          'category',
          'day_of_month',
          'start_month',
          'end_month',
          'is_active',
        ],
        headers: const [
          'ID',
          'Nome',
          'Importo',
          'Categoria',
          'Giorno del mese',
          'Mese di inizio',
          'Mese di fine',
          'Attiva',
        ],
      ),
    );

    files.add(
      await _writeTable(
        exportDir,
        fileName: 'spese_pianificate.csv',
        rows: await db.query('planned_expenses', orderBy: 'due_date ASC'),
        columns: const [
          'id',
          'name',
          'amount',
          'category',
          'due_date',
          'is_paid',
        ],
        headers: const [
          'ID',
          'Nome',
          'Importo',
          'Categoria',
          'Scadenza',
          'Pagata',
        ],
      ),
    );

    files.add(
      await _writeTable(
        exportDir,
        fileName: 'spese_annuali.csv',
        rows: await db.query('annual_expenses', orderBy: 'due_date ASC'),
        columns: const [
          'id',
          'name',
          'amount',
          'category',
          'due_date',
          'saving_start_date',
          'is_paid',
        ],
        headers: const [
          'ID',
          'Nome',
          'Importo',
          'Categoria',
          'Scadenza',
          'Inizio accantonamento',
          'Pagata',
        ],
      ),
    );

    return files;
  }

  Future<File> _writeTable(
    Directory dir, {
    required String fileName,
    required List<Map<String, Object?>> rows,
    required List<String> columns,
    required List<String> headers,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsvField).join(','));

    for (final row in rows) {
      final values = columns.map((column) {
        final value = row[column];
        return _formatValue(column, value);
      });
      buffer.writeln(values.map(_escapeCsvField).join(','));
    }

    final file = File('${dir.path}/$fileName');
    // BOM UTF-8 iniziale: garantisce che Excel apra correttamente gli
    // accenti italiani senza bisogno di importazione manuale.
    await file.writeAsBytes([
      0xEF,
      0xBB,
      0xBF,
      ...buffer.toString().codeUnits,
    ]);
    return file;
  }

  String _formatValue(String column, Object? value) {
    if (value == null) return '';
    if (column == 'is_income' || column == 'is_active' || column == 'is_paid') {
      return (value == 1 || value == true) ? 'Sì' : 'No';
    }
    return value.toString();
  }

  String _escapeCsvField(String field) {
    final needsQuoting =
        field.contains(',') || field.contains('"') || field.contains('\n');
    if (!needsQuoting) return field;
    return '"${field.replaceAll('"', '""')}"';
  }
}
