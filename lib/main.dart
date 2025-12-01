import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_options_placeholder.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kReleaseMode;
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/providers/shared_prefs_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  } catch (e) {}
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppLocalizations.of(context)?.appTitle ?? 'Cashlyze',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
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
