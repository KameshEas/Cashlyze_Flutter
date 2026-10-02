import 'dart:convert';

import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, theme) in [('dark', AppTheme.darkTheme), ('light', AppTheme.lightTheme)]) {
    group('$name theme typography', () {
      test('Geist is the theme-wide fallback family', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, kFontFamily);
        expect(kFontFamily, 'Geist');
      });

      test('every text style uses Geist: one typeface across the app', () {
        final t = theme.textTheme;
        final styles = {
          'displayLarge': t.displayLarge,
          'displayMedium': t.displayMedium,
          'headlineLarge': t.headlineLarge,
          'headlineMedium': t.headlineMedium,
          'headlineSmall': t.headlineSmall,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge,
          'labelMedium': t.labelMedium,
          'labelSmall': t.labelSmall,
          'appBar title': theme.appBarTheme.titleTextStyle,
          'dialog title': theme.dialogTheme.titleTextStyle,
        };
        for (final e in styles.entries) {
          expect(e.value?.fontFamily, kFontFamily, reason: '${e.key} must use Geist');
        }
      });

      test('display sizes are tracked tighter than body text', () {
        expect(theme.textTheme.displayLarge!.letterSpacing, lessThan(0));
        expect(theme.textTheme.displayMedium!.letterSpacing, lessThan(0));
        expect(theme.textTheme.bodyMedium!.letterSpacing, isNull);
      });
    });
  }

  test('the font is bundled (not fetched at runtime) at every weight the app uses', () async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
    final geist = manifest.cast<Map<String, dynamic>>().singleWhere((final e) => e['family'] == 'Geist');
    final weights = {for (final f in (geist['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) f['weight'] as int};
    // The app uses w400/w500/w600/w700 (and one w800): none may be synthesised.
    expect(weights, containsAll(<int>{400, 500, 600, 700, 800}));
  });

  test('the font files and their licence ship with the app', () async {
    for (final n in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = await rootBundle.load('assets/fonts/Geist-$n.ttf');
      expect(bytes.lengthInBytes, greaterThan(50 * 1024), reason: 'Geist-$n.ttf should be a real font file');
    }
    final licence = await rootBundle.loadString('assets/fonts/OFL.txt');
    expect(licence, contains('SIL OPEN FONT LICENSE'));
  });
}
