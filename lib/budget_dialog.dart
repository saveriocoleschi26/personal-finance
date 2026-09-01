import 'package:flutter/material.dart';

import 'currency/app_currency.dart';
import 'localization/app_language.dart';

class BudgetResult {
  final double savingsGoal;

  const BudgetResult({
    required this.savingsGoal,
  });
}

class BudgetDialog extends StatefulWidget {
  final double currentSavingsGoal;

  const BudgetDialog({
    super.key,
    required this.currentSavingsGoal,
  });

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  late String savingsGoalText;

  @override
  void initState() {
    super.initState();

    savingsGoalText = widget.currentSavingsGoal == 0
        ? ''
        : widget.currentSavingsGoal.toStringAsFixed(2);
  }

  double parseMoney(String value) {
    final parsed = double.tryParse(
      value.trim().replaceAll(',', '.'),
    );

    if (parsed == null || parsed < 0) {
      return 0;
    }

    return parsed;
  }

  void save() {
    Navigator.pop(
      context,
      BudgetResult(
        savingsGoal: parseMoney(savingsGoalText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l('Obiettivo di risparmio')),
      content: SizedBox(
        width: 400,
        child: TextFormField(
          initialValue: savingsGoalText,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: l('Quanto vuoi proteggere questo mese?'),
            prefixText: AppCurrencyController.instance.inputPrefix,
          ),
          onChanged: (value) {
            savingsGoalText = value;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l('Annulla')),
        ),
        FilledButton(
          onPressed: save,
          child: Text(l('Salva')),
        ),
      ],
    );
  }
}
