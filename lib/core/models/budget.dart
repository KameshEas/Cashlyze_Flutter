enum BudgetPeriod { daily, weekly, monthly }

class BudgetModel {
  final String id;
  final String userId;
  final String name;
  final double allocated;
  final BudgetPeriod period;
  final List<String> categoryIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

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

  factory BudgetModel.fromRTDB(String id, Map<String, dynamic> data) {
    return BudgetModel(
      id: id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      allocated: (data['allocated'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (p) => p.name == (data['period'] as String),
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryIds: (data['categoryIds'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch((data['created_at_ms'] as num).toInt()),
      updatedAt: data['updated_at_ms'] != null ? DateTime.fromMillisecondsSinceEpoch((data['updated_at_ms'] as num).toInt()) : null,
    );
  }

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
}