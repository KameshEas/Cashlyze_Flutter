import 'package:riverpod/riverpod.dart';
import 'shared_prefs_provider.dart';

/// Tracks first-time feature visits to show tutorials
/// Each feature tutorial is shown only once per user

// First-time budget creation
class FirstTimeBudgetNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getBool('first_time_budget_tutorial_seen') ?? false;
    return !seen;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_budget_tutorial_seen', true);
    state = false;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_budget_tutorial_seen', false);
    state = true;
  }
}

final firstTimeBudgetProvider = NotifierProvider<FirstTimeBudgetNotifier, bool>(
  FirstTimeBudgetNotifier.new,
);

// First-time transaction creation
class FirstTimeTransactionNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getBool('first_time_transaction_tutorial_seen') ?? false;
    return !seen;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_transaction_tutorial_seen', true);
    state = false;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_transaction_tutorial_seen', false);
    state = true;
  }
}

final firstTimeTransactionProvider = NotifierProvider<FirstTimeTransactionNotifier, bool>(
  FirstTimeTransactionNotifier.new,
);

// First-time EMI creation
class FirstTimeEMINotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getBool('first_time_emi_tutorial_seen') ?? false;
    return !seen;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_emi_tutorial_seen', true);
    state = false;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_emi_tutorial_seen', false);
    state = true;
  }
}

final firstTimeEMIProvider = NotifierProvider<FirstTimeEMINotifier, bool>(
  FirstTimeEMINotifier.new,
);

// First-time category creation
class FirstTimeCategoryNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getBool('first_time_category_tutorial_seen') ?? false;
    return !seen;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_category_tutorial_seen', true);
    state = false;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_category_tutorial_seen', false);
    state = true;
  }
}

final firstTimeCategoryProvider = NotifierProvider<FirstTimeCategoryNotifier, bool>(
  FirstTimeCategoryNotifier.new,
);

// First-time settings visit
class FirstTimeSettingsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getBool('first_time_settings_tutorial_seen') ?? false;
    return !seen;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_settings_tutorial_seen', true);
    state = false;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('first_time_settings_tutorial_seen', false);
    state = true;
  }
}

final firstTimeSettingsProvider = NotifierProvider<FirstTimeSettingsNotifier, bool>(
  FirstTimeSettingsNotifier.new,
);

// Dismissed tooltips (tracking which tooltips user has dismissed)
class DismissedTooltipsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.read(sharedPrefsProvider);
    final savedJson = prefs.getString('dismissed_tooltips') ?? '[]';
    try {
      // Simple parsing: "tooltip_id1,tooltip_id2"
      final tooltips = (savedJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet());
      return tooltips;
    } catch (_) {
      return {};
    }
  }

  Future<void> dismiss(String tooltipId) async {
    state = {...state, tooltipId};
    final prefs = ref.read(sharedPrefsProvider);
    final json = state.map((id) => '"$id"').toList();
    await prefs.setString('dismissed_tooltips', '[${json.join(',')}]');
  }

  Future<void> reset() async {
    state = {};
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove('dismissed_tooltips');
  }
}

final dismissedTooltipsProvider = NotifierProvider<DismissedTooltipsNotifier, Set<String>>(
  DismissedTooltipsNotifier.new,
);
