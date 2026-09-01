import 'package:flutter/material.dart';

import 'categories/category_selector.dart';
import 'currency/app_currency.dart';
import 'localization/app_language.dart';
import 'transaction/final_transaction.dart';

class AddTransactionPage extends StatefulWidget {
  final FinanceTransaction? transaction;

  const AddTransactionPage({
    super.key,
    this.transaction,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late final TextEditingController amountController;
  late final TextEditingController descriptionController;

  late String selectedCategory;
  late bool isIncome;
  late DateTime selectedDate;

  bool get isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    amountController = TextEditingController(
      text: transaction == null
          ? ''
          : transaction.amount.toStringAsFixed(2).replaceAll('.', ','),
    );

    descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );

    selectedCategory = transaction?.category ?? 'Spesa alimentare';
    isIncome = transaction?.isIncome ?? false;
    selectedDate = transaction?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime initialDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    // Una transazione rappresenta un movimento reale: per le spese future
    // utilizziamo la sezione Pianifica, quindi qui non consentiamo date future.
    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: today,
      helpText: isEditing ? l('Modifica data') : l('Data del movimento'),
      cancelText: l('Annulla'),
      confirmText: l('Conferma'),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      selectedDate = pickedDate;
    });
  }

  DateTime transactionDateForSave() {
    final originalDate = widget.transaction?.date;
    final now = DateTime.now();

    // Manteniamo una componente oraria, così più movimenti dello stesso giorno
    // continuano ad avere un ordinamento naturale nel database.
    final timeSource = originalDate ?? now;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      timeSource.hour,
      timeSource.minute,
      timeSource.second,
      timeSource.millisecond,
      timeSource.microsecond,
    );
  }

  void saveTransaction() {
    final normalizedAmount =
        amountController.text.trim().replaceAll(',', '.');

    final double? amount = double.tryParse(normalizedAmount);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l('Inserisci un importo valido')),
        ),
      );
      return;
    }

    final transaction = FinanceTransaction(
      id: widget.transaction?.id,
      amount: amount,
      description: descriptionController.text.trim(),
      category: selectedCategory,
      isIncome: isIncome,
      date: transactionDateForSave(),
    );

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l('Modifica movimento') : l('Nuovo movimento'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l('Tipo di movimento'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.trending_down_rounded),
                  label: Text(l('Uscita')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.trending_up_rounded),
                  label: Text(l('Entrata')),
                ),
              ],
              selected: {isIncome},
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              onSelectionChanged: (selection) {
                setState(() {
                  isIncome = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l('Importo'),
                hintText: l('Es. 25,50'),
                prefixText: AppCurrencyController.instance.inputPrefix,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: l('Descrizione'),
                hintText: l('Es. Cena con amici'),
              ),
            ),
            const SizedBox(height: 20),
            CategorySelector(
              selectedCategory: selectedCategory,
              includeInactiveSelected: isEditing,
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: chooseDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l('Data'),
                  prefixIcon: Icon(
                    Icons.calendar_today_outlined,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDate(selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l('Puoi registrare anche un movimento dimenticato di un mese precedente.'),
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 30),
            FilledButton.icon(
              onPressed: saveTransaction,
              icon: Icon(
                isEditing ? Icons.check : Icons.add,
              ),
              label: Text(
                isEditing ? l('Salva modifiche') : l('Salva movimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
