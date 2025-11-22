import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      allocated: (data['allocated'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (p) => p.name == (data['period'] as String),
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryIds: (data['categoryIds'] as List?)?.cast<String>() ?? const [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'allocated': allocated,
      'period': period.name,
      'categoryIds': categoryIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}