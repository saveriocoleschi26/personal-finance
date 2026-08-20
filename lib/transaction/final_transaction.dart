class FinanceTransaction {
  final int? id;
  final double amount;
  final String description;
  final String category;
  final bool isIncome;
  final DateTime date;

  FinanceTransaction({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.isIncome,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'is_income': isIncome ? 1 : 0,
      'date': date.toIso8601String(),
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] as int,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      category: map['category'] as String,
      isIncome: map['is_income'] == 1,
      date: DateTime.parse(map['date'] as String),
    );
  }

  FinanceTransaction copyWith({
    int? id,
    double? amount,
    String? description,
    String? category,
    bool? isIncome,
    DateTime? date,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      isIncome: isIncome ?? this.isIncome,
      date: date ?? this.date,
    );
  }
}
