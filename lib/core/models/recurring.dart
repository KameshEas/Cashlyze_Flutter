import 'package:flutter/foundation.dart';

enum RecurringFrequency { weekly, monthly }

@immutable
class RecurringRule {

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

  factory RecurringRule.fromRTDB(final String id, final Map<String, dynamic> data) {
    return RecurringRule(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      isIncome: (data['isIncome'] as bool?) ?? false,
      categoryId: data['categoryId'] as String?,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        (data['start_ms'] as num).toInt(),
      ),
      lastPostedDate: data['last_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (data['last_ms'] as num).toInt(),
            ),
      frequency: (data['frequency'] as String) == 'weekly'
          ? RecurringFrequency.weekly
          : RecurringFrequency.monthly,
    );
  }
  final String id;
  final String userId;
  final String title;
  final double amount;
  final bool isIncome;
  final String? categoryId;
  final DateTime startDate;
  final DateTime? lastPostedDate;
  final RecurringFrequency frequency;

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'isIncome': isIncome,
      'categoryId': categoryId,
      'start_ms': startDate.millisecondsSinceEpoch,
      'last_ms': lastPostedDate?.millisecondsSinceEpoch,
      'frequency': frequency == RecurringFrequency.weekly
          ? 'weekly'
          : 'monthly',
    };
  }

  RecurringRule copyWith({
    final String? id,
    final String? userId,
    final String? title,
    final double? amount,
    final bool? isIncome,
    final String? categoryId,
    final DateTime? startDate,
    final DateTime? lastPostedDate,
    final RecurringFrequency? frequency,
    final bool clearCategoryId = false,
    final bool clearLastPostedDate = false,
  }) {
    return RecurringRule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      startDate: startDate ?? this.startDate,
      lastPostedDate: clearLastPostedDate ? null : (lastPostedDate ?? this.lastPostedDate),
      frequency: frequency ?? this.frequency,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is RecurringRule &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          amount == other.amount &&
          isIncome == other.isIncome &&
          categoryId == other.categoryId &&
          startDate == other.startDate &&
          lastPostedDate == other.lastPostedDate &&
          frequency == other.frequency;

  @override
  int get hashCode => Object.hash(id, userId, title, amount, isIncome, categoryId, startDate, lastPostedDate, frequency);
}
