import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version.dart';
import '../repositories/app_version_repository.dart';
import '../services/analytics_service.dart';
import '../services/app_version_service.dart';
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
  final versionConfig = await repository.getVersionByPlatform(platform);
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
  const factory MaintenanceState.active(final String? message) = _MaintenanceActive;
  const factory MaintenanceState.inactive() = _MaintenanceInactive;

  bool get isActive => this is _MaintenanceActive;

  String? get message => switch (this) {
        _MaintenanceActive(:final message) => message,
        _ => null,
      };
}

class _MaintenanceInitial extends MaintenanceState {
  const _MaintenanceInitial();
}

class _MaintenanceActive extends MaintenanceState {
  const _MaintenanceActive(this.message);
  final String? message;
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

      if (versionConfig != null && versionConfig.maintenanceMode) {
        state = MaintenanceState.active(versionConfig.maintenanceMessage);
      } else {
        state = const MaintenanceState.inactive();
      }
    } catch (_) {
      // Fail-open: never block the app because the maintenance check itself
      // failed (e.g. no network).
      state = const MaintenanceState.inactive();
    }
  }
}

final maintenanceStateProvider =
    NotifierProvider<MaintenanceStateNotifier, MaintenanceState>(
        MaintenanceStateNotifier.new);

// ── Announcement banner ─────────────────────────────────────────────────────

class AnnouncementState {
  const AnnouncementState({this.message, this.visible = false});
  final String? message;
  final bool visible;
}

class AnnouncementStateNotifier extends Notifier<AnnouncementState> {
  @override
  AnnouncementState build() => const AnnouncementState();

  Future<void> check() async {
    try {
      final versionConfig = await ref.read(currentPlatformVersionProvider.future);
      final message = versionConfig?.announcementMessage;

      if (versionConfig == null ||
          !versionConfig.announcementActive ||
          message == null ||
          message.isEmpty) {
        state = const AnnouncementState();
        return;
      }

      final dismissedHash =
          ref.read(sharedPrefsServiceProvider).dismissedAnnouncementHash;
      if (dismissedHash == message.hashCode.toString()) {
        state = const AnnouncementState();
        return;
      }

      state = AnnouncementState(message: message, visible: true);
    } catch (_) {
      state = const AnnouncementState();
    }
  }

  Future<void> dismiss() async {
    final message = state.message;
    if (message == null) return;
    await ref
        .read(sharedPrefsServiceProvider)
        .setDismissedAnnouncementHash(message.hashCode.toString());
    state = const AnnouncementState();
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
