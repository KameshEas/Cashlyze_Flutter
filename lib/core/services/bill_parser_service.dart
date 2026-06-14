import '../models/scanned_bill.dart';

class BillParserService {
  /// Parses OCR text into structured bill data
  ScannedBill parseBillText(String ocrText) {
    final lines = ocrText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    if (lines.isEmpty) {
      throw BillParseException('No text extracted from bill');
    }

    // Extract merchant name (typically first non-empty line)
    String merchantName = _extractMerchantName(lines);
    
    // Extract total amount
    double amount = _extractAmount(ocrText);
    
    // Extract date
    DateTime? date = _extractDate(ocrText);
    
    // Extract payment method
    String? paymentMethod = _extractPaymentMethod(ocrText);
    
    // Extract line items
    List<BillItem> items = _extractItems(lines);

    return ScannedBill(
      merchantName: merchantName,
      amount: amount,
      date: date,
      paymentMethod: paymentMethod,
      items: items,
      suggestedCategory: '', // Will be set by categorizer
      categoryConfidence: 0.0,
    );
  }

  String _extractMerchantName(List<String> lines) {
    // First non-empty line is usually the merchant name
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.length > 2) {
        // Skip lines that look like amounts or dates
        if (!_looksLikeAmount(trimmed) && !_looksLikeDate(trimmed)) {
          return trimmed;
        }
      }
    }
    return 'Unknown Merchant';
  }

  double _extractAmount(String text) {
    // Match currency patterns: $123.45, ₹999, etc.
    final amountPattern = RegExp(r'(?:total|amount|sub.?total|balance|payable)[:\s]+([₹$€£¥]?\s*[\d,]+\.?\d*)');
    final match = amountPattern.firstMatch(text.toLowerCase());
    
    if (match != null) {
      String amountStr = match.group(1) ?? '';
      // Remove currency symbols and commas
      amountStr = amountStr.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(amountStr) ?? 0.0;
    }

    // Fallback: look for largest number in text
    final numberPattern = RegExp(r'[\d,]+\.?\d*');
    final matches = numberPattern.allMatches(text);
    double maxAmount = 0.0;
    
    for (final match in matches) {
      final numStr = match.group(0)?.replaceAll(',', '') ?? '0';
      final num = double.tryParse(numStr) ?? 0.0;
      if (num > maxAmount && num < 10000) { // Assume bill < 10000
        maxAmount = num;
      }
    }
    
    return maxAmount > 0 ? maxAmount : 0.0;
  }

  DateTime? _extractDate(String text) {
    // Match common date patterns
    final datePatterns = [
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})'), // DD/MM/YYYY or MM/DD/YYYY
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'), // YYYY/MM/DD
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{2,4})'), // 15 Jan 2024
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          return _parseMatchedDate(match);
        } catch (_) {}
      }
    }

    return DateTime.now(); // Default to today
  }

  DateTime _parseMatchedDate(RegExpMatch match) {
    final groups = match.groups([1, 2, 3]);
    
    if (groups[0]!.length == 4) {
      // YYYY format first
      final year = int.parse(groups[0]!);
      final month = int.parse(groups[1]!);
      final day = int.parse(groups[2]!);
      return DateTime(year, month, day);
    } else {
      // DD/MM/YYYY format
      final day = int.parse(groups[0]!);
      final month = int.parse(groups[1]!);
      final year = int.parse(groups[2]!);
      final fullYear = year < 100 ? 2000 + year : year;
      return DateTime(fullYear, month, day);
    }
  }

  String? _extractPaymentMethod(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('credit card') || lowerText.contains('visa') || lowerText.contains('mastercard')) {
      return 'Credit Card';
    }
    if (lowerText.contains('debit card') || lowerText.contains('atm')) {
      return 'Debit Card';
    }
    if (lowerText.contains('cash') || lowerText.contains('paid cash')) {
      return 'Cash';
    }
    if (lowerText.contains('upi') || lowerText.contains('gpay') || lowerText.contains('phonepe')) {
      return 'Digital Wallet';
    }

    return null;
  }

  List<BillItem> _extractItems(List<String> lines) {
    final items = <BillItem>[];
    
    // Lines that look like items (contain description and possibly price)
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Skip headers, totals, and short lines
      if (trimmed.isEmpty || trimmed.length < 3) continue;
      if (trimmed.toLowerCase().contains('total') || trimmed.toLowerCase().contains('amount')) continue;
      if (_looksLikeAmount(trimmed) || _looksLikeDate(trimmed)) continue;

      // Try to extract price from line
      final priceMatch = RegExp(r'[\d,]+\.?\d*\s*$').firstMatch(trimmed);
      final price = priceMatch != null 
          ? double.tryParse(priceMatch.group(0)!.replaceAll(',', ''))
          : null;

      items.add(BillItem(
        description: trimmed,
        price: price,
      ));
    }

    return items.take(10).toList(); // Limit to 10 items for brevity
  }

  bool _looksLikeAmount(String text) {
    return RegExp(r'^[\d,]+\.?\d*\s*(?:₹|\$|€|£)?$').hasMatch(text);
  }

  bool _looksLikeDate(String text) {
    return RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(text);
  }
}

class BillParseException implements Exception {
  final String message;
  BillParseException(this.message);
  
  @override
  String toString() => message;
}
