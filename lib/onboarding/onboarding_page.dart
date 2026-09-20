import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../import/import_review_page.dart';
import '../localization/app_language.dart';

enum _StepKind { info, language, currency, importChoice }

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
  bool _importingFromOnboarding = false;

  List<_OnboardingStep> get steps => [
        const _OnboardingStep(
          kind: _StepKind.language,
          icon: Icons.language_rounded,
        ),
        const _OnboardingStep(
          kind: _StepKind.currency,
          icon: Icons.payments_outlined,
        ),
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
          description: le(
            'Dalla Home puoi cambiare mese, vedere il riepilogo e lo storico dei movimenti. Tocca una fetta del grafico per vedere le spese di quella categoria.',
            'From the Home screen you can change month, see the overview and the transaction history. Tap a slice of the chart to see the expenses in that category.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.tune_rounded,
          title: l('Personalizza Liblo'),
          description: l(
            'Nelle Impostazioni puoi gestire categorie, lingua, valuta e protezione biometrica. La scelta della valuta cambia solo il simbolo, non converte gli importi.',
          ),
        ),
        const _OnboardingStep(
          kind: _StepKind.importChoice,
          icon: Icons.file_upload_outlined,
        ),
        _OnboardingStep(
          icon: Icons.receipt_long_outlined,
          title: l('Scansiona lo scontrino'),
          description: l(
            'Quando aggiungi un movimento, puoi fotografare lo scontrino invece di scrivere tutto a mano: Liblo prova a leggere automaticamente importo, data ed esercente, così devi solo controllare prima di salvare.',
          ),
        ),
        _OnboardingStep(
          icon: Icons.cloud_done_outlined,
          title: le('I tuoi dati sono al sicuro', 'Your data is safe'),
          description: le(
            'Liblo salva automaticamente una copia dei tuoi dati su iCloud (beta), così li ritrovi sugli altri tuoi dispositivi Apple. Dalle Impostazioni puoi anche esportare tutto in CSV, pronto per Excel.',
            'Liblo automatically backs up your data to iCloud (beta), so you\'ll find it on your other Apple devices too. From Settings you can also export everything to CSV, ready for Excel.',
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
      // Avvolgiamo il salvataggio in un try/catch: se per qualunque
      // motivo fallisse (es. database appena scaricato da iCloud al
      // primissimo avvio su un nuovo dispositivo), l'utente non deve
      // comunque restare bloccato sulla guida. Nel peggiore dei casi,
      // la guida ricomparirà alla prossima apertura dell'app.
      try {
        await DatabaseService.instance
            .setBoolSetting('onboarding_completed', true)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Errore silenzioso di proposito: si procede comunque sotto.
      }
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

  Future<void> _importFromStatementDuringOnboarding() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _importingFromOnboarding = true;
    });

    if (!mounted) return;

    await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => ImportReviewPage(filePath: path),
      ),
    );

    if (!mounted) return;

    setState(() {
      _importingFromOnboarding = false;
    });
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
                    child: switch (step.kind) {
                      _StepKind.language => _buildLanguageStep(colors),
                      _StepKind.currency => _buildCurrencyStep(colors),
                      _StepKind.importChoice =>
                        _buildImportChoiceStep(colors),
                      _StepKind.info => _buildInfoStep(colors, step),
                    },
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

  Widget _buildInfoStep(ColorScheme colors, _OnboardingStep step) {
    return Column(
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
    );
  }

  Widget _buildStepHeader(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, size: 34, color: colors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _selectableOption(
    ColorScheme colors, {
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageStep(ColorScheme colors) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final controller = AppLanguageController.instance;
        final detected =
            AppLanguageController.nativeNames[controller.systemLanguageCode] ??
                controller.systemLanguageCode;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepHeader(
              colors,
              icon: Icons.language_rounded,
              title: l('Scegli la lingua'),
              subtitle:
                  l('Puoi cambiarla in qualsiasi momento dalle Impostazioni.'),
            ),
            Expanded(
              child: ListView(
                children: [
                  _selectableOption(
                    colors,
                    title: l('Automatico'),
                    subtitle: '${l('Usa la lingua del telefono')} · $detected',
                    selected:
                        controller.preference == AppLanguageController.system,
                    onTap: () => controller
                        .setPreference(AppLanguageController.system),
                  ),
                  for (final code in AppLanguageController.supportedLanguages)
                    _selectableOption(
                      colors,
                      title: AppLanguageController.nativeNames[code] ?? code,
                      selected: controller.preference == code,
                      onTap: () => controller.setPreference(code),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrencyStep(ColorScheme colors) {
    return AnimatedBuilder(
      animation: AppCurrencyController.instance,
      builder: (context, _) {
        final controller = AppCurrencyController.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepHeader(
              colors,
              icon: Icons.payments_outlined,
              title: l('Scegli la valuta'),
              subtitle: l(
                'Cambia solo il simbolo mostrato: gli importi non vengono convertiti. Puoi cambiarla in qualsiasi momento dalle Impostazioni.',
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final code in AppCurrencyController.supportedCurrencies)
                    _selectableOption(
                      colors,
                      title: AppCurrencyController.displayLabel(code),
                      selected: controller.currencyCode == code,
                      onTap: () => controller.setCurrencyCode(code),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImportChoiceStep(ColorScheme colors) {
    return Column(
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
            Icons.file_upload_outlined,
            size: 46,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          l('Importa i tuoi movimenti'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l(
            'Vuoi importare i movimenti di questo mese da un estratto conto, oppure preferisci inserirli tu man mano?',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _importingFromOnboarding
                ? null
                : _importFromStatementDuringOnboarding,
            icon: _importingFromOnboarding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: Text(l('Importa da estratto conto (PDF)')),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l(
            'Funziona con PDF con testo selezionabile (non foto o scansioni).',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: next,
            child: Text(l('Preferisco inserirli manualmente')),
          ),
        ),
      ],
    );
  }
}

class _OnboardingStep {
  final _StepKind kind;
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingStep({
    this.kind = _StepKind.info,
    required this.icon,
    this.title = '',
    this.description = '',
  });
}
