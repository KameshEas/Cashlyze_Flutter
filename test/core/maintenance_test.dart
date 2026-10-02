import 'package:cashlyze/core/api/api_exception.dart';
import 'package:cashlyze/core/api/read_only_interceptor.dart';
import 'package:cashlyze/core/models/app_version.dart';
import 'package:cashlyze/core/providers/app_version_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _response(final Map<String, dynamic> overrides) => {
      'minimumVersion': '1.0.0',
      'currentVersion': '1.0.0',
      'releaseNotes': '',
      'rolloutPercentage': 100,
      'storeUrl': '',
      'forceUpdate': false,
      'maintenanceMode': false,
      'announcementActive': false,
      ...overrides,
    };

void main() {
  group('AppVersionModel maintenance parsing', () {
    test('reads the structured maintenance object', () {
      final model = AppVersionModel.fromRTDB(_response({
        'maintenance': {
          'active': true,
          'type': 'read_only',
          'title': 'Upgrading',
          'message': 'Back soon',
          'endsAt': '2026-09-18T13:00:00+00:00',
          'retryAfterSeconds': 120,
          'statusUrl': 'https://status.example.com',
        },
      }));

      final m = model.maintenance;
      expect(m.active, isTrue);
      expect(m.isReadOnly, isTrue);
      expect(m.title, 'Upgrading');
      expect(m.message, 'Back soon');
      expect(m.endsAt, DateTime.utc(2026, 9, 18, 13));
      expect(m.retryAfterSeconds, 120);
      expect(m.statusUrl, 'https://status.example.com');
    });

    test('falls back to the legacy flat fields from an older backend', () {
      final model = AppVersionModel.fromRTDB(_response({
        'maintenanceMode': true,
        'maintenanceMessage': 'Down for a bit',
      }));

      expect(model.maintenance.active, isTrue);
      expect(model.maintenance.isReadOnly, isFalse);
      expect(model.maintenance.message, 'Down for a bit');
    });

    test('clamps an out-of-range retry interval', () {
      final low = MaintenanceInfo.fromJson({'retryAfterSeconds': 1});
      final high = MaintenanceInfo.fromJson({'retryAfterSeconds': 999999});
      expect(low.retryAfterSeconds, 15);
      expect(high.retryAfterSeconds, 3600);
    });
  });

  group('MaintenanceState', () {
    test('block mode is blocking, read-only is not', () {
      const block = MaintenanceState.active(MaintenanceInfo(active: true));
      const readOnly = MaintenanceState.active(
        MaintenanceInfo(active: true, isReadOnly: true),
      );

      expect(block.isBlocking, isTrue);
      expect(block.isReadOnly, isFalse);
      expect(readOnly.isBlocking, isFalse);
      expect(readOnly.isReadOnly, isTrue);
      expect(const MaintenanceState.inactive().isBlocking, isFalse);
      expect(const MaintenanceState.inactive().isReadOnly, isFalse);
    });
  });

  group('ReadOnlyInterceptor', () {
    Future<Object?> run(
      final String method,
      final String path, {
      required final bool readOnly,
    }) async {
      final interceptor = ReadOnlyInterceptor(() => readOnly);
      final options = RequestOptions(path: path, method: method);
      final handler = _CapturingHandler();
      interceptor.onRequest(options, handler);
      return handler.result;
    }

    test('rejects writes while read-only, with a ReadOnlyModeException', () async {
      for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        final result = await run(method, '/transactions', readOnly: true);
        expect(result, isA<DioException>(), reason: method);
        expect((result! as DioException).error, isA<ReadOnlyModeException>());
      }
    });

    test('lets reads through while read-only', () async {
      expect(await run('GET', '/transactions', readOnly: true), isA<RequestOptions>());
    });

    test('lets auth calls through so users can still sign in', () async {
      expect(await run('POST', '/auth/login', readOnly: true), isA<RequestOptions>());
      expect(await run('POST', '/auth/refresh', readOnly: true), isA<RequestOptions>());
    });

    test('lets everything through when not read-only', () async {
      expect(await run('POST', '/transactions', readOnly: false), isA<RequestOptions>());
    });
  });
}

/// Records what an interceptor did with a request: forwarded ([RequestOptions])
/// or rejected ([DioException]).
class _CapturingHandler extends RequestInterceptorHandler {
  Object? result;

  @override
  void next(final RequestOptions requestOptions) => result = requestOptions;

  @override
  void reject(final DioException error, [final bool callFollowingErrorInterceptor = false]) =>
      result = error;
}
