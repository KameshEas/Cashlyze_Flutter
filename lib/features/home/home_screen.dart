import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/transaction.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/recurring_providers.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/finance_style.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/grouped_list.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/transaction_row.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/balance_card.dart';
import 'widgets/quick_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    ref.watch(recurringProcessorProvider);
    final currency = ref.watch(
      sharedPrefsServiceProvider.select((final s) => s.currency),
    );
    final txsAsync = ref.watch(recentTransactionsProvider);
    final plansAsync = ref.watch(userEMIPlansProvider);
    final hasEmis = plansAsync.maybeWhen(
      data: (final list) => list.isNotEmpty,
      orElse: () => false,
    );
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _performRefresh(context, ref),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s8,
            AppSpacing.s20,
            AppSpacing.s24,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            bottom: false,
            child: MotionStagger(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeHeader(
                  greeting: t?.dashboard ?? 'Dashboard',
                  l10n: t,
                  onSearch: () => context.push('/search'),
                  onNotifications: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications coming soon'),
                          duration: Duration(seconds: 2),
                        ),
                      ),
                ),
                const SizedBox(height: AppSpacing.s24),
                const BalanceCard(),
                const SizedBox(height: AppSpacing.s20),
                const QuickActions(),
                if (hasEmis) ...[
                  const SizedBox(height: AppSpacing.s24),
                  _SectionHeader(title: t?.emiTracker ?? 'EMI Tracker'),
                  _buildUpcomingEmi(context, ref, currency),
                ],
                const SizedBox(height: AppSpacing.s24),
                _SectionHeader(
                  title: t?.recentTransactions ?? 'Recent Transactions',
                  onSeeAll: () => GoRouter.of(context).go('/transactions'),
                ),
                _buildRecentTransactions(context, ref, currency, txsAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEmi(
    final BuildContext context,
    final WidgetRef ref,
    final String currency,
  ) {
    final upcomingAsync = ref.watch(emiUpcomingProvider);
    final theme = Theme.of(context);
    return MotionSwitcher(
      child: upcomingAsync.when(
        loading: () => const SkeletonListTile(key: ValueKey('emi-loading')),
        error: (final e, final _) => Container(
          key: const ValueKey('emi-error'),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.08),
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Text('EMI load error: $e'),
        ),
        data: (final items) {
          if (items.isEmpty) {
            return const SizedBox.shrink(key: ValueKey('emi-empty'));
          }
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          return GroupedSection(
            key: const ValueKey('emi-data'),
            children: [
              for (final e in items.take(3))
                Builder(
                  builder: (final ctx) {
                    final dueDays = e.dueDate.difference(today).inDays;
                    final overdue = dueDays < 0;
                    return Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? AppColors.darkSurfaceHigh
                                : AppColors.tint050,
                            borderRadius: AppRadius.mdAll,
                          ),
                          child: Icon(
                            Icons.credit_card_outlined,
                            size: 20,
                            color: theme.brightness == Brightness.dark
                                ? AppColors.ocean400
                                : AppColors.ocean700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dueDays < 0
                                    ? 'Overdue'
                                    : dueDays == 0
                                    ? 'Due today'
                                    : 'Due in $dueDays days',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (overdue)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 14,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Past due date',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Flexible(
                          child: AmountText(
                            amount: -e.installment,
                            currency: currency,
                            color: overdue ? theme.colorScheme.error : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentTransactions(
    final BuildContext context,
    final WidgetRef ref,
    final String currency,
    final AsyncValue<List<TransactionModel>> txsAsync,
  ) {
    return MotionSwitcher(
      child: txsAsync.when(
        loading: () => const Column(
          key: ValueKey('rt-loading'),
          children: [
            SkeletonListTile(),
            SizedBox(height: 12),
            SkeletonListTile(),
            SizedBox(height: 12),
            SkeletonListTile(),
          ],
        ),
        error: (final e, final _) => Builder(
          builder: (final ctx) {
            final errColor = Theme.of(ctx).colorScheme.error;
            return Container(
              key: const ValueKey('rt-error'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: errColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: errColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errColor),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: Text('Failed to load: $e')),
                ],
              ),
            );
          },
        ),
        data: (final items) {
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month);
          final nextMonthStart = DateTime(now.year, now.month + 1);
          final monthItems = items
              .where(
                (final t) =>
                    t.date.isAfter(
                      monthStart.subtract(const Duration(seconds: 1)),
                    ) &&
                    t.date.isBefore(nextMonthStart),
              )
              .toList();

          if (monthItems.isEmpty) {
            final l10n = AppLocalizations.of(context);
            return Container(
              key: const ValueKey('rt-empty'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s32,
                horizontal: AppSpacing.s16,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n?.homeNoTransactionsMonth ??
                        'No transactions this month',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return GroupedSection(
            key: const ValueKey('rt-data'),
            children: [
              for (final tx in monthItems.take(5))
                RecentTransactionItem(tx: tx, currency: currency),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performRefresh(
    final BuildContext context,
    final WidgetRef ref,
  ) async {
    try {
      ref.invalidate(currentMonthKpisProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(userEMIPlansProvider);
      ref.invalidate(emiUpcomingProvider);
      ref.invalidate(recurringProcessorProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// A single recent transaction line on the home screen (content only; the
/// surrounding [GroupedSection] supplies the surface and dividers).
class RecentTransactionItem extends StatelessWidget {
  const RecentTransactionItem({
    super.key,
    required this.tx,
    required this.currency,
  });
  final TransactionModel tx;
  final String currency;

  @override
  Widget build(final BuildContext context) =>
      TransactionRow(tx: tx, currency: currency);
}

/// Personalized greeting + date, and the search/notifications/refresh
/// actions - replaces a bare default `AppBar` with a treatment matching the
/// display typography used elsewhere on this screen.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.greeting,
    required this.l10n,
    required this.onSearch,
    required this.onNotifications,
  });

  final String greeting;
  final AppLocalizations? l10n;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  String _greetingFor(final String name) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n?.homeGreetingMorning(name) ?? 'Good morning, $name';
    if (h < 17) {
      return l10n?.homeGreetingAfternoon(name) ?? 'Good afternoon, $name';
    }
    return l10n?.homeGreetingEvening(name) ?? 'Good evening, $name';
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final raw = user?.email.split('@').first ?? '';
    final name = raw.isEmpty ? '' : raw[0].toUpperCase() + raw.substring(1);
    final today = formatDate(DateTime.now(), 'EEEE, MMM d');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? greeting : _greetingFor(name),
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(today, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onPressed: onSearch,
        ),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onPressed: onNotifications,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(final BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
    );
  }
}

/// Section heading used between the home screen's stacked content blocks
/// (EMI Tracker / Recent Transactions), with an optional "See all" link.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(final BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionLabel(
      title,
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      trailing: onSeeAll == null
          ? null
          : TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n?.homeSeeAll ?? 'See all'),
            ),
    );
  }
}
