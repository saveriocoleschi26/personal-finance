import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'add_transaction_page.dart';
import 'annual_expenses/annual_expense.dart';
import 'categories/expense_category.dart';
import 'database/database_service.dart';
import 'localization/app_language.dart';
import 'planned_expenses/planned_expense.dart';
import 'settings/settings_page.dart';
import 'transaction/final_transaction.dart';

enum TransactionAction {
  edit,
  delete,
}

class HomePage extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;
  final VoidCallback onDataChanged;

  const HomePage({
    super.key,
    required this.refreshNotifier,
    required this.onDataChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<FinanceTransaction> transactions = [];
  List<AnnualExpense> annualExpenses = [];
  List<PlannedExpense> monthlyPlannedExpenses = [];
  List<ExpenseCategory> categories = [];

  double savingsGoal = 0;

  int touchedCategoryIndex = -1;
  bool isLoading = true;

  late DateTime selectedMonth;

  List<String> get monthNames => AppLanguageController.instance.monthNames;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    widget.refreshNotifier.addListener(_externalRefresh);
    loadSelectedMonthData();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_externalRefresh);
    super.dispose();
  }

  void _externalRefresh() {
    loadSelectedMonthData();
  }

  bool get isCurrentMonth {
    final now = DateTime.now();

    return selectedMonth.year == now.year &&
        selectedMonth.month == now.month;
  }

  String get selectedMonthLabel {
    return '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  String get currentMonthLabel {
    final now = DateTime.now();

    return '${monthNames[now.month - 1]} ${now.year}';
  }

  Future<void> goToPreviousMonth() async {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month - 1,
        1,
      );

      isLoading = true;
      touchedCategoryIndex = -1;
    });

    await loadSelectedMonthData();
  }

  Future<void> goToNextMonth() async {
    if (isCurrentMonth) return;

    final next = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    final now = DateTime.now();

    final currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    if (next.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      selectedMonth = next;
      isLoading = true;
      touchedCategoryIndex = -1;
    });

    await loadSelectedMonthData();
  }

  Future<void> goToCurrentMonth() async {
    final now = DateTime.now();

    setState(() {
      selectedMonth = DateTime(
        now.year,
        now.month,
        1,
      );

      isLoading = true;
      touchedCategoryIndex = -1;
    });

    await loadSelectedMonthData();
  }

  Future<void> loadSelectedMonthData() async {
    final monthToLoad = selectedMonth;

    final savedTransactions =
        await DatabaseService.instance.getTransactionsForMonth(
      monthToLoad,
    );

    final savedBudget =
        await DatabaseService.instance.getMonthlyBudget(
      monthToLoad,
    );

    final savedAnnualExpenses =
        await DatabaseService.instance.getAnnualExpenses();

    final savedPlannedExpenses =
        await DatabaseService.instance.getPlannedExpensesForMonth(
      monthToLoad,
    );

    final savedCategories =
        await DatabaseService.instance.getCategories(
      includeInactive: true,
    );

    if (!mounted) return;

    if (selectedMonth.year != monthToLoad.year ||
        selectedMonth.month != monthToLoad.month) {
      return;
    }

    setState(() {
      transactions.clear();
      transactions.addAll(savedTransactions);

      savingsGoal = savedBudget['savingsGoal'] ?? 0;
      annualExpenses = savedAnnualExpenses;
      monthlyPlannedExpenses = savedPlannedExpenses;
      categories = savedCategories;

      touchedCategoryIndex = -1;
      isLoading = false;
    });
  }

  double get totalIncome {
    return transactions
        .where((transaction) => transaction.isIncome)
        .fold(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );
  }

  double get totalExpenses {
    return transactions
        .where((transaction) => !transaction.isIncome)
        .fold(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );
  }

  double get balance {
    return totalIncome - totalExpenses;
  }

  double get annualPlanningCommitment {
    return annualExpenses.fold(
      0.0,
      (sum, expense) =>
          sum + expense.commitmentForMonth(selectedMonth),
    );
  }

  double get monthlyPlanningCommitment {
    return monthlyPlannedExpenses
        .where((expense) => !expense.isPaid)
        .fold(
          0.0,
          (sum, expense) => sum + expense.amount,
        );
  }

  double get plannedExpenses {
    return monthlyPlanningCommitment + annualPlanningCommitment;
  }

  double get committedExpenses {
    return totalExpenses + plannedExpenses;
  }

  // Tutti i soldi che l'utente ha già destinato nel mese:
  // spese già fatte, spese da pagare e obiettivo di risparmio.
  double get totalAssignedMoney {
    return committedExpenses + savingsGoal;
  }

  // Disponibilità reale del mese: ciò che resta dopo aver considerato
  // spese già pagate, spese pianificate, quote delle spese annuali
  // e obiettivo di risparmio. Può essere negativa se il mese è
  // sovra-impegnato.
  double get availableMoney {
    return totalIncome - committedExpenses - savingsGoal;
  }

  // Il budget spendibile non può essere negativo: se gli impegni
  // superano le entrate, per il calcolo giornaliero consideriamo 0.
  double get spendableMoney {
    if (availableMoney <= 0) return 0;

    return availableMoney;
  }

  int get daysRemainingInMonth {
    final now = DateTime.now();

    final lastDayOfMonth = DateTime(
      now.year,
      now.month + 1,
      0,
    );

    return lastDayOfMonth.day - now.day + 1;
  }

  double get dailySpendingLimit {
    if (!isCurrentMonth || spendableMoney <= 0) {
      return 0;
    }

    return spendableMoney / daysRemainingInMonth;
  }

  double get spendingPercentage {
    if (totalIncome <= 0) return 0;

    final percentage = totalAssignedMoney / totalIncome;

    if (percentage > 1) return 1;

    return percentage;
  }

  static const String _savingsAnalysisKey = '__pf_savings_goal__';

  // Il grafico non mostra soltanto le spese già pagate.
  // Include tutto ciò che ha già una destinazione nel mese:
  // - spese già effettuate
  // - spese pianificate ancora da pagare (incluse le ricorrenti)
  // - quota del mese per le scadenze a lungo termine
  // - soldi che l'utente vuole mettere da parte
  Map<String, double> get assignedMoneyByCategory {
    final Map<String, double> result = {};

    void addAmount(String category, double amount) {
      if (amount <= 0) return;

      result.update(
        category,
        (currentValue) => currentValue + amount,
        ifAbsent: () => amount,
      );
    }

    // Spese già effettuate.
    for (final transaction in transactions) {
      if (transaction.isIncome) continue;
      addAmount(transaction.category, transaction.amount);
    }

    // Spese del mese ancora da pagare. Le spese ricorrenti sono già
    // presenti qui come PlannedExpense, quindi non vanno aggiunte
    // una seconda volta.
    for (final expense in monthlyPlannedExpenses) {
      if (expense.isPaid) continue;
      addAmount(expense.category, expense.amount);
    }

    // Scadenze a lungo termine: entra nel grafico soltanto ciò che
    // deve essere messo da parte / pagato nel mese selezionato.
    for (final expense in annualExpenses) {
      addAmount(
        expense.category,
        expense.commitmentForMonth(selectedMonth),
      );
    }

    // Il risparmio è una destinazione dei soldi a tutti gli effetti,
    // ma usiamo una chiave interna per non confonderlo con una
    // categoria personalizzata che potrebbe chiamarsi "Risparmio".
    addAmount(_savingsAnalysisKey, savingsGoal);

    return result;
  }

  double get analysisTotal {
    return assignedMoneyByCategory.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );
  }

  List<MapEntry<String, double>> get sortedCategoryExpenses {
    final entries = assignedMoneyByCategory.entries.toList();

    entries.sort(
      (a, b) => b.value.compareTo(a.value),
    );

    return entries;
  }

  double categoryPercentage(double amount) {
    if (analysisTotal <= 0) return 0;
    return amount / analysisTotal;
  }

  String analysisCategoryLabel(String category) {
    if (category == _savingsAnalysisKey) {
      return l('Risparmio');
    }

    return localizedCategory(category);
  }

  ExpenseCategory? categoryDetails(String name) {
    for (final category in categories) {
      if (category.name == name) {
        return category;
      }
    }

    return null;
  }

  Color categoryColor(String category) {
    if (category == _savingsAnalysisKey) {
      return const Color(0xFF3D8B6D);
    }

    return categoryDetails(category)?.color ??
        const Color(0xFF8B8F9C);
  }

  IconData categoryIcon(String category) {
    if (category == _savingsAnalysisKey) {
      return Icons.savings_outlined;
    }

    return categoryDetails(category)?.icon ??
        Icons.receipt_outlined;
  }

  String formatEuro(double value) {
    final fixed = value.toStringAsFixed(2);
    return AppLanguageController.instance.isEnglish
        ? '€ $fixed'
        : '€ ${fixed.replaceAll('.', ',')}';
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return AppLanguageController.instance.isEnglish
        ? '$month/$day'
        : '$day/$month';
  }

  DateTime monthStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      1,
    );
  }

  Future<void> addTransaction() async {
    if (!isCurrentMonth) return;

    final FinanceTransaction? newTransaction =
        await Navigator.push<FinanceTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTransactionPage(),
      ),
    );

    if (newTransaction == null) return;

    await DatabaseService.instance.insertTransaction(
      newTransaction,
    );

    // Se l'utente ha inserito una data di un mese precedente,
    // spostiamo subito la Home su quel mese così può verificare il movimento.
    if (mounted) {
      setState(() {
        selectedMonth = monthStart(newTransaction.date);
        isLoading = true;
        touchedCategoryIndex = -1;
      });
    }

    widget.onDataChanged();
    await loadSelectedMonthData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCurrentMonth
              ? le(
                  'Movimento aggiunto · Disponibile ${formatEuro(availableMoney)}',
                  'Transaction added · Available ${formatEuro(availableMoney)}',
                )
              : le(
                  'Movimento aggiunto in $selectedMonthLabel',
                  'Transaction added in $selectedMonthLabel',
                ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> editTransaction(
    FinanceTransaction transaction,
  ) async {
    final FinanceTransaction? updatedTransaction =
        await Navigator.push<FinanceTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          transaction: transaction,
        ),
      ),
    );

    if (updatedTransaction == null) return;

    await DatabaseService.instance.updateTransaction(
      updatedTransaction,
    );

    // Anche in modifica, se cambia il mese della data,
    // mostriamo automaticamente il mese in cui il movimento è stato spostato.
    if (mounted) {
      setState(() {
        selectedMonth = monthStart(updatedTransaction.date);
        isLoading = true;
        touchedCategoryIndex = -1;
      });
    }

    widget.onDataChanged();
    await loadSelectedMonthData();
  }

  Future<void> deleteTransaction(
    FinanceTransaction transaction,
  ) async {
    if (transaction.id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final name = transaction.description.isEmpty
            ? transaction.category
            : transaction.description;

        return AlertDialog(
          title: Text(l('Eliminare movimento?')),
          content: Text(
            le(
              'Vuoi eliminare definitivamente "$name"?',
              'Do you want to permanently delete "$name"?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(l('Annulla')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l('Elimina')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await DatabaseService.instance.deleteTransaction(
      transaction.id!,
    );

    widget.onDataChanged();
    await loadSelectedMonthData();
  }

  Future<void> showTransactionActions(
    FinanceTransaction transaction,
  ) async {
    final TransactionAction? action =
        await showModalBottomSheet<TransactionAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final errorColor =
            Theme.of(sheetContext).colorScheme.error;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l('Modifica')),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    TransactionAction.edit,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: errorColor,
                ),
                title: Text(
                  l('Elimina'),
                  style: TextStyle(color: errorColor),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    TransactionAction.delete,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case TransactionAction.edit:
        await editTransaction(transaction);
        break;
      case TransactionAction.delete:
        await deleteTransaction(transaction);
        break;
    }
  }

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );

    if (!mounted) return;

    widget.onDataChanged();
    await loadSelectedMonthData();
  }

  Future<void> showInfo({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            message,
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(l('Ho capito')),
            ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> buildPieSections() {
    final entries = sortedCategoryExpenses;

    return List.generate(
      entries.length,
      (index) {
        final entry = entries[index];
        final isTouched =
            index == touchedCategoryIndex;
        final percentage =
            categoryPercentage(entry.value) * 100;

        return PieChartSectionData(
          color: categoryColor(entry.key),
          value: entry.value,
          radius: isTouched ? 34 : 28,
          showTitle: percentage >= 8,
          title: '${percentage.round()}%',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }

  Widget buildHeroCard(ColorScheme colors) {
    final String title;
    final String subtitle;
    final String value;

    if (isCurrentMonth) {
      title = l('BUDGET GIORNALIERO');
      value = formatEuro(dailySpendingLimit);
      subtitle = le(
        'tenendo conto delle spese da pagare e dei soldi che vuoi mettere da parte',
        'based on upcoming expenses and the money you want to set aside',
      );
    } else {
      title = l('RISULTATO DEL MESE');
      value = formatEuro(balance);

      if (balance > 0) {
        subtitle = l('Hai chiuso il mese in positivo');
      } else if (balance < 0) {
        subtitle = l('Le spese hanno superato le entrate');
      } else {
        subtitle = l('Entrate e spese si sono compensate');
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (isCurrentMonth)
                InkWell(
                  onTap: () {
                    showInfo(
                      title: l('Puoi spendere oggi'),
                      message: l(
                          'È una stima di quanto puoi spendere oggi senza compromettere il resto del mese. Tiene conto del denaro disponibile e dei giorni che mancano alla fine del mese.',
                        ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: colors.onPrimary.withValues(alpha: 0.82),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.80),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: isCurrentMonth && !isLoading
          ? FloatingActionButton.extended(
              onPressed: addTransaction,
              icon: const Icon(Icons.add),
              label: Text(
                l('Aggiungi movimento'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Text(
          'Personal Finance',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: openSettings,
            tooltip: l('Impostazioni'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          110,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonthSelector(
              label: selectedMonthLabel,
              isCurrentMonth: isCurrentMonth,
              onPrevious: goToPreviousMonth,
              onNext: isCurrentMonth
                  ? null
                  : goToNextMonth,
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const SizedBox(
                height: 420,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    isCurrentMonth
                        ? l('Disponibile')
                        : l('Saldo del mese'),
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (isCurrentMonth) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        showInfo(
                          title: l('Disponibile'),
                          message: l(
                              'È quello che ti resta davvero da spendere dopo aver considerato le spese già fatte, quelle da pagare, i soldi da mettere da parte per le scadenze a lungo termine e il tuo obiettivo di risparmio.',
                            ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatEuro(
                  isCurrentMonth ? availableMoney : balance,
                ),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    isCurrentMonth
                        ? Icons.calendar_today_outlined
                        : Icons.history_outlined,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isCurrentMonth
                        ? le(
                            '$daysRemainingInMonth giorni alla fine del mese',
                            '$daysRemainingInMonth days left this month',
                          )
                        : selectedMonthLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              buildHeroCard(colors),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: l('Entrate'),
                      value: formatEuro(totalIncome),
                      icon: Icons.arrow_downward_rounded,
                      iconColor: const Color(0xFF16865C),
                      iconBackground: const Color(0xFFE5F6EF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: l('Uscite'),
                      value: formatEuro(totalAssignedMoney),
                      subtitle: le(
                          '${formatEuro(totalExpenses)} già spesi · ${formatEuro(plannedExpenses + savingsGoal)} già destinati',
                          '${formatEuro(totalExpenses)} spent · ${formatEuro(plannedExpenses + savingsGoal)} set aside',
                        ),
                      onInfo: () {
                        showInfo(
                          title: l('Soldi già destinati'),
                          message: l(
                              'Comprendono i soldi già spesi, quelli che serviranno per le spese future e quelli che hai scelto di mettere da parte. In questo modo P.F. non considera disponibili soldi che ti serviranno più avanti.',
                            ),
                        );
                      },
                      icon: Icons.arrow_upward_rounded,
                      iconColor: const Color(0xFFC34949),
                      iconBackground: const Color(0xFFFFEBEB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE9EAF0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l('Percentuale spese/entrate'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(spendingPercentage * 100).round()}%',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: spendingPercentage,
                        minHeight: 8,
                        backgroundColor:
                            colors.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      totalIncome == 0
                          ? l('Nessuna entrata registrata')
                          : le(
                              '${formatEuro(totalExpenses)} già spesi · ${formatEuro(plannedExpenses)} per spese future · ${formatEuro(savingsGoal)} da mettere da parte',
                              '${formatEuro(totalExpenses)} spent · ${formatEuro(plannedExpenses)} for upcoming expenses · ${formatEuro(savingsGoal)} set aside',
                            ),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isCurrentMonth
                    ? l('Analisi spese')
                    : le(
                        'I tuoi soldi di ${monthNames[selectedMonth.month - 1]}',
                        'Your money in ${monthNames[selectedMonth.month - 1]}',
                      ),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l('Vedi quanto hai già speso e quanto hai già destinato.'),
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (analysisTotal == 0)
                const AnalysisEmptyState()
              else
                SpendingAnalysisCard(
                  entries: sortedCategoryExpenses,
                  totalAmount: analysisTotal,
                  touchedIndex: touchedCategoryIndex,
                  pieSections: buildPieSections(),
                  categoryColor: categoryColor,
                  categoryIcon: categoryIcon,
                  categoryLabel: analysisCategoryLabel,
                  formatEuro: formatEuro,
                  onTouched: (index) {
                    setState(() {
                      touchedCategoryIndex = index;
                    });
                  },
                ),
              const SizedBox(height: 28),
              if (!isCurrentMonth) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: goToCurrentMonth,
                    icon: const Icon(
                      Icons.today_outlined,
                    ),
                    label: Text(
                      le('Torna a $currentMonthLabel', 'Back to $currentMonthLabel'),
                    ),
                  ),
                ),
                const SizedBox(height: 34),
              ] else
                const SizedBox(height: 6),
              Text(
                isCurrentMonth
                    ? l('Ultimi movimenti')
                    : le(
                        'Movimenti di ${monthNames[selectedMonth.month - 1]}',
                        '${monthNames[selectedMonth.month - 1]} transactions',
                      ),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                l('Tocca un movimento per modificarlo o eliminarlo.'),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                const EmptyTransactions()
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE9EAF0),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0;
                          i < transactions.length;
                          i++) ...[
                        TransactionItem(
                          transaction: transactions[i],
                          formattedAmount:
                              formatEuro(transactions[i].amount),
                          formattedDate:
                              formatDate(transactions[i].date),
                          categoryIcon: categoryIcon(
                            transactions[i].category,
                          ),
                          categoryColor: categoryColor(
                            transactions[i].category,
                          ),
                          onTap: () {
                            showTransactionActions(
                              transactions[i],
                            );
                          },
                        ),
                        if (i != transactions.length - 1)
                          const Divider(
                            height: 1,
                            indent: 68,
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class MonthSelector extends StatelessWidget {
  final String label;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const MonthSelector({
    super.key,
    required this.label,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isCurrentMonth)
                  Text(
                    l('Storico mensile'),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onInfo;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onInfo,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onInfo != null)
                InkWell(
                  onTap: onInfo,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SpendingAnalysisCard extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double totalAmount;
  final int touchedIndex;
  final List<PieChartSectionData> pieSections;
  final Color Function(String category) categoryColor;
  final IconData Function(String category) categoryIcon;
  final String Function(String category) categoryLabel;
  final String Function(double value) formatEuro;
  final ValueChanged<int> onTouched;

  const SpendingAnalysisCard({
    super.key,
    required this.entries,
    required this.totalAmount,
    required this.touchedIndex,
    required this.pieSections,
    required this.categoryColor,
    required this.categoryIcon,
    required this.categoryLabel,
    required this.formatEuro,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    String centerTitle = l('Totale destinato');
    String centerValue = formatEuro(totalAmount);

    if (touchedIndex >= 0 &&
        touchedIndex < entries.length) {
      centerTitle = categoryLabel(entries[touchedIndex].key);
      centerValue =
          formatEuro(entries[touchedIndex].value);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: pieSections,
                    centerSpaceRadius: 64,
                    sectionsSpace: 3,
                    borderData: FlBorderData(
                      show: false,
                    ),
                    pieTouchData: PieTouchData(
                      touchCallback: (
                        FlTouchEvent event,
                        PieTouchResponse? response,
                      ) {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          onTouched(-1);
                          return;
                        }

                        onTouched(
                          response
                              .touchedSection!
                              .touchedSectionIndex,
                        );
                      },
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        centerValue,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l('Per categoria'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < entries.length; i++) ...[
            CategorySpendingRow(
              category: categoryLabel(entries[i].key),
              amount: entries[i].value,
              totalAmount: totalAmount,
              color: categoryColor(entries[i].key),
              icon: categoryIcon(entries[i].key),
              formattedAmount:
                  formatEuro(entries[i].value),
              isSelected: i == touchedIndex,
            ),
            if (i != entries.length - 1)
              const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class CategorySpendingRow extends StatelessWidget {
  final String category;
  final double amount;
  final double totalAmount;
  final Color color;
  final IconData icon;
  final String formattedAmount;
  final bool isSelected;

  const CategorySpendingRow({
    super.key,
    required this.category,
    required this.amount,
    required this.totalAmount,
    required this.color,
    required this.icon,
    required this.formattedAmount,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final percentage =
        totalAmount == 0
            ? 0.0
            : amount / totalAmount;

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 180,
      ),
      padding: EdgeInsets.all(
        isSelected ? 10 : 0,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formattedAmount,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 5,
                    backgroundColor:
                        const Color(0xFFEEF0F4),
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  le(
                    '${(percentage * 100).round()}% del totale',
                    '${(percentage * 100).round()}% of total',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
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

class AnalysisEmptyState extends StatelessWidget {
  const AnalysisEmptyState({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.donut_large_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l('Niente da mostrare'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l('Quando aggiungi spese o scegli dei soldi da mettere da parte, vedrai qui come sono distribuiti.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionItem extends StatelessWidget {
  final FinanceTransaction transaction;
  final String formattedAmount;
  final String formattedDate;
  final IconData categoryIcon;
  final Color categoryColor;
  final VoidCallback onTap;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.formattedAmount,
    required this.formattedDate,
    required this.categoryIcon,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;

    final amountColor = isIncome
        ? const Color(0xFF16865C)
        : const Color(0xFFC34949);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isIncome
                    ? const Color(0xFFE5F6EF)
                    : categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isIncome ? Icons.payments_outlined : categoryIcon,
                size: 20,
                color: isIncome
                    ? const Color(0xFF16865C)
                    : categoryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isEmpty
                        ? localizedCategory(transaction.category)
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${localizedCategory(transaction.category)} · $formattedDate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${isIncome ? '+' : '-'} $formattedAmount',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyTransactions extends StatelessWidget {
  const EmptyTransactions({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l('Nessun movimento'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l('Nessun movimento registrato per questo mese.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
