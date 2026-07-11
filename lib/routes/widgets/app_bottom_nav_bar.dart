import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/first_time_feature_provider.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../features/onboarding/quick_menu_tutorial_overlay.dart';
import 'radial_quick_menu.dart';

/// The app's bottom navigation bar: the stock 5-destination [NavigationBar]
/// with an elevated center button overlaid on top that expands into a
/// [showRadialQuickMenu] fan-out menu for less-frequent destinations
/// (Goals, Categories, EMI, Search, Scan, Help Center).
class AppBottomNavBar extends ConsumerStatefulWidget {
  const AppBottomNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

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

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: widget.navigationShell.goBranch,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -20),
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
                    color: theme.colorScheme.primary,
                    boxShadow: AppShadow.brand(theme.colorScheme.primary),
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
