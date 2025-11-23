import 'package:flutter_test/flutter_test.dart';
import 'package:cashlyze/core/services/categorization_service.dart';

void main() {
  group('EMI Categorization Tests', () {
    late CategorizationService categorizationService;

    setUp(() {
      categorizationService = CategorizationService();
    });

    test('Should categorize EMI transactions correctly', () {
      expect(categorizationService.suggestCategory('Home Loan EMI'), equals('EMI'));
      expect(categorizationService.suggestCategory('Car Loan Payment'), equals('EMI'));
      expect(categorizationService.suggestCategory('Mortgage Installment'), equals('EMI'));
      expect(categorizationService.suggestCategory('Personal Loan EMI'), equals('EMI'));
      expect(categorizationService.suggestCategory('Monthly EMI Payment'), equals('EMI'));
    });

    test('Should not categorize non-EMI transactions as EMI', () {
      expect(categorizationService.suggestCategory('Grocery Shopping'), equals('Food'));
      expect(categorizationService.suggestCategory('Netflix Subscription'), equals('Entertainment'));
      expect(categorizationService.suggestCategory('Uber Ride'), equals('Transport'));
      expect(categorizationService.suggestCategory('Salary Credit'), equals('Income'));
    });

    test('Should handle case insensitive matching', () {
      expect(categorizationService.suggestCategory('emi payment'), equals('EMI'));
      expect(categorizationService.suggestCategory('LOAN INSTALLMENT'), equals('EMI'));
      expect(categorizationService.suggestCategory('Mortgage'), equals('EMI'));
    });
  });
}