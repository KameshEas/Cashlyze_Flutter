import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version.dart';
import '../repositories/app_version_repository.dart';
import '../services/analytics_service.dart';
import '../services/app_version_service.dart';

/// Provider for AppVersionService
final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  final analyticsService = ref.watch(analyticsServiceProvider);
  return AppVersionService(analyticsService);
});

/// FutureProvider that fetches version config for current platform
final currentPlatformVersionProvider =
    FutureProvider<AppVersionModel?>((ref) async {
  final repository = ref.watch(appVersionRepositoryProvider);
  final service = ref.watch(appVersionServiceProvider);

  final platform = service.getPlatformName();
  final versionConfig = await repository.getVersionByPlatform(platform);
  return versionConfig;
});

/// FutureProvider that checks if force update is required for current platform
final forceUpdateRequiredProvider = FutureProvider<bool>((ref) async {
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
  (ref) async {
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
    final versionConfig = state.whenOrNull(updateRequired: (config) => config);
    if (versionConfig != null) {
      final service = ref.read(appVersionServiceProvider);
      await service.logUpdateInitiated(versionConfig.minimumVersion);
    }
  }

  /// Log that user was redirected to store
  Future<void> logRedirectedToStore(String platform) async {
    final service = ref.read(appVersionServiceProvider);
    await service.logRedirectedToStore(platform);
  }
}

/// State for force update feature
sealed class ForceUpdateState {
  const ForceUpdateState();

  const factory ForceUpdateState.initial() = _Initial;
  const factory ForceUpdateState.loading() = _Loading;
  const factory ForceUpdateState.updateRequired(AppVersionModel config) =
      _UpdateRequired;
  const factory ForceUpdateState.noUpdateRequired() = _NoUpdateRequired;

  T? whenOrNull<T>({
    T? Function()? initial,
    T? Function()? loading,
    T? Function(AppVersionModel config)? updateRequired,
    T? Function()? noUpdateRequired,
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
  final AppVersionModel config;
  const _UpdateRequired(this.config);
}

class _NoUpdateRequired extends ForceUpdateState {
  const _NoUpdateRequired();
}

/// NotifierProvider for force update state management
final forceUpdateStateProvider =
    NotifierProvider<ForceUpdateStateNotifier, ForceUpdateState>(
        ForceUpdateStateNotifier.new);
