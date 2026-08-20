class PlannedExpense {
  final int? id;
  final String name;
  final double amount;
  final String category;
  final DateTime dueDate;
  final bool isPaid;
  final int? paidTransactionId;
  final int? recurringExpenseId;

  const PlannedExpense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDate,
    this.isPaid = false,
    this.paidTransactionId,
    this.recurringExpenseId,
  });

  bool get isRecurring => recurringExpenseId != null;

  DateTime get dueMonth => DateTime(
        dueDate.year,
        dueDate.month,
        1,
      );

  bool isForMonth(DateTime month) {
    return dueDate.year == month.year && dueDate.month == month.month;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'due_date': dueDate.toIso8601String(),
      'is_paid': isPaid ? 1 : 0,
      'paid_transaction_id': paidTransactionId,
      'recurring_expense_id': recurringExpenseId,
    };
  }

  factory PlannedExpense.fromMap(Map<String, dynamic> map) {
    return PlannedExpense(
      id: map['id'] as int,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      isPaid: map['is_paid'] == 1,
      paidTransactionId: map['paid_transaction_id'] as int?,
      recurringExpenseId: map['recurring_expense_id'] as int?,
    );
  }

  PlannedExpense copyWith({
    int? id,
    String? name,
    double? amount,
    String? category,
    DateTime? dueDate,
    bool? isPaid,
    int? paidTransactionId,
    bool clearPaidTransactionId = false,
    int? recurringExpenseId,
  }) {
    return PlannedExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      paidTransactionId: clearPaidTransactionId
          ? null
          : paidTransactionId ?? this.paidTransactionId,
      recurringExpenseId: recurringExpenseId ?? this.recurringExpenseId,
    );
  }
}
