import 'package:cashlyze/features/goals/widgets/goal_completion_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GoalCompletionCelebration loads and renders the Lottie asset without error', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoalCompletionCelebration(),
        ),
      ),
    );

    // Let the asset load, the animation play out, and its internal dismiss
    // timer fire (composition is ~1s + a 300ms hold).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(GoalCompletionCelebration), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoalCompletionCelebration.show displays and auto-dismisses under reduce motion', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (final context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => GoalCompletionCelebration.show(context),
                child: const Text('Celebrate'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Celebrate'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(GoalCompletionCelebration), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reduce-motion dismisses after ~900ms; settle well past that.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GoalCompletionCelebration), findsNothing);
  });
}
