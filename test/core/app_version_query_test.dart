import 'package:cashlyze/features/version/data/app_version_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appVersionQuery', () {
    test('always sends the platform', () {
      expect(appVersionQuery('android'), {'platform': 'android'});
    });

    test('adds the installed version and the app language when known', () {
      expect(
        appVersionQuery('android', version: '1.4.0', locale: 'hi'),
        {'platform': 'android', 'version': '1.4.0', 'locale': 'hi'},
      );
    });

    test('leaves out blank version and language', () {
      expect(appVersionQuery('ios', version: '', locale: ''), {'platform': 'ios'});
    });

    test('asks for test announcements only when told to (debug builds)', () {
      expect(appVersionQuery('android').containsKey('test'), isFalse);
      expect(appVersionQuery('android', includeTest: true)['test'], 'true');
    });

    test('sends the OneSignal id so a chosen test device sees test announcements', () {
      expect(appVersionQuery('android', deviceId: 'abc-123')['device'], 'abc-123');
    });

    test('leaves out the device id until the phone has one', () {
      expect(appVersionQuery('android').containsKey('device'), isFalse);
      expect(appVersionQuery('android', deviceId: '').containsKey('device'), isFalse);
    });

    test('pushSubscriptionId is null (not a crash) when OneSignal is not set up', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(pushSubscriptionId(), isNull);
    });
  });
}
