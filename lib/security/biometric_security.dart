import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../database/database_service.dart';
import '../localization/app_language.dart';

class BiometricSecurityController extends ChangeNotifier {
  BiometricSecurityController._();

  static final BiometricSecurityController instance =
      BiometricSecurityController._();

  static const String _settingKey = 'biometric_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled = false;
  bool _available = false;
  List<BiometricType> _availableBiometrics = const [];

  bool get enabled => _enabled;
  bool get available => _available;
  List<BiometricType> get availableBiometrics =>
      List.unmodifiable(_availableBiometrics);

  Future<void> load() async {
    _enabled = await DatabaseService.instance.getBoolSetting(
      _settingKey,
    );
    await refreshAvailability(notify: false);

    // Se la biometria non è più disponibile non disattiviamo la preferenza:
    // così tornerà a funzionare appena l'utente la configura di nuovo.
  }

  Future<void> refreshAvailability({bool notify = true}) async {
    bool canCheck = false;
    List<BiometricType> biometrics = const [];

    try {
      canCheck = await _auth.canCheckBiometrics;
      if (canCheck) {
        biometrics = await _auth.getAvailableBiometrics();
      }
    } catch (_) {
      canCheck = false;
      biometrics = const [];
    }

    _availableBiometrics = biometrics;
    _available = canCheck && biometrics.isNotEmpty;

    if (notify) notifyListeners();
  }

  String get biometricName {
    if (Platform.isIOS) {
      if (_availableBiometrics.contains(BiometricType.face)) {
        return 'Face ID';
      }
      if (_availableBiometrics.contains(BiometricType.fingerprint)) {
        return 'Touch ID';
      }
      return 'Face ID / Touch ID';
    }

    if (Platform.isAndroid) {
      if (_availableBiometrics.contains(BiometricType.fingerprint)) {
        return le('impronta digitale', 'fingerprint');
      }
      return le('biometria', 'biometrics');
    }

    return le('biometria', 'biometrics');
  }

  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Preferiamo Face ID / impronta, lasciando al sistema la possibilità
        // di proporre il codice del dispositivo come recupero sicuro.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateForUnlock() async {
    if (!_enabled) return true;

    await refreshAvailability(notify: false);

    // Anche se Face ID / impronta viene rimossa dopo l'attivazione,
    // lasciamo al sistema la possibilità di usare il codice del dispositivo.
    return authenticate(
      reason: le(
        'Sblocca Liblo per vedere i tuoi dati',
        'Unlock Liblo to view your data',
      ),
    );
  }

  Future<bool> setEnabled(bool value) async {
    if (value == _enabled) return true;

    await refreshAvailability(notify: false);
    if (value && !_available) {
      notifyListeners();
      return false;
    }

    final confirmed = await authenticate(
      reason: value
          ? le(
              'Conferma la tua identità per proteggere Liblo',
              'Confirm your identity to protect Liblo',
            )
          : le(
              'Conferma la tua identità per togliere la protezione di Liblo',
              'Confirm your identity to turn off Liblo protection.',
            ),
    );

    if (!confirmed) return false;

    _enabled = value;
    await DatabaseService.instance.setBoolSetting(
      _settingKey,
      value,
    );
    notifyListeners();
    return true;
  }
}
