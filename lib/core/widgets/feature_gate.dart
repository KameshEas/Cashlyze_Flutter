import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_version_providers.dart';

/// Conditionally shows [child] based on a remote feature flag (see
/// AppVersionModel.featureFlags, managed via the admin console). Defaults to
/// showing [child] (fail-open) while the flags are loading or if [flag] is
/// missing from the response, unless [defaultValue] is set to false.
///
/// Usage:
/// ```dart
/// FeatureGate(
///   flag: 'groups',
///   defaultValue: false, // hide until explicitly enabled
///   child: GroupsNavTile(),
/// )
/// ```
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    required this.flag,
    required this.child,
    super.key,
    this.fallback,
    this.defaultValue = true,
  });

  final String flag;
  final Widget child;
  final Widget? fallback;
  final bool defaultValue;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final enabled = ref.watch(
      featureEnabledProvider((flag: flag, defaultValue: defaultValue)),
    );
    if (enabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
