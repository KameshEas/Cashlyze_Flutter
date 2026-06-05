import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

/// Row of quick action buttons (Expense, Top-up, Add EMI, Add Budget, Scan).
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final actions = _buildActions(t);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: actions.map((action) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Semantics(
              label: '${action.label} action',
              button: true,
              child: InkWell(
                onTap: () => _onActionTap(context, action),
                borderRadius: BorderRadius.circular(16),
                focusColor: scheme.primary.withValues(alpha: 0.1),
                hoverColor: scheme.secondary.withValues(alpha: 0.08),
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(action.icon, color: scheme.secondary, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_QuickAction> _buildActions(AppLocalizations? t) => [
        _QuickAction(
          icon: Icons.remove,
          label: 'Expense',
          type: 'Expense',
        ),
        _QuickAction(
          icon: Icons.add_card,
          label: t?.quickTopUp ?? 'Top-up',
          type: 'Income',
        ),
        _QuickAction(
          icon: Icons.payments,
          label: 'Add EMI',
          route: '/emi/new',
        ),
        _QuickAction(
          icon: Icons.savings,
          label: 'Add Budget',
          route: '/budgets',
        ),
        _QuickAction(
          icon: Icons.camera_alt,
          label: 'Scan',
          isScanAction: true,
        ),
      ];

  void _onActionTap(BuildContext context, _QuickAction action) {
    if (action.route != null) {
      GoRouter.of(context).go(action.route!);
    } else if (action.isScanAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan feature coming soon')),
      );
    }
  }
}

/// Internal model for a quick action item.
class _QuickAction {
  final IconData icon;
  final String label;
  final String? type;
  final String? route;
  final bool isScanAction;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.type,
    this.route,
    this.isScanAction = false,
  });
}