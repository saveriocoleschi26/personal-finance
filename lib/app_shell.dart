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
  bool _planningInitialized = false;

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
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDDF3F0),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected
                  ? const Color(0xFF0B8D86)
                  : const Color(0xFF7B8785),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected
                  ? const Color(0xFF0B8D86)
                  : const Color(0xFF7B8785),
              size: 24,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
              if (index == 1) {
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
