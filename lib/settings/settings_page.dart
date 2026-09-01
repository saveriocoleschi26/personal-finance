import 'dart:io';

import 'package:flutter/material.dart';

import '../categories/categories_page.dart';
import '../currency/app_currency.dart';
import '../localization/app_language.dart';
import '../onboarding/onboarding_page.dart';
import '../security/biometric_security.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _changingSecurity = false;

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

  String _languageSubtitle() {
    switch (_language.preference) {
      case AppLanguageController.italian:
        return l('Italiano');
      case AppLanguageController.english:
        return l('Inglese');
      default:
        final detected = _language.systemLanguageCode ==
                AppLanguageController.italian
            ? l('Italiano')
            : l('Inglese');
        return '${l('Automatico')} · $detected';
    }
  }

  String _currencySubtitle() {
    return _currency.currencyCode == AppCurrencyController.usDollar
        ? l(r'Dollaro statunitense ($)')
        : l('Euro (€)');
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
            child: Column(
              children: [
                languageOption(
                  value: AppLanguageController.system,
                  title: l('Automatico'),
                  subtitle: l('Usa la lingua del telefono'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                languageOption(
                  value: AppLanguageController.italian,
                  title: 'Italiano',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                languageOption(
                  value: AppLanguageController.english,
                  title: 'English',
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
            child: Column(
              children: [
                currencyOption(
                  value: AppCurrencyController.euro,
                  title: l('Euro (€)'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                currencyOption(
                  value: AppCurrencyController.usDollar,
                  title: l(r'Dollaro statunitense ($)'),
                ),
              ],
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
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
