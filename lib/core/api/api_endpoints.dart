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
  static String categoryById(final String id) => '/categories/$id';

  // ── Transactions ──────────────────────────────────────────────────────────
  static const String transactions = '/transactions';
  static String transactionById(final String id) => '/transactions/$id';

  // ── Budgets ───────────────────────────────────────────────────────────────
  static const String budgets = '/budgets';
  static String budgetById(final String id) => '/budgets/$id';
  static const String budgetsCategoryBreakdown = '/budgets/analytics/category-breakdown';
  static const String budgetsUtilizationAll = '/budgets/utilization/all';
  static const String budgetsAlertsCurrent = '/budgets/alerts/current';

  // ── EMI ───────────────────────────────────────────────────────────────────
  static const String emiPlans = '/emi-plans';
  static String emiPlanById(final String id) => '/emi-plans/$id';
  static String emiSchedules(final String planId) => '/emi-plans/$planId/schedules';
  static String emiScheduleById(final String planId, final String scheduleId) =>
      '/emi-plans/$planId/schedules/$scheduleId';

  // ── Recurring Rules ───────────────────────────────────────────────────────
  static const String recurringRules = '/recurring-rules';
  static String recurringRuleById(final String id) => '/recurring-rules/$id';
  static String recurringRuleTrigger(final String id) =>
      '/recurring-rules/$id/trigger';

  // ── Savings Goals ─────────────────────────────────────────────────────────
  static const String savingsGoals = '/savings-goals';
  static String savingsGoalById(final String id) => '/savings-goals/$id';
  static String savingsGoalProgress(final String id) =>
      '/savings-goals/$id/progress';

  // ── Search ────────────────────────────────────────────────────────────────
  static const String search = '/search';

  // ── WebSocket ─────────────────────────────────────────────────────────────
  /// Returns the full WebSocket URL for a given user.
  ///
  /// [token] is the JWT access token appended as a query parameter.
  static String wsUser(final String userId, final String token) {
    final base = Uri.parse(EnvConfig.baseUrl);
    final scheme = base.scheme == 'https'
        ? 'wss'
        : (base.scheme == 'http' ? 'ws' : base.scheme);
    final pathSegments = <String>[];
    if (base.pathSegments.isNotEmpty) pathSegments.addAll(base.pathSegments);
    pathSegments.addAll(['ws', 'user', userId]);
    final wsUri = Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: pathSegments,
      queryParameters: {'token': token},
    );
    return wsUri.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the absolute URL for [path].
  static String resolve(final String path) => '${EnvConfig.baseUrl}$path';
}
