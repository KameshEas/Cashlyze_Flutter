import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import 'analytics_service.dart';

class TransactionIngestService {

  TransactionIngestService(
    this._repo,
    this._analytics, [
    this._budgetRepo,
  ]);
  final TransactionRepository _repo;
  final AnalyticsService _analytics;
  final BudgetRepository? _budgetRepo;

  Future<void> addManual({
    required final String userId,
    required final String title,
    required final double amount,
    required final bool isIncome,
    final String? categoryId,
    final String? categoryName,
    required final DateTime date,
    final String? notes,
    final List<String>? tags,
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
        final hasBudgetForCategory = budgets.any((final budget) {
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
    required final String userId,
    required final String transactionId,
  }) async {
    await _repo.deleteForUser(userId, transactionId);
    await _analytics.logEvent('transaction_delete');
  }
}

final transactionIngestServiceProvider = Provider<TransactionIngestService>((
  final ref,
) {
  return TransactionIngestService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(analyticsServiceProvider),
    ref.watch(budgetRepositoryProvider),
  );
});

class BudgetMissingException implements Exception {

  BudgetMissingException(this.categoryName, this.transactionData);
  final String categoryName;
  final Map<String, dynamic> transactionData;

  @override
  String toString() => 'No budget found for category: $categoryName';
}
