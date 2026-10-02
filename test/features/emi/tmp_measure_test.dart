import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/features/emi/emi_form_screen.dart';
import 'package:cashlyze/features/emi/widgets/emi_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('measure', (final tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: EMIFormScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '100000');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.enterText(find.byType(TextField).at(2), '12');
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREEN ${tester.view.physicalSize / tester.view.devicePixelRatio}');
    // ignore: avoid_print
    print('SUMMARY ${tester.getRect(find.byType(EmiSummaryLine))}');
    // ignore: avoid_print
    print('BUTTON ${tester.getRect(find.byType(FilledButton))}');
    // ignore: avoid_print
    print('WEEKLY ${tester.getRect(find.text('Weekly'))}');
    // ignore: avoid_print
    print('INSETS ${tester.view.viewInsets} pad ${tester.view.padding}');
  });
}
