import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Leaves an HTTP breadcrumb (method, path, status, duration) for every
/// request, so a crash report shows what the app was doing just before it
/// happened. Deliberately never includes headers or request/response bodies:
/// this app's API carries auth tokens and financial data, neither of which
/// belongs in Sentry.
class SentryBreadcrumbInterceptor extends Interceptor {
  final _startedAt = Expando<DateTime>();

  @override
  void onRequest(final RequestOptions options, final RequestInterceptorHandler handler) {
    _startedAt[options] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(final Response<dynamic> response, final ResponseInterceptorHandler handler) {
    _addBreadcrumb(response.requestOptions, statusCode: response.statusCode);
    handler.next(response);
  }

  @override
  void onError(final DioException err, final ErrorInterceptorHandler handler) {
    _addBreadcrumb(err.requestOptions, statusCode: err.response?.statusCode, error: err.type.name);
    handler.next(err);
  }

  void _addBreadcrumb(final RequestOptions options, {final int? statusCode, final String? error}) {
    final started = _startedAt[options];
    final duration = started == null ? null : DateTime.now().difference(started);
    Sentry.addBreadcrumb(
      Breadcrumb.http(
        // Strip query params: some endpoints accept search/filter text there.
        url: options.uri.replace(query: ''),
        method: options.method,
        statusCode: statusCode,
        requestDuration: duration,
        reason: error,
      ),
    );
  }
}
