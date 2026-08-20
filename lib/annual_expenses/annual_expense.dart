class AnnualExpense {
  final int? id;
  final String name;
  final double amount;
  final String category;
  final DateTime dueDate;
  final DateTime savingStartDate;
  final bool isPaid;
  final int? paidTransactionId;

  const AnnualExpense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDate,
    required this.savingStartDate,
    this.isPaid = false,
    this.paidTransactionId,
  });

  DateTime get dueMonth => DateTime(dueDate.year, dueDate.month, 1);

  DateTime get savingStartMonth => DateTime(
        savingStartDate.year,
        savingStartDate.month,
        1,
      );

  int get savingMonths => _monthsBetween(savingStartMonth, dueMonth);

  double get regularMonthlyReserve {
    if (savingMonths <= 0) return 0;
    return amount / savingMonths;
  }

  bool isDueInMonth(DateTime month) {
    final target = DateTime(month.year, month.month, 1);
    return target.year == dueMonth.year && target.month == dueMonth.month;
  }

  bool isSavingInMonth(DateTime month) {
    final target = DateTime(month.year, month.month, 1);
    return !target.isBefore(savingStartMonth) && target.isBefore(dueMonth);
  }

  double reserveForMonth(DateTime month) {
    if (!isSavingInMonth(month)) return 0;
    return regularMonthlyReserve;
  }

  double commitmentForMonth(DateTime month) {
    if (isSavingInMonth(month)) {
      return regularMonthlyReserve;
    }

    if (isDueInMonth(month) && !isPaid) {
      return amount;
    }

    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'year_key': dueDate.year,
      'name': name,
      'amount': amount,
      'category': category,
      'due_date': dueDate.toIso8601String(),
      'saving_start_date': savingStartDate.toIso8601String(),
      'is_paid': isPaid ? 1 : 0,
      'paid_transaction_id': paidTransactionId,
    };
  }

  factory AnnualExpense.fromMap(Map<String, dynamic> map) {
    return AnnualExpense(
      id: map['id'] as int,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      savingStartDate: DateTime.parse(map['saving_start_date'] as String),
      isPaid: map['is_paid'] == 1,
      paidTransactionId: map['paid_transaction_id'] as int?,
    );
  }

  AnnualExpense copyWith({
    int? id,
    String? name,
    double? amount,
    String? category,
    DateTime? dueDate,
    DateTime? savingStartDate,
    bool? isPaid,
    int? paidTransactionId,
    bool clearPaidTransactionId = false,
  }) {
    return AnnualExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      savingStartDate: savingStartDate ?? this.savingStartDate,
      isPaid: isPaid ?? this.isPaid,
      paidTransactionId: clearPaidTransactionId
          ? null
          : paidTransactionId ?? this.paidTransactionId,
    );
  }

  static int _monthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + (end.month - start.month);
  }
}
