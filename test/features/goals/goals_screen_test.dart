import 'dart:async';

import 'package:cashlyze/core/models/goals_model.dart';
import 'package:cashlyze/core/providers/goals_providers.dart';
import 'package:cashlyze/core/widgets/skeleton.dart';
import 'package:cashlyze/features/goals/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GoalsModel _fixtureGoal({
  final String id = 'g1',
  final double targetAmount = 1000,
  final double currentAmount = 250,
  final bool isActive = true,
}) {
  final now = DateTime(2026);
  return GoalsModel(
    id: id,
    userId: 'u1',
    name: 'Emergency Fund',
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpGoalsScreen(
  final WidgetTester tester, {
  required final AsyncValue<List<GoalsModel>> Function() build,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        goalsListProvider.overrideWith((final ref) {
          final value = build();
          return value.when(
            data: Future.value,
            // Never completes, so the provider stays in AsyncLoading for the
            // duration of the test.
            loading: () => Completer<List<GoalsModel>>().future,
            error: Future<List<GoalsModel>>.error,
          );
        }),
      ],
      child: const MaterialApp(home: GoalsScreen()),
    ),
  );
}

void main() {
  testWidgets('shows a skeleton loading state while goals are loading', (
    final WidgetTester tester,
  ) async {
    await _pumpGoalsScreen(tester, build: () => const AsyncLoading());
    await tester.pump();

    expect(find.byType(SkeletonListTile), findsWidgets);
    expect(find.text('No savings goals yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state with a create-goal action when there are no goals', (
    final WidgetTester tester,
  ) async {
    await _pumpGoalsScreen(tester, build: () => const AsyncData([]));
    await tester.pumpAndSettle();

    expect(find.text('No savings goals yet'), findsOneWidget);
    expect(find.text('Create Goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a clean error message and retry action when loading fails', (
    final WidgetTester tester,
  ) async {
    await _pumpGoalsScreen(
      tester,
      build: () => AsyncError(Exception('network down'), StackTrace.empty),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load savings goals'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Must not leak the raw exception's runtime type/toString into the UI.
    expect(find.textContaining('Exception:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders goals grouped into Active and Completed sections', (
    final WidgetTester tester,
  ) async {
    await _pumpGoalsScreen(
      tester,
      build: () => AsyncData([
        _fixtureGoal(),
        _fixtureGoal(id: 'g2', currentAmount: 500, targetAmount: 500),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Active Goals'), findsOneWidget);
    expect(find.text('Emergency Fund'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
