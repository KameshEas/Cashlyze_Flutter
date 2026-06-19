import 'package:flutter/foundation.dart';

@immutable
class TransactionModel {

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.categoryId,
    this.categoryName,
    required this.date,
    this.notes,
    this.tags,
  });

  factory TransactionModel.fromRTDB(final String id, final Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String? ?? data['category'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch((data['date_ms'] as num).toInt()),
      notes: data['notes'] as String?,
      tags: (data['tags'] as List?)?.cast<String>(),
    );
  }
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String? categoryId;
  final String? categoryName;
  final DateTime date;
  final String? notes;
  final List<String>? tags;

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'date_ms': date.millisecondsSinceEpoch,
      'notes': notes,
      'tags': tags,
    };
  }

  TransactionModel copyWith({
    final String? id,
    final String? userId,
    final String? title,
    final double? amount,
    final String? categoryId,
    final String? categoryName,
    final DateTime? date,
    final String? notes,
    final List<String>? tags,
    final bool clearCategoryId = false,
    final bool clearCategoryName = false,
    final bool clearNotes = false,
    final bool clearTags = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategoryName ? null : (categoryName ?? this.categoryName),
      date: date ?? this.date,
      notes: clearNotes ? null : (notes ?? this.notes),
      tags: clearTags ? null : (tags ?? this.tags),
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          amount == other.amount &&
          categoryId == other.categoryId &&
          categoryName == other.categoryName &&
          date == other.date &&
          notes == other.notes &&
          listEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(id, userId, title, amount, categoryId, categoryName, date, notes, tags == null ? null : Object.hashAll(tags!));
}
