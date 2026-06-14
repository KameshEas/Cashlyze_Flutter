import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/transaction_repository.dart';
import 'analytics_service.dart';
import '../repositories/budget_repository.dart';

class TransactionIngestService {
  final TransactionRepository _repo;
  final AnalyticsService _analytics;
  final BudgetRepository? _budgetRepo;

  TransactionIngestService(
    this._repo,
    this._analytics, [
    this._budgetRepo,
  ]);

  Future<void> addManual({
    required String userId,
    required String title,
    required double amount,
    required bool isIncome,
    String? categoryId,
    String? categoryName,
    required DateTime date,
    String? notes,
    List<String>? tags,
  }) async {
    final rawCat = categoryId?.trim();
    final cat = (rawCat == null || rawCat.isEmpty) ? null : rawCat;

    // Check if budget exists for this category (match by id OR name)
    if (_budgetRepo != null && !isIncome) {
      final budgets = await _budgetRepo.streamForUser(userId).first;

      final lookupRaw = (cat ?? categoryName ?? '').trim();
      if (lookupRaw.isNotEmpty) {
        // Treat 'General' as always having a budget (maps to synthetic General budget)
        if (lookupRaw.toLowerCase() == 'general') {
          // Skip budget existence check for General
        } else {
        final lcCat = lookupRaw.toLowerCase();
        final hasBudgetForCategory = budgets.any((budget) {
          // Match by budget name
          if (budget.name.toLowerCase() == lcCat) return true;
          // Match by explicit budget id
          if (budget.id == lookupRaw) return true;
          // Match any listed category identifier (could be id or name)
          for (final bid in budget.categoryIds) {
            final bTrim = bid.trim();
            if (bTrim.isEmpty) continue;
            if (bTrim.toLowerCase() == lcCat) return true;
            if (bTrim == lookupRaw) return true;
          }
          return false;
        });

          if (!hasBudgetForCategory) {
          // Store the transaction data for later processing
          // The UI will need to handle the budget creation prompt
          throw BudgetMissingException(lookupRaw, {
            'userId': userId,
            'title': title,
            'amount': isIncome ? amount.abs() : -amount.abs(),
            'categoryId': cat,
            'categoryName': categoryName,
            'date': date,
            'notes': notes,
            'isIncome': isIncome,
          });
          }
        }
      }
    }

    await _repo.create(
      userId: userId,
      title: title,
      amount: isIncome ? amount.abs() : -amount.abs(),
      categoryId: cat,
      categoryName: categoryName,
      isIncome: isIncome,
      date: date,
      notes: notes,
      tags: tags,
    );
    await _analytics.logEvent(
      'transaction_add',
      params: {
        'amount': amount,
        'is_income': isIncome ? 1 : 0,
        'category': cat ?? 'General',
      },
    );
  }

  Future<void> delete({
    required String userId,
    required String transactionId,
  }) async {
    await _repo.deleteForUser(userId, transactionId);
    await _analytics.logEvent('transaction_delete');
  }
}

final transactionIngestServiceProvider = Provider<TransactionIngestService>((
  ref,
) {
  return TransactionIngestService(
    ref.watch(transactionRepositoryProvider),
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
