import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'add_transaction_page.dart';
import 'annual_expenses/annual_expense.dart';
import 'categories/expense_category.dart';
import 'currency/app_currency.dart';
import 'database/database_service.dart';
import 'localization/app_language.dart';
import 'monthly_carryover/monthly_balance_calculator.dart';
import 'planned_expenses/planned_expense.dart';
import 'settings/settings_page.dart';
import 'transaction/final_transaction.dart';

enum TransactionAction {
  edit,
  delete,
}

// Tutti i colori della Home che devono cambiare tra tema chiaro e scuro,
// raccolti in un unico posto. I colori delle categorie (icone, sfondi
// pastello) restano invariati nei due temi, quindi non sono qui dentro.
class HomeColors {
  final bool isDark;

  const HomeColors._(this.isDark);

  factory HomeColors.of(BuildContext context) {
    return HomeColors._(Theme.of(context).brightness == Brightness.dark);
  }

  Color get cardBackground =>
      isDark ? const Color(0xFF16221F) : Colors.white;
  Color get pageBackground =>
      isDark ? const Color(0xFF0E1917) : const Color(0xFFF7FAF9);
  Color get textPrimary =>
      isDark ? const Color(0xFFF2F5F4) : const Color(0xFF14263A);
  Color get textPrimaryAlt =>
      isDark ? const Color(0xFFF2F5F4) : const Color(0xFF17282D);
  Color get textPrimaryStrong =>
      isDark ? const Color(0xFFF2F5F4) : const Color(0xFF1F2D31);
  Color get textPrimaryDeep =>
      isDark ? const Color(0xFFF2F5F4) : const Color(0xFF1F3034);
  Color get textSecondary =>
      isDark ? const Color(0xFF8FA39D) : const Color(0xFF7E8B89);
  Color get textSecondaryAlt =>
      isDark ? const Color(0xFF8FA39D) : const Color(0xFF899694);
  Color get textSecondaryDim =>
      isDark ? const Color(0xFF7C908A) : const Color(0xFF8A9694);
  Color get textMuted =>
      isDark ? const Color(0xFF7C908A) : const Color(0xFF7A8986);
  Color get textMutedAlt =>
      isDark ? const Color(0xFF7C908A) : const Color(0xFF73807E);
  Color get iconMuted =>
      isDark ? const Color(0xFF7C908A) : const Color(0xFF667370);
  Color get border =>
      isDark ? const Color(0xFF223532) : const Color(0xFFE9EEEC);
  Color get borderAlt =>
      isDark ? const Color(0xFF223532) : const Color(0xFFE7ECEB);
  Color get divider =>
      isDark ? const Color(0xFF223532) : const Color(0xFFEDF0EF);
  Color get mutedFill =>
      isDark ? const Color(0xFF26363A) : const Color(0xFFCAD2D0);
  Color get teal =>
      isDark ? const Color(0xFF1FBF95) : const Color(0xFF0B8D86);
  Color get tealDeep =>
      isDark ? const Color(0xFF19A483) : const Color(0xFF087F79);
  Color get green =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF119B6B);
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

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver {
  final List<FinanceTransaction> transactions = [];
  List<AnnualExpense> annualExpenses = [];
  List<PlannedExpense> monthlyPlannedExpenses = [];
  double savingsGoal = 0;
  double monthlyCarryover = 0;
  bool hasAnyTransactionsEver = true;

  int touchedCategoryIndex = -1;
  bool isLoading = true;
  bool hasLoadError = false;
  bool showAllTransactions = false;
  bool _skipNextExternalRefresh = false;
  Timer? _monthBoundaryTimer;

  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  List<FinanceTransaction> searchResults = [];
  bool searchLoading = false;
  Timer? _searchDebounce;

  Map<String, ExpenseCategory> _categoriesByName = {};

  late DateTime selectedMonth;
  late DateTime _lastKnownCalendarMonth;

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
    _lastKnownCalendarMonth = selectedMonth;

    WidgetsBinding.instance.addObserver(this);
    widget.refreshNotifier.addListener(_externalRefresh);
    _scheduleMonthBoundaryRefresh();
    loadSelectedMonthData();
  }

  @override
  void dispose() {
    _monthBoundaryTimer?.cancel();
    _searchDebounce?.cancel();
    searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshNotifier.removeListener(_externalRefresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _moveToNewMonthIfNeeded();
    _scheduleMonthBoundaryRefresh();
  }

  void _scheduleMonthBoundaryRefresh() {
    _monthBoundaryTimer?.cancel();

    final now = DateTime.now();
    final nextMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    );
    final delay = nextMonth.difference(now) +
        const Duration(seconds: 1);

    _monthBoundaryTimer = Timer(
      delay,
      () async {
        await _moveToNewMonthIfNeeded();

        if (mounted) {
          _scheduleMonthBoundaryRefresh();
        }
      },
    );
  }

  Future<void> _moveToNewMonthIfNeeded() async {
    if (!mounted) return;

    final now = DateTime.now();
    final currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    if (!_lastKnownCalendarMonth.isBefore(currentMonth)) return;

    _lastKnownCalendarMonth = currentMonth;

    setState(() {
      selectedMonth = currentMonth;
      isLoading = true;
      touchedCategoryIndex = -1;
      showAllTransactions = false;
    });

    await loadSelectedMonthData();
  }

  void _externalRefresh() {
    if (_skipNextExternalRefresh) {
      _skipNextExternalRefresh = false;
      return;
    }

    loadSelectedMonthData();
  }

  void toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        _searchDebounce?.cancel();
        searchController.clear();
        searchResults = [];
        searchLoading = false;
      }
    });
  }

  void onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        searchLoading = false;
      });
      return;
    }

    setState(() {
      searchLoading = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results =
          await DatabaseService.instance.searchTransactions(query);

      if (!mounted) return;
      // Se nel frattempo l'utente ha già cambiato/svuotato la ricerca,
      // scartiamo questo risultato ormai obsoleto.
      if (searchController.text.trim() != query.trim()) return;

      setState(() {
        searchResults = results;
        searchLoading = false;
      });
    });
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

    try {
      // Avviamo le letture insieme: SQLite le gestisce in modo sicuro e
      // la Home non aspetta le operazioni una dopo l'altra.
      final database = DatabaseService.instance;
      final transactionsFuture =
          database.getTransactionsForMonth(monthToLoad);
      final budgetFuture = database.getMonthlyBudget(monthToLoad);
      final carryoverFuture = database.getMonthlyCarryover(monthToLoad);
      final annualExpensesFuture = database.getAnnualExpenses();
      final plannedExpensesFuture =
          database.getPlannedExpensesForMonth(monthToLoad);
      final categoriesFuture = database.getCategories(includeInactive: true);
      final hasAnyTransactionsFuture = database.hasAnyTransactions();

      final savedTransactions = await transactionsFuture.timeout(
        const Duration(seconds: 15),
      );
      final savedBudget = await budgetFuture.timeout(
        const Duration(seconds: 15),
      );
      final savedCarryover = await carryoverFuture.timeout(
        const Duration(seconds: 15),
      );
      final savedAnnualExpenses = await annualExpensesFuture.timeout(
        const Duration(seconds: 15),
      );
      final savedPlannedExpenses = await plannedExpensesFuture.timeout(
        const Duration(seconds: 15),
      );
      final savedCategories = await categoriesFuture.timeout(
        const Duration(seconds: 15),
      );
      final savedHasAnyTransactions = await hasAnyTransactionsFuture.timeout(
        const Duration(seconds: 15),
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
        monthlyCarryover = savedCarryover;
        annualExpenses = savedAnnualExpenses;
        monthlyPlannedExpenses = savedPlannedExpenses;
        _categoriesByName = {
          for (final category in savedCategories) category.name: category,
        };
        hasAnyTransactionsEver = savedHasAnyTransactions;

        touchedCategoryIndex = -1;
        hasLoadError = false;
        isLoading = false;
      });
    } catch (_) {
      // Qualunque cosa vada storta nella lettura (database inaccessibile,
      // file incompleto, ecc.), la schermata non deve restare bloccata sul
      // caricamento: mostriamo uno stato di errore con un modo per
      // riprovare, invece di uno spinner infinito.
      if (!mounted) return;
      setState(() {
        hasLoadError = true;
        isLoading = false;
      });
    }
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
  // il riporto del mese precedente, le spese già pagate, le spese
  // pianificate, le quote delle scadenze a lungo termine e l'obiettivo
  // di risparmio. Può essere negativa se il mese è sovra-impegnato.
  double get availableMoney {
    return MonthlyBalanceCalculator.availableMoney(
      carryover: monthlyCarryover,
      income: totalIncome,
      paidExpenses: totalExpenses,
      plannedExpenses: monthlyPlanningCommitment,
      longTermCommitments: annualPlanningCommitment,
      savingsGoal: savingsGoal,
    );
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
    final availableResources = totalIncome + monthlyCarryover;

    if (availableResources <= 0) return 0;

    final percentage = totalAssignedMoney / availableResources;

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

  String formatMoney(double value) {
    return AppCurrencyController.instance.format(value);
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return AppLanguageController.instance.isEnglish
        ? '$month/$day'
        : '$day/$month';
  }

  void openCategoryTransactions(String category) {
    if (category == _savingsAnalysisKey) return;

    List<FinanceTransaction> filterForCategory() => transactions
        .where((t) => !t.isIncome && t.category == category)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => StatefulBuilder(
          builder: (statefulContext, setLocalState) {
            final categoryTransactions = filterForCategory();

            return Scaffold(
              appBar: AppBar(
                title: Text(analysisCategoryLabel(category)),
              ),
              body: categoryTransactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l('Nessuna transazione in questa categoria questo mese.'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: categoryTransactions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: HomeColors.of(statefulContext).divider,
                      ),
                      itemBuilder: (itemContext, i) => TransactionItem(
                        transaction: categoryTransactions[i],
                        formattedAmount:
                            formatMoney(categoryTransactions[i].amount),
                        formattedDate:
                            formatDate(categoryTransactions[i].date),
                        categoryIcon:
                            categoryIcon(categoryTransactions[i].category),
                        categoryColor:
                            categoryColor(categoryTransactions[i].category),
                        onTap: () async {
                          await showTransactionActions(
                            categoryTransactions[i],
                          );
                          // Rilegge le transazioni aggiornate dopo una
                          // modifica o eliminazione, così questa lista non
                          // resta con dati superati finché non si torna
                          // indietro e la si riapre.
                          setLocalState(() {});
                        },
                      ),
                    ),
            );
          },
        ),
      ),
    );
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
                  'Movimento aggiunto · Disponibile ${formatMoney(availableMoney)}',
                  'Transaction added · Available ${formatMoney(availableMoney)}',
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

  Future<void> showCarryoverInfo() async {
    await showInfo(
      title: l('Saldo mese precedente'),
      message: le(
        'È il Disponibile del mese scorso, positivo o negativo, riportato automaticamente all\'inizio di questo mese. Si aggiorna da solo: per modificarlo devi correggere i movimenti del mese di provenienza, non puoi cambiarlo da qui.',
        'This is last month\'s Available balance, positive or negative, carried over automatically at the start of this month. It updates on its own: to change it you need to fix the transactions in the month it came from, you can\'t edit it here.',
      ),
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
        'Budget giornaliero ${formatMoney(dailySpendingLimit)}',
        'Daily budget ${formatMoney(dailySpendingLimit)}',
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
                            message: le(
                              'È quello che ti resta davvero da spendere dopo aver considerato ciò che è rimasto, in positivo o in negativo, dal mese precedente, le spese già fatte, quelle da pagare, i soldi da mettere da parte per le scadenze a lungo termine e il tuo obiettivo di risparmio.',
                              'It is what you can actually spend after accounting for the positive or negative amount carried over from the previous month, expenses already paid and still due, money set aside for long-term expenses, and your savings goal.',
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
                    formatMoney(value),
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
                value: formatMoney(totalIncome),
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFF119B6B),
                iconBackground: const Color(0xFFE1F5EC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OverviewCard(
                title: l('Uscite'),
                value: formatMoney(monthlyOutgoings),
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
                value: formatMoney(savingsGoal),
                icon: Icons.savings_outlined,
                accentColor: const Color(0xFF287AD6),
                iconBackground: const Color(0xFFE5F0FC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OverviewCard(
                title: l('Scadenze a lungo termine'),
                value: formatMoney(annualPlanningCommitment),
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
    final hc = HomeColors.of(context);
    final teal = hc.teal;
    final analysis = _buildAnalysisSnapshot();

    return Scaffold(
      backgroundColor: hc.pageBackground,
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
        backgroundColor: hc.pageBackground,
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Text(
          'Liblo',
          style: TextStyle(
            color: teal,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: hc.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: hc.borderAlt),
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
              icon: Icon(
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
            else if (hasLoadError)
              SizedBox(
                height: 480,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: hc.textSecondaryAlt,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l('Non riesco a caricare i tuoi dati'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          le(
                            'Può essere un problema temporaneo, ad esempio durante la sincronizzazione con iCloud. Riprova tra poco.',
                            'This might be a temporary issue, for example during iCloud sync. Try again shortly.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: hc.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                            });
                            loadSelectedMonthData();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(l('Riprova')),
                        ),
                      ],
                    ),
                  ),
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
                  formatMoney: formatMoney,
                  onTouched: (index) {
                    setState(() {
                      touchedCategoryIndex = index;
                    });
                  },
                  onSliceTap: (index) {
                    if (index >= 0 && index < analysis.entries.length) {
                      openCategoryTransactions(analysis.entries[index].key);
                    }
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
                formatMoney: formatMoney,
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
                carryoverAmount:
                    monthlyCarryover != 0 ? monthlyCarryover : null,
                carryoverFormattedAmount:
                    formatMoney(monthlyCarryover.abs()),
                onCarryoverTap: showCarryoverInfo,
                showFirstTransactionPrompt:
                    !hasAnyTransactionsEver && transactions.isEmpty,
                onAddFirstTransaction:
                    isCurrentMonth ? addTransaction : null,
                isSearching: isSearching,
                onToggleSearch: toggleSearch,
                searchController: searchController,
                onSearchQueryChanged: onSearchQueryChanged,
                searchResults: searchResults,
                searchLoading: searchLoading,
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
    final hc = HomeColors.of(context);
    final teal = hc.teal;

    Widget arrowButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return Material(
        color: hc.cardBackground,
        shape: const CircleBorder(),
        elevation: onPressed == null ? 0 : 1,
        shadowColor: const Color(0x14000000),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed == null
              ? hc.mutedFill
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
                style: TextStyle(
                  color: hc.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (!isCurrentMonth) ...[
                const SizedBox(height: 2),
                Text(
                  l('Storico mensile'),
                  style: TextStyle(
                    color: hc.textMuted,
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
    final hc = HomeColors.of(context);

    return Container(
      height: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: hc.border),
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
                        style: TextStyle(
                          color: hc.textPrimaryDeep,
                          fontSize: 12.5,
                          height: 1.12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onInfo != null)
                      InkWell(
                        onTap: onInfo,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: hc.textSecondaryDim,
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
  final String Function(double value) formatMoney;
  final ValueChanged<int> onTouched;
  final ValueChanged<int>? onSliceTap;

  const SpendingAnalysisCard({
    super.key,
    required this.entries,
    required this.totalAmount,
    required this.touchedIndex,
    required this.pieSections,
    required this.categoryColor,
    required this.categoryLabel,
    required this.formatMoney,
    required this.onTouched,
    this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);
    String centerTitle = l('Totale destinato');
    String centerValue = formatMoney(totalAmount);

    if (touchedIndex >= 0 && touchedIndex < entries.length) {
      centerTitle = categoryLabel(entries[touchedIndex].key);
      centerValue = formatMoney(entries[touchedIndex].value);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hc.border),
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
          Text(
            l('Analisi spese'),
            style: TextStyle(
              color: hc.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
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
                                  final touchedIndex = response
                                      ?.touchedSection
                                      ?.touchedSectionIndex;

                                  final isReleaseEvent =
                                      event is FlTapUpEvent ||
                                          event is FlPanEndEvent ||
                                          event is FlLongPressEnd;

                                  if (isReleaseEvent && touchedIndex != null) {
                                    onSliceTap?.call(touchedIndex);
                                  }

                                  if (!event.isInterestedForInteractions ||
                                      touchedIndex == null) {
                                    onTouched(-1);
                                    return;
                                  }

                                  onTouched(touchedIndex);
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
                                  style: TextStyle(
                                    color: hc.textMutedAlt,
                                    fontSize: 8.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    centerValue,
                                    style: TextStyle(
                                      color: hc.textPrimaryDeep,
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
                            amount: formatMoney(entries[i].value),
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
    final hc = HomeColors.of(context);

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
              style: TextStyle(
                color: hc.textPrimaryAlt,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(percentage * 100).round()}%',
            style: TextStyle(
              color: hc.textSecondaryDim,
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
              style: TextStyle(
                color: hc.textPrimaryDeep,
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
  final String Function(double value) formatMoney;
  final String Function(DateTime date) formatDate;
  final IconData Function(String category) categoryIcon;
  final Color Function(String category) categoryColor;
  final VoidCallback? onToggleAll;
  final ValueChanged<FinanceTransaction> onTransactionTap;
  final double? carryoverAmount;
  final String? carryoverFormattedAmount;
  final VoidCallback? onCarryoverTap;
  final bool showFirstTransactionPrompt;
  final VoidCallback? onAddFirstTransaction;
  final bool isSearching;
  final VoidCallback onToggleSearch;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchQueryChanged;
  final List<FinanceTransaction> searchResults;
  final bool searchLoading;

  const RecentTransactionsCard({
    super.key,
    required this.title,
    required this.transactions,
    required this.showAll,
    required this.formatMoney,
    required this.formatDate,
    required this.categoryIcon,
    required this.categoryColor,
    required this.onToggleAll,
    required this.onTransactionTap,
    this.carryoverAmount,
    this.carryoverFormattedAmount,
    this.onCarryoverTap,
    this.showFirstTransactionPrompt = false,
    this.onAddFirstTransaction,
    required this.isSearching,
    required this.onToggleSearch,
    required this.searchController,
    required this.onSearchQueryChanged,
    required this.searchResults,
    required this.searchLoading,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hc.border),
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
            child: isSearching
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          onChanged: onSearchQueryChanged,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: le(
                              'Cerca per descrizione o categoria',
                              'Search by description or category',
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onToggleSearch,
                        icon: const Icon(Icons.close_rounded),
                        color: hc.iconMuted,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: hc.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onToggleSearch,
                        icon: const Icon(Icons.search_rounded),
                        color: hc.teal,
                        tooltip: le('Cerca nello storico', 'Search history'),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (onToggleAll != null)
                        TextButton(
                          onPressed: onToggleAll,
                          style: TextButton.styleFrom(
                            foregroundColor: hc.teal,
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
          if (isSearching)
            _SearchResultsSection(
              query: searchController.text,
              results: searchResults,
              loading: searchLoading,
              formatMoney: formatMoney,
              formatDate: formatDate,
              categoryIcon: categoryIcon,
              categoryColor: categoryColor,
              onTransactionTap: onTransactionTap,
            )
          else ...[
            if (carryoverAmount != null) ...[
              CarryoverItem(
                amount: carryoverAmount!,
                formattedAmount: carryoverFormattedAmount ??
                    formatMoney(carryoverAmount!.abs()),
                onTap: onCarryoverTap,
              ),
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: hc.divider,
              ),
            ],
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: EmptyTransactions(
                  compact: true,
                  showFirstPrompt: showFirstTransactionPrompt,
                  onAddTransaction: onAddFirstTransaction,
                ),
              )
            else
              for (int i = 0; i < transactions.length; i++) ...[
                TransactionItem(
                  transaction: transactions[i],
                  formattedAmount: formatMoney(transactions[i].amount),
                  formattedDate: formatDate(transactions[i].date),
                  categoryIcon: categoryIcon(transactions[i].category),
                  categoryColor: categoryColor(transactions[i].category),
                  onTap: () => onTransactionTap(transactions[i]),
                ),
                if (i != transactions.length - 1)
                  Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: hc.divider,
                  ),
            ],
            if (transactions.isNotEmpty) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SearchResultsSection extends StatelessWidget {
  final String query;
  final List<FinanceTransaction> results;
  final bool loading;
  final String Function(double) formatMoney;
  final String Function(DateTime) formatDate;
  final IconData Function(String) categoryIcon;
  final Color Function(String) categoryColor;
  final ValueChanged<FinanceTransaction> onTransactionTap;

  const _SearchResultsSection({
    required this.query,
    required this.results,
    required this.loading,
    required this.formatMoney,
    required this.formatDate,
    required this.categoryIcon,
    required this.categoryColor,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 22),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (query.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        child: Text(
          le(
            'Scrivi qualcosa per cercare tra tutti i tuoi movimenti, non solo quelli di questo mese.',
            'Type something to search across all your transactions, not just this month.',
          ),
          style: TextStyle(
            color: hc.textSecondary,
            fontSize: 12.5,
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        child: Text(
          l('Nessun risultato.'),
          style: TextStyle(
            color: hc.textSecondary,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < results.length; i++) ...[
          TransactionItem(
            transaction: results[i],
            formattedAmount: formatMoney(results[i].amount),
            formattedDate: formatDate(results[i].date),
            categoryIcon: categoryIcon(results[i].category),
            categoryColor: categoryColor(results[i].category),
            onTap: () => onTransactionTap(results[i]),
          ),
          if (i != results.length - 1)
            Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
              color: hc.divider,
            ),
        ],
        const SizedBox(height: 8),
      ],
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
    final hc = HomeColors.of(context);
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? hc.green : hc.textPrimaryStrong;

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
                color: categoryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIcon,
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
                    style: TextStyle(
                      color: hc.textPrimaryAlt,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${localizedCategory(transaction.category)} · $formattedDate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hc.textSecondary,
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

class CarryoverItem extends StatelessWidget {
  final double amount;
  final String formattedAmount;
  final VoidCallback? onTap;

  const CarryoverItem({
    super.key,
    required this.amount,
    required this.formattedAmount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);
    final isPositive = amount >= 0;
    final amountColor = isPositive ? hc.green : hc.textPrimaryStrong;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(
                color: Color(0xFF5E78A8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync_alt_rounded,
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
                    l('Saldo mese precedente'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hc.textPrimaryAlt,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l('Riportato automaticamente'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hc.textSecondary,
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
                '${isPositive ? '+' : '-'} $formattedAmount',
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
    final hc = HomeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hc.border),
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
            child: Icon(
              Icons.donut_large_outlined,
              color: hc.teal,
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
            style: TextStyle(
              color: hc.textSecondary,
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
  final bool showFirstPrompt;
  final VoidCallback? onAddTransaction;

  const EmptyTransactions({
    super.key,
    this.compact = false,
    this.showFirstPrompt = false,
    this.onAddTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 22 : 32,
      ),
      decoration: compact
          ? null
          : BoxDecoration(
              color: hc.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: hc.border),
            ),
      child: Column(
        children: [
          Icon(
            showFirstPrompt
                ? Icons.celebration_outlined
                : Icons.receipt_long_outlined,
            size: 36,
            color: hc.textSecondaryAlt,
          ),
          const SizedBox(height: 10),
          Text(
            showFirstPrompt
                ? l('Inserisci il tuo primo movimento')
                : l('Nessun movimento'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            showFirstPrompt
                ? l('Registra un\'entrata o una spesa per iniziare a vedere il tuo Disponibile.')
                : l('Nessun movimento registrato per questo mese.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hc.textSecondary,
              fontSize: 12.5,
            ),
          ),
          if (showFirstPrompt && onAddTransaction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddTransaction,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(l('Aggiungi movimento')),
            ),
          ],
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
