import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/constants.dart';
import '../../../core/ui/motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/transaction_form_sheet.dart';

/// Row of quick action buttons with enhanced styling and animations.
/// Includes: Expense, Top-up, Add EMI, Add Budget, Scan, and more.
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final actions = _buildActions(t);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Horizontal padding must be >= the action card's own shadow blur
      // (see _buildActionButton) or the first/last card's shadow gets
      // clipped by the viewport edge - matches home_screen.dart's own page
      // padding so the row's cards line up with the rest of the page.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Row(
        children: List.generate(actions.length, (final index) {
          final action = actions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: MotionFadeIn(
              delay: MotionStagger.delayFor(index),
              slideY: 16,
              beginScale: 0.96,
              child: _buildActionButton(context, action, scheme),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton(
    final BuildContext context,
    final _QuickAction action,
    final ColorScheme scheme,
  ) {
    final color = action.getColor(scheme);
    final bgColor = color.withValues(alpha: 0.15);

    return Semantics(
      label: '${action.label} action',
      button: true,
      child: PressableScale(
        onTap: () => _onActionTap(context, action),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action.icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_QuickAction> _buildActions(final AppLocalizations? t) => [
        const _QuickAction(
          icon: Icons.remove_circle_outline,
          label: 'Expense',
          type: 'Expense',
          colorType: ActionColorType.expense,
        ),
        _QuickAction(
          icon: Icons.add_card,
          label: t?.quickTopUp ?? 'Top-up',
          type: 'Income',
          colorType: ActionColorType.income,
        ),
        const _QuickAction(
          icon: Icons.payments,
          label: 'Add EMI',
          route: '/emi/new',
          colorType: ActionColorType.emi,
        ),
        const _QuickAction(
          icon: Icons.savings,
          label: 'Add Budget',
          route: '/budgets',
          colorType: ActionColorType.budget,
        ),
        const _QuickAction(
          icon: Icons.camera_alt,
          label: 'Scan',
          route: '/scan',
          colorType: ActionColorType.scan,
        ),
      ];

  // Paths that are bottom-nav tabs (StatefulShellBranch routes) must be
  // reached via go() to switch tabs in place; everything else is a
  // standalone screen that should be pushed so the back button returns here.
  static const _kShellBranchPaths = {'/', '/transactions', '/budgets', '/insights', '/settings'};

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

  Future<void> _openTransactionForm(final BuildContext context, final String type) async {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final result = await showModalBottomSheet<bool?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (final ctx) => TransactionFormSheet.create(initialType: type),
    );
    if (result == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(t?.transactionSaved ?? 'Transaction saved')));
    }
  }
}

enum ActionColorType { expense, income, emi, budget, scan }

/// Internal model for a quick action item.
class _QuickAction {

  const _QuickAction({
    required this.icon,
    required this.label,
    this.type,
    this.route,
    required this.colorType,
  });
  final IconData icon;
  final String label;
  final String? type;
  final String? route;
  final ActionColorType colorType;

  Color getColor(final ColorScheme scheme) {
    return switch (colorType) {
      ActionColorType.expense => scheme.error,
      ActionColorType.income => scheme.secondary,
      ActionColorType.emi => Colors.amber,
      ActionColorType.budget => Colors.cyan,
      ActionColorType.scan => Colors.purple,
    };
  }
}
