abstract final class ApiConstants {
  static const String cashlyzeBaseUrl = 'https://cashlyze-api.kameshsdeveloper.workers.dev';

  // OTP endpoints
  static const String sendOtp   = '$cashlyzeBaseUrl/api/send-otp';
  static const String verifyOtp = '$cashlyzeBaseUrl/api/verify-otp';
}
