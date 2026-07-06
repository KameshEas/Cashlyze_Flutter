import 'package:flutter/foundation.dart';

@immutable
class QueuedTransaction {
  const QueuedTransaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.transactionDate,
    this.categoryId,
    this.categoryName,
    this.notes,
    this.tags,
    this.accountId,
    this.attachmentPath,
    required this.createdAt,
    required this.status,
    this.errorMessage,
    required this.retryCount,
  });

  factory QueuedTransaction.fromJson(final Map<String, dynamic> json) {
    return QueuedTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      notes: json['notes'] as String?,
      tags: (json['tags'] as List?)?.cast<String>(),
      accountId: json['account_id'] as String?,
      attachmentPath: json['attachment_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  final String id;
  final String userId;
  final String title;
  final double amount;
  final DateTime transactionDate;
  final String? categoryId;
  final String? categoryName;
  final String? notes;
  final List<String>? tags;
  final String? accountId;
  final String? attachmentPath;
  final DateTime createdAt;
  final String status; // 'pending', 'syncing', 'synced', 'failed'
  final String? errorMessage;
  final int retryCount;

  bool get isPending => status == 'pending';
  bool get isSyncing => status == 'syncing';
  bool get isSynced => status == 'synced';
  bool get isFailed => status == 'failed';
  bool get shouldRetry => isFailed && retryCount < 3;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String(),
      'category_id': categoryId,
      'category_name': categoryName,
      'notes': notes,
      'tags': tags,
      'account_id': accountId,
      'attachment_path': attachmentPath,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'error_message': errorMessage,
      'retry_count': retryCount,
    };
  }

  QueuedTransaction copyWith({
    final String? status,
    final String? errorMessage,
    final int? retryCount,
  }) {
    return QueuedTransaction(
      id: id,
      userId: userId,
      title: title,
      amount: amount,
      transactionDate: transactionDate,
      categoryId: categoryId,
      categoryName: categoryName,
      notes: notes,
      tags: tags,
      accountId: accountId,
      attachmentPath: attachmentPath,
      createdAt: createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is QueuedTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
