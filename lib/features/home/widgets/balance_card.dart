import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/flow_backdrop.dart';
import '../../../core/providers/insights_providers.dart';
import '../../../core/providers/shared_prefs_provider.dart';
import '../../../core/ui/constants.dart';
import '../../../core/ui/finance_style.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';

/// The month's net position: a teal gradient card with the brand's flowing
/// arcs, one large figure, and Income | Expense in two tinted pills.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final currency = ref.watch(sharedPrefsServiceProvider.select((final s) => s.currency));
    final kpis = ref.watch(currentMonthKpisProvider);
    final status = getBalanceStatus(kpis.net, currency);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    const onHero = Colors.white;
    final muted = onHero.withValues(alpha: 0.78);
    final label = theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600);

    return Semantics(
      container: true,
      label: '${l10n?.homeNetBalance ?? 'Net balance'}, ${status.message}',
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ocean600, AppColors.ocean800],
          ),
          borderRadius: AppRadius.xlAll,
          boxShadow: AppShadow.brand(AppColors.ocean700),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: FlowArcs()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            l10n?.homeNetBalance ?? 'Net balance',
                            style: label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: onHero.withValues(alpha: 0.16),
                              borderRadius: AppRadius.fullAll,
                            ),
                            child: Text(
                              l10n?.homeThisMonth ?? 'This month',
                              style: label?.copyWith(color: onHero),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: AmountText(
                        key: ValueKey(kpis.net),
                        amount: kpis.net,
                        currency: currency,
                        showSign: kpis.net < 0,
                        alignment: Alignment.centerLeft,
                        color: onHero,
                        incomeColor: onHero,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: onHero,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      children: [
                        Icon(
                          status.isPositive ? Icons.check_circle_rounded : Icons.error_rounded,
                          size: 16,
                          color: status.isPositive ? kIncomeOnHero : const Color(0xFFFFB4B4),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            status.message,
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    Row(
                      children: [
                        Expanded(
                          child: _Pill(
                            icon: Icons.south_west_rounded,
                            label: l10n?.income ?? 'Income',
                            amount: kpis.income,
                            currency: currency,
                            labelStyle: label,
                            accent: kIncomeOnHero,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: _Pill(
                            icon: Icons.north_east_rounded,
                            label: l10n?.expense ?? 'Expense',
                            amount: -kpis.expense.abs(),
                            currency: currency,
                            labelStyle: label,
                            accent: kExpenseOnHero,
                          ),
                        ),
                      ],
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

/// A tinted glass pill holding one figure (Income or Expense).
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.labelStyle,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final num amount;
  final String currency;
  final TextStyle? labelStyle;

  /// Tint for this pill (mint for income, coral for expense).
  final Color accent;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          AmountText(
            amount: amount,
            currency: currency,
            alignment: Alignment.centerLeft,
            incomeColor: kIncomeOnHero,
            expenseColor: kExpenseOnHero,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
