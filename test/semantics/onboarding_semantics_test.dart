import 'package:cashlyze/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Onboarding includes Semantics widgets with reduced motion', (final WidgetTester tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Semantics), findsWidgets);
  });
}
