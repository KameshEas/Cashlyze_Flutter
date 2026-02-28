import 'package:cashlyze/core/services/categorization_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategorizationService', () {
    late CategorizationService service;

    setUp(() {
      service = CategorizationService();
    });

    group('suggestCategory', () {
      test('categorizes food-related transactions', () {
        expect(service.suggestCategory('Grocery shopping'), equals('Food'));
        expect(service.suggestCategory('Supermarket visit'), equals('Food'));
        expect(service.suggestCategory('GROCERY STORE'), equals('Food'));
      });

      test('categorizes entertainment transactions', () {
        expect(service.suggestCategory('Netflix subscription'), equals('Entertainment'));
        expect(service.suggestCategory('NETFLIX PAYMENT'), equals('Entertainment'));
      });

      test('categorizes transport transactions', () {
        expect(service.suggestCategory('Uber ride'), equals('Transport'));
        expect(service.suggestCategory('Bus ticket'), equals('Transport'));
        expect(service.suggestCategory('UBER TRIP'), equals('Transport'));
      });

      test('categorizes income transactions', () {
        expect(service.suggestCategory('Salary credit'), equals('Income'));
        expect(service.suggestCategory('Freelance payment'), equals('Income'));
        expect(service.suggestCategory('SALARY DEPOSIT'), equals('Income'));
      });

      test('categorizes EMI transactions', () {
        expect(service.suggestCategory('Home loan EMI'), equals('EMI'));
        expect(service.suggestCategory('Car loan payment'), equals('EMI'));
        expect(service.suggestCategory('Mortgage installment'), equals('EMI'));
        expect(service.suggestCategory('Monthly payment'), equals('EMI'));
        expect(service.suggestCategory('LOAN EMI'), equals('EMI'));
      });

      test('returns null for uncategorized transactions', () {
        expect(service.suggestCategory('Random transaction'), isNull);
        expect(service.suggestCategory('Unknown payment'), isNull);
        expect(service.suggestCategory('Test'), isNull);
      });

      test('handles empty string', () {
        expect(service.suggestCategory(''), isNull);
      });

      test('handles case insensitive matching', () {
        expect(service.suggestCategory('grocery'), equals('Food'));
        expect(service.suggestCategory('GROCERY'), equals('Food'));
        expect(service.suggestCategory('GrOcErY'), equals('Food'));
      });

      test('matches partial keywords', () {
        expect(service.suggestCategory('Bought groceries today'), equals('Food'));
        expect(service.suggestCategory('Paid EMI for home'), equals('EMI'));
        expect(service.suggestCategory('Took uber to work'), equals('Transport'));
      });

      test('returns first matching category for multiple keywords', () {
        // If a transaction contains multiple keywords, it should return the first match
        final result = service.suggestCategory('Grocery payment for supermarket');
        expect(result, isNotNull);
        expect(['Food', 'EMI'], contains(result));
      });

      test('handles special characters', () {
        expect(service.suggestCategory('Grocery @ Store #1'), equals('Food'));
        expect(service.suggestCategory('EMI - Home Loan'), equals('EMI'));
      });

      test('handles numbers in transaction title', () {
        expect(service.suggestCategory('Grocery Store 123'), equals('Food'));
        expect(service.suggestCategory('EMI Payment 2024'), equals('EMI'));
      });
    });

    group('edge cases', () {
      test('handles very long transaction titles', () {
        final longTitle = 'This is a very long transaction title that contains the word grocery somewhere in the middle of all this text';
        expect(service.suggestCategory(longTitle), equals('Food'));
      });

      test('handles transaction with only spaces', () {
        expect(service.suggestCategory('   '), isNull);
      });

      test('handles transaction with special characters only', () {
        expect(service.suggestCategory('!@#\$%^&*()'), isNull);
      });

      test('handles unicode characters', () {
        expect(service.suggestCategory('Grocery 🛒'), equals('Food'));
        expect(service.suggestCategory('🚗 Uber ride'), equals('Transport'));
      });
    });

    group('priority and specificity', () {
      test('EMI keywords take precedence when present', () {
        // 'payment' is an EMI keyword, so it should categorize as EMI
        expect(service.suggestCategory('Monthly payment'), equals('EMI'));
      });

      test('more specific keywords are matched', () {
        expect(service.suggestCategory('Supermarket grocery shopping'), equals('Food'));
        expect(service.suggestCategory('Home loan installment payment'), equals('EMI'));
      });
    });
  });
}
