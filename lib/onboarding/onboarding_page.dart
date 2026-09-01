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
          title: l('Benvenuto in Liblo'),
          description: l(
            'Liblo ti mostra quanto puoi davvero spendere. Il Disponibile tiene conto delle entrate, delle spese e dei soldi che hai già destinato al futuro.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.add_circle_outline,
          title: l('Registra entrate e spese'),
          description: l(
            'Tocca il pulsante “+” nella Home per aggiungere un movimento. Puoi scegliere la categoria, cambiare la data e modificare o eliminare i movimenti in seguito.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.event_note_outlined,
          title: l('Organizza il mese'),
          description: l(
            'In Pianifica puoi inserire le spese previste, creare spese ricorrenti e scegliere quanti soldi mettere da parte come obiettivo di risparmio.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.calendar_month_outlined,
          title: l('Preparati alle scadenze'),
          description: l(
            'Aggiungi una scadenza a lungo termine, come bollo o assicurazione. Liblo divide l’importo tra i mesi precedenti e ti indica quanto mettere da parte.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.sync_alt_rounded,
          title: l('Il saldo continua nel mese nuovo'),
          description: l(
            'Quando inizia un nuovo mese, il Disponibile positivo o negativo del mese precedente viene riportato automaticamente. Non serve creare un movimento.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.pie_chart_outline_rounded,
          title: l('Controlla dove vanno i soldi'),
          description: l(
            'Dalla Home puoi cambiare mese, vedere il riepilogo, l’analisi per categoria e lo storico dei movimenti.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.tune_rounded,
          title: l('Personalizza Liblo'),
          description: l(
            'Nelle Impostazioni puoi gestire categorie, lingua, valuta e protezione biometrica. La scelta tra euro e dollari cambia il simbolo, non converte gli importi.',
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
                  Text(
                    '${currentPage + 1} / ${steps.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
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
