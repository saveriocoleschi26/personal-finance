import 'dart:async';
import 'dart:io';

import 'package:icloud_storage/icloud_storage.dart';
import 'package:sqflite/sqflite.dart';

/// Nomi fissi dei file coinvolti nella sincronizzazione, condivisi con
/// DatabaseService. Tenuti qui (invece di importare database_service.dart)
/// per evitare un riferimento circolare tra i due file, dato che
/// DatabaseService chiama questo servizio dopo ogni scrittura.
const String _databaseFileName = 'personal_finance.db';
const String _versionFileName = 'personal_finance.version';

/// Gestisce la sincronizzazione del database locale (sqflite) con iCloud,
/// così da poter usare Liblo su più dispositivi Apple con gli stessi dati.
///
/// Approccio scelto: sincronizzazione dell'intero file del database,
/// non dei singoli movimenti. È la soluzione più semplice e adatta a un
/// uso personale su un dispositivo alla volta. Non gestisce conflitti in
/// caso di modifiche fatte su due dispositivi nello stesso momento, senza
/// che uno dei due abbia fatto in tempo a sincronizzarsi: in quel caso
/// vince l'ultima copia caricata.
///
/// Per decidere quale copia sia più recente, insieme al database viene
/// caricato anche un piccolo file di testo con un numero di versione
/// (vedi [_versionFileName]). Il confronto tra dispositivi legge SOLO
/// questo piccolo file di testo, mai il database vero: aprire il
/// database per un semplice confronto rischiava di intralciare
/// l'apertura "vera" che l'app fa subito dopo per usarlo davvero.
class ICloudSyncService {
  ICloudSyncService._();

  static const String containerId = 'iCloud.com.saverio.Liblo';

  static bool get _isSupportedPlatform => Platform.isIOS || Platform.isMacOS;

  /// Da chiamare UNA SOLA VOLTA, all'avvio dell'app, PRIMA di aprire il
  /// database locale.
  ///
  /// [localDbPath] è il percorso locale del file del database.
  /// [localVersionPath] è il percorso locale del piccolo file "marcatore
  /// di versione" (vedi sopra).
  ///
  /// Non lancia mai eccezioni: se qualcosa va storto (iCloud non
  /// disponibile, utente non loggato, nessuna connessione...) l'app deve
  /// comunque poter partire e funzionare normalmente in locale.
  static Future<void> downloadIfNewer(
    String localDbPath,
    String localVersionPath,
  ) async {
    if (!_isSupportedPlatform) return;

    try {
      final remoteVersion = await _fetchRemoteVersion(localVersionPath);
      if (remoteVersion == null) return; // niente su iCloud, o errore

      final localVersion = await _readLocalVersion(localVersionPath);
      final localIsUpToDate =
          localVersion != null && remoteVersion <= localVersion;
      if (localIsUpToDate) return;

      // Solo se il marcatore remoto è davvero più recente, scarichiamo
      // anche il database vero (più pesante), lo validiamo, e solo
      // allora lo mettiamo al posto di quello locale.
      final tempDbFile = File('$localDbPath.icloud_tmp');
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
      await _downloadFile(_databaseFileName, tempDbFile.path);

      final isValid = await _looksLikeValidDatabase(tempDbFile);
      if (!isValid) {
        await tempDbFile.delete().catchError((_) => tempDbFile);
        return;
      }

      final localDbFile = File(localDbPath);
      if (await localDbFile.exists()) {
        await localDbFile.delete();
      }
      await tempDbFile.rename(localDbPath);

      await File(localVersionPath).writeAsString('$remoteVersion');
    } catch (_) {
      // Silenzioso di proposito: l'app deve poter partire comunque.
    }
  }

