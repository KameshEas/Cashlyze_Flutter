import 'package:cashlyze/core/utils/validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTitle', () {
    test('should return true for non-empty title', () {
      expect(validateTitle('Test transaction'), isTrue);
      expect(validateTitle('  Test  '), isTrue); // trims whitespace
    });

    test('should return false for empty title', () {
      expect(validateTitle(''), isFalse);
      expect(validateTitle('   '), isFalse); // only whitespace
    });
  });

  group('validateAmount', () {
    test('should return true for valid numbers', () {
      expect(validateAmount('100.50'), isTrue);
      expect(validateAmount('0'), isTrue);
      expect(validateAmount('-50.25'), isTrue);
    });

    test('should return false for invalid amounts', () {
      expect(validateAmount('abc'), isFalse);
      expect(validateAmount(''), isFalse);
      expect(validateAmount('12.34.56'), isFalse);
    });
  });

  group('validateDate', () {
    test('should return true for past and current dates', () {
      final now = DateTime.now();
      expect(validateDate(now), isTrue);
      expect(validateDate(now.subtract(const Duration(days: 1))), isTrue);
    });

    test('should return false for future dates', () {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      expect(validateDate(futureDate), isFalse);
    });
  });
}
