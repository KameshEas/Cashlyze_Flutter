import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory EMIPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EMIPlan(
      id: doc.id,
      userId: data['userId'] as String,
      loanAmount: (data['loanAmount'] as num).toDouble(),
      annualInterestRate: (data['annualInterestRate'] as num).toDouble(),
      tenureMonths: data['tenureMonths'] as int,
      startDate: (data['startDate'] as Timestamp).toDate(),
      frequency: PaymentFrequency.values.firstWhere((e) => e.name == data['frequency'] as String),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'loanAmount': loanAmount,
      'annualInterestRate': annualInterestRate,
      'tenureMonths': tenureMonths,
      'startDate': Timestamp.fromDate(startDate),
      'frequency': frequency.name,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
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

  factory EMIPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EMIPayment(
      id: doc.id,
      planId: data['planId'] as String,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      installment: (data['installment'] as num).toDouble(),
      interest: (data['interest'] as num).toDouble(),
      principal: (data['principal'] as num).toDouble(),
      remainingPrincipal: (data['remainingPrincipal'] as num).toDouble(),
      paid: data['paid'] as bool? ?? false,
      paidAt: data['paidAt'] != null ? (data['paidAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'planId': planId,
      'dueDate': Timestamp.fromDate(dueDate),
      'installment': installment,
      'interest': interest,
      'principal': principal,
      'remainingPrincipal': remainingPrincipal,
      'paid': paid,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    };
  }
}