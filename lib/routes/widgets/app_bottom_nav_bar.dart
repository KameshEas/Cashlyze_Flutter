import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/feature_flags.dart';
import '../../core/providers/app_version_providers.dart';
import '../../core/providers/first_time_feature_provider.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../features/onboarding/quick_menu_tutorial_overlay.dart';
import 'radial_quick_menu.dart';

class _NavEntry {
  const _NavEntry({
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Index into the router's [StatefulShellRoute] branches — fixed, must
  /// NOT be confused with this entry's position in the bar.
  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app's bottom navigation bar: two destinations on each side of a
/// floating center button that expands into a [showRadialQuickMenu] fan-out
/// menu for less-frequent destinations (Goals, Categories, EMI, Search,
/// Scan, Help Center).
///
/// The center button is an action, never a tab: it is not part of the
/// selection state, so it stays un-highlighted on every screen (including
/// Budgets, which has no tab of its own and is reached from Home's quick
/// actions).
class AppBottomNavBar extends ConsumerStatefulWidget {
  const AppBottomNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

/// Height of the bar's tappable row (excludes the bottom system inset).
const double _kBarHeight = 68;

class _AppBottomNavBarState extends ConsumerState<AppBottomNavBar> {
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      if (!mounted) return;
      if (!ref.read(firstTimeQuickMenuProvider)) return;
      showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (final dialogContext) => QuickMenuTutorialOverlay(
          onComplete: () => Navigator.of(dialogContext).pop(),
        ),
      );
    });
  }

  Future<void> _toggleMenu() async {
    if (_menuOpen) return;
    setState(() => _menuOpen = true);
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    await showRadialQuickMenu(context);
    if (mounted) setState(() => _menuOpen = false);
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    final showTransactions = ref.watch(
      featureEnabledProvider((flag: FeatureFlags.transactions, defaultValue: true)),
    );
    final showInsights = ref.watch(
      featureEnabledProvider((flag: FeatureFlags.insights, defaultValue: true)),
    );

    // Home and Settings are always shown — see FeatureFlags doc comment.
    // Budgets (branch 2) deliberately has no slot: the center button owns
    // that spot in the bar.
    const home = _NavEntry(
      branchIndex: 0,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    );
    const transactions = _NavEntry(
      branchIndex: 1,
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Transactions',
    );
    const insights = _NavEntry(
      branchIndex: 3,
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Insights',
    );
    const settings = _NavEntry(
      branchIndex: 4,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    );
    // Two slots per side keep the center button centered even when a
    // feature flag hides a destination (null = empty slot).
    final left = <_NavEntry?>[home, if (showTransactions) transactions else null];
    final right = <_NavEntry?>[if (showInsights) insights else null, settings];
    final currentBranch = widget.navigationShell.currentIndex;
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor = isDark ? AppColors.ocean400 : AppColors.ocean700;
    final idleColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    Widget slot(final _NavEntry? e) {
      if (e == null) return const Expanded(child: SizedBox.shrink());
      return Expanded(
        child: _NavItem(
          entry: e,
          selected: e.branchIndex == currentBranch,
          selectedColor: selectedColor,
          idleColor: idleColor,
          onTap: () => widget.navigationShell.goBranch(
            e.branchIndex,
            initialLocation: e.branchIndex == currentBranch,
          ),
        ),
      );
    }

    final bar = Container(
      height: _kBarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          for (final e in left) slot(e),
          const SizedBox(width: 84), // room for the floating center button
          for (final e in right) slot(e),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Bar sits on the system inset so gesture-nav phones don't overlap it.
        Container(
          color: theme.colorScheme.surface,
          child: SafeArea(top: false, child: bar),
        ),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Tooltip(
            message: _menuOpen ? 'Close quick menu' : 'Open quick menu',
            child: Semantics(
              button: true,
              label: 'Quick menu',
              hint: _menuOpen ? 'Double tap to close' : 'Double tap to open more options',
              child: PressableScale(
                onTap: _toggleMenu,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandTeal, AppColors.ocean700],
                    ),
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                    boxShadow: AppShadow.brand(AppColors.brandTeal),
                  ),
                  child: Center(
                    child: MotionSwitcher(
                      child: Icon(
                        _menuOpen ? Icons.close_rounded : Icons.apps_rounded,
                        key: ValueKey(_menuOpen),
                        color: theme.colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.entry,
    required this.selected,
    required this.selectedColor,
    required this.idleColor,
    required this.onTap,
  });

  final _NavEntry entry;
  final bool selected;
  final Color selectedColor;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final color = selected ? selectedColor : idleColor;
    return Semantics(
      button: true,
      selected: selected,
      label: entry.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? entry.selectedIcon : entry.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
