import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/transaction_repository.dart';
import '../services/categorization_service.dart';
import 'bank_import_service.dart';
import 'analytics_service.dart';
import '../repositories/budget_repository.dart';

class TransactionIngestService {
  final TransactionRepository _repo;
  final CategorizationService _categorizer;
  final BankImportService _bank;
  final AnalyticsService _analytics;
  final BudgetRepository? _budgetRepo;

  TransactionIngestService(this._repo, this._categorizer, this._bank, this._analytics, [this._budgetRepo]);

  Future<void> addManual({
    required String userId,
    required String title,
    required double amount,
    required bool isIncome,
    String? categoryId,
    required DateTime date,
    String? notes,
  }) async {
    final cat = categoryId ?? _categorizer.suggestCategory(title);
    
    // Check if budget exists for this category
    if (_budgetRepo != null && cat != null && !isIncome) {
      final budgets = await _budgetRepo!.streamForUser(userId).first;
      final hasBudgetForCategory = budgets.any((budget) => budget.name.toLowerCase() == cat.toLowerCase());
      
      if (!hasBudgetForCategory) {
        // Store the transaction data for later processing
        // The UI will need to handle the budget creation prompt
        throw BudgetMissingException(cat, {
          'userId': userId,
          'title': title,
          'amount': isIncome ? amount.abs() : -amount.abs(),
          'categoryId': cat,
          'date': date,
          'notes': notes,
          'isIncome': isIncome,
        });
      }
    }
    
    await _repo.create(
      userId: userId,
      title: title,
      amount: isIncome ? amount.abs() : -amount.abs(),
      categoryId: cat,
      date: date,
      notes: notes,
    );
    await _analytics.logEvent('transaction_add', params: {
      'amount': amount,
      'is_income': isIncome ? 1 : 0,
      'category': cat ?? 'Uncategorized',
    });
  }

  Future<int> importBankDemo(String userId) async {
    final rows = await _bank.fetchDemo(userId);
    int count = 0;
    for (final r in rows) {
      await _repo.create(
        userId: userId,
        title: r['title'] as String,
        amount: (r['amount'] as num).toDouble(),
        categoryId: r['categoryId'] as String?,
        date: r['date'] as DateTime,
        notes: r['notes'] as String?,
      );
      count++;
    }
    await _analytics.logEvent('bank_import', params: {
      'count': count,
    });
    return count;
  }
}

final transactionIngestServiceProvider = Provider<TransactionIngestService>((ref) {
  return TransactionIngestService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(categorizationServiceProvider),
    ref.watch(bankImportServiceProvider),
    ref.watch(analyticsServiceProvider),
    ref.watch(budgetRepositoryProvider),
  );
});

class BudgetMissingException implements Exception {
  final String categoryName;
  final Map<String, dynamic> transactionData;
  
  BudgetMissingException(this.categoryName, this.transactionData);
  
  @override
  String toString() => 'No budget found for category: $categoryName';
}