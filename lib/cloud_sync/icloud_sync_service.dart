import 'dart:async';
import 'dart:io';

import 'package:icloud_storage/icloud_storage.dart';

/// Nome del file del database, condiviso con DatabaseService.
/// Tenuto qui (invece di importare database_service.dart) per evitare
/// un riferimento circolare tra i due file, dato che DatabaseService
/// chiama questo servizio dopo ogni scrittura.
const String _databaseFileName = 'personal_finance.db';

/// Gestisce la sincronizzazione del database locale (sqflite) con iCloud,
/// così da poter usare Liblo su più dispositivi Apple con gli stessi dati.
///
/// Approccio scelto: sincronizzazione dell'intero file del database,
/// non dei singoli movimenti. È la soluzione più semplice e adatta a un
/// uso personale su un dispositivo alla volta. Non gestisce conflitti in
/// caso di modifiche fatte su due dispositivi nello stesso momento, senza
/// che uno dei due abbia fatto in tempo a sincronizzarsi: in quel caso
/// vince l'ultima copia caricata.
class ICloudSyncService {
  ICloudSyncService._();

  static const String containerId = 'iCloud.com.saverio.Liblo';

  static bool get _isSupportedPlatform => Platform.isIOS || Platform.isMacOS;

  /// Da chiamare UNA SOLA VOLTA, all'avvio dell'app, PRIMA di aprire il
  /// database locale. Se su iCloud esiste una copia più recente di
  /// quella locale, la scarica e sostituisce il file locale.
  ///
  /// [localDbPath] è il percorso locale del file del database.
  ///
  /// Non lancia mai eccezioni: se qualcosa va storto (iCloud non
  /// disponibile, utente non loggato, nessuna connessione...) l'app deve
  /// comunque poter partire e funzionare normalmente in locale.
  static Future<void> downloadIfNewer(String localDbPath) async {
    if (!_isSupportedPlatform) return;

    try {
      final remoteFile = await _findRemoteDatabaseFile();
      if (remoteFile == null) return;

      final localFile = File(localDbPath);
      final localExists = await localFile.exists();
      final localModified =
          localExists ? await localFile.lastModified() : null;

      final remoteIsNewer = localModified == null ||
          remoteFile.contentChangeDate.isAfter(localModified);
      if (!remoteIsNewer) return;

      // Scarichiamo PRIMA in un file temporaneo, senza toccare quello
      // vero: se il download dovesse risultare incompleto o corrotto
      // (es. connessione instabile), è molto meglio tenere la copia
      // locale che funziona piuttosto che sostituirla con una rotta.
      final tempFile = File('$localDbPath.icloud_tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await _downloadFile(tempFile.path);

      final isValid = await _looksLikeValidDatabase(tempFile);
      if (!isValid) {
        await tempFile.delete().catchError((_) => tempFile);
        return;
      }

      if (localExists) {
        await localFile.delete();
      }
      await tempFile.rename(localDbPath);
    } catch (_) {
      // Silenzioso di proposito: l'app deve poter partire comunque.
    }
  }

  // Controllo "leggero" ma efficace: ogni file SQLite valido inizia
  // sempre con la stessa firma di 16 byte. Non garantisce che il
  // database sia perfetto al 100%, ma basta a scartare un download
  // troncato o interrotto a metà, che è il caso più comune.
  static Future<bool> _looksLikeValidDatabase(File file) async {
    try {
      if (!await file.exists()) return false;
      if (await file.length() < 100) return false;

      final handle = await file.open();
      final header = await handle.read(16);
      await handle.close();

      return String.fromCharCodes(header).startsWith('SQLite format 3');
    } catch (_) {
      return false;
    }
  }

  /// Carica la copia locale del database su iCloud, sovrascrivendo
  /// l'eventuale copia precedente.
  ///
  /// [localDbPath] è il percorso locale del file del database.
  ///
  /// Da chiamare subito dopo ogni scrittura importante (mentre l'app è
  /// ancora in primo piano: aspettare che l'utente esca dall'app è troppo
  /// rischioso, iOS potrebbe interrompere il caricamento a metà) e, come
  /// rete di sicurezza aggiuntiva, anche quando l'app va in background.
  ///
  /// Non lancia mai eccezioni, per lo stesso motivo di [downloadIfNewer].
  static Future<void> uploadDatabase(String localDbPath) async {
    if (!_isSupportedPlatform) return;

    try {
      final localFile = File(localDbPath);
      if (!await localFile.exists()) return;

      try {
        await ICloudStorage.delete(
          containerId: containerId,
          relativePath: _databaseFileName,
        );
      } catch (_) {
        // Va bene anche se il file non esisteva ancora su iCloud.
      }

      final completer = Completer<void>();
      await ICloudStorage.upload(
        containerId: containerId,
        filePath: localDbPath,
        destinationRelativePath: _databaseFileName,
        onProgress: (stream) {
          stream.listen(
            (_) {},
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            onError: (_) {
              if (!completer.isCompleted) completer.complete();
            },
            cancelOnError: true,
          );
        },
      );
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    } catch (_) {
      // Silenzioso di proposito, vedi downloadIfNewer.
    }
  }

  static Future<ICloudFile?> _findRemoteDatabaseFile() async {
    final files = await ICloudStorage.gather(containerId: containerId);
    for (final file in files) {
      if (file.relativePath == _databaseFileName) {
        return file;
      }
    }
    return null;
  }

  static Future<void> _downloadFile(String destinationPath) async {
    final completer = Completer<void>();
    await ICloudStorage.download(
      containerId: containerId,
      relativePath: _databaseFileName,
      destinationFilePath: destinationPath,
      onProgress: (stream) {
        stream.listen(
          (_) {},
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (_) {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }
}
