import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App builds', (final WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const App(),
      ),
    );
    // Ensure the App widget is present and builds without throwing side-effects.
    expect(find.byType(App), findsOneWidget);
  });
}
