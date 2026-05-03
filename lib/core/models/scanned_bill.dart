class ScannedBill {
  final String merchantName;
  final double amount;
  final DateTime? date;
  final String? paymentMethod;
  final List<BillItem> items;
  final String suggestedCategory;
  final double categoryConfidence; // 0.0 - 1.0

  ScannedBill({
    required this.merchantName,
    required this.amount,
    this.date,
    this.paymentMethod,
    required this.items,
    required this.suggestedCategory,
    required this.categoryConfidence,
  });

  // Copy with for easy modifications in UI
  ScannedBill copyWith({
    String? merchantName,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    List<BillItem>? items,
    String? suggestedCategory,
    double? categoryConfidence,
  }) {
    return ScannedBill(
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      categoryConfidence: categoryConfidence ?? this.categoryConfidence,
    );
  }
}

class BillItem {
  final String description;
  final double? quantity;
  final double? price;

  BillItem({
    required this.description,
    this.quantity,
    this.price,
  });
}
