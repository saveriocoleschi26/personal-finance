import 'package:flutter/material.dart';

import '../database/database_service.dart';

/// Gestisce la scelta del tema chiaro/scuro dell'app.
///
/// "Automatico" (il valore di default) segue semplicemente l'aspetto di
/// sistema di iOS — che a sua volta l'utente può impostare per cambiare
/// da solo con l'orario/tramonto in Impostazioni > Schermo e
/// luminosità > Aspetto > Automatico. Non serve reinventare quella
/// logica dentro l'app: iOS la fa già bene.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const String _settingKey = 'theme_mode';
  static const String _lightValue = 'light';
  static const String _darkValue = 'dark';
  static const String _systemValue = 'system';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final saved = await DatabaseService.instance.getSetting(_settingKey);

    switch (saved) {
      case _lightValue:
        _themeMode = ThemeMode.light;
      case _darkValue:
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final value = switch (mode) {
      ThemeMode.light => _lightValue,
      ThemeMode.dark => _darkValue,
      ThemeMode.system => _systemValue,
    };

    await DatabaseService.instance.setSetting(_settingKey, value);
  }
}
