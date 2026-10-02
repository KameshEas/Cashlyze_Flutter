import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version.dart';
import '../repositories/app_version_repository.dart';
import '../services/analytics_service.dart';
import '../services/announcement_rules.dart';
import '../services/app_version_service.dart';
import 'read_only_mode_provider.dart';
import 'shared_prefs_provider.dart';

/// Provider for AppVersionService
final appVersionServiceProvider = Provider<AppVersionService>((final ref) {
  final analyticsService = ref.watch(analyticsServiceProvider);
  return AppVersionService(analyticsService);
});

/// FutureProvider that fetches version config for current platform
final currentPlatformVersionProvider =
    FutureProvider<AppVersionModel?>((final ref) async {
  final repository = ref.watch(appVersionRepositoryProvider);
  final service = ref.watch(appVersionServiceProvider);

  final platform = service.getPlatformName();
  final installedVersion = await service.getCurrentAppVersion();
  // Watched, so changing the app language refetches (translated announcements).
  final languageCode = ref.watch(localeProvider)?.languageCode;
  final versionConfig = await repository.getVersionByPlatform(
    platform,
    version: installedVersion,
    locale: languageCode,
  );
  return versionConfig;
});

/// FutureProvider that checks if force update is required for current platform
final forceUpdateRequiredProvider = FutureProvider<bool>((final ref) async {
  final versionConfig = await ref.watch(currentPlatformVersionProvider.future);

  if (versionConfig == null) {
    return false;
  }

  final service = ref.watch(appVersionServiceProvider);
  final shouldUpdate = await service.shouldForceUpdate(versionConfig);
  return shouldUpdate;
});

/// FutureProvider that fetches all version configs
final allVersionsProvider = FutureProvider<Map<String, AppVersionModel?>>(
  (final ref) async {
    final repository = ref.watch(appVersionRepositoryProvider);
    final platform = ref.watch(appVersionServiceProvider).getPlatformName();
    final version = await repository.getVersionByPlatform(platform);
    return {platform: version};
  },
);

/// StateNotifier for managing force update UI state
class ForceUpdateStateNotifier extends Notifier<ForceUpdateState> {
  @override
  ForceUpdateState build() {
    return const ForceUpdateState.initial();
  }

  /// Check for required update and update state
  Future<void> checkForceUpdate() async {
    state = const ForceUpdateState.loading();

    try {
      final forceUpdateRequired = await ref.read(forceUpdateRequiredProvider.future);
      final versionConfig = await ref.read(currentPlatformVersionProvider.future);

      if (forceUpdateRequired && versionConfig != null) {
        state = ForceUpdateState.updateRequired(versionConfig);
      } else {
        state = const ForceUpdateState.noUpdateRequired();
      }
    } catch (e) {
      state = const ForceUpdateState.noUpdateRequired();
    }
  }

  /// Mark as dismissed (though users won't be able to dismiss in practice)
  void dismiss() {
    state = const ForceUpdateState.noUpdateRequired();
  }

  /// Log that user initiated update
  Future<void> logUpdateInitiated() async {
    final versionConfig = state.whenOrNull(updateRequired: (final config) => config);
    if (versionConfig != null) {
      final service = ref.read(appVersionServiceProvider);
      await service.logUpdateInitiated(versionConfig.minimumVersion);
    }
  }

  /// Log that user was redirected to store
  Future<void> logRedirectedToStore(final String platform) async {
    final service = ref.read(appVersionServiceProvider);
    await service.logRedirectedToStore(platform);
  }
}

/// State for force update feature
sealed class ForceUpdateState {
  const ForceUpdateState();

  const factory ForceUpdateState.initial() = _Initial;
  const factory ForceUpdateState.loading() = _Loading;
  const factory ForceUpdateState.updateRequired(final AppVersionModel config) =
      _UpdateRequired;
  const factory ForceUpdateState.noUpdateRequired() = _NoUpdateRequired;

  T? whenOrNull<T>({
    final T? Function()? initial,
    final T? Function()? loading,
    final T? Function(AppVersionModel config)? updateRequired,
    final T? Function()? noUpdateRequired,
  }) {
    return switch (this) {
      _Initial() => initial?.call(),
      _Loading() => loading?.call(),
      _UpdateRequired(:final config) => updateRequired?.call(config),
      _NoUpdateRequired() => noUpdateRequired?.call(),
    };
  }

  bool get isUpdateRequired =>
      this is _UpdateRequired;

  bool get isLoading =>
      this is _Loading;
}

class _Initial extends ForceUpdateState {
  const _Initial();
}

class _Loading extends ForceUpdateState {
  const _Loading();
}

class _UpdateRequired extends ForceUpdateState {
  const _UpdateRequired(this.config);
  final AppVersionModel config;
}

class _NoUpdateRequired extends ForceUpdateState {
  const _NoUpdateRequired();
}

/// NotifierProvider for force update state management
final forceUpdateStateProvider =
    NotifierProvider<ForceUpdateStateNotifier, ForceUpdateState>(
        ForceUpdateStateNotifier.new);

// ── Maintenance mode ────────────────────────────────────────────────────────

/// State for the maintenance-mode blocking screen
sealed class MaintenanceState {
  const MaintenanceState();

