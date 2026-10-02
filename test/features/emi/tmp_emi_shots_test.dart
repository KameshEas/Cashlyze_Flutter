import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/emi/emi_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = r'C:\Users\KAMESH~1\AppData\Local\Temp\claude\e--Mobile-Development-Flutter-Projects-aspired2d-services\b9191fa8-9c2e-41f0-a57b-154460e32002\scratchpad';

Future<void> _shot(final WidgetTester tester, final String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out\\$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

late ThemeData _darkT;
late ThemeData _lightT;

ThemeData _roboto(final ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamily: 'Roboto'),
    );

Future<void> _pump(final WidgetTester tester, final bool dark) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: RepaintBoundary(
        key: const ValueKey('shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _roboto(dark ? _darkT : _lightT),
          home: const EMIFormScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Offline: google_fonts reports failed downloads; the theme still builds.
    FlutterError.onError = (final d) {
      if (!d.toString().contains('google_fonts') && !d.toString().contains('fonts.gstatic')) {
        FlutterError.presentError(d);
      }
    };
    GoogleFonts.config.allowRuntimeFetching = false;
    const dir = 'C:/flutter/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final f in ['regular', 'medium', 'bold']) {
      final bytes = await File('$dir/roboto-$f.ttf').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File('$dir/materialicons-regular.otf').readAsBytesSync())));
    await icons.load();
    // Build the themes once in a zone that swallows google_fonts' offline errors.
    await runZonedGuarded(() async {
      _darkT = AppTheme.darkTheme;
      _lightT = AppTheme.lightTheme;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }, (final e, final st) {});
  });

  for (final dark in [true, false]) {
    final t = dark ? 'dark' : 'light';
    testWidgets('shots $t', (final tester) async {
      await _pump(tester, dark);
      await _shot(tester, 'emi_${t}_1_empty');

      await tester.enterText(find.byType(TextField).at(0), '250000');
      await tester.enterText(find.byType(TextField).at(1), '9.5');
      await tester.enterText(find.byType(TextField).at(2), '24');
      await tester.pumpAndSettle();
      await _shot(tester, 'emi_${t}_2_preview');

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await _shot(tester, 'emi_${t}_3_zero');
    });
  }

  testWidgets('shots errors', (final tester) async {
    await _pump(tester, true);
    await tester.tap(find.text('Create plan'));
    await tester.pumpAndSettle();
    await _shot(tester, 'emi_dark_4_errors');
  });
}
