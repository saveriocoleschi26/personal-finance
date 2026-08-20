import 'package:flutter/material.dart';

import '../categories/category_selector.dart';
import '../database/database_service.dart';
import 'annual_expense.dart';

enum AnnualExpenseAction {
  edit,
  pay,
  delete,
}

class AnnualExpensesPage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const AnnualExpensesPage({
    super.key,
    this.onDataChanged,
  });

  @override
  State<AnnualExpensesPage> createState() => _AnnualExpensesPageState();
}

class _AnnualExpensesPageState extends State<AnnualExpensesPage> {
  List<AnnualExpense> expenses = [];
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
    final saved = await DatabaseService.instance.getAnnualExpenses();

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

  String reserveDescription(AnnualExpense expense) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    if (expense.isPaid) {
      return 'Pagata';
    }

    if (expense.isDueInMonth(currentMonth)) {
      return 'Da pagare questo mese';
    }

    if (currentMonth.isAfter(expense.dueMonth)) {
      return 'Scaduta';
    }

    final reserve = expense.reserveForMonth(currentMonth);

    if (reserve > 0) {
      final previousMonth = DateTime(
        expense.dueDate.year,
        expense.dueDate.month - 1,
        1,
      );

      return 'Metti da parte ${formatEuro(reserve)} al mese fino a ${monthNames[previousMonth.month - 1]} ${previousMonth.year}';
    }

