import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategorizationService {
  static const Map<String, String> _keywordToCategory = {
    'grocery': 'Food',
    'supermarket': 'Food',
    'netflix': 'Entertainment',
    'uber': 'Transport',
    'bus': 'Transport',
    'salary': 'Income',
    'freelance': 'Income',
  };

  String? suggestCategory(String title) {
    final t = title.toLowerCase();
    for (final entry in _keywordToCategory.entries) {
      if (t.contains(entry.key)) return entry.value;
    }
    return null;
  }
}

final categorizationServiceProvider = Provider<CategorizationService>((ref) {
  return CategorizationService();
});