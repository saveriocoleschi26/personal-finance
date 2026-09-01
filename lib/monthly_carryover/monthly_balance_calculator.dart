class MonthlyBalanceCalculator {
  const MonthlyBalanceCalculator._();

  static int toCents(double value) {
    return (value * 100).round();
  }

  static double fromCents(int value) {
    return value / 100;
  }

  static double availableMoney({
    required double carryover,
    required double income,
    required double paidExpenses,
    required double plannedExpenses,
    required double longTermCommitments,
    required double savingsGoal,
  }) {
    final availableCents = toCents(carryover) +
        toCents(income) -
        toCents(paidExpenses) -
        toCents(plannedExpenses) -
        toCents(longTermCommitments) -
        toCents(savingsGoal);

    return fromCents(availableCents);
  }
}
