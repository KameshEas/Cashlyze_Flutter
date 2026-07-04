import 'package:flutter/foundation.dart';

@immutable
class GoalsModel {
  const GoalsModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.icon,
    this.color,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.progressPercent,
    this.remainingAmount,
  });

  factory GoalsModel.fromJson(final Map<String, dynamic> json) {
    return GoalsModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String id;
  final String userId;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String? icon;
  final String? color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? progressPercent;
  final double? remainingAmount;

  double get calculatedProgress {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }

  int get daysRemaining {
    if (targetDate == null) return 0;
    return targetDate!.difference(DateTime.now()).inDays;
  }

  bool get isCompleted => currentAmount >= targetAmount;

  bool get isOverdue => targetDate != null && targetDate!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String(),
      'icon': icon,
      'color': color,
      'is_active': isActive,
    };
  }

  GoalsModel copyWith({
    final String? id,
    final String? userId,
    final String? name,
    final String? description,
    final double? targetAmount,
    final double? currentAmount,
    final DateTime? targetDate,
    final String? icon,
    final String? color,
    final bool? isActive,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final double? progressPercent,
    final double? remainingAmount,
  }) {
    return GoalsModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      progressPercent: progressPercent ?? this.progressPercent,
      remainingAmount: remainingAmount ?? this.remainingAmount,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is GoalsModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          description == other.description &&
          targetAmount == other.targetAmount &&
          currentAmount == other.currentAmount &&
          targetDate == other.targetDate &&
          icon == other.icon &&
          color == other.color &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    description,
    targetAmount,
    currentAmount,
    targetDate,
    icon,
    color,
    isActive,
  );
}
