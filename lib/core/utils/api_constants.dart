// ─────────────────────────────────────────────
// API CONSTANTS
// All external API base URLs and endpoint paths
// are defined here. Never hardcode URLs elsewhere.
// ─────────────────────────────────────────────

abstract final class ApiConstants {
  // Base URLs
  static const String cashlyzeBaseUrl = 'https://cashlyze.netlify.app/api';

  // OTP endpoints
  static const String sendOtp   = '$cashlyzeBaseUrl/send-otp';
  static const String verifyOtp = '$cashlyzeBaseUrl/verify-otp';
}
