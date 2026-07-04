import 'package:flutter/foundation.dart';

@immutable
class SearchResult {
  const SearchResult({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.subtitle,
    this.amount = 0.0,
    this.date,
    this.metadata = const {},
  });

  factory SearchResult.fromJson(final Map<String, dynamic> json) {
    return SearchResult(
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  final String entityType;
  final String entityId;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime? date;
  final Map<String, dynamic> metadata;

  String get displayIcon {
    switch (entityType) {
      case 'transaction':
        return '💳';
      case 'category':
        return '📁';
      case 'budget':
        return '💰';
      case 'savings_goal':
        return metadata['icon'] as String? ?? '🎯';
      default:
        return '📄';
    }
  }

  String get displayType {
    switch (entityType) {
      case 'transaction':
        return 'Transaction';
      case 'category':
        return 'Category';
      case 'budget':
        return 'Budget';
      case 'savings_goal':
        return 'Savings Goal';
      default:
        return 'Item';
    }
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          entityId == other.entityId &&
          entityType == other.entityType;

  @override
  int get hashCode => Object.hash(entityId, entityType);
}
