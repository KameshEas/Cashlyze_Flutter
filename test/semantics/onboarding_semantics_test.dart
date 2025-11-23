import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashlyze/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding includes Semantics widgets with reduced motion', (WidgetTester tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Semantics), findsWidgets);
  });
}