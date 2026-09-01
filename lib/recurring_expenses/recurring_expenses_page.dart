import 'package:flutter/material.dart';

import '../categories/category_selector.dart';
import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../localization/app_language.dart';
import 'recurring_expense.dart';

enum RecurringExpenseAction {
  edit,
  toggleActive,
  delete,
}

class RecurringExpensesPage extends StatefulWidget {
  final DateTime selectedMonth;
  final VoidCallback? onDataChanged;

  const RecurringExpensesPage({
    super.key,
    required this.selectedMonth,
    this.onDataChanged,
  });

  @override
  State<RecurringExpensesPage> createState() =>
      _RecurringExpensesPageState();
}

class _RecurringExpensesPageState
    extends State<RecurringExpensesPage> {
  List<RecurringExpense> expenses = [];
  bool isLoading = true;

  List<String> get monthNames =>
      AppLanguageController.instance.monthNamesForDates;

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final saved =
        await DatabaseService.instance.getRecurringExpenses();

    if (!mounted) return;

    setState(() {
      expenses = saved;
      isLoading = false;
    });
  }

  String formatMoney(double value) {
    return AppCurrencyController.instance.format(value);
  }

  String formatMonth(DateTime date) {
    final name = monthNames[date.month - 1];
    return AppLanguageController.instance.isEnglish
        ? '$name ${date.year}'
        : '${name[0].toUpperCase()}${name.substring(1)} ${date.year}';
  }

  double get selectedMonthTotal {
    return expenses
        .where(
          (expense) => expense.isActiveForMonth(widget.selectedMonth),
        )
        .fold(
          0.0,
          (sum, expense) => sum + expense.amount,
        );
  }

  int get activeCount {
    return expenses.where((expense) => expense.isActive).length;
  }

  Future<void> addExpense() async {
    final result = await showDialog<RecurringExpense>(
      context: context,
      builder: (context) {
        return RecurringExpenseDialog(
          defaultStartMonth: widget.selectedMonth,
        );
      },
    );

    if (result == null) return;

    await DatabaseService.instance.insertRecurringExpense(result);
    await DatabaseService.instance.ensureRecurringExpensesForMonth(
      widget.selectedMonth,
    );

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> editExpense(RecurringExpense expense) async {
    final result = await showDialog<RecurringExpense>(
      context: context,
      builder: (context) {
        return RecurringExpenseDialog(
          defaultStartMonth: widget.selectedMonth,
          expense: expense,
        );
      },
    );

    if (result == null) return;

    await DatabaseService.instance.updateRecurringExpense(result);
    await DatabaseService.instance.ensureRecurringExpensesForMonth(
      widget.selectedMonth,
    );

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> toggleExpense(RecurringExpense expense) async {
    if (expense.id == null) return;

    final updated = expense.copyWith(
      isActive: !expense.isActive,
    );

    await DatabaseService.instance.updateRecurringExpense(updated);
    await DatabaseService.instance.ensureRecurringExpensesForMonth(
      widget.selectedMonth,
    );

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> deleteExpense(RecurringExpense expense) async {
    if (expense.id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l('Eliminare la ricorrenza?')),
          content: Text(
            le(
              'Vuoi eliminare "${expense.name}" dalle spese ricorrenti? I pagamenti già registrati resteranno nello storico.',
              'Delete "${expense.name}" from recurring expenses? Payments already recorded will stay in your history.',
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
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
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

    await DatabaseService.instance.deleteRecurringExpense(
      expense.id!,
    );

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> showActions(RecurringExpense expense) async {
    final action = await showModalBottomSheet<RecurringExpenseAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final errorColor = Theme.of(sheetContext).colorScheme.error;

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
                    RecurringExpenseAction.edit,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  expense.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                title: Text(
                  expense.isActive
                      ? l('Metti in pausa')
                      : l('Riattiva'),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    RecurringExpenseAction.toggleActive,
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
                    RecurringExpenseAction.delete,
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
      case RecurringExpenseAction.edit:
        await editExpense(expense);
        break;
      case RecurringExpenseAction.toggleActive:
        await toggleExpense(expense);
        break;
      case RecurringExpenseAction.delete:
        await deleteExpense(expense);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l('Spese ricorrenti'),
          style: TextStyle(
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
                          le(
                            'RICORRENTI IN ${formatMonth(widget.selectedMonth).toUpperCase()}',
                            'RECURRING IN ${formatMonth(widget.selectedMonth).toUpperCase()}',
                          ),
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatMoney(selectedMonthTotal),
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          le(
                            '$activeCount ricorrenze attive complessivamente',
                            '$activeCount active recurring expenses overall',
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
                    l('Le tue ricorrenze'),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l('Affitto, telefono, palestra, streaming e altre spese che si ripetono ogni mese.'),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE9EAF0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 42,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l('Nessuna spesa ricorrente'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l('Aggiungi una spesa una sola volta e l’app la inserirà automaticamente nei mesi successivi.'),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE9EAF0),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < expenses.length; i++) ...[
                            InkWell(
                              onTap: () {
                                showActions(expenses[i]);
                              },
                              child: RecurringExpenseRow(
                                expense: expenses[i],
                                formatMoney: formatMoney,
                                formatMonth: formatMonth,
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

class RecurringExpenseRow extends StatelessWidget {
  final RecurringExpense expense;
  final String Function(double) formatMoney;
  final String Function(DateTime) formatMonth;

  const RecurringExpenseRow({
    super.key,
    required this.expense,
    required this.formatMoney,
    required this.formatMonth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final endText = expense.endMonth == null
        ? l('senza scadenza finale')
        : le(
            'fino a ${formatMonth(expense.endMonth!)}',
            'until ${formatMonth(expense.endMonth!)}',
          );

    return Opacity(
      opacity: expense.isActive ? 1 : 0.55,
      child: Padding(
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
                color: expense.isActive
                    ? colors.primaryContainer
                    : const Color(0xFFF0F1F4),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                expense.isActive
                    ? Icons.repeat_rounded
                    : Icons.pause_rounded,
                color: expense.isActive
                    ? colors.primary
                    : colors.onSurfaceVariant,
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
                    expense.isActive
                        ? le(
                            '${localizedCategory(expense.category)} · ogni ${expense.dayOfMonth} del mese · $endText',
                            '${localizedCategory(expense.category)} · every month on day ${expense.dayOfMonth} · $endText',
                          )
                        : '${localizedCategory(expense.category)} · ${l('In pausa')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
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

class RecurringExpenseDialog extends StatefulWidget {
  final DateTime defaultStartMonth;
  final RecurringExpense? expense;

  const RecurringExpenseDialog({
    super.key,
    required this.defaultStartMonth,
    this.expense,
  });

  @override
  State<RecurringExpenseDialog> createState() =>
      _RecurringExpenseDialogState();
}

class _RecurringExpenseDialogState
    extends State<RecurringExpenseDialog> {
  late String name;
  late String amountText;
  late String category;
  late String dayText;
  late DateTime startMonth;
  late DateTime? endMonth;
  late bool hasEndMonth;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    name = expense?.name ?? '';
    amountText = expense == null
        ? ''
        : expense.amount.toStringAsFixed(2);
    category = expense?.category ?? 'Altro';
    dayText = (expense?.dayOfMonth ?? DateTime.now().day).toString();
    startMonth = DateTime(
      (expense?.startMonth ?? widget.defaultStartMonth).year,
      (expense?.startMonth ?? widget.defaultStartMonth).month,
      1,
    );
    endMonth = expense?.endMonth == null
        ? null
        : DateTime(
            expense!.endMonth!.year,
            expense.endMonth!.month,
            1,
          );
    hasEndMonth = endMonth != null;
  }

  String formatMonth(DateTime date) {
    final names = AppLanguageController.instance.monthNames;
    return '${names[date.month - 1]} ${date.year}';
  }

  Future<DateTime?> selectMonth({
    required DateTime initialMonth,
    required String helpText,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initialMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: helpText,
    );

    if (selected == null) return null;

    return DateTime(
      selected.year,
      selected.month,
      1,
    );
  }

  Future<void> selectStartMonth() async {
    final selected = await selectMonth(
      initialMonth: startMonth,
      helpText: l('Seleziona il mese di inizio'),
    );

    if (selected == null || !mounted) return;

    setState(() {
      startMonth = selected;

      if (endMonth != null && endMonth!.isBefore(startMonth)) {
        endMonth = startMonth;
      }
    });
  }

  Future<void> selectEndMonth() async {
    final selected = await selectMonth(
      initialMonth: endMonth ?? startMonth,
      helpText: l('Seleziona il mese finale'),
    );

    if (selected == null || !mounted) return;

    setState(() {
      endMonth = selected;
      hasEndMonth = true;
    });
  }

  void save() {
    final cleanName = name.trim();
    final amount = double.tryParse(
      amountText.trim().replaceAll(',', '.'),
    );
    final day = int.tryParse(dayText.trim());

    if (cleanName.isEmpty ||
        amount == null ||
        amount <= 0 ||
        day == null ||
        day < 1 ||
        day > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l('Inserisci nome, importo e giorno del mese validi')),
        ),
      );
      return;
    }

    if (hasEndMonth &&
        endMonth != null &&
        endMonth!.isBefore(startMonth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l('Il mese finale non può precedere quello iniziale')),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      RecurringExpense(
        id: widget.expense?.id,
        name: cleanName,
        amount: amount,
        category: category,
        dayOfMonth: day,
        startMonth: startMonth,
        endMonth: hasEndMonth ? endMonth : null,
        isActive: widget.expense?.isActive ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEditing
            ? l('Modifica spesa ricorrente')
            : l('Nuova spesa ricorrente'),
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
                  hintText: l('Es. Netflix'),
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
                  labelText: l('Importo mensile'),
                  prefixText: AppCurrencyController.instance.inputPrefix,
                  hintText: l('Es. 12,99'),
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
              TextFormField(
                initialValue: dayText,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l('Giorno di scadenza'),
                  hintText: l('Es. 5'),
                  helperText: l('Se il mese ha meno giorni, useremo l’ultimo giorno disponibile.'),
                ),
                onChanged: (value) {
                  dayText = value;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: selectStartMonth,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l('A partire da'),
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    formatMonth(startMonth),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l('Imposta un mese finale')),
                subtitle: Text(
                  hasEndMonth && endMonth != null
                      ? le('Fino a ${formatMonth(endMonth!)}', 'Until ${formatMonth(endMonth!)}')
                      : l('La spesa continuerà ogni mese'),
                ),
                value: hasEndMonth,
                onChanged: (value) {
                  setState(() {
                    hasEndMonth = value;
                    if (value && endMonth == null) {
                      endMonth = startMonth;
                    }
                  });
                },
              ),
              if (hasEndMonth) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: selectEndMonth,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l('Mese finale'),
                      suffixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      formatMonth(endMonth ?? startMonth),
                    ),
                  ),
                ),
              ],
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
