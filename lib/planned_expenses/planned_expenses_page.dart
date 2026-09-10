import 'package:flutter/material.dart';

import '../categories/category_selector.dart';
import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../home_page.dart' show HomeColors;
import '../localization/app_language.dart';
import '../recurring_expenses/recurring_expenses_page.dart';
import 'planned_expense.dart';

enum PlannedExpenseAction {
  edit,
  pay,
  manageRecurring,
  delete,
}

class PlannedExpensesPage extends StatefulWidget {
  final DateTime month;
  final VoidCallback? onDataChanged;

  const PlannedExpensesPage({
    super.key,
    required this.month,
    this.onDataChanged,
  });

  @override
  State<PlannedExpensesPage> createState() => _PlannedExpensesPageState();
}

class _PlannedExpensesPageState extends State<PlannedExpensesPage> {
  List<PlannedExpense> expenses = [];
  bool isLoading = true;

  List<String> get monthNames =>
      AppLanguageController.instance.monthNamesForDates;

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final saved = await DatabaseService.instance.getPlannedExpensesForMonth(
      widget.month,
    );

    if (!mounted) return;

    setState(() {
      expenses = saved;
      isLoading = false;
    });
  }

  String formatMoney(double value) {
    return AppCurrencyController.instance.format(value);
  }

  String formatDate(DateTime date) {
    return AppLanguageController.instance.isEnglish
        ? '${monthNames[date.month - 1]} ${date.day}, ${date.year}'
        : '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String get monthLabel {
    final name = monthNames[widget.month.month - 1];
    return AppLanguageController.instance.isEnglish
        ? '$name ${widget.month.year}'
        : '${name[0].toUpperCase()}${name.substring(1)} ${widget.month.year}';
  }

  double get unpaidTotal {
    return expenses
        .where((expense) => !expense.isPaid)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double get paidTotal {
    return expenses
        .where((expense) => expense.isPaid)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<void> addExpense() async {
    final expense = await showDialog<PlannedExpense>(
      context: context,
      builder: (context) {
        return PlannedExpenseDialog(
          month: widget.month,
        );
      },
    );

    if (expense == null) return;

    await DatabaseService.instance.insertPlannedExpense(expense);

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> editExpense(PlannedExpense expense) async {
    if (expense.isPaid || expense.isRecurring) return;

    final updated = await showDialog<PlannedExpense>(
      context: context,
      builder: (context) {
        return PlannedExpenseDialog(
          month: widget.month,
          expense: expense,
        );
      },
    );

    if (updated == null) return;

    await DatabaseService.instance.updatePlannedExpense(updated);

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> payExpense(PlannedExpense expense) async {
    if (expense.isPaid) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l('Registra pagamento')),
          content: Text(
            le(
              'Vuoi registrare "${expense.name}" come spesa pagata oggi per ${formatMoney(expense.amount)}?',
              'Record "${expense.name}" as paid today for ${formatMoney(expense.amount)}?',
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
              child: Text(l('Registra')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await DatabaseService.instance.payPlannedExpense(
      expense,
      paymentDate: DateTime.now(),
    );

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> openRecurringExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecurringExpensesPage(
          selectedMonth: widget.month,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );

    await loadExpenses();
  }

  Future<void> deleteExpense(PlannedExpense expense) async {
    if (expense.id == null || expense.isRecurring) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final paidNotice = expense.isPaid
            ? le(
                '\n\nIl movimento già registrato resterà nello storico delle spese.',
                '\n\nThe transaction already recorded will stay in your history.',
              )
            : '';

        return AlertDialog(
          title: Text(l('Eliminare la spesa prevista?')),
          content: Text(
            le(
              'Vuoi eliminare "${expense.name}" dalla pianificazione?$paidNotice',
              'Delete "${expense.name}" from your plan?$paidNotice',
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(l('Elimina')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await DatabaseService.instance.deletePlannedExpense(expense.id!);

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> showActions(PlannedExpense expense) async {
    final action = await showModalBottomSheet<PlannedExpenseAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final errorColor = Theme.of(sheetContext).colorScheme.error;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!expense.isPaid && !expense.isRecurring)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l('Modifica')),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      PlannedExpenseAction.edit,
                    );
                  },
                ),
              if (!expense.isPaid)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(l('Registra pagamento')),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      PlannedExpenseAction.pay,
                    );
                  },
                ),
              if (expense.isRecurring)
                ListTile(
                  leading: const Icon(Icons.repeat_rounded),
                  title: Text(l('Gestisci ricorrenza')),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      PlannedExpenseAction.manageRecurring,
                    );
                  },
                ),
              if (!expense.isRecurring)
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
                      PlannedExpenseAction.delete,
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
      case PlannedExpenseAction.edit:
        await editExpense(expense);
        break;
      case PlannedExpenseAction.pay:
        await payExpense(expense);
        break;
      case PlannedExpenseAction.manageRecurring:
        await openRecurringExpenses();
        break;
      case PlannedExpenseAction.delete:
        await deleteExpense(expense);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hc = HomeColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          le('Spese previste · $monthLabel', 'Planned expenses · $monthLabel'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addExpense,
        icon: const Icon(Icons.add),
        label: Text(l('Aggiungi')),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          l('ANCORA DA PAGARE'),
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatMoney(unpaidTotal),
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          le(
                            '${formatMoney(paidTotal)} già registrate come pagate',
                            '${formatMoney(paidTotal)} already recorded as paid',
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
                    l('Voci del mese'),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l('Le ricorrenti vengono create automaticamente. Tocca una voce per le azioni disponibili.'),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (expenses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: hc.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hc.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 42,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l('Nessuna spesa prevista'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l('Aggiungi affitto, telefono, palestra o qualsiasi altra spesa che sai già di dover sostenere nel mese.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: hc.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hc.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < expenses.length; i++) ...[
                            InkWell(
                              onTap: () {
                                showActions(expenses[i]);
                              },
                              child: PlannedExpenseRow(
                                expense: expenses[i],
                                formatMoney: formatMoney,
                                formatDate: formatDate,
                              ),
                            ),
                            if (i != expenses.length - 1)
                              const Divider(
                                height: 1,
                                indent: 70,
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class PlannedExpenseRow extends StatelessWidget {
  final PlannedExpense expense;
  final String Function(double) formatMoney;
  final String Function(DateTime) formatDate;

  const PlannedExpenseRow({
    super.key,
    required this.expense,
    required this.formatMoney,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: expense.isPaid
                  ? const Color(0xFFE5F6EF)
                  : colors.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              expense.isPaid
                  ? Icons.check_rounded
                  : expense.isRecurring
                      ? Icons.repeat_rounded
                      : Icons.schedule_outlined,
              color: expense.isPaid
                  ? const Color(0xFF16865C)
                  : colors.primary,
              size: 20,
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
                        expense.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(expense.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  expense.isPaid
                      ? '${localizedCategory(expense.category)} · ${expense.isRecurring ? '${l('Ricorrente')} · ' : ''}${l('Pagata')}'
                      : expense.isRecurring
                          ? '${localizedCategory(expense.category)} · ${l('Ricorrente')} · ${l('Scadenza')} ${formatDate(expense.dueDate)}'
                          : '${localizedCategory(expense.category)} · ${l('Scadenza')} ${formatDate(expense.dueDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
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

class PlannedExpenseDialog extends StatefulWidget {
  final DateTime month;
  final PlannedExpense? expense;

  const PlannedExpenseDialog({
    super.key,
    required this.month,
    this.expense,
  });

  @override
  State<PlannedExpenseDialog> createState() => _PlannedExpenseDialogState();
}

class _PlannedExpenseDialogState extends State<PlannedExpenseDialog> {
  late String name;
  late String amountText;
  late String category;
  late DateTime dueDate;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    name = widget.expense?.name ?? '';
    amountText = widget.expense == null
        ? ''
        : widget.expense!.amount.toStringAsFixed(2);
    category = widget.expense?.category ?? 'Altro';
    dueDate = widget.expense?.dueDate ?? _defaultDueDate();
  }

  DateTime _defaultDueDate() {
    final now = DateTime.now();
    final lastDay = DateTime(
      widget.month.year,
      widget.month.month + 1,
      0,
    ).day;

    if (now.year == widget.month.year && now.month == widget.month.month) {
      final day = now.day > lastDay ? lastDay : now.day;
      return DateTime(widget.month.year, widget.month.month, day, 12);
    }

    return DateTime(widget.month.year, widget.month.month, 1, 12);
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return AppLanguageController.instance.isEnglish
        ? '$month/$day/${date.year}'
        : '$day/$month/${date.year}';
  }

  Future<void> selectDueDate() async {
    final firstDate = DateTime(
      widget.month.year,
      widget.month.month,
      1,
    );

    final lastDate = DateTime(
      widget.month.year,
      widget.month.month + 1,
      0,
    );

    final selected = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: l('Seleziona la scadenza'),
    );

    if (selected == null || !mounted) return;

    setState(() {
      dueDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        12,
      );
    });
  }

  void save() {
    final cleanName = name.trim();
    final amount = double.tryParse(
      amountText.trim().replaceAll(',', '.'),
    );

    if (cleanName.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l('Inserisci nome e importo validi')),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      PlannedExpense(
        id: widget.expense?.id,
        name: cleanName,
        amount: amount,
        category: category,
        dueDate: dueDate,
        isPaid: widget.expense?.isPaid ?? false,
        paidTransactionId: widget.expense?.paidTransactionId,
        recurringExpenseId: widget.expense?.recurringExpenseId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEditing
            ? l('Modifica spesa prevista')
            : l('Nuova spesa prevista'),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: InputDecoration(
                  labelText: l('Nome'),
                  hintText: l('Es. Affitto'),
                ),
                onChanged: (value) {
                  name = value;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: amountText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l('Importo'),
                  prefixText: AppCurrencyController.instance.inputPrefix,
                  hintText: l('Es. 500'),
                ),
                onChanged: (value) {
                  amountText = value;
                },
              ),
              const SizedBox(height: 16),
              CategorySelector(
                selectedCategory: category,
                includeInactiveSelected: isEditing,
                onChanged: (value) {
                  setState(() {
                    category = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: selectDueDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l('Scadenza'),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    formatDate(dueDate),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(l('Annulla')),
        ),
        FilledButton(
          onPressed: save,
          child: Text(
            isEditing ? l('Salva modifiche') : l('Aggiungi'),
          ),
        ),
      ],
    );
  }
}
