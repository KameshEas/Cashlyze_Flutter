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
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/skeleton.dart';
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
            AppSpacing.pagePadding,
            AppSpacing.s8,
            AppSpacing.pagePadding,
            AppSpacing.pagePadding,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            bottom: false,
            child: MotionStagger(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeHeader(
                  greeting: t?.dashboard ?? 'Dashboard',
                  onSearch: () => context.push('/search'),
                  onNotifications: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  ),
                  onRefresh: () {
                    try {
                      ref.invalidate(userEMIPlansProvider);
                      ref.invalidate(emiUpcomingProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Refreshing EMI data')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Refresh failed: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.s24),
                const BalanceCard(),
                const SizedBox(height: AppSpacing.s40),
                _SectionHeader(title: t?.quickActions ?? 'Quick Actions'),
                const SizedBox(height: AppSpacing.s16),
                const QuickActions(),
                if (hasEmis) ...[
                  const SizedBox(height: AppSpacing.s24),
                  _SectionHeader(title: t?.emiTracker ?? 'EMI Tracker'),
                  const SizedBox(height: AppSpacing.s12),
                  _buildUpcomingEmi(context, ref, currency),
                ],
                const SizedBox(height: AppSpacing.s24),
                _SectionHeader(title: t?.recentTransactions ?? 'Recent Transactions'),
                const SizedBox(height: AppSpacing.s16),
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
      loading: () => const SizedBox(
        key: ValueKey('emi-loading'),
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (final e, final _) => Container(
        key: const ValueKey('emi-error'),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.08),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Text('EMI load error: $e'),
      ),
      data: (final items) {
        if (items.isEmpty) return const SizedBox.shrink(key: ValueKey('emi-empty'));
        return Column(
          key: const ValueKey('emi-data'),
          children: items.take(3).map((final e) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final dueDays = e.dueDate.difference(today).inDays;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, size: 18),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAmount(e.installment, currency),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dueDays < 0
                            ? 'Overdue'
                            : dueDays == 0
                                ? 'Due Today'
                                : 'Due in $dueDays days',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dueDays < 0 ? theme.colorScheme.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
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
          return Center(
            key: const ValueKey('rt-empty'),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return Column(
          key: const ValueKey('rt-data'),
          children: monthItems.take(2).map((final tx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RecentTransactionItem(
                tx: tx,
                currency: currency,
              ),
            );
          }).toList(),
        );
      },
    ),
    );
  }

  Future<void> _performRefresh(final BuildContext context, final WidgetRef ref) async {
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

/// A single recent transaction item displayed on the home screen.
class RecentTransactionItem extends StatelessWidget {

  const RecentTransactionItem({
    super.key,
    required this.tx,
    required this.currency,
  });
  final TransactionModel tx;
  final String currency;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final displayCategory = tx.categoryName ?? tx.categoryId ?? 'General';
    final isIncome = tx.amount >= 0;

    return AppListTile(
      title: tx.title,
      subtitle: displayCategory,
      leadingIcon: Icons.shopping_bag_outlined,
      trailing: formatAmount(tx.amount, currency),
      trailingColor: isIncome ? AppColors.success : theme.colorScheme.error,
    );
  }
}

/// Personalized greeting + date, and the search/notifications/refresh
/// actions - replaces a bare default `AppBar` with a treatment matching the
/// display typography used elsewhere on this screen.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.greeting,
    required this.onSearch,
    required this.onNotifications,
    required this.onRefresh,
  });

  final String greeting;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final name = user?.email.split('@').first;
    final today = formatDate(DateTime.now(), 'EEEE, MMM d');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null || name.isEmpty ? greeting : 'Hi, $name 👋',
                style: theme.textTheme.headlineMedium,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                today,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _HeaderIconButton(icon: Icons.search_outlined, tooltip: 'Search', onPressed: onSearch),
        const SizedBox(width: AppSpacing.s8),
        _HeaderIconButton(icon: Icons.notifications_outlined, tooltip: 'Notifications', onPressed: onNotifications),
        const SizedBox(width: AppSpacing.s8),
        _HeaderIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: onRefresh),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Section heading used between the home screen's stacked content blocks
/// (Quick Actions / EMI Tracker / Recent Transactions).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(final BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
