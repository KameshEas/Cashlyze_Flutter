import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exception.dart';

// ── Response models ───────────────────────────────────────────────────────────

/// Result of a successful OTP verification.
///
/// [otpToken] is an opaque server-issued token that must be forwarded to
/// `POST /auth/register` to prove the email was verified.
class OtpVerifyResult {
  const OtpVerifyResult({this.otpToken, this.message});

  final String? otpToken;
  final String? message;

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    final token = json['otp_token'] as String? ?? json['token'] as String?;
    return OtpVerifyResult(
      otpToken: token,
      message: json['message'] as String?,
    );
  }
}

// ── Data source ───────────────────────────────────────────────────────────────

/// Remote data source for OTP endpoints:
/// - `POST /auth/otp/send`
/// - `POST /auth/otp/verify`
///
/// The OTP flow must be completed **before** calling
/// [AuthRemoteDataSource.register] so that the backend-issued [OtpVerifyResult.otpToken]
/// can be forwarded.
class OtpRemoteDataSource {
  const OtpRemoteDataSource({required ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  // ── Send OTP ──────────────────────────────────────────────────────────────

  /// Requests the backend to send a 6-digit OTP to [email].
  ///
  /// Throws an [ApiException] subtype on failure.
  Future<void> sendOtp({required String email}) async {
    await _api.post<Map<String, dynamic>>(
      ApiEndpoints.otpSend,
      data: {'email': email},
    );
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────

  /// Verifies [otp] for [email] and returns an [OtpVerifyResult] containing
  /// the server-issued token needed for registration.
  ///
  /// Throws [ValidationException] if the OTP is incorrect or expired.
  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.otpVerify,
      data: {'email': email, 'otp': otp},
    );
    return OtpVerifyResult.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final otpRemoteDataSourceProvider = Provider<OtpRemoteDataSource>((ref) {
  return OtpRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
