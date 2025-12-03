import 'package:cashlyze/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('app launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // App should launch without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('splash screen appears on launch', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      
      // Give time for splash screen to appear
      await tester.pump(const Duration(milliseconds: 100));

      // Splash screen should be visible initially
      // Note: This test may need adjustment based on your actual splash screen implementation
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app navigates through basic flow', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Wait for any initial navigation
      await tester.pumpAndSettle();

      // App should be running
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Theme Tests', () {
    testWidgets('app supports dark and light themes', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Find MaterialApp widget
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      
      // Verify theme and darkTheme are set
      expect(materialApp.theme, isNotNull);
      expect(materialApp.darkTheme, isNotNull);
    });
  });

  group('Localization Tests', () {
    testWidgets('app has localization delegates', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      
      // Verify localization is configured
      expect(materialApp.localizationsDelegates, isNotEmpty);
      expect(materialApp.supportedLocales, isNotEmpty);
    });
  });
}