  const factory MaintenanceState.initial() = _MaintenanceInitial;
  const factory MaintenanceState.active(final MaintenanceInfo info) = _MaintenanceActive;
  const factory MaintenanceState.inactive() = _MaintenanceInactive;

  MaintenanceInfo? get info => switch (this) {
        _MaintenanceActive(:final info) => info,
        _ => null,
      };

  /// Full-screen block: maintenance is on and the app can't be used.
  bool get isBlocking => info != null && !info!.isReadOnly;

  /// Maintenance is on but the app stays usable; writes are rejected.
  bool get isReadOnly => info != null && info!.isReadOnly;

  String? get message => info?.message;
}

class _MaintenanceInitial extends MaintenanceState {
  const _MaintenanceInitial();
}

class _MaintenanceActive extends MaintenanceState {
  const _MaintenanceActive(this.info);
  @override
  final MaintenanceInfo info;
}

class _MaintenanceInactive extends MaintenanceState {
  const _MaintenanceInactive();
}

class MaintenanceStateNotifier extends Notifier<MaintenanceState> {
  @override
  MaintenanceState build() => const MaintenanceState.initial();

  Future<void> check() async {
    try {
      // Force a fresh fetch (rather than reusing a stale cached result) so
      // "Retry" on the maintenance screen actually re-checks the backend.
      ref.invalidate(currentPlatformVersionProvider);
      final versionConfig = await ref.read(currentPlatformVersionProvider.future);

      if (versionConfig != null && versionConfig.maintenance.active) {
        state = MaintenanceState.active(versionConfig.maintenance);
      } else {
        state = const MaintenanceState.inactive();
      }
    } catch (_) {
      // Fail-open: never block the app because the maintenance check itself
      // failed (e.g. no network).
      state = const MaintenanceState.inactive();
    }
    // Lets the API client reject writes during read-only maintenance.
    ref.read(readOnlyModeProvider.notifier).update(state.isReadOnly);
  }
}

final maintenanceStateProvider =
    NotifierProvider<MaintenanceStateNotifier, MaintenanceState>(
        MaintenanceStateNotifier.new);

// ── Announcement banner ─────────────────────────────────────────────────────

class AnnouncementState {
  const AnnouncementState({this.banner, this.dialog});

  /// The highest-priority banner the user hasn't hidden.
  final AnnouncementInfo? banner;

  /// The highest-priority dialog the user hasn't seen yet.
  final AnnouncementInfo? dialog;
}

class AnnouncementStateNotifier extends Notifier<AnnouncementState> {
  // Announcements dismissed since the app launched, for `every_launch`.
  final Set<String> _seenThisSession = {};
  List<AnnouncementInfo> _live = const [];

  @override
  AnnouncementState build() {
    // A new language means new text: fetch again. Invalidate explicitly, since
    // this listener can run before the cached fetch notices the language change.
    ref.listen(localeProvider, (_, _) {
      ref.invalidate(currentPlatformVersionProvider);
      check();
    });
    return const AnnouncementState();
  }

  Future<void> check() async {
    try {
      final versionConfig = await ref.read(currentPlatformVersionProvider.future);
      _live = versionConfig?.announcements ?? const [];
    } catch (_) {
      _live = const [];
    }
    _publish();
  }

  Future<void> dismiss(final AnnouncementInfo announcement) async {
    _seenThisSession.add(announcement.id);
    await ref.read(sharedPrefsServiceProvider).markAnnouncementSeen(
          announcement.id,
          DateTime.now().millisecondsSinceEpoch,
        );
    _publish();
  }

  void _publish() {
    final seenAt = ref.read(sharedPrefsServiceProvider).announcementSeenAt;
    final now = DateTime.now();
    final visible = _live.where(
      (final a) => !isAnnouncementSuppressed(
        a,
        lastSeenMillis: seenAt[a.id],
        seenThisSession: _seenThisSession.contains(a.id),
        now: now,
      ),
    );
    // The backend already sorted by priority, so the first of each kind wins.
    state = AnnouncementState(
      banner: visible.where((final a) => a.isBanner).firstOrNull,
      dialog: visible.where((final a) => a.isDialog).firstOrNull,
    );
  }
}

final announcementStateProvider =
    NotifierProvider<AnnouncementStateNotifier, AnnouncementState>(
        AnnouncementStateNotifier.new);

// ── Feature flags ────────────────────────────────────────────────────────────

/// Feature flags for the current platform, keyed by flag name. Missing keys
/// are left for the caller to default (see [featureEnabledProvider]) rather
/// than assumed here, since "missing" and "explicitly false" mean different
/// things depending on the feature.
final featureFlagsProvider = FutureProvider<Map<String, bool>>((final ref) async {
  final versionConfig = await ref.watch(currentPlatformVersionProvider.future);
  return versionConfig?.featureFlags ?? const {};
});

/// Convenience provider family: whether [flag] is enabled, defaulting to
/// [defaultValue] while loading or if the flag key isn't present. Defaults to
/// fail-open (true) so an already-shipped feature is never hidden just
/// because the admin console hasn't set that flag yet.
final featureEnabledProvider =
    Provider.family<bool, ({String flag, bool defaultValue})>((final ref, final args) {
  final flagsAsync = ref.watch(featureFlagsProvider);
  return flagsAsync.maybeWhen(
    data: (final flags) => flags[args.flag] ?? args.defaultValue,
    orElse: () => args.defaultValue,
  );
});
