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

  factory TransactionModel.fromRTDB(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      categoryId: data['categoryId'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch((data['date_ms'] as num).toInt()),
      notes: data['notes'] as String?,
      tags: (data['tags'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'date_ms': date.millisecondsSinceEpoch,
      'notes': notes,
      'tags': tags,
    };
  }
}