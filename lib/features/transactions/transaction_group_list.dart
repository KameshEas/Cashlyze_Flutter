import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import 'transaction_list_item.dart';

/// Widget for rendering grouped transactions with date headers
class TransactionGroupList extends StatelessWidget {

  const TransactionGroupList({
    super.key,
    required this.groupedTransactions,
    required this.currency,
    required this.datePattern,
    required this.selectionMode,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.onLongPress,
    required this.onTapTransaction,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 88),
  });
  final Map<String, List<TransactionModel>> groupedTransactions;
  final String currency;
  final String datePattern;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback? onLongPress;
  final ValueChanged<String> onTapTransaction;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  // Order for date groups to display consistently
  static const _groupOrder = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Last Month',
    'Older',
  ];

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    
    // Sort groups in consistent order
    final sortedKeys = _groupOrder.where(groupedTransactions.containsKey).toList();

    return ListView.separated(
      controller: scrollController,
      padding: padding,
      separatorBuilder: (final ctx, final i) => const SizedBox(height: 12),
      itemCount: _buildItemCount(sortedKeys),
      itemBuilder: (final ctx, final globalIndex) {
        return _buildItem(context, theme, sortedKeys, globalIndex);
      },
    );
  }

  int _buildItemCount(final List<String> sortedKeys) {
    int count = 0;
    for (final key in sortedKeys) {
      count += 1; // header
      count += groupedTransactions[key]?.length ?? 0;
    }
    return count;
  }

  Widget _buildItem(final BuildContext context, final ThemeData theme, final List<String> sortedKeys, final int globalIndex) {
    int currentIndex = 0;
    
    for (final groupKey in sortedKeys) {
      final transactions = groupedTransactions[groupKey] ?? [];
      
      // Check if this is a header
      if (currentIndex == globalIndex) {
        return _buildDateHeader(context, theme, groupKey);
      }
      currentIndex++;

      // Check if this is a transaction
      final txIndex = globalIndex - currentIndex;
      if (txIndex >= 0 && txIndex < transactions.length) {
        final tx = transactions[txIndex];
        return TransactionListItem(
          tx: tx,
          currency: currency,
          datePattern: datePattern,
          selectionMode: selectionMode,
          selected: selectedIds.contains(tx.id),
          onSelectedChanged: onSelectionChanged,
          onLongPress: onLongPress,
          onTap: () => onTapTransaction(tx.id),
        );
      }
      currentIndex += transactions.length;
    }

    return const SizedBox.shrink();
  }

  Widget _buildDateHeader(final BuildContext context, final ThemeData theme, final String groupLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Text(
            groupLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
