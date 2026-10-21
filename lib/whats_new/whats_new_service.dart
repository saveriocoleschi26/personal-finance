import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'whats_new_content.dart';
import 'whats_new_page.dart';

/// Mostra la schermata "Novità" una sola volta, la prima volta che l'app
/// viene aperta dopo un aggiornamento.
///
/// L'ultima versione vista è salvata in un piccolo file LOCALE e non nel
/// database: il database si sincronizza tra dispositivi con iCloud, ma la
/// versione dell'app è una cosa di ogni singolo dispositivo (ognuno si
/// aggiorna per conto suo).
class WhatsNewService {
  WhatsNewService._();

  static Future<File> _storageFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'last_seen_version.txt'));
  }

  static Future<String?> _readLastSeenVersion() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) return null;
      final text = (await file.readAsString()).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeLastSeenVersion(String version) async {
    try {
      final file = await _storageFile();
      await file.writeAsString(version, flush: true);
    } catch (_) {
      // Se non riesce a salvare, al peggio la schermata si rivede al
      // prossimo avvio: meglio che bloccare l'app.
    }
  }

  /// Da usare alla PRIMA installazione: la guida iniziale spiega già tutto,
  /// quindi segniamo la versione corrente come "già vista" senza mostrare
  /// le novità.
  static Future<void> markCurrentVersionSeen() async {
    try {
      final info = await PackageInfo.fromPlatform();
      await _writeLastSeenVersion(info.version);
    } catch (_) {}
  }

  /// Mostra le novità se la versione installata è diversa dall'ultima vista
  /// e ne esistono per questa versione.
  static Future<void> showIfNeeded(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final lastSeen = await _readLastSeenVersion();

      if (lastSeen == current) return;

      // Si segna come vista PRIMA di mostrarla: così non può ripresentarsi
      // all'infinito qualunque cosa succeda mentre è aperta.
      await _writeLastSeenVersion(current);

      final items = whatsNewByVersion[current];
      if (items == null || items.isEmpty) return;
      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => WhatsNewPage(
            version: current,
            items: items,
          ),
        ),
      );
    } catch (_) {
      // Le novità sono un extra: in caso di errore l'app prosegue normale.
    }
  }
}
