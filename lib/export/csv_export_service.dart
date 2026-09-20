import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database_service.dart';

/// Esporta l'intero contenuto del database di Liblo in un unico file .zip
/// contenente un CSV per ciascuna tabella, pronto per essere condiviso o
/// salvato dall'utente.
class CsvExportService {
  CsvExportService._();

  static final CsvExportService instance = CsvExportService._();

  /// Genera i CSV di tutte le tabelle rilevanti, li comprime in un unico
  /// file .zip in una cartella temporanea e restituisce quel [File].
  Future<File> exportAll() async {
    final db = await DatabaseService.instance.database;

    final archive = Archive();

    void addCsv(String fileName, Uint8List bytes) {
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }

    addCsv(
      'transazioni.csv',
      _buildCsv(
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

    addCsv(
      'categorie.csv',
      _buildCsv(
        rows: await db.query('categories', orderBy: 'sort_order ASC'),
        columns: const ['id', 'name', 'icon_key', 'is_active'],
        headers: const ['ID', 'Nome', 'Icona', 'Attiva'],
      ),
    );

    addCsv(
      'spese_ricorrenti.csv',
      _buildCsv(
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

    addCsv(
      'spese_pianificate.csv',
      _buildCsv(
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

    addCsv(
      'spese_annuali.csv',
      _buildCsv(
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

    final zipBytes = ZipEncoder().encode(archive);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final zipFile = File('${dir.path}/Liblo-export-$stamp.zip');
    await zipFile.writeAsBytes(zipBytes, flush: true);

    return zipFile;
  }

  Uint8List _buildCsv({
    required List<Map<String, Object?>> rows,
    required List<String> columns,
    required List<String> headers,
  }) {
    // Punto e virgola come separatore: è il delimitatore CSV che Excel si
    // aspetta con le impostazioni regionali italiane (dove la virgola è
    // il separatore decimale), quindi apre le colonne correttamente senza
    // bisogno di un'importazione guidata manuale.
    const separator = ';';

    final buffer = StringBuffer();
    // Direttiva "sep=;" riconosciuta da Excel su qualunque lingua/sistema:
    // forza il separatore indicato indipendentemente dalle impostazioni
    // regionali di chi apre il file (utile anche per chi usa Excel in
    // inglese, dove il separatore atteso di default sarebbe la virgola).
    buffer.writeln('sep=$separator');
    buffer.writeln(headers.map(_escapeCsvField).join(separator));

    for (final row in rows) {
      final values = columns.map((column) {
        final value = row[column];
        return _formatValue(column, value);
      });
      buffer.writeln(values.map(_escapeCsvField).join(separator));
    }

    // BOM UTF-8 iniziale: garantisce che Excel apra correttamente gli
    // accenti italiani senza bisogno di importazione manuale.
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
  }

  String _formatValue(String column, Object? value) {
    if (value == null) return '';
    if (column == 'is_income' || column == 'is_active' || column == 'is_paid') {
      return (value == 1 || value == true) ? 'Sì' : 'No';
    }
    if (column == 'amount' && value is num) {
      // Virgola come separatore decimale, coerente con il separatore di
      // colonna ';' e con le impostazioni regionali italiane: così Excel
      // riconosce il valore come numero anziché come testo.
      return value.toStringAsFixed(2).replaceAll('.', ',');
    }
    return value.toString();
  }

  String _escapeCsvField(String field) {
    final needsQuoting = field.contains(';') ||
        field.contains(',') ||
        field.contains('"') ||
        field.contains('\n');
    if (!needsQuoting) return field;
    return '"${field.replaceAll('"', '""')}"';
  }
}

