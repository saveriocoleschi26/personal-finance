import 'package:flutter/material.dart';

import 'assistant/assistant_page.dart';
import 'currency/app_currency.dart';
import 'database/database_service.dart';
import 'home_page.dart';
import 'localization/app_language.dart';
import 'onboarding/onboarding_page.dart';
import 'planning/planning_page.dart';
import 'whats_new/whats_new_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  bool _planningInitialized = false;

  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    AppLanguageController.instance.addListener(_languageChanged);
    AppCurrencyController.instance.addListener(_currencyChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingIfNeeded();
    });
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  void _currencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLanguageController.instance.removeListener(_languageChanged);
    AppCurrencyController.instance.removeListener(_currencyChanged);
    refreshNotifier.dispose();
    super.dispose();
  }

  void notifyDataChanged() {
    refreshNotifier.value++;
  }

  void _openAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AssistantPage()),
    );
  }

  Future<void> _showOnboardingIfNeeded() async {
    final completed = await DatabaseService.instance.getBoolSetting(
      'onboarding_completed',
    );

    if (!mounted) return;

    if (completed) {
      // Utente già avviato: se l'app è appena stata aggiornata, mostriamo
      // le novità (una sola volta per versione).
      await WhatsNewService.showIfNeeded(context);
      return;
    }

    // Prima installazione: la guida spiega già tutto, quindi la versione
    // corrente viene segnata come vista senza mostrare le novità.
    await WhatsNewService.markCurrentVersionSeen();
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const OnboardingPage(),
      ),
    );

    // Quando si chiude la guida (con "Salta" o arrivando alla fine),
    // ricarichiamo i dati della Home: se il database era ancora in fase
    // di sincronizzazione da un altro dispositivo quando la Home si è
    // caricata la prima volta, questo evita che resti con dati vecchi o
    // vuoti finché l'utente non riavvia l'app da sé.
    notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);
    final isDark = hc.isDark;

    // L'assistente per ora risponde solo in italiano.
    final showAssistant =
        AppLanguageController.instance.effectiveLanguageCode ==
            AppLanguageController.italian;

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomePage(
            refreshNotifier: refreshNotifier,
            onDataChanged: notifyDataChanged,
          ),
          if (_planningInitialized)
            PlanningPage(
              refreshNotifier: refreshNotifier,
              onDataChanged: notifyDataChanged,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 72,
          backgroundColor: hc.cardBackground,
          indicatorColor: isDark
              ? const Color(0xFF1A3B37)
              : const Color(0xFFDDF3F0),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? hc.teal : hc.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? hc.teal : hc.textSecondary,
              size: 24,
            );
          }),
        ),
        child: NavigationBar(
          // Con l'assistente visibile la barra ha 3 voci (Home, Assistente,
          // Pianifica): la voce centrale non è una scheda, apre la chat.
          selectedIndex: showAssistant && selectedIndex == 1
              ? 2
              : selectedIndex,
          onDestinationSelected: (index) {
            if (showAssistant && index == 1) {
              _openAssistant();
              return;
            }
            final tab = showAssistant && index == 2 ? 1 : index;
            setState(() {
              selectedIndex = tab;
              if (tab == 1) {
                _planningInitialized = true;
              }
            });
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            if (showAssistant)
              NavigationDestination(
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hc.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                label: l('Assistente'),
              ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: l('Pianifica'),
            ),
          ],
        ),
      ),
    );
  }
}
