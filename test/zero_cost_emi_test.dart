import 'package:flutter_test/flutter_test.dart';
import 'package:cashlyze/core/services/emi_calculator.dart';
import 'package:cashlyze/core/models/emi.dart';

void main() {
  group('Zero Cost EMI Calculator Tests', () {
    test('Should calculate zero interest EMI correctly', () {
      final result = EMICalculator.compute(
        planId: 'test-plan',
        loanAmount: 10000,
        annualRate: 0, // Zero interest
        tenureMonths: 10,
        startDate: DateTime(2024, 1, 1),
        frequency: PaymentFrequency.monthly,
      );

      // For zero interest, installment should be loanAmount / totalPeriods
      expect(result.installment, equals(1000)); // 10000 / 10 months
      expect(result.totalInterest, equals(0)); // No interest
      expect(result.schedule.length, equals(10));
      
      // Verify each payment has zero interest
      for (final payment in result.schedule) {
        expect(payment.interest, equals(0));
        expect(payment.principal, equals(1000)); // Equal principal payments
      }
    });

    test('Should handle zero cost EMI with quarterly frequency', () {
      final result = EMICalculator.compute(
        planId: 'test-plan',
        loanAmount: 12000,
        annualRate: 0, // Zero interest
        tenureMonths: 12,
        startDate: DateTime(2024, 1, 1),
        frequency: PaymentFrequency.quarterly,
      );

      // 12000 / 4 quarters = 3000 per quarter
      expect(result.installment, equals(3000));
      expect(result.totalInterest, equals(0));
      expect(result.schedule.length, equals(4));
    });

    test('Should handle zero cost EMI with weekly frequency', () {
      final result = EMICalculator.compute(
        planId: 'test-plan',
        loanAmount: 5200,
        annualRate: 0, // Zero interest
        tenureMonths: 2, // ~8 weeks
        startDate: DateTime(2024, 1, 1),
        frequency: PaymentFrequency.weekly,
      );

      // Should create equal weekly payments
      expect(result.totalInterest, equals(0));
      expect(result.schedule.length, greaterThan(0));
      
      // Verify all payments have zero interest
      for (final payment in result.schedule) {
        expect(payment.interest, equals(0));
      }
    });

    test('Should differentiate between zero and non-zero interest', () {
      // Zero interest
      final zeroInterestResult = EMICalculator.compute(
        planId: 'zero-interest',
        loanAmount: 10000,
        annualRate: 0,
        tenureMonths: 10,
        startDate: DateTime(2024, 1, 1),
        frequency: PaymentFrequency.monthly,
      );

      // With interest
      final withInterestResult = EMICalculator.compute(
        planId: 'with-interest',
        loanAmount: 10000,
        annualRate: 12, // 12% annual interest
        tenureMonths: 10,
        startDate: DateTime(2024, 1, 1),
        frequency: PaymentFrequency.monthly,
      );

      // Zero interest should have no interest and equal installments
      expect(zeroInterestResult.totalInterest, equals(0));
      expect(zeroInterestResult.installment, equals(1000));

      // With interest should have interest and different installment amount
      expect(withInterestResult.totalInterest, greaterThan(0));
      expect(withInterestResult.installment, isNot(equals(1000)));
    });
  });
}