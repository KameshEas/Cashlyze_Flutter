/// Canonical feature-flag keys for the top-level features/menu items a user
/// can reach from the bottom nav bar or the quick menu. These must exactly
/// match the flag names configured in the admin console (see FeatureGate).
///
/// Home and Settings are deliberately excluded — they're structural nav
/// anchors (landing screen, account/logout access), not optional features.
abstract final class FeatureFlags {
  static const transactions = 'transactions';
  static const budgets = 'budgets';
  static const insights = 'insights';
  static const goals = 'goals';
  static const categories = 'categories';
  static const emi = 'emi';
  static const search = 'search';
  static const scan = 'scan';
  static const helpCenter = 'help_center';
  static const aiAssistant = 'ai_assistant';

  /// All flaggable feature keys, in the order they're presented in the app.
  static const all = [
    transactions,
    budgets,
    insights,
    goals,
    categories,
    emi,
    search,
    scan,
    helpCenter,
    aiAssistant,
  ];
}
