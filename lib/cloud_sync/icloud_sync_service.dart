import 'dart:async';
import 'dart:io';

import 'package:icloud_storage/icloud_storage.dart';

import '../database/database_service.dart';

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
  /// Non lancia mai eccezioni: se qualcosa va storto (iCloud non
  /// disponibile, utente non loggato, nessuna connessione...) l'app deve
  /// comunque poter partire e funzionare normalmente in locale.
  static Future<void> downloadIfNewer() async {
    if (!_isSupportedPlatform) return;

    try {
      final localPath =
          await DatabaseService.instance.getDatabaseFilePath();
      final remoteFile = await _findRemoteDatabaseFile();
      if (remoteFile == null) return;

      final localFile = File(localPath);
      final localExists = await localFile.exists();
      final localModified =
          localExists ? await localFile.lastModified() : null;

      final remoteIsNewer = localModified == null ||
          remoteFile.contentChangeDate.isAfter(localModified);
      if (!remoteIsNewer) return;

      if (localExists) {
        await localFile.delete();
      }

      await _downloadFile(localPath);
    } catch (_) {
      // Silenzioso di proposito: l'app deve poter partire comunque.
    }
  }

  /// Carica la copia locale del database su iCloud, sovrascrivendo
  /// l'eventuale copia precedente. Da chiamare dopo scritture importanti
  /// e/o quando l'app va in background.
  ///
  /// Non lancia mai eccezioni, per lo stesso motivo di [downloadIfNewer].
  static Future<void> uploadDatabase() async {
    if (!_isSupportedPlatform) return;

    try {
      final localPath =
          await DatabaseService.instance.getDatabaseFilePath();
      final localFile = File(localPath);
      if (!await localFile.exists()) return;

      try {
        await ICloudStorage.delete(
          containerId: containerId,
          relativePath: DatabaseService.databaseFileName,
        );
      } catch (_) {
        // Va bene anche se il file non esisteva ancora su iCloud.
      }

      final completer = Completer<void>();
      await ICloudStorage.upload(
        containerId: containerId,
        filePath: localPath,
        destinationRelativePath: DatabaseService.databaseFileName,
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
      if (file.relativePath == DatabaseService.databaseFileName) {
        return file;
      }
    }
    return null;
  }

  static Future<void> _downloadFile(String destinationPath) async {
    final completer = Completer<void>();
    await ICloudStorage.download(
      containerId: containerId,
      relativePath: DatabaseService.databaseFileName,
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
