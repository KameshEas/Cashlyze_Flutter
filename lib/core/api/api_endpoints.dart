import '../config/env_config.dart';

/// All REST endpoint paths for the Cashlyze backend API.
///
/// Paths are relative to [EnvConfig.baseUrl].  Use [ApiEndpoints.resolve]
/// to get the full URL string.
abstract final class ApiEndpoints {
  // ── OTP ───────────────────────────────────────────────────────────────────
  static const String otpSend = '/auth/otp/send';
  static const String otpVerify = '/auth/otp/verify';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String changePassword = '/auth/password';

  // ── Users ─────────────────────────────────────────────────────────────────
  static const String usersMe = '/users/me';
  // deleteMe uses DELETE method on usersMe

  // ── App Version ───────────────────────────────────────────────────────────
  static const String appVersion = '/app-version';

  // ── Categories ────────────────────────────────────────────────────────────
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';

  // ── Transactions ──────────────────────────────────────────────────────────
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';

  // ── Budgets ───────────────────────────────────────────────────────────────
  static const String budgets = '/budgets';
  static String budgetById(String id) => '/budgets/$id';

  // ── EMI ───────────────────────────────────────────────────────────────────
  static const String emiPlans = '/emi-plans';
  static String emiPlanById(String id) => '/emi-plans/$id';
  static String emiSchedules(String planId) => '/emi-plans/$planId/schedules';
  static String emiScheduleById(String planId, String scheduleId) =>
      '/emi-plans/$planId/schedules/$scheduleId';

  // ── Recurring Rules ───────────────────────────────────────────────────────
  static const String recurringRules = '/recurring-rules';
  static String recurringRuleById(String id) => '/recurring-rules/$id';
  static String recurringRuleTrigger(String id) =>
      '/recurring-rules/$id/trigger';

  // ── WebSocket ─────────────────────────────────────────────────────────────
  /// Returns the full WebSocket URL for a given user.
  ///
  /// [token] is the JWT access token appended as a query parameter.
  static String wsUser(String userId, String token) {
    final wsBase = EnvConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/ws/user/$userId?token=$token';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the absolute URL for [path].
  static String resolve(String path) => '${EnvConfig.baseUrl}$path';
}
