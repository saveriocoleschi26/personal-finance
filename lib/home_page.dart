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
  double savingsGoal = 0;

  int touchedCategoryIndex = -1;
  bool isLoading = true;
  bool showAllTransactions = false;
  bool _skipNextExternalRefresh = false;

  Map<String, ExpenseCategory> _categoriesByName = {};

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
    if (_skipNextExternalRefresh) {
      _skipNextExternalRefresh = false;
      return;
    }

    loadSelectedMonthData();
  }

  void _notifyOtherPages() {
    _skipNextExternalRefresh = true;
    widget.onDataChanged();
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
      showAllTransactions = false;
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
      showAllTransactions = false;
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
      showAllTransactions = false;
    });

    await loadSelectedMonthData();
  }

  Future<void> loadSelectedMonthData() async {
    final monthToLoad = selectedMonth;

    // Avviamo le letture insieme: SQLite le gestisce in modo sicuro e
    // la Home non aspetta cinque operazioni una dopo l'altra.
    final database = DatabaseService.instance;
    final transactionsFuture = database.getTransactionsForMonth(monthToLoad);
    final budgetFuture = database.getMonthlyBudget(monthToLoad);
    final annualExpensesFuture = database.getAnnualExpenses();
    final plannedExpensesFuture =
        database.getPlannedExpensesForMonth(monthToLoad);
    final categoriesFuture = database.getCategories(includeInactive: true);

    final savedTransactions = await transactionsFuture;
    final savedBudget = await budgetFuture;
    final savedAnnualExpenses = await annualExpensesFuture;
    final savedPlannedExpenses = await plannedExpensesFuture;
    final savedCategories = await categoriesFuture;

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
      _categoriesByName = {
        for (final category in savedCategories) category.name: category,
      };

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

  // Spese del mese escluse le quote delle scadenze a lungo termine
  // e l'obiettivo di risparmio. In questo modo le quattro card della
  // Home non si sovrappongono tra loro.
  double get monthlyOutgoings {
    return totalExpenses + monthlyPlanningCommitment;
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
  _AnalysisSnapshot _buildAnalysisSnapshot() {
    final result = <String, double>{};

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

    // Le ricorrenti ancora da pagare sono già presenti come PlannedExpense,
    // quindi vengono conteggiate qui una sola volta.
    for (final expense in monthlyPlannedExpenses) {
      if (expense.isPaid) continue;
      addAmount(expense.category, expense.amount);
    }

    // Per le scadenze a lungo termine entra solo la quota del mese.
    for (final expense in annualExpenses) {
      addAmount(
        expense.category,
        expense.commitmentForMonth(selectedMonth),
      );
    }

    addAmount(_savingsAnalysisKey, savingsGoal);

    final entries = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return _AnalysisSnapshot(
      entries: entries,
      total: total,
    );
  }

  List<FinanceTransaction> get visibleTransactions {
    if (showAllTransactions || transactions.length <= 4) {
      return transactions;
    }

    return transactions.take(4).toList();
  }


  String analysisCategoryLabel(String category) {
    if (category == _savingsAnalysisKey) {
      return l('Risparmio');
    }

    return localizedCategory(category);
  }

  ExpenseCategory? categoryDetails(String name) {
    return _categoriesByName[name];
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

    await loadSelectedMonthData();

    if (!mounted) return;
    _notifyOtherPages();

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

    await loadSelectedMonthData();

    if (!mounted) return;
    _notifyOtherPages();
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

    await loadSelectedMonthData();

    if (!mounted) return;
    _notifyOtherPages();
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

    await loadSelectedMonthData();

    if (!mounted) return;
    _notifyOtherPages();
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

  List<PieChartSectionData> buildPieSections(
    List<MapEntry<String, double>> entries,
    double totalAmount,
  ) {
    return List.generate(
      entries.length,
      (index) {
        final entry = entries[index];
        final isTouched = index == touchedCategoryIndex;
        final percentage = totalAmount <= 0
            ? 0.0
            : (entry.value / totalAmount) * 100;

        return PieChartSectionData(
          color: categoryColor(entry.key),
          value: entry.value,
          radius: isTouched ? 31 : 27,
          showTitle: percentage >= 9,
          title: '${percentage.round()}%',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        );
      },
    );
  }

  Widget buildHeroCard() {
    final value = isCurrentMonth ? availableMoney : balance;
    final title = isCurrentMonth ? l('Disponibile') : l('Saldo del mese');

    final String footer;
    if (isCurrentMonth) {
      footer = le(
        'Budget giornaliero ${formatEuro(dailySpendingLimit)}',
        'Daily budget ${formatEuro(dailySpendingLimit)}',
      );
    } else if (balance > 0) {
      footer = l('Hai chiuso il mese in positivo');
    } else if (balance < 0) {
      footer = l('Le spese hanno superato le entrate');
    } else {
      footer = l('Entrate e spese si sono compensate');
    }

    return Container(
      width: double.infinity,
      height: 205,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087F79),
            Color(0xFF159B94),
            Color(0xFF42B7AF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260B827C),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _HeroWavesPainter(),
            ),
          ),
          Positioned(
            right: 20,
            top: 48,
            child: Opacity(
              opacity: 0.92,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 66,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -8,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF087F79),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            right: 44,
            top: 28,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xAFFFFFFF),
              size: 20,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 23, 106, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrentMonth) ...[
                      const SizedBox(width: 5),
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
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xDFFFFFFF),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatEuro(value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 43,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 190,
                  height: 1,
                  color: const Color(0x55FFFFFF),
                ),
                const SizedBox(height: 12),
                Text(
                  footer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xEFFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOverviewGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OverviewCard(
                title: l('Entrate'),
                value: formatEuro(totalIncome),
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFF119B6B),
                iconBackground: const Color(0xFFE1F5EC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OverviewCard(
                title: l('Uscite'),
                value: formatEuro(monthlyOutgoings),
                icon: Icons.trending_down_rounded,
                accentColor: const Color(0xFFE04F4F),
                iconBackground: const Color(0xFFFFE9E7),
                onInfo: () {
                  showInfo(
                    title: l('Uscite'),
                    message: le(
                      'Comprendono le spese già fatte e quelle del mese ancora da pagare, incluse le ricorrenti.',
                      'This includes expenses already paid and expenses still due this month, including recurring ones.',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OverviewCard(
                title: le('Da mettere da parte', 'Set aside'),
                value: formatEuro(savingsGoal),
                icon: Icons.savings_outlined,
                accentColor: const Color(0xFF287AD6),
                iconBackground: const Color(0xFFE5F0FC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OverviewCard(
                title: l('Scadenze a lungo termine'),
                value: formatEuro(annualPlanningCommitment),
                icon: Icons.calendar_month_outlined,
                accentColor: const Color(0xFF7556C8),
                iconBackground: const Color(0xFFF0EAFB),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0B8D86);
    final analysis = _buildAnalysisSnapshot();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isCurrentMonth && !isLoading
          ? FloatingActionButton(
              onPressed: addTransaction,
              tooltip: l('Aggiungi movimento'),
              backgroundColor: teal,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF9),
        toolbarHeight: 68,
        titleSpacing: 20,
        title: const Text(
          'Liblo',
          style: TextStyle(
            color: teal,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE7ECEB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: openSettings,
              tooltip: l('Impostazioni'),
              icon: const Icon(
                Icons.settings_outlined,
                color: teal,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 112),
        children: [
            MonthSelector(
              label: selectedMonthLabel,
              isCurrentMonth: isCurrentMonth,
              onPrevious: goToPreviousMonth,
              onNext: isCurrentMonth ? null : goToNextMonth,
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const SizedBox(
                height: 480,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              buildHeroCard(),
              const SizedBox(height: 18),
              buildOverviewGrid(),
              const SizedBox(height: 20),
              if (analysis.total == 0)
                const AnalysisEmptyState()
              else
                SpendingAnalysisCard(
                  entries: analysis.entries,
                  totalAmount: analysis.total,
                  touchedIndex: touchedCategoryIndex,
                  pieSections: buildPieSections(
                    analysis.entries,
                    analysis.total,
                  ),
                  categoryColor: categoryColor,
                  categoryLabel: analysisCategoryLabel,
                  formatEuro: formatEuro,
                  onTouched: (index) {
                    setState(() {
                      touchedCategoryIndex = index;
                    });
                  },
                ),
              if (!isCurrentMonth) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: goToCurrentMonth,
                    icon: const Icon(Icons.today_outlined),
                    label: Text(
                      le(
                        'Torna a $currentMonthLabel',
                        'Back to $currentMonthLabel',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              RecentTransactionsCard(
                title: isCurrentMonth
                    ? l('Ultimi movimenti')
                    : le(
                        'Movimenti di ${monthNames[selectedMonth.month - 1]}',
                        '${monthNames[selectedMonth.month - 1]} transactions',
                      ),
                transactions: visibleTransactions,
                showAll: showAllTransactions,
                formatEuro: formatEuro,
                formatDate: formatDate,
                categoryIcon: categoryIcon,
                categoryColor: categoryColor,
                onToggleAll: transactions.length > 4
                    ? () {
                        setState(() {
                          showAllTransactions = !showAllTransactions;
                        });
                      }
                    : null,
                onTransactionTap: showTransactionActions,
              ),
            ],
          ],
      ),
    );
  }
}

class _AnalysisSnapshot {
  final List<MapEntry<String, double>> entries;
  final double total;

  const _AnalysisSnapshot({
    required this.entries,
    required this.total,
  });
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
    const teal = Color(0xFF0B8D86);

    Widget arrowButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: onPressed == null ? 0 : 1,
        shadowColor: const Color(0x14000000),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed == null
              ? const Color(0xFFCAD2D0)
              : teal,
          iconSize: 25,
          tooltip: null,
        ),
      );
    }

    return Row(
      children: [
        arrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF14263A),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (!isCurrentMonth) ...[
                const SizedBox(height: 2),
                Text(
                  l('Storico mensile'),
                  style: const TextStyle(
                    color: Color(0xFF7A8986),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        arrowButton(
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color iconBackground;
  final VoidCallback? onInfo;

  const OverviewCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.iconBackground,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EEEC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF26363A),
                          fontSize: 12.5,
                          height: 1.12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onInfo != null)
                      InkWell(
                        onTap: onInfo,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF8A9694),
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
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

class SpendingAnalysisCard extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double totalAmount;
  final int touchedIndex;
  final List<PieChartSectionData> pieSections;
  final Color Function(String category) categoryColor;
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
    required this.categoryLabel,
    required this.formatEuro,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    String centerTitle = l('Totale destinato');
    String centerValue = formatEuro(totalAmount);

    if (touchedIndex >= 0 && touchedIndex < entries.length) {
      centerTitle = categoryLabel(entries[touchedIndex].key);
      centerValue = formatEuro(entries[touchedIndex].value);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EEEC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l('Analisi spese'),
                  style: const TextStyle(
                    color: Color(0xFF14263A),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF889592),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartSize = constraints.maxWidth < 340 ? 126.0 : 142.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RepaintBoundary(
                          child: PieChart(
                            PieChartData(
                              sections: pieSections,
                              centerSpaceRadius: chartSize * 0.30,
                              sectionsSpace: 2.2,
                              borderData: FlBorderData(show: false),
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  if (!event.isInterestedForInteractions ||
                                      response?.touchedSection == null) {
                                    onTouched(-1);
                                    return;
                                  }

                                  onTouched(
                                    response!
                                        .touchedSection!
                                        .touchedSectionIndex,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  centerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF73807E),
                                    fontSize: 8.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    centerValue,
                                    style: const TextStyle(
                                      color: Color(0xFF1F3034),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (int i = 0; i < entries.length; i++) ...[
                          AnalysisLegendRow(
                            label: categoryLabel(entries[i].key),
                            amount: formatEuro(entries[i].value),
                            percentage:
                                totalAmount <= 0 ? 0 : entries[i].value / totalAmount,
                            color: categoryColor(entries[i].key),
                            selected: i == touchedIndex,
                          ),
                          if (i != entries.length - 1)
                            const SizedBox(height: 9),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AnalysisLegendRow extends StatelessWidget {
  final String label;
  final String amount;
  final double percentage;
  final Color color;
  final bool selected;

  const AnalysisLegendRow({
    super.key,
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: selected
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 5)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF344447),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(percentage * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFF8A9694),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1F3034),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentTransactionsCard extends StatelessWidget {
  final String title;
  final List<FinanceTransaction> transactions;
  final bool showAll;
  final String Function(double value) formatEuro;
  final String Function(DateTime date) formatDate;
  final IconData Function(String category) categoryIcon;
  final Color Function(String category) categoryColor;
  final VoidCallback? onToggleAll;
  final ValueChanged<FinanceTransaction> onTransactionTap;

  const RecentTransactionsCard({
    super.key,
    required this.title,
    required this.transactions,
    required this.showAll,
    required this.formatEuro,
    required this.formatDate,
    required this.categoryIcon,
    required this.categoryColor,
    required this.onToggleAll,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EEEC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 12, 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF14263A),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onToggleAll != null)
                  TextButton(
                    onPressed: onToggleAll,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0B8D86),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showAll
                              ? le('Mostra meno', 'Show less')
                              : le('Vedi tutti', 'See all'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          showAll
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.chevron_right_rounded,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: EmptyTransactions(compact: true),
            )
          else
            for (int i = 0; i < transactions.length; i++) ...[
              TransactionItem(
                transaction: transactions[i],
                formattedAmount: formatEuro(transactions[i].amount),
                formattedDate: formatDate(transactions[i].date),
                categoryIcon: categoryIcon(transactions[i].category),
                categoryColor: categoryColor(transactions[i].category),
                onTap: () => onTransactionTap(transactions[i]),
              ),
              if (i != transactions.length - 1)
                const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                  color: Color(0xFFEDF0EF),
                ),
            ],
          if (transactions.isNotEmpty) const SizedBox(height: 8),
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
        ? const Color(0xFF119B6B)
        : const Color(0xFF1F2D31);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: isIncome
                    ? const Color(0xFF24BA70)
                    : categoryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome ? Icons.work_outline_rounded : categoryIcon,
                size: 21,
                color: Colors.white,
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
                      color: Color(0xFF17282D),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${localizedCategory(transaction.category)} · $formattedDate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7E8B89),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${isIncome ? '+' : '-'} $formattedAmount',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalysisEmptyState extends StatelessWidget {
  const AnalysisEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EEEC)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F4F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.donut_large_outlined,
              color: Color(0xFF0B8D86),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            l('Niente da mostrare'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l('Quando aggiungi spese o scegli dei soldi da mettere da parte, vedrai qui come sono distribuiti.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7E8B89),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyTransactions extends StatelessWidget {
  final bool compact;

  const EmptyTransactions({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 22 : 32,
      ),
      decoration: compact
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE9EEEC)),
            ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: Color(0xFF899694),
          ),
          const SizedBox(height: 10),
          Text(
            l('Nessun movimento'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l('Nessun movimento registrato per questo mese.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7E8B89),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroWavesPainter extends CustomPainter {
  const _HeroWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final darkWave = Paint()
      ..color = const Color(0x2200524E)
      ..style = PaintingStyle.fill;

    final lightWave = Paint()
      ..color = const Color(0x18FFFFFF)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.48,
        size.width * 0.48,
        size.height * 0.92,
        size.width * 0.70,
        size.height * 0.73,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.60,
        size.width * 0.94,
        size.height * 0.55,
        size.width,
        size.height * 0.56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.58)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.74,
        size.width * 0.50,
        size.height * 0.47,
        size.width * 0.76,
        size.height * 0.67,
      )
      ..cubicTo(
        size.width * 0.87,
        size.height * 0.76,
        size.width * 0.94,
        size.height * 0.79,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, darkWave);
    canvas.drawPath(path2, lightWave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
