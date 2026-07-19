import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/features/goals/create_edit_goal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpSheet(final WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: CreateEditGoalSheet()),
        ),
      ),
    );
  }

  testWidgets(
    'shows a validation error instead of crashing when the target amount is non-numeric',
    (final WidgetTester tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Test Goal');
      // Target Amount field (index 2): name=0, description=1, target=2, current=3.
      await tester.enterText(find.byType(TextField).at(2), '12.34.56');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows a validation error instead of crashing when the current amount is non-numeric',
    (final WidgetTester tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Test Goal');
      await tester.enterText(find.byType(TextField).at(2), '1000');
      await tester.enterText(find.byType(TextField).at(3), 'abc');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows a validation error when required fields are empty',
    (final WidgetTester tester) async {
      await pumpSheet(tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Please fill in required fields'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
