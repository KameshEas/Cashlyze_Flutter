import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/transaction.dart';
import '../../core/utils/format.dart';

class TransactionListItem extends ConsumerWidget {
  final TransactionModel tx;
  final String currency;
  final String datePattern;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const TransactionListItem({
    Key? key,
    required this.tx,
    required this.currency,
    required this.datePattern,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.onLongPress,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncome = tx.amount > 0;
    return InkWell(
      onTap: selectionMode
          ? () => onSelectedChanged?.call(!selected)
          : onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.14),
          ),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Checkbox(value: selected, onChanged: (v) => onSelectedChanged?.call(v ?? false)),
              const SizedBox(width: 8),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tx.categoryId ?? 'Uncategorized',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatDate(tx.date, datePattern),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatAmount(tx.amount, currency),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
