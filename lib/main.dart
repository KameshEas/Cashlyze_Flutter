import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_options_placeholder.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/providers/shared_prefs_provider.dart';

Future<void> _runAppWithPrefs() async {
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}

Future<void> _appRunner() async {
  final usePlaceholder =
      const bool.fromEnvironment('FIREBASE_PLACEHOLDER') && !kReleaseMode;

  try {
    await Firebase.initializeApp(
      options: usePlaceholder
          ? (defaultTargetPlatform == TargetPlatform.iOS
              ? DefaultFirebaseOptionsPlaceholder.ios
              : DefaultFirebaseOptionsPlaceholder.android)
          : DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!kReleaseMode) debugPrint('Firebase init failed: $e');
  }

  try {
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
      if (kReleaseMode) {
        Sentry.captureException(details.exception, stackTrace: details.stack);
      } else {
        FlutterError.dumpErrorToConsole(details);
      }
    };
  } catch (e) {
    if (!kReleaseMode) debugPrint('Crashlytics init failed: $e');
  }

  await _runAppWithPrefs();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (!kReleaseMode) debugPrint('Failed to load .env file: $e');
  }

  // Resolve DSN from .env first then compile-time env
  final sentryDsn = dotenv.env['SENTRY_DSN'] ??
      const String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  if (sentryDsn.isEmpty) {
    if (!kReleaseMode) debugPrint('SENTRY_DSN not set — running without Sentry.');
    await _appRunner();
    return;
  }

  // Initialize Sentry safely — do not let Sentry failures block startup.
  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.0;
        options.environment = const String.fromEnvironment(
          'SENTRY_ENV',
          defaultValue: kReleaseMode ? 'production' : 'development',
        );

        (options as dynamic).beforeSend = (event, {hint}) {
          if (!kReleaseMode) return null;

          final ex = event.exceptions?.first;
          final exType = ex?.type ?? '';
          const skipTypes = [
            'FormatException',
            'AssertionError',
            'RangeError',
            'StateError'
          ];
          for (final skip in skipTypes) {
            if (exType.contains(skip)) return null;
          }
          return event;
        };
      },
      appRunner: _appRunner,
    );
  } catch (e) {
    // If Sentry init fails for any reason, log and continue startup.
    if (!kReleaseMode) debugPrint('Sentry init failed: $e');
    await _appRunner();
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: AppLocalizations.of(context)?.appTitle ?? 'Cashlyze',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
