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
  });
}
