import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import '../localization/app_language.dart';

/// Scorciatoie che compaiono tenendo premuta l'icona dell'app nella Home
/// del telefono (iOS: menu a tendina sopra l'icona; Android: menu di
/// pressione prolungata).
///
/// Il servizio non apre nessuna schermata da solo: si limita a ricordare
/// che l'utente ha scelto una scorciatoia e a "suonare il campanello"
/// ([requests]). La Home, che è l'unica a sapere quando è sicuro mostrare
/// una schermata (app sbloccata, mese corrente, nessun'altra pagina
/// sopra), raccoglie la richiesta con [takePendingAction].
///
/// Questo evita due problemi:
/// - con Face ID attivo la Home non esiste finché l'app è bloccata, quindi
///   la richiesta resta "in attesa" e viene raccolta subito dopo lo sblocco;
/// - la richiesta scade dopo qualche secondo, così una scorciatoia toccata
///   e mai servita (es. sblocco annullato) non si apre a sorpresa più tardi.
class QuickActionsService {
  QuickActionsService._();

  static final QuickActionsService instance = QuickActionsService._();

  static const String addTransactionType = 'add_transaction';
  static const String scanReceiptType = 'scan_receipt';

  // Nomi delle immagini (template) nell'asset catalog di iOS. Se
  // un'immagine non esiste la scorciatoia compare comunque, senza icona.
  static const String _iosAddIcon = 'QuickAddTransaction';
  static const String _iosScanIcon = 'QuickScanReceipt';

  static const Duration _requestValidity = Duration(seconds: 90);

  final QuickActions _quickActions = QuickActions();

  /// Aumenta di uno ogni volta che l'utente sceglie una scorciatoia.
  final ValueNotifier<int> requests = ValueNotifier<int>(0);

  String? _pendingType;
  DateTime? _pendingRequestedAt;
  bool _initialized = false;

  /// Da chiamare una sola volta all'avvio, dopo il caricamento della lingua.
  void initialize() {
    if (_initialized) return;
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    _initialized = true;

    try {
      _quickActions.initialize(_handleAction);
    } catch (_) {
      // Le scorciatoie sono un extra: se il sistema non le supporta l'app
      // funziona normalmente senza.
      return;
    }

    AppLanguageController.instance.addListener(_refreshShortcuts);
    _refreshShortcuts();
  }

  void _handleAction(String type) {
    if (type != addTransactionType && type != scanReceiptType) return;
    _pendingType = type;
    _pendingRequestedAt = DateTime.now();
    requests.value++;
  }

  Future<void> _refreshShortcuts() async {
    try {
      await _quickActions.setShortcutItems(<ShortcutItem>[
        ShortcutItem(
          type: addTransactionType,
          localizedTitle: l('Nuovo movimento'),
          icon: Platform.isIOS ? _iosAddIcon : null,
        ),
        ShortcutItem(
          type: scanReceiptType,
          localizedTitle: l('Scansiona scontrino'),
          icon: Platform.isIOS ? _iosScanIcon : null,
        ),
      ]);
    } catch (_) {
      // Vedi sopra: nessun problema se non riesce.
    }
  }

  /// Restituisce (una sola volta) il tipo della scorciatoia scelta di
  /// recente e ancora da servire, oppure null se non ce n'è.
  String? takePendingAction() {
    final type = _pendingType;
    final requestedAt = _pendingRequestedAt;
    _pendingType = null;
    _pendingRequestedAt = null;

    if (type == null || requestedAt == null) return null;
    if (DateTime.now().difference(requestedAt) > _requestValidity) {
      return null;
    }
    return type;
  }
}
