import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';

class _QuickMenuItem {
  const _QuickMenuItem({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;
}

const _kQuickMenuItems = [
  _QuickMenuItem(icon: Icons.savings_outlined, label: 'Goals', route: '/goals'),
  _QuickMenuItem(icon: Icons.category_outlined, label: 'Categories', route: '/categories'),
  _QuickMenuItem(icon: Icons.payments_outlined, label: 'EMI', route: '/emi'),
  _QuickMenuItem(icon: Icons.search_rounded, label: 'Search', route: '/search'),
  _QuickMenuItem(icon: Icons.camera_alt_outlined, label: 'Scan', route: '/scan'),
  _QuickMenuItem(icon: Icons.help_outline_rounded, label: 'Help', route: '/help_center'),
];

/// Material 3's default [NavigationBar] height.
const _kNavBarHeight = 80.0;

/// How far the center button in [AppBottomNavBar] floats above the nav bar's
/// top edge — must match that widget's `Transform.translate` offset.
const _kCenterButtonOverlap = 20.0;

/// Gap between the nav bar's top edge and the quick-menu card.
const _kCardGap = 12.0;

/// Distance (logical px) from the bottom of the screen to the quick-menu
/// card, derived from the nav bar's height plus the center button's float
/// offset so the card sits just above the button rather than a bare magic
/// number.
const _kCardBottom = _kNavBarHeight + _kCenterButtonOverlap + _kCardGap;

/// Shows the quick-menu as a self-dismissing overlay above the persistent
/// bottom nav bar. Tapping the scrim, pressing back, or selecting an item
/// all close it.
Future<void> showRadialQuickMenu(final BuildContext context) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    'Quick menu opened',
    TextDirection.ltr,
  );
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Quick menu',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: AppMotion.durationFor(context),
    pageBuilder: (final ctx, final animation, final secondaryAnimation) =>
        const _QuickMenuOverlay(),
    transitionBuilder: (final ctx, final animation, final secondaryAnimation, final child) {
      final curved = CurvedAnimation(parent: animation, curve: AppCurve.standard);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _QuickMenuOverlay extends StatelessWidget {
  const _QuickMenuOverlay();

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: AppSpacing.pagePadding,
              right: AppSpacing.pagePadding,
              bottom: _kCardBottom,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s16,
                  AppSpacing.s16,
                  AppSpacing.s20,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: AppRadius.xlAll,
                  boxShadow: AppShadow.elevated,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quick Menu',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Close quick menu',
                          child: ExcludeSemantics(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpacing.s16,
                        crossAxisSpacing: AppSpacing.s8,
                        mainAxisExtent: 88,
                      ),
                      itemCount: _kQuickMenuItems.length,
                      itemBuilder: (final gridContext, final i) => MotionFadeIn(
                        delay: MotionStagger.delayFor(i),
                        beginScale: 0.85,
                        child: _QuickMenuButton(item: _kQuickMenuItems[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMenuButton extends StatelessWidget {
  const _QuickMenuButton({required this.item});

  final _QuickMenuItem item;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: item.label,
      child: ExcludeSemantics(
        child: PressableScale(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context, rootNavigator: true).pop();
            context.push(item.route);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(item.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