    return 'Non devi ancora mettere da parte nulla';
  }

  Future<void> addExpense() async {
    final expense = await showDialog<AnnualExpense>(
      context: context,
      builder: (context) {
        return const AnnualExpenseDialog();
      },
    );

    if (expense == null) return;

    await DatabaseService.instance.insertAnnualExpense(expense);

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> editExpense(AnnualExpense expense) async {
    final updated = await showDialog<AnnualExpense>(
      context: context,
      builder: (context) {
        return AnnualExpenseDialog(
          expense: expense,
        );
      },
    );

    if (updated == null) return;

    await DatabaseService.instance.updateAnnualExpense(updated);

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> payExpense(AnnualExpense expense) async {
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

    await DatabaseService.instance.payAnnualExpense(
      expense,
      paymentDate: DateTime.now(),
    );

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> deleteExpense(AnnualExpense expense) async {
    if (expense.id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminare la spesa?'),
          content: Text(
            'Vuoi eliminare "${expense.name}" dalla pianificazione?',
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

    await DatabaseService.instance.deleteAnnualExpense(expense.id!);

    widget.onDataChanged?.call();
    await loadExpenses();
  }

  Future<void> showActions(AnnualExpense expense) async {
    final action = await showModalBottomSheet<AnnualExpenseAction>(
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
                title: const Text('Modifica'),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    AnnualExpenseAction.edit,
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
                      AnnualExpenseAction.pay,
                    );
                  },
                ),
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
                    AnnualExpenseAction.delete,
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
      case AnnualExpenseAction.edit:
        await editExpense(expense);
        break;
      case AnnualExpenseAction.pay:
        await payExpense(expense);
        break;
      case AnnualExpenseAction.delete:
        await deleteExpense(expense);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    final activeExpenses = expenses
        .where(
          (expense) =>
              !expense.isPaid &&
              !currentMonth.isAfter(expense.dueMonth),
        )
        .toList();

    final currentCommitment = expenses.fold<double>(
      0,
      (sum, expense) =>
          sum + expense.commitmentForMonth(currentMonth),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scadenze a lungo termine'),
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
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DA METTERE DA PARTE QUESTO MESE',
                          style: TextStyle(
                            color: colors.onPrimaryContainer.withValues(
                              alpha: 0.70,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatEuro(currentCommitment),
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${activeExpenses.length} scadenze attive',
                          style: TextStyle(
                            color: colors.onPrimaryContainer.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Le tue scadenze',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tocca una voce per modificarla, registrare il pagamento o eliminarla.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            Icons.event_repeat_outlined,
                            size: 42,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Nessuna scadenza a lungo termine',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aggiungi bollo, assicurazione, abbonamenti o altre spese con una data di scadenza.',
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: expenses[i].isPaid
                                            ? const Color(0xFFE5F6EF)
                                            : colors.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        expenses[i].isPaid
                                            ? Icons.check_rounded
                                            : Icons.event_repeat_outlined,
                                        color: expenses[i].isPaid
                                            ? const Color(0xFF16865C)
                                            : colors.primary,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expenses[i].name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Scadenza ${formatDate(expenses[i].dueDate)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            reserveDescription(expenses[i]),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: expenses[i].isPaid
                                                  ? const Color(0xFF16865C)
                                                  : colors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formatEuro(expenses[i].amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (i != expenses.length - 1)
                              const Divider(
                                height: 1,
                                indent: 72,
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

class AnnualExpenseDialog extends StatefulWidget {
  final AnnualExpense? expense;

  const AnnualExpenseDialog({
    super.key,
    this.expense,
  });

  @override
  State<AnnualExpenseDialog> createState() =>
      _AnnualExpenseDialogState();
}

class _AnnualExpenseDialogState extends State<AnnualExpenseDialog> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;

  late String selectedCategory;
  late DateTime dueDate;
  late DateTime savingStartDate;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;
    final now = DateTime.now();

    nameController = TextEditingController(
      text: expense?.name ?? '',
    );

    amountController = TextEditingController(
      text: expense == null
          ? ''
          : expense.amount.toStringAsFixed(2).replaceAll('.', ','),
    );

    selectedCategory = expense?.category ?? 'Altro';

    savingStartDate = expense?.savingStartDate ??
        DateTime(
          now.year,
          now.month,
          1,
        );

    dueDate = expense?.dueDate ??
        DateTime(
          now.year + 1,
          now.month,
          now.day,
        );
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  int monthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 +
        (end.month - start.month);
  }

  double? get previewAmount {
    return double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );
  }

  double get previewMonthlyReserve {
    final amount = previewAmount;

    if (amount == null || amount <= 0) {
      return 0;
    }

    final startMonth = DateTime(
      savingStartDate.year,
      savingStartDate.month,
      1,
    );

    final dueMonth = DateTime(
      dueDate.year,
      dueDate.month,
      1,
    );

    final months = monthsBetween(
      startMonth,
      dueMonth,
    );

    if (months <= 0) return 0;

    return amount / months;
  }

  String formatEuro(double value) {
    return '€ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> selectDueDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: isEditing
          ? DateTime(2000, 1, 1)
          : DateTime(
              now.year,
              now.month,
              1,
            ),
      lastDate: DateTime(
        now.year + 10,
        12,
        31,
      ),
    );

    if (picked == null) return;

    setState(() {
      dueDate = picked;
    });
  }

  void save() {
    final name = nameController.text.trim();

    final amount = double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty ||
        amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inserisci nome e importo validi',
          ),
        ),
      );
      return;
    }

    final dueMonthStart = DateTime(
      dueDate.year,
      dueDate.month,
      1,
    );

    final now = DateTime.now();

    final currentMonthStart = DateTime(
      now.year,
      now.month,
      1,
    );

    if (!isEditing &&
        dueMonthStart.isBefore(currentMonthStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La scadenza non può essere in un mese già trascorso',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      AnnualExpense(
        id: widget.expense?.id,
        name: name,
        amount: amount,
        category: selectedCategory,
        dueDate: dueDate,
        savingStartDate:
            widget.expense?.savingStartDate ?? savingStartDate,
        isPaid: widget.expense?.isPaid ?? false,
        paidTransactionId:
            widget.expense?.paidTransactionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Modifica scadenza'
            : 'Nuova scadenza',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Bollo auto',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  prefixText: '€ ',
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              CategorySelector(
                selectedCategory: selectedCategory,
                includeInactiveSelected: isEditing,
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: selectDueDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data di scadenza',
                    prefixIcon: Icon(
                      Icons.event_outlined,
                    ),
                  ),
                  child: Text(
                    formatDate(dueDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quanto mettere da parte',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      previewMonthlyReserve > 0
                          ? 'Metti da parte ${formatEuro(previewMonthlyReserve)} al mese dal ${formatDate(savingStartDate)} fino al mese prima della scadenza.'
                          : 'La scadenza è nello stesso mese: non ci sono mesi precedenti in cui mettere da parte questa somma.',
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
            isEditing
                ? 'Salva modifiche'
                : 'Aggiungi',
          ),
        ),
      ],
    );
  }
}
