import 'package:flutter/material.dart';

import '../home_page.dart' show HomeColors;
import '../localization/app_language.dart';
import 'whats_new_content.dart';

class WhatsNewPage extends StatelessWidget {
  final String version;
  final List<WhatsNewItem> items;

  const WhatsNewPage({
    super.key,
    required this.version,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);

    // Le pagine aperte sopra la Home non ereditano la direzione del testo
    // (serve per l'arabo, da destra a sinistra), quindi la impostiamo qui.
    return Directionality(
      textDirection: AppLanguageController.instance.isRTL
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: _buildScaffold(context, hc),
    );
  }

  Widget _buildScaffold(BuildContext context, HomeColors hc) {
    final isItalian = AppLanguageController.instance.effectiveLanguageCode ==
        AppLanguageController.italian;
    final visibleItems =
        items.where((item) => !item.italianOnly || isItalian).toList();

    return Scaffold(
      backgroundColor: hc.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: hc.teal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 36,
                        color: hc.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    whatsNewText(whatsNewHeading),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    whatsNewText(whatsNewVersionLabel).replaceAll('{v}', version),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  for (final item in visibleItems) ...[
                    _WhatsNewCard(item: item, hc: hc),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: hc.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    whatsNewText(whatsNewContinue),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsNewCard extends StatelessWidget {
  final WhatsNewItem item;
  final HomeColors hc;

  const _WhatsNewCard({
    required this.item,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hc.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hc.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: hc.teal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  whatsNewText(item.title),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  whatsNewText(item.body),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
