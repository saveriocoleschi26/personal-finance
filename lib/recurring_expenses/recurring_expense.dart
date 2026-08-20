class RecurringExpense {
  final int? id;
  final String name;
  final double amount;
  final String category;
  final int dayOfMonth;
  final DateTime startMonth;
  final DateTime? endMonth;
  final bool isActive;

  const RecurringExpense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dayOfMonth,
    required this.startMonth,
    this.endMonth,
    this.isActive = true,
  });

  DateTime get normalizedStartMonth => DateTime(
        startMonth.year,
        startMonth.month,
        1,
      );

  DateTime? get normalizedEndMonth {
    if (endMonth == null) return null;

    return DateTime(
      endMonth!.year,
      endMonth!.month,
      1,
    );
  }

  bool isActiveForMonth(DateTime month) {
    if (!isActive) return false;

    final target = DateTime(
      month.year,
      month.month,
      1,
    );

    if (target.isBefore(normalizedStartMonth)) {
      return false;
    }

    final end = normalizedEndMonth;

    if (end != null && target.isAfter(end)) {
      return false;
    }

    return true;
  }

  DateTime dueDateForMonth(DateTime month) {
    final lastDay = DateTime(
      month.year,
      month.month + 1,
      0,
    ).day;

    final safeDay = dayOfMonth > lastDay
        ? lastDay
        : dayOfMonth;

    return DateTime(
      month.year,
      month.month,
      safeDay,
      12,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'day_of_month': dayOfMonth,
      'start_month': normalizedStartMonth.toIso8601String(),
      'end_month': normalizedEndMonth?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory RecurringExpense.fromMap(
    Map<String, dynamic> map,
  ) {
    return RecurringExpense(
      id: map['id'] as int,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      dayOfMonth: map['day_of_month'] as int,
      startMonth: DateTime.parse(map['start_month'] as String),
      endMonth: map['end_month'] == null
          ? null
          : DateTime.parse(map['end_month'] as String),
      isActive: map['is_active'] == 1,
    );
  }

  RecurringExpense copyWith({
    int? id,
    String? name,
    double? amount,
    String? category,
    int? dayOfMonth,
    DateTime? startMonth,
    DateTime? endMonth,
    bool clearEndMonth = false,
    bool? isActive,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startMonth: startMonth ?? this.startMonth,
      endMonth: clearEndMonth
          ? null
          : endMonth ?? this.endMonth,
      isActive: isActive ?? this.isActive,
    );
  }
}
