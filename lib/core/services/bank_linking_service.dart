import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final bankLinkingServiceProvider = Provider<BankLinkingService>((ref) {
  return BankLinkingService();
});

/// Mock bank linking service POC.
class BankLinkingService {
  /// Simulate linking to a bank and returning a list of canonical transactions.
  Future<List<Map<String, dynamic>>> linkBank(String providerId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final now = DateTime.now().toUtc();
    // Return two sample canonical transactions matching core/schema/transaction.json
    return [
      {
        'id': '${providerId}_txn_${now.millisecondsSinceEpoch}_1',
        'account_id': 'acct_mock_1',
        'provider': providerId,
        'amount': -1499.00,
        'currency': 'INR',
        'date': now.subtract(const Duration(days: 2)).toIso8601String(),
        'transaction_type': 'debit',
        'merchant_name': 'Mock Store',
        'raw_description': 'MOCK STORE POS 1234',
        'normalized_description': 'Mock Store - POS',
        'category': 'shopping',
        'category_confidence': 0.85,
        'is_emi': false,
        'metadata': {'raw_account_mask': '****5678'},
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      {
        'id': '${providerId}_txn_${now.millisecondsSinceEpoch}_2',
        'account_id': 'acct_mock_1',
        'provider': providerId,
        'amount': -2999.00,
        'currency': 'INR',
        'date': now.subtract(const Duration(days: 7)).toIso8601String(),
        'transaction_type': 'debit',
        'merchant_name': 'Mock Electronics',
        'raw_description': 'MOCK ELECTRONICS ONLINE',
        'normalized_description': 'Mock Electronics',
        'category': 'electronics',
        'category_confidence': 0.9,
        'is_emi': true,
        'emi_details': {
          'emi_amount': 2999.00,
          'emi_tenure_months': 12,
          'emi_start_date': now.subtract(const Duration(days: 7)).toIso8601String(),
          'emi_issuer': 'card_mock'
        },
        'metadata': {'raw_account_mask': '****5678'},
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }
    ];
  }
}
