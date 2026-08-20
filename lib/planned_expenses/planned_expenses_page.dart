import 'package:flutter/material.dart';

import '../categories/category_selector.dart';
import '../database/database_service.dart';
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

  final List<String> monthNames = const [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

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

  String formatEuro(double value) {
    return '€ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String formatDate(DateTime date) {
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String get monthLabel {
    final name = monthNames[widget.month.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${widget.month.year}';
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
          title: const Text('Registra pagamento'),
          content: Text(
            'Vuoi registrare "${expense.name}" come spesa pagata oggi per ${formatEuro(expense.amount)}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Registra'),
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
            ? '\n\nIl movimento già registrato resterà nello storico delle spese.'
            : '';

        return AlertDialog(
          title: const Text('Eliminare la spesa prevista?'),
          content: Text(
            'Vuoi eliminare "${expense.name}" dalla pianificazione?$paidNotice',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Elimina'),
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
                  title: const Text('Modifica'),
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
                  title: const Text('Registra pagamento'),
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
                  title: const Text('Gestisci ricorrenza'),
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
                    'Elimina',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Spese previste · $monthLabel',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
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
                          'ANCORA DA PAGARE',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatEuro(unpaidTotal),
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${formatEuro(paidTotal)} già registrate come pagate',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.80),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Voci del mese',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Le ricorrenti vengono create automaticamente. Tocca una voce per le azioni disponibili.',
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
                            Icons.receipt_long_outlined,
                            size: 42,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Nessuna spesa prevista',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aggiungi affitto, telefono, palestra o qualsiasi altra spesa che sai già di dover sostenere nel mese.',
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
                              child: PlannedExpenseRow(
                                expense: expenses[i],
                                formatEuro: formatEuro,
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
  final String Function(double) formatEuro;
  final String Function(DateTime) formatDate;

  const PlannedExpenseRow({
    super.key,
    required this.expense,
    required this.formatEuro,
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
                      formatEuro(expense.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  expense.isPaid
                      ? '${expense.category} · ${expense.isRecurring ? 'Ricorrente · ' : ''}Pagata'
                      : expense.isRecurring
                          ? '${expense.category} · Ricorrente · Scadenza ${formatDate(expense.dueDate)}'
                          : '${expense.category} · Scadenza ${formatDate(expense.dueDate)}',
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
    return '$day/$month/${date.year}';
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
      helpText: 'Seleziona la scadenza',
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
        const SnackBar(
          content: Text('Inserisci nome e importo validi'),
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
            ? 'Modifica spesa prevista'
            : 'Nuova spesa prevista',
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Affitto',
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
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  prefixText: '€ ',
                  hintText: 'Es. 500',
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
                  decoration: const InputDecoration(
                    labelText: 'Scadenza',
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
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: save,
          child: Text(
            isEditing ? 'Salva modifiche' : 'Aggiungi',
          ),
        ),
      ],
    );
  }
}
