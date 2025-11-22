import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String? categoryId;
  final DateTime date;
  final String? notes;
  final List<String>? tags;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.categoryId,
    required this.date,
    this.notes,
    this.tags,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      categoryId: data['categoryId'] as String?,
      date: (data['date'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
      tags: (data['tags'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}