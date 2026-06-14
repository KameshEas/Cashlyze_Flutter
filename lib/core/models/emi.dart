enum PaymentFrequency { weekly, monthly, quarterly }

class EMIPlan {
  final String id;
  final String userId;
  final double loanAmount;
  final double annualInterestRate;
  final int tenureMonths;
  final DateTime startDate;
  final PaymentFrequency frequency;
  final bool active;

  const EMIPlan({
    required this.id,
    required this.userId,
    required this.loanAmount,
    required this.annualInterestRate,
    required this.tenureMonths,
    required this.startDate,
    required this.frequency,
    required this.active,
  });

  factory EMIPlan.fromRTDB(String id, Map<String, dynamic> data) {
    return EMIPlan(
      id: id,
      userId: data['userId'] as String,
      loanAmount: (data['loanAmount'] as num).toDouble(),
      annualInterestRate: (data['annualInterestRate'] as num).toDouble(),
      tenureMonths: data['tenureMonths'] as int,
      startDate: DateTime.fromMillisecondsSinceEpoch((data['startDate_ms'] as num).toInt()),
      frequency: PaymentFrequency.values.firstWhere((e) => e.name == data['frequency'] as String),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'loanAmount': loanAmount,
      'annualInterestRate': annualInterestRate,
      'tenureMonths': tenureMonths,
      'startDate_ms': startDate.millisecondsSinceEpoch,
      'frequency': frequency.name,
      'active': active,
    };
  }
}

class EMIPayment {
  final String id;
  final String planId;
  final DateTime dueDate;
  final double installment;
  final double interest;
  final double principal;
  final double remainingPrincipal;
  final bool paid;
  final DateTime? paidAt;

  const EMIPayment({
    required this.id,
    required this.planId,
    required this.dueDate,
    required this.installment,
    required this.interest,
    required this.principal,
    required this.remainingPrincipal,
    required this.paid,
    this.paidAt,
  });

  factory EMIPayment.fromRTDB(String id, Map<String, dynamic> data) {
    return EMIPayment(
      id: id,
      planId: data['planId'] as String,
      dueDate: DateTime.fromMillisecondsSinceEpoch((data['dueDate_ms'] as num).toInt()),
      installment: (data['installment'] as num).toDouble(),
      interest: (data['interest'] as num).toDouble(),
      principal: (data['principal'] as num).toDouble(),
      remainingPrincipal: (data['remainingPrincipal'] as num).toDouble(),
      paid: data['paid'] as bool? ?? false,
      paidAt: data['paidAt_ms'] != null ? DateTime.fromMillisecondsSinceEpoch((data['paidAt_ms'] as num).toInt()) : null,
    );
  }

  Map<String, dynamic> toRTDB() {
    return {
      'planId': planId,
      'dueDate_ms': dueDate.millisecondsSinceEpoch,
      'installment': installment,
      'interest': interest,
      'principal': principal,
      'remainingPrincipal': remainingPrincipal,
      'paid': paid,
      'paidAt_ms': paidAt?.millisecondsSinceEpoch,
    };
  }
}
