import 'dart:math';
import '../models/emi.dart';

class EMICalculatorResult {
  final double installment;
  final double totalInterest;
  final List<EMIPayment> schedule;
  const EMICalculatorResult(this.installment, this.totalInterest, this.schedule);
}

class EMICalculator {
  static EMICalculatorResult compute({
    required String planId,
    required double loanAmount,
    required double annualRate,
    required int tenureMonths,
    required DateTime startDate,
    required PaymentFrequency frequency,
  }) {
    final periodsPerYear = frequency == PaymentFrequency.weekly
        ? 52
        : frequency == PaymentFrequency.monthly
            ? 12
            : 4;
    final totalPeriods = frequency == PaymentFrequency.monthly
        ? tenureMonths
        : frequency == PaymentFrequency.quarterly
            ? (tenureMonths / 3).ceil()
            : (tenureMonths * 4).ceil();
    final r = annualRate / 100 / periodsPerYear;
    final installment = r == 0
        ? loanAmount / totalPeriods
        : loanAmount * r * pow(1 + r, totalPeriods) / (pow(1 + r, totalPeriods) - 1);

    double remaining = loanAmount;
    double totalInterest = 0;
    final schedule = <EMIPayment>[];
    DateTime due = startDate;
    for (int i = 0; i < totalPeriods; i++) {
      final interest = remaining * r;
      final principal = installment - interest;
      remaining = (remaining - principal);
      totalInterest += interest;
      schedule.add(EMIPayment(
        id: 'p$i',
        planId: planId,
        dueDate: due,
        installment: doubleParse(installment),
        interest: doubleParse(interest),
        principal: doubleParse(principal),
        remainingPrincipal: doubleParse(remaining < 0 ? 0 : remaining),
        paid: false,
      ));
      due = nextDueDate(due, frequency);
    }
    return EMICalculatorResult(doubleParse(installment), doubleParse(totalInterest), schedule);
  }

  static DateTime nextDueDate(DateTime date, PaymentFrequency f) {
    switch (f) {
      case PaymentFrequency.weekly:
        return date.add(const Duration(days: 7));
      case PaymentFrequency.monthly:
        return DateTime(date.year, date.month + 1, date.day);
      case PaymentFrequency.quarterly:
        return DateTime(date.year, date.month + 3, date.day);
    }
  }

  static double doubleParse(double v) => double.parse(v.toStringAsFixed(2));
}