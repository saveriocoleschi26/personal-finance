import 'package:flutter/material.dart';

import 'database/database_service.dart';
import 'home_page.dart';
import 'localization/app_language.dart';
import 'onboarding/onboarding_page.dart';
import 'planning/planning_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    AppLanguageController.instance.addListener(_languageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingIfNeeded();
    });
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLanguageController.instance.removeListener(_languageChanged);
    refreshNotifier.dispose();
    super.dispose();
  }

  void notifyDataChanged() {
    refreshNotifier.value++;
  }

  Future<void> _showOnboardingIfNeeded() async {
    final completed = await DatabaseService.instance.getBoolSetting(
      'onboarding_completed',
    );

    if (!mounted || completed) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const OnboardingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomePage(
            refreshNotifier: refreshNotifier,
            onDataChanged: notifyDataChanged,
          ),
          PlanningPage(
            refreshNotifier: refreshNotifier,
            onDataChanged: notifyDataChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_note_outlined),
            selectedIcon: const Icon(Icons.event_note),
            label: l('Pianifica'),
          ),
        ],
      ),
    );
  }
}
