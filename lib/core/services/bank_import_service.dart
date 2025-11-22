import 'package:flutter_riverpod/flutter_riverpod.dart';

class BankImportService {
  Future<List<Map<String, dynamic>>> fetchDemo(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      {
        'title': 'Bank POS Grocery',
        'amount': -52.35,
        'categoryId': 'Food',
        'date': DateTime.now(),
        'notes': 'Demo import',
      },
      {
        'title': 'Bank ACH Salary',
        'amount': 1200.0,
        'categoryId': 'Income',
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'notes': 'Demo import',
      },
    ];
  }
}

final bankImportServiceProvider = Provider<BankImportService>((ref) {
  return BankImportService();
});