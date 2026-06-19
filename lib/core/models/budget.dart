import 'package:flutter/foundation.dart';

enum BudgetPeriod { daily, weekly, monthly }

@immutable
class BudgetModel {

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.allocated,
    required this.period,
    required this.categoryIds,
    required this.createdAt,
    this.updatedAt,
  });

  factory BudgetModel.fromRTDB(final String id, final Map<String, dynamic> data) {
    return BudgetModel(
      id: id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      allocated: (data['allocated'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (final p) => p.name == (data['period'] as String),
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryIds: (data['categoryIds'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch((data['created_at_ms'] as num).toInt()),
      updatedAt: data['updated_at_ms'] != null ? DateTime.fromMillisecondsSinceEpoch((data['updated_at_ms'] as num).toInt()) : null,
    );
  }
  final String id;
  final String userId;
  final String name;
  final double allocated;
  final BudgetPeriod period;
  final List<String> categoryIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'name': name,
      'allocated': allocated,
      'period': period.name,
      'categoryIds': categoryIds,
      'created_at_ms': createdAt.millisecondsSinceEpoch,
      'updated_at_ms': updatedAt?.millisecondsSinceEpoch,
    };
  }

  BudgetModel copyWith({
    final String? id,
    final String? userId,
    final String? name,
    final double? allocated,
    final BudgetPeriod? period,
    final List<String>? categoryIds,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final bool clearUpdatedAt = false,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      allocated: allocated ?? this.allocated,
      period: period ?? this.period,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is BudgetModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          allocated == other.allocated &&
          period == other.period &&
          listEquals(categoryIds, other.categoryIds) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, userId, name, allocated, period, Object.hashAll(categoryIds), createdAt, updatedAt);
}
