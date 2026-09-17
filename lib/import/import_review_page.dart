import 'package:flutter/material.dart';

import '../categories/expense_category.dart';
import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../home_page.dart' show HomeColors;
import '../localization/app_language.dart';
import '../transaction/final_transaction.dart';
import 'bank_statement_parser.dart';

class ImportReviewPage extends StatefulWidget {
  final String filePath;

  const ImportReviewPage({
    super.key,
    required this.filePath,
  });

  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  bool loading = true;
  bool importing = false;
  String? errorMessage;
  StatementDocumentType documentType = StatementDocumentType.creditCard;
  List<ImportedTransactionCandidate> candidates = [];
  List<ExpenseCategory> categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cats = await DatabaseService.instance.getCategories();
      final text =
          await BankStatementParser.extractTextFromPdf(widget.filePath);
      final parsed = BankStatementParser.parseText(
        text,
        cats.map((c) => c.name).toList(),
      );

      await _flagDuplicates(parsed);

      if (!mounted) return;
      setState(() {
        categories = cats;
        candidates = parsed;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = le(
          'Non sono riuscito a leggere questo file. Assicurati che sia un PDF con testo selezionabile, non una scansione o una foto.',
          'I couldn\'t read this file. Make sure it\'s a PDF with selectable text, not a scan or a photo.',
        );
        loading = false;
      });
    }
  }

  Future<void> _flagDuplicates(
    List<ImportedTransactionCandidate> parsed,
  ) async {
    final monthsToCheck = <DateTime>{};
    for (final c in parsed) {
      monthsToCheck.add(DateTime(c.date.year, c.date.month, 1));
    }

    final existingByMonth = <DateTime, List<FinanceTransaction>>{};
    for (final month in monthsToCheck) {
      existingByMonth[month] =
          await DatabaseService.instance.getTransactionsForMonth(month);
    }

    for (final candidate in parsed) {
      final monthKey = DateTime(candidate.date.year, candidate.date.month, 1);
      final existing = existingByMonth[monthKey] ?? const [];

      final isDuplicate = existing.any(
        (t) =>
            t.date.year == candidate.date.year &&
            t.date.month == candidate.date.month &&
            t.date.day == candidate.date.day &&
            (t.amount - candidate.amount).abs() < 0.01,
      );

      candidate.looksLikeDuplicate = isDuplicate;
      candidate.selected = !isDuplicate;
    }
  }

  Future<void> _confirmImport() async {
    final selected = candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    setState(() => importing = true);

    for (final candidate in selected) {
      await DatabaseService.instance.insertTransaction(
        FinanceTransaction(
          amount: candidate.amount,
          description: candidate.description,
          category: candidate.category,
          isIncome: candidate.isIncomeFor(documentType),
          date: candidate.date,
        ),
      );
    }

    if (documentType == StatementDocumentType.creditCard) {
      await _maybeOfferToDisableCreditCardRecurring(selected.length);
    } else {
      if (!mounted) return;
      Navigator.of(context).pop(selected.length);
    }
  }

  Future<void> _maybeOfferToDisableCreditCardRecurring(
    int importedCount,
  ) async {
    final recurring = await DatabaseService.instance.getRecurringExpenses();
    final matches = recurring.where((r) {
      final name = r.name.toLowerCase();
      return r.isActive && name.contains('carta') && name.contains('credito');
    }).toList();

    if (!mounted) return;

    if (matches.length != 1) {
      Navigator.of(context).pop(importedCount);
      return;
    }

    final match = matches.first;

    final shouldDisable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          le('Spesa ricorrente duplicata?', 'Duplicate recurring expense?'),
        ),
        content: Text(
          le(
            'Hai importato $importedCount spese dal rendiconto della carta. Hai ancora attiva la spesa ricorrente "${match.name}" da ${AppCurrencyController.instance.format(match.amount)}/mese: tenendole entrambe il totale verrebbe contato due volte. Vuoi disattivarla?',
            'You imported $importedCount expenses from the card statement. The recurring expense "${match.name}" of ${AppCurrencyController.instance.format(match.amount)}/month is still active: keeping both would count the total twice. Disable it?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(le('Non ora', 'Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(le('Disattiva', 'Disable')),
          ),
        ],
      ),
    );

    if (shouldDisable == true) {
      await DatabaseService.instance.updateRecurringExpense(
        match.copyWith(isActive: false),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(importedCount);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);
    final selectedCount = candidates.where((c) => c.selected).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(le('Importa transazioni', 'Import transactions')),
      ),
      body: _buildBody(hc),
      bottomNavigationBar:
          (loading || errorMessage != null || candidates.isEmpty)
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: selectedCount == 0 || importing
                          ? null
                          : _confirmImport,
                      child: importing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              selectedCount == 0
                                  ? le(
                                      'Seleziona almeno una transazione',
                                      'Select at least one transaction',
                                    )
                                  : le(
                                      'Importa $selectedCount transazioni',
                                      'Import $selectedCount transactions',
                                    ),
                            ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildBody(HomeColors hc) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            le(
              'Non ho trovato transazioni riconoscibili in questo file.',
              'I couldn\'t find any recognizable transactions in this file.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<StatementDocumentType>(
            segments: [
              ButtonSegment(
                value: StatementDocumentType.creditCard,
                label: Text(le('Carta di credito', 'Credit card')),
              ),
              ButtonSegment(
                value: StatementDocumentType.currentAccount,
                label: Text(le('Conto corrente', 'Current account')),
              ),
            ],
            selected: {documentType},
            onSelectionChanged: (selection) {
              setState(() {
                documentType = selection.first;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _CandidateCard(
              candidate: candidates[i],
              documentType: documentType,
              categories: categories,
              hc: hc,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final ImportedTransactionCandidate candidate;
  final StatementDocumentType documentType;
  final List<ExpenseCategory> categories;
  final HomeColors hc;
  final VoidCallback onChanged;

  const _CandidateCard({
    required this.candidate,
    required this.documentType,
    required this.categories,
    required this.hc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = candidate.isIncomeFor(documentType);
    final day = candidate.date.day.toString().padLeft(2, '0');
    final month = candidate.date.month.toString().padLeft(2, '0');
    final dateLabel = '$day/$month/${candidate.date.year}';
    final categoryExists =
        categories.any((c) => c.name == candidate.category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: candidate.looksLikeDuplicate
              ? const Color(0xFFE0A83C)
              : hc.border,
          width: candidate.looksLikeDuplicate ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: candidate.selected,
                onChanged: (v) {
                  candidate.selected = v ?? false;
                  onChanged();
                },
              ),
              Expanded(
                child: TextFormField(
                  initialValue: candidate.description,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hc.textPrimaryStrong,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => candidate.description = v,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${isIncome ? '+' : '-'} ${AppCurrencyController.instance.format(candidate.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isIncome ? hc.green : hc.textPrimaryStrong,
                  ),
                ),
              ),
            ],
          ),
          if (candidate.looksLikeDuplicate)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 2, bottom: 4),
              child: Text(
                le(
                  'Possibile duplicato: sembra già presente in quel giorno',
                  'Possible duplicate: seems already present that day',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB8862A),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 4),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: candidate.date,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      candidate.date = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        12,
                      );
                      onChanged();
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: hc.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: categoryExists ? candidate.category : null,
                    hint: Text(
                      candidate.category,
                      style: TextStyle(
                        fontSize: 13,
                        color: hc.textSecondary,
                      ),
                    ),
                    isDense: true,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(
                              c.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      candidate.category = v;
                      onChanged();
                    },
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
