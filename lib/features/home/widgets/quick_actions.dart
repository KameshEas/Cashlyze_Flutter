import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/constants.dart';
import '../../../core/ui/motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/transaction_form_sheet.dart';

/// Home's shortcuts, as one light, uniform row with no card chrome.
///
/// All five are the same quiet tonal button: colour and weight don't rank them,
/// the labels do. Expense and Top-up use a custom coin-on-the-flow-wave mark
/// (a minus or a plus in the coin) from the illustration family instead of
/// generic arrows. Labels are short and single-line (they scale down rather
/// than wrap), and the buttons shrink on narrow phones instead of overflowing.
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  /// Preferred button size; shrinks (not below [_minSize]) when five don't fit.
  static const double _size = 56;
  static const double _minSize = 44;
  static const double _gap = AppSpacing.s8;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final actions = _buildActions(t);

    return LayoutBuilder(
      builder: (final context, final box) {
        final slot = (box.maxWidth - _gap * (actions.length - 1)) / actions.length;
        final size = slot.clamp(_minSize, _size);
        // Top-aligned: a label that has to scale down must not nudge its button.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: MotionFadeIn(
                  delay: MotionStagger.delayFor(i),
                  slideY: 8,
                  child: _ActionButton(
                    action: actions[i],
                    size: size,
                    onTap: () => _onActionTap(context, actions[i]),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<_QuickAction> _buildActions(final AppLocalizations? t) => [
    _QuickAction(
      coin: _CoinSign.minus,
      label: t?.expense ?? 'Expense',
      semanticLabel: 'Add expense',
      type: 'Expense',
    ),
    _QuickAction(
      coin: _CoinSign.plus,
      label: t?.quickTopUp ?? 'Top-up',
      semanticLabel: 'Add income',
      type: 'Income',
    ),
    const _QuickAction(
      icon: Icons.payments_outlined,
      label: 'EMI',
      semanticLabel: 'Add EMI',
      route: '/emi/new',
    ),
    const _QuickAction(
      icon: Icons.donut_small_rounded,
      label: 'Budget',
      semanticLabel: 'Open budgets',
      route: '/budgets',
    ),
    const _QuickAction(
      icon: Icons.document_scanner_outlined,
      label: 'Scan',
      semanticLabel: 'Scan a receipt',
      route: '/scan',
    ),
  ];

  // Paths that are bottom-nav tabs (StatefulShellBranch routes) must be
  // reached via go() to switch tabs in place; everything else is a
  // standalone screen that should be pushed so the back button returns here.
  static const _kShellBranchPaths = {
    '/',
    '/transactions',
    '/budgets',
    '/insights',
    '/settings',
  };

  void _onActionTap(final BuildContext context, final _QuickAction action) {
    final route = action.route;
    if (route != null) {
      if (_kShellBranchPaths.contains(route)) {
        GoRouter.of(context).go(route);
      } else {
        context.push(route);
      }
      return;
    }
    final type = action.type;
    if (type != null) {
      _openTransactionForm(context, type);
    }
  }

  Future<void> _openTransactionForm(
    final BuildContext context,
    final String type,
  ) async {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final result = await showModalBottomSheet<bool?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (final ctx) => TransactionFormSheet.create(initialType: type),
    );
    if (result == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(t?.transactionSaved ?? 'Transaction saved')),
      );
    }
  }
}

/// One shortcut: a rounded-square button over a one-line label. The whole
/// column is the tap target (taller than the 48dp minimum), the button
/// presses down on touch, and screen readers get the full action name rather
/// than the short visible label.
/// Largest text scale applied to the short labels.
const double _maxLabelScale = 1.15;

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.size,
    required this.onTap,
  });

  final _QuickAction action;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // One quiet tonal style for all five. The icon uses the lighter brand tone
    // in dark mode so it stays readable (colorScheme.primary is a fill colour
    // there).
    final background = scheme.primaryContainer;
    final foreground = isDark ? AppColors.ocean400 : AppColors.ocean700;
    final iconSize = size * 0.5;

    return Semantics(
      label: action.semanticLabel,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.94,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(size * 0.34),
                ),
                alignment: Alignment.center,
                child: action.coin != null
                    ? _CoinIcon(sign: action.coin!, color: foreground, size: iconSize)
                    : Icon(action.icon, size: iconSize, color: foreground),
              ),
              const SizedBox(height: AppSpacing.s8),
              // Scales down instead of wrapping or truncating, so every label
              // stays on one line at any text size.
              // Text scale is capped for these short labels (as for nav-bar
              // labels) so they stay one consistent size across the row; the
              // buttons are large and screen readers get the full name.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxLabelScale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.label,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal model for a quick action item. Either an [icon] or a [coin] mark.
class _QuickAction {
  const _QuickAction({
    this.icon,
    this.coin,
    required this.label,
    required this.semanticLabel,
    this.type,
    this.route,
  }) : assert(icon != null || coin != null, 'an action needs an icon or a coin mark');

  final IconData? icon;
  final _CoinSign? coin;

  /// Short visible label.
  final String label;

  /// Full action name for screen readers.
  final String semanticLabel;
  final String? type;
  final String? route;
}

/// Which sign sits in the coin.
enum _CoinSign { minus, plus }

/// A solid coin above the logo's flow wave, with a minus (money out) or a plus
/// (money in) knocked out of it. Same visual language as the illustration
/// family (round caps, the wave baseline), and a solid disc so it carries the
/// same visual weight as the other filled icons in the row. Drawn on a 24-unit
/// grid and scaled, so it stays crisp at any size.
class _CoinIcon extends StatelessWidget {
  const _CoinIcon({required this.sign, required this.color, required this.size});

  final _CoinSign sign;
  final Color color;
  final double size;

  @override
  Widget build(final BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _CoinPainter(sign: sign, color: color),
      );
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter({required this.sign, required this.color});

  final _CoinSign sign;
  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    canvas.scale(size.width / 24);
    const centre = Offset(12, 9.5);

    // Solid coin with the sign cut out of it.
    final coin = Path()..addOval(Rect.fromCircle(center: centre, radius: 7.4));
    RRect bar(final double w, final double h) => RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: w, height: h),
          Radius.circular(h / 2),
        );
    final sign = Path()..addRRect(bar(8, 2.4));
    if (this.sign == _CoinSign.plus) {
      sign.addRRect(bar(2.4, 8));
    }
    canvas.drawPath(
      Path.combine(PathOperation.difference, coin, sign),
      Paint()..color = color,
    );

    // The flow wave beneath it.
    final wave = Path()
      ..moveTo(4, 21.2)
      ..cubicTo(7, 19.2, 9.2, 23.2, 12, 21.2)
      ..cubicTo(14.8, 19.2, 17, 23.2, 20, 21.2);
    canvas.drawPath(
      wave,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(final _CoinPainter old) => old.sign != sign || old.color != color;
}
