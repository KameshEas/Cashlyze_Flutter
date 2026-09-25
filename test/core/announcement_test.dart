import 'package:cashlyze/core/models/app_version.dart';
import 'package:cashlyze/core/providers/app_version_providers.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/services/announcement_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnnouncementInfo _a(
  final String id, {
  final String placement = 'banner',
  final String frequency = 'once',
  final bool dismissible = true,
}) =>
    AnnouncementInfo(
      id: id,
      body: 'Body $id',
      placement: placement,
      frequency: frequency,
      dismissible: dismissible,
    );

AppVersionModel _config(final List<AnnouncementInfo> announcements) => AppVersionModel(
      minimumVersion: '1.0.0',
      currentVersion: '1.0.0',
      releaseNotes: '',
      rolloutPercentage: 100,
      storeUrl: '',
      announcements: announcements,
    );

Map<String, dynamic> _json(final Map<String, dynamic> overrides) => {
      'minimumVersion': '1.0.0',
      'currentVersion': '1.0.0',
      'releaseNotes': '',
      'rolloutPercentage': 100,
      'storeUrl': '',
      ...overrides,
    };

void main() {
  final now = DateTime(2026, 9, 18, 15);

  group('isAnnouncementSuppressed', () {
    bool suppressed(
      final AnnouncementInfo a, {
      final int? lastSeen,
      final bool session = false,
    }) =>
        isAnnouncementSuppressed(a, lastSeenMillis: lastSeen, seenThisSession: session, now: now);

    test('once: hidden forever after being seen', () {
      final a = _a('x');
      expect(suppressed(a), isFalse);
      expect(
        suppressed(a, lastSeen: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch),
        isTrue,
      );
    });

    test('daily: hidden the same day, back the next day', () {
      final a = _a('x', frequency: 'daily');
      final earlierToday = DateTime(2026, 9, 18, 8).millisecondsSinceEpoch;
      final yesterday = DateTime(2026, 9, 17, 23, 59).millisecondsSinceEpoch;
      expect(suppressed(a, lastSeen: earlierToday), isTrue);
      expect(suppressed(a, lastSeen: yesterday), isFalse);
      expect(suppressed(a), isFalse);
    });

    test('every_launch: hidden only for the rest of this session', () {
      final a = _a('x', frequency: 'every_launch');
      expect(suppressed(a, lastSeen: 1), isFalse);
      expect(suppressed(a, session: true), isTrue);
    });

    test('a banner that cannot be dismissed is never suppressed', () {
      final a = _a('x', dismissible: false);
      expect(suppressed(a, lastSeen: 1, session: true), isFalse);
    });

    test('a required dialog is suppressed once acknowledged', () {
      final a = _a('x', placement: 'dialog', dismissible: false);
      expect(suppressed(a, lastSeen: 1), isTrue);
    });
  });

  group('AppVersionModel announcements parsing', () {
    test('reads the announcements array', () {
      final model = AppVersionModel.fromRTDB(_json({
        'announcements': [
          {
            'id': 'a1',
            'type': 'warning',
            'placement': 'dialog',
            'title': 'Heads up',
            'body': 'Downtime tonight',
            'ctaLabel': 'Update',
            'ctaType': 'store',
            'dismissible': false,
            'frequency': 'daily',
            'priority': 5,
          },
        ],
      }));

      final a = model.announcements.single;
      expect(a.id, 'a1');
      expect(a.type, 'warning');
      expect(a.isDialog, isTrue);
      expect(a.title, 'Heads up');
      expect(a.hasCta, isTrue);
      expect(a.ctaType, 'store');
      expect(a.dismissible, isFalse);
      expect(a.frequency, 'daily');
      expect(a.priority, 5);
    });

    test('skips entries without an id or body', () {
      final model = AppVersionModel.fromRTDB(_json({
        'announcements': [
          {'id': '', 'body': 'no id'},
          {'id': 'a1', 'body': ''},
          {'id': 'a2', 'body': 'ok'},
        ],
      }));
      expect(model.announcements.map((final a) => a.id), ['a2']);
    });

    test('a button needs both a type and a label', () {
      expect(const AnnouncementInfo(id: 'a', body: 'b', ctaType: 'url').hasCta, isFalse);
      expect(
        const AnnouncementInfo(id: 'a', body: 'b', ctaType: 'url', ctaLabel: 'Go').hasCta,
        isTrue,
      );
    });

    test('an older backend sends only the single banner fields', () {
      final model = AppVersionModel.fromRTDB(_json({
        'announcementActive': true,
        'announcementMessage': 'Old style',
      }));
      final a = model.announcements.single;
      expect(a.body, 'Old style');
      expect(a.isBanner, isTrue);
      expect(a.id, startsWith('legacy-'));
    });

    test('no announcements at all', () {
      expect(AppVersionModel.fromRTDB(_json({})).announcements, isEmpty);
    });
  });

  group('AnnouncementStateNotifier', () {
    Future<ProviderContainer> containerWith(
      final List<AnnouncementInfo> live,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        currentPlatformVersionProvider.overrideWith((final ref) async => _config(live)),
      ]);
      addTearDown(container.dispose);
      await container.read(announcementStateProvider.notifier).check();
      return container;
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('picks the first banner and the first dialog', () async {
      final container = await containerWith([
        _a('d1', placement: 'dialog'),
        _a('b1'),
        _a('b2'),
        _a('d2', placement: 'dialog'),
      ]);
      final state = container.read(announcementStateProvider);
      expect(state.banner?.id, 'b1');
      expect(state.dialog?.id, 'd1');
    });

    test('dismissing a banner shows the next one and remembers it', () async {
      final container = await containerWith([_a('b1'), _a('b2')]);
      final notifier = container.read(announcementStateProvider.notifier);

      await notifier.dismiss(container.read(announcementStateProvider).banner!);
      expect(container.read(announcementStateProvider).banner?.id, 'b2');

      // A fresh launch (new container, same storage) must not bring b1 back.
      final relaunched = await containerWith([_a('b1'), _a('b2')]);
      expect(relaunched.read(announcementStateProvider).banner?.id, 'b2');
    });

    test('every_launch comes back on the next launch', () async {
      final container = await containerWith([_a('b1', frequency: 'every_launch')]);
      await container
          .read(announcementStateProvider.notifier)
          .dismiss(container.read(announcementStateProvider).banner!);
      expect(container.read(announcementStateProvider).banner, isNull);

      final relaunched = await containerWith([_a('b1', frequency: 'every_launch')]);
      expect(relaunched.read(announcementStateProvider).banner?.id, 'b1');
    });

    test('an undismissable banner stays after a dismiss attempt', () async {
      final container = await containerWith([_a('b1', dismissible: false)]);
      await container
          .read(announcementStateProvider.notifier)
          .dismiss(container.read(announcementStateProvider).banner!);
      expect(container.read(announcementStateProvider).banner?.id, 'b1');
    });

    test('nothing live means nothing shown', () async {
      final container = await containerWith(const []);
      final state = container.read(announcementStateProvider);
      expect(state.banner, isNull);
      expect(state.dialog, isNull);
    });
  });
}
