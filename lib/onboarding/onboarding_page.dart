import 'package:flutter/material.dart';

import '../database/database_service.dart';
import '../localization/app_language.dart';

class OnboardingPage extends StatefulWidget {
  final bool markCompletedOnFinish;

  const OnboardingPage({
    super.key,
    this.markCompletedOnFinish = true,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController pageController = PageController();

  int currentPage = 0;

  List<_OnboardingStep> get steps => [
        _OnboardingStep(
          icon: Icons.account_balance_wallet_outlined,
          title: l('Tieni sotto controllo il mese'),
          description: l(
            'Il Disponibile considera ciò che hai già speso, le spese da pagare e i soldi che vuoi mettere da parte.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.event_note_outlined,
          title: l('Pianifica in anticipo'),
          description: l(
            'Inserisci spese previste, ricorrenti e scadenze a lungo termine. P.F. calcola quanto mettere da parte ogni mese prima delle scadenze.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.add_circle_outline,
          title: l('Registra i movimenti in un tap'),
          description: l(
            'Usa il pulsante “+ Movimento” sempre visibile nella Home per aggiungere rapidamente un’entrata o una spesa.',
          ),
        ),
      ];

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (widget.markCompletedOnFinish) {
      await DatabaseService.instance.setBoolSetting(
        'onboarding_completed',
        true,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> next() async {
    if (currentPage == steps.length - 1) {
      await finish();
      return;
    }

    await pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.markCompletedOnFinish,
        actions: [
          if (currentPage < steps.length - 1)
            TextButton(
              onPressed: finish,
              child: Text(l('Salta')),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: steps.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final step = steps[index];

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            step.icon,
                            size: 46,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == currentPage
                              ? colors.primary
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: next,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          currentPage == steps.length - 1
                              ? l('Inizia')
                              : l('Avanti'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}
