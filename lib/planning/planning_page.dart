import 'package:flutter/material.dart';

import '../annual_expenses/annual_expense.dart';
import '../annual_expenses/annual_expenses_page.dart';
import '../budget_dialog.dart';
import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../home_page.dart' show HomeColors;
import '../localization/app_language.dart';
import '../planned_expenses/planned_expense.dart';
import '../planned_expenses/planned_expenses_page.dart';
import '../recurring_expenses/recurring_expense.dart';
import '../recurring_expenses/recurring_expenses_page.dart';

class PlanningPage extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;
  final VoidCallback onDataChanged;

  const PlanningPage({
    super.key,
    required this.refreshNotifier,
    required this.onDataChanged,
  });

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  double savingsGoal = 0;
  List<PlannedExpense> monthlyExpenses = [];
  List<AnnualExpense> annualExpenses = [];
  List<RecurringExpense> recurringExpenses = [];

  bool isLoading = true;
  late DateTime selectedMonth;

  List<String> get monthNames => AppLanguageController.instance.monthNames;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);

    widget.refreshNotifier.addListener(_externalRefresh);
    loadData();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_externalRefresh);
    super.dispose();
  }

  void _externalRefresh() {
    loadData();
  }

  String formatMoney(double value) {
    return AppCurrencyController.instance.format(value);
  }

  String get selectedMonthLabel {
    return '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  double get monthlyCommitment {
    return monthlyExpenses
        .where((expense) => !expense.isPaid)
        .fold(
          0.0,
          (sum, expense) => sum + expense.amount,
        );
  }

  double get annualCommitment {
    return annualExpenses.fold(
      0.0,
      (sum, expense) =>
          sum + expense.commitmentForMonth(selectedMonth),
    );
  }

  double get recurringCommitmentForSelectedMonth {
    return recurringExpenses
        .where(
          (expense) => expense.isActiveForMonth(selectedMonth),
        )
        .fold(
          0.0,
          (sum, expense) => sum + expense.amount,
        );
  }

  int get selectedMonthRecurringCount {
    return recurringExpenses
        .where(
          (expense) => expense.isActiveForMonth(selectedMonth),
        )
        .length;
  }

  double get plannedExpenses {
    return monthlyCommitment + annualCommitment;
  }

  double get totalProtected {
    return plannedExpenses + savingsGoal;
  }

  List<_PlanningDeadline> get upcomingDeadlines {
    final start = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final deadlines = <_PlanningDeadline>[];

    for (final expense in monthlyExpenses) {
      if (expense.isPaid) continue;

      deadlines.add(
        _PlanningDeadline(
          title: expense.name,
          amount: expense.amount,
          dueDate: expense.dueDate,
          kind: expense.isRecurring ? l('Ricorrente') : le('Mensile', 'Monthly'),
          icon: expense.isRecurring
              ? Icons.repeat_rounded
              : Icons.receipt_long_outlined,
        ),
      );
    }

    for (final expense in annualExpenses) {
      if (expense.isPaid || expense.dueMonth.isBefore(start)) {
        continue;
      }

      deadlines.add(
        _PlanningDeadline(
          title: expense.name,
          amount: expense.amount,
          dueDate: expense.dueDate,
          kind: le('Lungo termine', 'Long-term'),
          icon: Icons.event_repeat_outlined,
        ),
      );
    }

    deadlines.sort(
      (a, b) => a.dueDate.compareTo(b.dueDate),
    );

    return deadlines.take(5).toList();
  }

  Future<void> loadData() async {
    final monthToLoad = selectedMonth;

    final budget = await DatabaseService.instance.getMonthlyBudget(
      monthToLoad,
    );

    final monthly =
        await DatabaseService.instance.getPlannedExpensesForMonth(
      monthToLoad,
    );

    final annual =
        await DatabaseService.instance.getAnnualExpenses();

    final recurring =
        await DatabaseService.instance.getRecurringExpenses();

    if (!mounted) return;

    if (selectedMonth.year != monthToLoad.year ||
        selectedMonth.month != monthToLoad.month) {
      return;
    }

    setState(() {
      savingsGoal = budget['savingsGoal'] ?? 0;
      monthlyExpenses = monthly;
      annualExpenses = annual;
      recurringExpenses = recurring;
      isLoading = false;
    });
  }

  Future<void> previousMonth() async {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month - 1,
        1,
      );
      isLoading = true;
    });

    await loadData();
  }

  Future<void> nextMonth() async {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        1,
      );
      isLoading = true;
    });

    await loadData();
  }

  Future<void> editSavingsGoal() async {
    final result = await showDialog<BudgetResult>(
      context: context,
      builder: (dialogContext) {
        return BudgetDialog(
          currentSavingsGoal: savingsGoal,
        );
      },
    );

    if (result == null) return;

    await DatabaseService.instance.saveMonthlyBudget(
      selectedMonth,
      fixedExpenses: 0,
      savingsGoal: result.savingsGoal,
    );

    widget.onDataChanged();
    await loadData();
  }

  Future<void> openMonthlyExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlannedExpensesPage(
          month: selectedMonth,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );

    await loadData();
  }

  Future<void> openRecurringExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecurringExpensesPage(
          selectedMonth: selectedMonth,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );

    await loadData();
  }

  Future<void> openAnnualExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnualExpensesPage(
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );

    await loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final homeColors = HomeColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l('Pianifica'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l('Organizza ciò che devi pagare e quanto vuoi mettere da parte.'),
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: homeColors.cardBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: homeColors.border,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: previousMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      selectedMonthLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (isLoading)
              const SizedBox(
                height: 420,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l('FONDI DA METTERE DA PARTE'),
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(totalProtected),
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      le(
                        '${formatMoney(plannedExpenses)} per spese · ${formatMoney(savingsGoal)} da mettere da parte',
                        '${formatMoney(plannedExpenses)} for expenses · ${formatMoney(savingsGoal)} set aside',
                      ),
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l('Piano del mese'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: homeColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: homeColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    PlanningNavigationRow(
                      icon: Icons.receipt_long_outlined,
                      title: l('Spese previste del mese'),
                      subtitle: le(
                          '${monthlyExpenses.where((expense) => !expense.isPaid).length} ancora da pagare',
                          '${monthlyExpenses.where((expense) => !expense.isPaid).length} still to pay',
                        ),
                      value: formatMoney(monthlyCommitment),
                      onTap: openMonthlyExpenses,
                    ),
                    const Divider(
                      height: 1,
                      indent: 56,
                    ),
                    PlanningNavigationRow(
                      icon: Icons.repeat_rounded,
                      title: l('Spese ricorrenti'),
                      subtitle: le(
                        '$selectedMonthRecurringCount nel mese · incluse nelle spese previste',
                        '$selectedMonthRecurringCount this month · included in planned expenses',
                      ),
                      value: formatMoney(recurringCommitmentForSelectedMonth),
                      onTap: openRecurringExpenses,
                    ),
                    const Divider(
                      height: 1,
                      indent: 56,
                    ),
                    PlanningNavigationRow(
                      icon: Icons.savings_outlined,
                      title: l('Obiettivo di risparmio'),
                      subtitle: l('Soldi che vuoi mettere da parte'),
                      value: formatMoney(savingsGoal),
                      onTap: editSavingsGoal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l('Scadenze a lungo termine'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l('Liblo divide ogni spesa tra i mesi prima della scadenza, così sai quanto mettere da parte ogni mese.'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: openAnnualExpenses,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: homeColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: homeColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.event_repeat_outlined,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l('Scadenze a lungo termine'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              le(
                                '${annualExpenses.where((expense) => !expense.isPaid).length} attive',
                                '${annualExpenses.where((expense) => !expense.isPaid).length} active',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(annualCommitment),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            l('questo mese'),
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l('Prossime scadenze'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (upcomingDeadlines.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: homeColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: homeColors.border,
                    ),
                  ),
                  child: Text(
                    l('Nessuna scadenza pianificata.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: homeColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: homeColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < upcomingDeadlines.length; i++) ...[
                        _PlanningDeadlineRow(
                          deadline: upcomingDeadlines[i],
                          formatMoney: formatMoney,
                          monthNames: monthNames,
                        ),
                        if (i != upcomingDeadlines.length - 1)
                          const Divider(
                            height: 1,
                            indent: 64,
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

class PlanningNavigationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const PlanningNavigationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningDeadline {
  final String title;
  final double amount;
  final DateTime dueDate;
  final String kind;
  final IconData icon;

  const _PlanningDeadline({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.kind,
    required this.icon,
  });
}

class _PlanningDeadlineRow extends StatelessWidget {
  final _PlanningDeadline deadline;
  final String Function(double) formatMoney;
  final List<String> monthNames;

  const _PlanningDeadlineRow({
    required this.deadline,
    required this.formatMoney,
    required this.monthNames,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              deadline.icon,
              size: 19,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deadline.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLanguageController.instance.isEnglish
                      ? '${deadline.kind} · ${monthNames[deadline.dueDate.month - 1]} ${deadline.dueDate.day}, ${deadline.dueDate.year}'
                      : '${deadline.kind} · ${deadline.dueDate.day} ${monthNames[deadline.dueDate.month - 1].toLowerCase()} ${deadline.dueDate.year}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(deadline.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
