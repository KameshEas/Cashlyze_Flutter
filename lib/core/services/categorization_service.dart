import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategorizationService {
  static const Map<String, String> _keywordToCategory = {
    'grocery': 'Food',
    'groceries': 'Food',
    'supermarket': 'Food',
    'netflix': 'Entertainment',
    'uber': 'Transport',
    'bus': 'Transport',
    'salary': 'Income',
    'freelance': 'Income',
    'emi': 'EMI',
    'loan': 'EMI',
    'mortgage': 'EMI',
    'installment': 'EMI',
    'payment': 'EMI',
  };

  String? suggestCategory(final String title) {
    final t = title.toLowerCase();
    if (t.trim().isEmpty) return null;

    for (final entry in _keywordToCategory.entries) {
      if (!t.contains(entry.key)) continue;

      // Special-case 'payment' to require additional EMI cues so that
      // generic "payment" titles aren't misclassified.
      if (entry.key == 'payment' && entry.value == 'EMI') {
        final hasMonthly = t.contains('monthly');
        final hasEmiTrigger = t.contains('emi') || t.contains('loan') || t.contains('mortgage') || t.contains('installment');
        if (!hasMonthly && !hasEmiTrigger) {
          continue; // skip this noisy match
        }
      }

      return entry.value;
    }

    return null;
  }
}

final categorizationServiceProvider = Provider<CategorizationService>((final ref) {
  return CategorizationService();
});
