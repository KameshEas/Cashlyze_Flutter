import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Rejects requests that would change data while the backend has the app in
/// read-only maintenance. No request is sent.
///
/// Reads and the auth endpoints (login, token refresh, logout, OTP) still go
/// through so users can view their data and sign in.
class ReadOnlyInterceptor extends Interceptor {
  ReadOnlyInterceptor(this.isReadOnly);

  final bool Function() isReadOnly;

  static const _safeMethods = {'GET', 'HEAD', 'OPTIONS'};

  @override
  void onRequest(
    final RequestOptions options,
    final RequestInterceptorHandler handler,
  ) {
    final isWrite = !_safeMethods.contains(options.method.toUpperCase());
    if (isWrite && isReadOnly() && !options.path.contains('/auth/')) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const ReadOnlyModeException(),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}
