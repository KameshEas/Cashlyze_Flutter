import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exception.dart';

/// Remote data source for the forgot-password flow:
/// - `POST /auth/forgot-password`
/// - `POST /auth/reset-password/verify-otp`
/// - `POST /auth/reset-password`
///
/// Error contract (see [ApiClient]):
/// - [ValidationException] (400): wrong/expired code, expired reset session,
///   or a password the server's policy rejects. The messages are generic by
///   design - the server never says whether an email is registered.
/// - [TooManyRequestsException] (429): rate limited.
class PasswordResetRemoteDataSource {
  const PasswordResetRemoteDataSource({required final ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  static const String _appId = 'cashlyze';

  /// Asks the backend to email a 6-digit code to [email]. Succeeds (202) the
  /// same way whether or not the email is registered.
  Future<void> requestCode({required final String email}) async {
    await _api.post<Map<String, dynamic>>(
      ApiEndpoints.forgotPassword,
      data: {'email': email, 'app_id': _appId},
    );
  }

  /// Exchanges the emailed [otp] for a short-lived, single-use reset token.
  Future<String> verifyCode({
    required final String email,
    required final String otp,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.resetPasswordVerifyOtp,
      data: {'email': email, 'app_id': _appId, 'otp': otp},
    );
    final token = (response.data as Map)['reset_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ParseException('Missing reset token in response');
    }
    return token;
  }

  /// Sets the new password using the token from [verifyCode].
  Future<void> resetPassword({
    required final String resetToken,
    required final String newPassword,
  }) async {
    await _api.post<Map<String, dynamic>>(
      ApiEndpoints.resetPassword,
      data: {
        'reset_token': resetToken,
        'app_id': _appId,
        'new_password': newPassword,
      },
    );
  }
}

final passwordResetRemoteDataSourceProvider =
    Provider<PasswordResetRemoteDataSource>((final ref) {
  return PasswordResetRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
