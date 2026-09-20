import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../categories/categories_page.dart';
import '../cloud_sync/icloud_sync_service.dart';
import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../export/csv_export_service.dart';
import '../import/import_review_page.dart';
import '../localization/app_language.dart';
import '../onboarding/onboarding_page.dart';
import '../security/biometric_security.dart';
import '../theme/app_theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _changingSecurity = false;
  bool _syncingNow = false;
  bool _exportingNow = false;
  bool _importingNow = false;
  final GlobalKey _exportButtonKey = GlobalKey();
  DateTime? _lastSyncTime;

  AppLanguageController get _language => AppLanguageController.instance;
  AppCurrencyController get _currency => AppCurrencyController.instance;
  BiometricSecurityController get _security =>
      BiometricSecurityController.instance;

  @override
  void initState() {
    super.initState();
    _language.addListener(_refresh);
    _currency.addListener(_refresh);
    _security.addListener(_refresh);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _security.refreshAvailability();
    });
  }

  @override
  void dispose() {
    _language.removeListener(_refresh);
    _currency.removeListener(_refresh);
    _security.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _lastSyncLabel() {
    final lastSync = _lastSyncTime;
    if (lastSync == null) {
      return le(
        'Tocca per sincronizzare ora',
        'Tap to sync now',
      );
    }
    final hh = lastSync.hour.toString().padLeft(2, '0');
    final mm = lastSync.minute.toString().padLeft(2, '0');
    return le(
      'Ultima sincronizzazione: $hh:$mm',
      'Last synced: $hh:$mm',
    );
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncingNow = true;
    });

    final dbPath = await DatabaseService.instance.getDatabaseFilePath();
    final versionPath =
        await DatabaseService.instance.getDataVersionFilePath();
    await ICloudSyncService.uploadDatabase(dbPath, versionPath);

    if (!mounted) return;
    setState(() {
      _syncingNow = false;
      _lastSyncTime = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          le(
            'Sincronizzazione completata',
            'Sync completed',
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    setState(() {
      _exportingNow = true;
    });

    try {
      final zipFile = await CsvExportService.instance.exportAll();
      if (!mounted) return;

      Rect? sharePositionOrigin;
      final renderBox =
          _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final offset = renderBox.localToGlobal(Offset.zero);
        sharePositionOrigin = offset & renderBox.size;
      }

      await Share.shareXFiles(
        [XFile(zipFile.path)],
        subject: 'Liblo — ${le('Esportazione dati', 'Data export')}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e, stack) {
      if (!mounted) return;
      debugPrint('Errore export CSV: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            le(
              'Esportazione non riuscita. Riprova.',
              'Export failed. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingNow = false;
        });
      }
    }
  }

  Future<void> _importFromStatement() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _importingNow = true;
    });

    if (!mounted) return;

    final importedCount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => ImportReviewPage(filePath: path),
      ),
    );

    if (!mounted) return;

    setState(() {
      _importingNow = false;
    });

    if (importedCount != null && importedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            le(
              '$importedCount transazioni importate',
              '$importedCount transactions imported',
            ),
          ),
        ),
      );
    }
  }

  String _languageSubtitle() {
    if (_language.preference == AppLanguageController.system) {
      final detected = AppLanguageController
              .nativeNames[_language.systemLanguageCode] ??
          _language.systemLanguageCode;
      return '${l('Automatico')} · $detected';
    }

    return AppLanguageController.nativeNames[_language.preference] ??
        _language.preference;
  }

  String _themeSubtitle() {
    switch (AppThemeController.instance.themeMode) {
      case ThemeMode.light:
        return l('Chiaro');
      case ThemeMode.dark:
        return l('Scuro');
      case ThemeMode.system:
        return l('Automatico');
    }
  }

  String _currencySubtitle() {
    return AppCurrencyController.displayLabel(_currency.currencyCode);
  }

  IconData get _securityIcon {
    if (Platform.isIOS) {
      return Icons.face_retouching_natural_rounded;
    }
    return Icons.fingerprint_rounded;
  }

  String _securitySubtitle() {
    if (!_security.available) {
      if (_security.enabled) {
        return le(
          'Lo sblocco biometrico non è disponibile. Puoi disattivare la protezione usando il codice del telefono.',
          'Biometric unlock is unavailable. You can turn protection off using your phone passcode.',
        );
      }

      if (Platform.isIOS) {
        return le(
          'Configura prima Face ID o Touch ID nelle impostazioni dell’iPhone',
          'Set up Face ID or Touch ID in iPhone Settings first',
        );
      }

      if (Platform.isAndroid) {
        return le(
          'Configura prima l’impronta digitale nelle impostazioni del telefono',
          'Set up fingerprint in your phone settings first',
        );
      }

      return le(
        'Nessun sistema di sblocco biometrico disponibile',
        'No biometric unlock is available',
      );
    }

    if (Platform.isIOS) {
      return le(
        'Richiedi ${_security.biometricName} quando apri Liblo',
        'Require ${_security.biometricName} when opening Liblo',
      );
    }

    if (Platform.isAndroid) {
      return le(
        'Richiedi l’impronta digitale quando apri Liblo',
        'Require fingerprint when opening Liblo',
      );
    }

    return le(
      'Richiedi lo sblocco biometrico quando apri Liblo',
      'Require biometric unlock when opening Liblo',
    );
  }

  Future<void> _changeSecurity(bool value) async {
    if (_changingSecurity) return;

    setState(() {
      _changingSecurity = true;
    });

    final changed = await _security.setEnabled(value);

    if (!mounted) return;

    setState(() {
      _changingSecurity = false;
    });

    if (!changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _security.available
                ? le(
                    'Sblocco non riuscito. Riprova.',
                    'Unlock failed. Try again.',
                  )
                : le(
                    'Prima configura lo sblocco biometrico sul telefono.',
                    'Set up biometric unlock on your phone first.',
                  ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Impostazioni')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l('Personalizzazione'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: _SettingsIcon(
                    icon: Icons.category_outlined,
                    color: colors.primary,
                    background: colors.primaryContainer,
                  ),
                  title: Text(
                    l('Categorie'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l(
                      'Crea, modifica e disattiva le categorie di spesa',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoriesPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  leading: _SettingsIcon(
                    icon: Icons.dark_mode_outlined,
                    color: colors.primary,
                    background: colors.primaryContainer,
                  ),
                  title: Text(
                    l('Aspetto'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(_themeSubtitle()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeSettingsPage(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  leading: _SettingsIcon(
                    icon: Icons.language_rounded,
                    color: colors.primary,
                    background: colors.primaryContainer,
                  ),
                  title: Text(
                    l('Lingua'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(_languageSubtitle()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LanguageSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  leading: _SettingsIcon(
                    icon: Icons.payments_outlined,
                    color: colors.primary,
                    background: colors.primaryContainer,
                  ),
                  title: Text(
                    l('Valuta'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(_currencySubtitle()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CurrencySettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l('Sicurezza'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: SwitchListTile(
              secondary: _SettingsIcon(
                icon: _securityIcon,
                color: colors.primary,
                background: colors.primaryContainer,
              ),
              title: Text(
                l('Proteggi Liblo'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(_securitySubtitle()),
              value: _security.enabled,
              onChanged: (_security.available || _security.enabled) &&
                      !_changingSecurity
                  ? _changeSecurity
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              le(
                'Quando la protezione è attiva, Liblo si blocca all’avvio e dopo essere rimasta in background per qualche secondo.',
                'When protection is on, Liblo locks at startup and after being in the background for a short time.',
              ),
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l('Backup'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: _SettingsIcon(
                icon: Icons.cloud_outlined,
                color: colors.primary,
                background: colors.primaryContainer,
              ),
              title: Text(
                l('Sincronizza con iCloud'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _syncingNow
                    ? l('Sincronizzazione in corso...')
                    : _lastSyncLabel(),
              ),
              trailing: _syncingNow
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              onTap: _syncingNow ? null : _syncNow,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              le(
                'Liblo salva automaticamente una copia dei tuoi dati su iCloud quando esci dall’app, così li ritrovi anche sui tuoi altri dispositivi Apple. Usa questo pulsante se vuoi forzare subito la sincronizzazione.',
                'Liblo automatically saves a copy of your data to iCloud when you leave the app, so you’ll find it on your other Apple devices too. Use this button if you want to force a sync right away.',
              ),
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l('Dati'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              key: _exportButtonKey,
              leading: _SettingsIcon(
                icon: Icons.file_download_outlined,
                color: colors.primary,
                background: colors.primaryContainer,
              ),
              title: Text(
                le('Esporta dati (CSV)', 'Export data (CSV)'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                le(
                  'Transazioni, categorie, spese ricorrenti, pianificate e annuali',
                  'Transactions, categories, recurring, planned and annual expenses',
                ),
              ),
              trailing: _exportingNow
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              onTap: _exportingNow ? null : _exportCsv,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: _SettingsIcon(
                icon: Icons.file_upload_outlined,
                color: colors.primary,
                background: colors.primaryContainer,
              ),
              title: Text(
                le(
                  'Importa da estratto conto (PDF)',
                  'Import from account statement (PDF)',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                le(
                  'Riconosce le transazioni e te le fa rivedere prima di importarle',
                  'Detects transactions and lets you review them before importing',
                ),
              ),
              trailing: _importingNow
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _importingNow ? null : _importFromStatement,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l('Aiuto'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              leading: _SettingsIcon(
                icon: Icons.help_outline_rounded,
                color: colors.primary,
                background: colors.primaryContainer,
              ),
              title: Text(
                l('Come funziona Liblo'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                l('Rivedi la guida completa alle funzioni principali'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OnboardingPage(
                      markCompletedOnFinish: false,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  Future<void> _changeLanguage(String value) async {
    await AppLanguageController.instance.setPreference(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLanguageController.instance;
    final colors = Theme.of(context).colorScheme;

    Widget languageOption({
      required String value,
      required String title,
      String? subtitle,
    }) {
      final selected = controller.preference == value;

      return ListTile(
        onTap: () => _changeLanguage(value),
        leading: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
      );
    }

    final languageEntries = <Widget>[
      languageOption(
        value: AppLanguageController.system,
        title: l('Automatico'),
        subtitle: l('Usa la lingua del telefono'),
      ),
    ];

    for (final code in AppLanguageController.supportedLanguages) {
      languageEntries.add(
        const Divider(height: 1, indent: 16, endIndent: 16),
      );
      languageEntries.add(
        languageOption(
          value: code,
          title: AppLanguageController.nativeNames[code] ?? code,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Lingua dell’app')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l('Scegli la lingua usata da Liblo'),
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(children: languageEntries),
          ),
        ],
      ),
    );
  }
}

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  Future<void> _changeTheme(ThemeMode mode) async {
    await AppThemeController.instance.setThemeMode(mode);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final colors = Theme.of(context).colorScheme;

    Widget themeOption({
      required ThemeMode value,
      required String title,
      String? subtitle,
    }) {
      final selected = controller.themeMode == value;

      return ListTile(
        onTap: () => _changeTheme(value),
        leading: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Aspetto')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l('Scegli come deve apparire Liblo'),
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              children: [
                themeOption(
                  value: ThemeMode.system,
                  title: l('Automatico'),
                  subtitle: le(
                    'Segue l\'aspetto del sistema (anche se lo hai impostato per cambiare da solo con l\'orario)',
                    'Follows the system appearance (even if you\'ve set it to switch automatically with the time of day)',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                themeOption(
                  value: ThemeMode.light,
                  title: l('Chiaro'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                themeOption(
                  value: ThemeMode.dark,
                  title: l('Scuro'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CurrencySettingsPage extends StatefulWidget {
  const CurrencySettingsPage({super.key});

  @override
  State<CurrencySettingsPage> createState() =>
      _CurrencySettingsPageState();
}

class _CurrencySettingsPageState
    extends State<CurrencySettingsPage> {
  Future<void> _changeCurrency(String value) async {
    await AppCurrencyController.instance.setCurrencyCode(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppCurrencyController.instance;
    final colors = Theme.of(context).colorScheme;

    Widget currencyOption({
      required String value,
      required String title,
    }) {
      final selected = controller.currencyCode == value;

      return ListTile(
        onTap: () => _changeCurrency(value),
        leading: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        title: Text(title),
      );
    }

    final currencyEntries = <Widget>[];
    for (final code in AppCurrencyController.supportedCurrencies) {
      if (currencyEntries.isNotEmpty) {
        currencyEntries.add(
          const Divider(height: 1, indent: 16, endIndent: 16),
        );
      }
      currencyEntries.add(
        currencyOption(
          value: code,
          title: AppCurrencyController.displayLabel(code),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Valuta dell’app')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l('Scegli la valuta mostrata da Liblo'),
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(children: currencyEntries),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l('La scelta cambia soltanto il simbolo mostrato. Gli importi non vengono convertiti.'),
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _SettingsIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: color,
      ),
    );
  }
}
