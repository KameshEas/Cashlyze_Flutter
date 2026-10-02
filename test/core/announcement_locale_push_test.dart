import 'package:cashlyze/core/models/app_version.dart';
import 'package:cashlyze/core/providers/app_version_providers.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/repositories/app_version_repository.dart';
import 'package:cashlyze/core/services/app_version_service.dart';
import 'package:cashlyze/core/services/push_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the app asks the backend for.
class _RecordingRepository implements AppVersionRepository {
  final List<({String platform, String? version, String? locale})> calls = [];

  @override
  Future<AppVersionModel?> getVersionByPlatform(
    final String platform, {
    final String? version,
    final String? locale,
  }) async {
    calls.add((platform: platform, version: version, locale: locale));
    return AppVersionModel(
      minimumVersion: '1.0.0',
      currentVersion: '1.0.0',
      releaseNotes: '',
      rolloutPercentage: 100,
      storeUrl: '',
      announcements: [
        AnnouncementInfo(id: 'a-${locale ?? 'base'}', body: 'Text in ${locale ?? 'base'}'),
      ],
    );
  }
}

class _FakeVersionService implements AppVersionService {
  @override
  String getPlatformName() => 'android';

  @override
  Future<String> getCurrentAppVersion() async => '1.4.0';

  @override
  dynamic noSuchMethod(final Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('parsePushAction', () {
    test('reads the action an announcement push carries', () {
      final action = parsePushAction({
        'announcementId': 'a1',
        'ctaType': 'route',
        'ctaValue': '/budgets',
      })!;
      expect(action.ctaType, 'route');
      expect(action.ctaValue, '/budgets');
    });

    test('a store action needs no value', () {
      final action = parsePushAction({'ctaType': 'store', 'ctaValue': null})!;
      expect(action.ctaType, 'store');
      expect(action.ctaValue, isNull);
    });

    test('plain pushes and unknown action types do nothing', () {
      expect(parsePushAction(null), isNull);
      expect(parsePushAction({}), isNull);
      expect(parsePushAction({'ctaType': null}), isNull);
      expect(parsePushAction({'ctaType': 'delete-everything', 'ctaValue': 'x'}), isNull);
      expect(parsePushAction({'ctaType': 42}), isNull);
    });
  });

  group('language and version sent to the backend', () {
    late _RecordingRepository repository;

    Future<ProviderContainer> container({required final String language}) async {
      SharedPreferences.setMockInitialValues({'app_language_code': language});
      final prefs = await SharedPreferences.getInstance();
      repository = _RecordingRepository();
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appVersionRepositoryProvider.overrideWithValue(repository),
        appVersionServiceProvider.overrideWithValue(_FakeVersionService()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('sends the installed version and the app language', () async {
      final c = await container(language: 'HIN');
      await c.read(currentPlatformVersionProvider.future);

      expect(repository.calls.single.version, '1.4.0');
      expect(repository.calls.single.locale, 'hi');
    });

    test('English and Tamil map to en and ta', () async {
      final english = await container(language: 'ENG');
      await english.read(currentPlatformVersionProvider.future);
      expect(repository.calls.single.locale, 'en');

      final tamil = await container(language: 'TAM');
      await tamil.read(currentPlatformVersionProvider.future);
      expect(repository.calls.single.locale, 'ta');
    });

    test('changing the language refetches the announcements in that language', () async {
      final c = await container(language: 'ENG');
      final notifier = c.read(announcementStateProvider.notifier);
      await notifier.check();
      expect(c.read(announcementStateProvider).banner?.body, 'Text in en');

      await c.read(localeProvider.notifier).setCode('HIN');
      // The language change triggers a re-check; let it finish.
      await c.read(currentPlatformVersionProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls.map((final call) => call.locale), containsAllInOrder(['en', 'hi']));
      expect(c.read(announcementStateProvider).banner?.body, 'Text in hi');
    });
  });
}