  // Scarica il marcatore di versione remoto (un piccolo file di testo)
  // in un file temporaneo e ne legge il contenuto. Restituisce null se
  // non esiste su iCloud o se qualcosa va storto.
  static Future<int?> _fetchRemoteVersion(String localVersionPath) async {
    final remoteFile = await _findRemoteFile(_versionFileName);
    if (remoteFile == null) return null;

    final tempVersionFile = File('$localVersionPath.icloud_tmp');
    try {
      if (await tempVersionFile.exists()) {
        await tempVersionFile.delete();
      }
      await _downloadFile(_versionFileName, tempVersionFile.path);
      if (!await tempVersionFile.exists()) return null;

      final content = await tempVersionFile.readAsString();
      return int.tryParse(content.trim());
    } finally {
      if (await tempVersionFile.exists()) {
        await tempVersionFile.delete().catchError((_) => tempVersionFile);
      }
    }
  }

  static Future<int?> _readLocalVersion(String localVersionPath) async {
    try {
      final file = File(localVersionPath);
      if (!await file.exists()) return null;
      return int.tryParse((await file.readAsString()).trim());
    } catch (_) {
      return null;
    }
  }

  // Controllo di validità sul database appena scaricato: verifichiamo
  // sia l'intestazione tipica di ogni file SQLite, sia che si riesca
  // davvero ad aprirlo e leggerci qualcosa. Questo controllo avviene
  // SOLO su un file temporaneo, mai sul percorso "vero" del database,
  // proprio per non rischiare di intralciare l'apertura successiva.
  static Future<bool> _looksLikeValidDatabase(File file) async {
    try {
      if (!await file.exists()) return false;
      if (await file.length() < 100) return false;

      final handle = await file.open();
      final header = await handle.read(16);
      await handle.close();

      if (!String.fromCharCodes(header).startsWith('SQLite format 3')) {
        return false;
      }

      final testDb = await openReadOnlyDatabase(file.path);
      try {
        await testDb.rawQuery('SELECT count(*) FROM sqlite_master');
      } finally {
        await testDb.close();
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Carica la copia locale del database (e il suo marcatore di
  /// versione) su iCloud, sovrascrivendo l'eventuale copia precedente.
  ///
  /// [localDbPath] è il percorso locale del file del database.
  /// [localVersionPath] è il percorso locale del marcatore di versione.
  ///
  /// Da chiamare subito dopo ogni scrittura importante (mentre l'app è
  /// ancora in primo piano: aspettare che l'utente esca dall'app è troppo
  /// rischioso, iOS potrebbe interrompere il caricamento a metà) e, come
  /// rete di sicurezza aggiuntiva, anche quando l'app va in background.
  ///
  /// Non lancia mai eccezioni, per lo stesso motivo di [downloadIfNewer].
  static Future<void> uploadDatabase(
    String localDbPath,
    String localVersionPath,
  ) async {
    if (!_isSupportedPlatform) return;

    try {
      final localDbFile = File(localDbPath);
      if (!await localDbFile.exists()) return;

      await _deleteThenUpload(_databaseFileName, localDbPath);

      final localVersionFile = File(localVersionPath);
      if (await localVersionFile.exists()) {
        await _deleteThenUpload(_versionFileName, localVersionPath);
      }
    } catch (_) {
      // Silenzioso di proposito, vedi downloadIfNewer.
    }
  }

  static Future<void> _deleteThenUpload(
    String relativePath,
    String localPath,
  ) async {
    try {
      await ICloudStorage.delete(
        containerId: containerId,
        relativePath: relativePath,
      );
    } catch (_) {
      // Va bene anche se il file non esisteva ancora su iCloud.
    }

    final completer = Completer<void>();
    await ICloudStorage.upload(
      containerId: containerId,
      filePath: localPath,
      destinationRelativePath: relativePath,
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

  static Future<ICloudFile?> _findRemoteFile(String relativePath) async {
    final files = await ICloudStorage.gather(containerId: containerId);
    for (final file in files) {
      if (file.relativePath == relativePath) {
        return file;
      }
    }
    return null;
  }

  static Future<void> _downloadFile(
    String relativePath,
    String destinationPath,
  ) async {
    final completer = Completer<void>();
    await ICloudStorage.download(
      containerId: containerId,
      relativePath: relativePath,
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
