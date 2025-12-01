import 'package:flutter/material.dart';

enum RecurringFrequency { weekly, monthly }

class RecurringRule {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final bool isIncome;
  final String? categoryId;
  final DateTime startDate;
  final DateTime? lastPostedDate;
  final RecurringFrequency frequency;

  const RecurringRule({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.isIncome,
    this.categoryId,
    required this.startDate,
    this.lastPostedDate,
    required this.frequency,
  });

  factory RecurringRule.fromRTDB(String id, Map<String, dynamic> data) {
    return RecurringRule(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      isIncome: (data['isIncome'] as bool?) ?? false,
      categoryId: data['categoryId'] as String?,
      startDate: DateTime.fromMillisecondsSinceEpoch((data['start_ms'] as num).toInt()),
      lastPostedDate: data['last_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((data['last_ms'] as num).toInt()),
      frequency: (data['frequency'] as String) == 'weekly'
          ? RecurringFrequency.weekly
          : RecurringFrequency.monthly,
    );
  }

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'isIncome': isIncome,
      'categoryId': categoryId,
      'start_ms': startDate.millisecondsSinceEpoch,
      'last_ms': lastPostedDate?.millisecondsSinceEpoch,
      'frequency': frequency == RecurringFrequency.weekly ? 'weekly' : 'monthly',
    };
  }
}
