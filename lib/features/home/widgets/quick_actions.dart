import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/constants.dart';
import '../../../core/ui/motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/transaction_form_sheet.dart';

/// The five most common actions as one even row of quiet, outlined tiles:
/// a single-tone icon over a short label. Colour is not used to tell the
/// actions apart (the labels do), which keeps the row calm.
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final actions = _buildActions(t);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: MotionFadeIn(
              delay: MotionStagger.delayFor(i),
              slideY: 8,
              child: _ActionTile(action: actions[i], onTap: () => _onActionTap(context, actions[i])),
            ),
          ),
        ],
      ],
    );
  }

  List<_QuickAction> _buildActions(final AppLocalizations? t) => [
        _QuickAction(
          icon: Icons.remove_rounded,
          label: t?.expense ?? 'Expense',
          type: 'Expense',
        ),
        _QuickAction(
          icon: Icons.add_rounded,
          label: t?.quickTopUp ?? 'Top-up',
          type: 'Income',
        ),
        const _QuickAction(
          icon: Icons.payments_outlined,
          label: 'Add EMI',
          route: '/emi/new',
        ),
        const _QuickAction(
          icon: Icons.savings_outlined,
          label: 'Add Budget',
          route: '/budgets',
        ),
        const _QuickAction(
          icon: Icons.document_scanner_outlined,
          label: 'Scan',
          route: '/scan',
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      label: action.label,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: AppSpacing.s12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 22, color: isDark ? AppColors.ocean400 : AppColors.ocean700),
              const SizedBox(height: AppSpacing.s8),
              Text(
                action.label,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
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
}

/// Internal model for a quick action item.
class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    this.type,
    this.route,
  });

  final IconData icon;
  final String label;
  final String? type;
  final String? route;
}
