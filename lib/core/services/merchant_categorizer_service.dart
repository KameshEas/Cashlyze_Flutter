import '../models/scanned_bill.dart';

class MerchantCategorizerService {
  // Known merchant to category mapping (expand as needed)
  static const Map<String, String> _merchantCategories = {
    // Food & Grocery
    'amazon fresh': 'Food',
    'whole foods': 'Food',
    'trader joe': 'Food',
    'kroger': 'Food',
    'safeway': 'Food',
    'costco': 'Food',
    'walmart': 'Food',
    'target': 'Food',
    'supermarket': 'Food',
    'grocery': 'Food',
    'restaurant': 'Food',
    'pizza': 'Food',
    'coffee': 'Food',
    'starbucks': 'Food',
    'mcdonald': 'Food',
    'burger king': 'Food',
    'subway': 'Food',
    'taco bell': 'Food',
    'chick-fil-a': 'Food',
    'domino': 'Food',
    
    // Transport
    'uber': 'Transport',
    'lyft': 'Transport',
    'taxi': 'Transport',
    'gas station': 'Transport',
    'shell': 'Transport',
    'exxon': 'Transport',
    'chevron': 'Transport',
    'bp': 'Transport',
    'airline': 'Transport',
    'hotel': 'Transport',
    'parking': 'Transport',
    'transit': 'Transport',
    
    // Entertainment
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'hulu': 'Entertainment',
    'disney': 'Entertainment',
    'cinema': 'Entertainment',
    'movie': 'Entertainment',
    'theater': 'Entertainment',
    'concert': 'Entertainment',
    'game': 'Entertainment',
    'steam': 'Entertainment',
    'playstation': 'Entertainment',
    'xbox': 'Entertainment',
    
    // Health
    'pharmacy': 'Health',
    'cvs': 'Health',
    'walgreens': 'Health',
    'doctor': 'Health',
    'hospital': 'Health',
    'clinic': 'Health',
    'medical': 'Health',
    'dental': 'Health',
    'gym': 'Health',
    'fitness': 'Health',
    
    // Utilities
    'electric': 'Utilities',
    'electricity': 'Utilities',
    'water': 'Utilities',
    'gas': 'Utilities',
    'internet': 'Utilities',
    'phone': 'Utilities',
    'mobile': 'Utilities',
    'verizon': 'Utilities',
    'at&t': 'Utilities',
    't-mobile': 'Utilities',
    
    // Shopping
    'amazon': 'Shopping',
    'ebay': 'Shopping',
    'mall': 'Shopping',
    'store': 'Shopping',
    'clothing': 'Shopping',
    'fashion': 'Shopping',
    'shoe': 'Shopping',
    'zara': 'Shopping',
    'h&m': 'Shopping',
    
    // EMI/Finance
    'bank': 'EMI',
    'emi': 'EMI',
    'loan': 'EMI',
    'credit': 'EMI',
    'mortgage': 'EMI',
  };

  /// Categorizes a scanned bill based on merchant name
  /// Returns ScannedBill with suggested category and confidence score
  ScannedBill categorize(ScannedBill bill) {
    final merchantLower = bill.merchantName.toLowerCase();
    
    // Try exact keyword match first
    for (final entry in _merchantCategories.entries) {
      if (merchantLower.contains(entry.key)) {
        return bill.copyWith(
          suggestedCategory: entry.value,
          categoryConfidence: 0.95,
        );
      }
    }

    // Try fuzzy matching for close matches
    final fuzzyMatch = _fuzzyMatch(merchantLower);
    if (fuzzyMatch != null) {
      return bill.copyWith(
        suggestedCategory: fuzzyMatch,
        categoryConfidence: 0.7,
      );
    }

    // Fallback: try item keywords
    final itemCategory = _categorizeByItems(bill.items);
    if (itemCategory != null) {
      return bill.copyWith(
        suggestedCategory: itemCategory,
        categoryConfidence: 0.5,
      );
    }

    // Last resort: uncategorized
    return bill.copyWith(
      suggestedCategory: 'Other',
      categoryConfidence: 0.0,
    );
  }

  String? _fuzzyMatch(String merchant) {
    // Simple fuzzy matching: check if any key is a substring or has significant overlap
    for (final entry in _merchantCategories.entries) {
      if (_stringSimilarity(merchant, entry.key) > 0.6) {
        return entry.value;
      }
    }
    return null;
  }

  double _stringSimilarity(String a, String b) {
    final aWords = a.split(RegExp(r'\s+'));
    final bWords = b.split(RegExp(r'\s+'));
    
    int matches = 0;
    for (final aWord in aWords) {
      for (final bWord in bWords) {
        if (aWord == bWord) matches++;
      }
    }
    
    return matches / (aWords.length > bWords.length ? aWords.length : bWords.length);
  }

  String? _categorizeByItems(List<BillItem> items) {
    // Look for keywords in item descriptions
    final allItems = items.map((i) => i.description.toLowerCase()).join(' ');
    
    for (final entry in _merchantCategories.entries) {
      if (allItems.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
}
