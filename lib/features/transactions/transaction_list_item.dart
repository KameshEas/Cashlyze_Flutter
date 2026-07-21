import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';

class TransactionListItem extends ConsumerWidget {

  const TransactionListItem({
    super.key,
    required this.tx,
    required this.currency,
    required this.datePattern,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.onLongPress,
    this.onTap,
  });
  final TransactionModel tx;
  final String currency;
  final String datePattern;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncome = tx.amount > 0;
    final accentColor = isIncome ? AppColors.success : theme.colorScheme.error;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      accentColor: accentColor,
      onTap: selectionMode
          ? () => onSelectedChanged?.call(!selected)
          : onTap,
      onLongPress: onLongPress,
      child: Row(
          children: [
            if (selectionMode) ...[
              Checkbox(value: selected, onChanged: (final v) => onSelectedChanged?.call(v ?? false)),
              const SizedBox(width: 8),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: accentColor,
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
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Builder(builder: (final ctx) {
                                final cats = ref.watch(userCategoriesProvider).maybeWhen(
                                      data: (final d) => d,
                                      orElse: () => const <CategoryModel>[],
                                    );
                                final rawId = tx.categoryId?.trim();
                                final nameFallback = tx.categoryName?.trim();

                                if ((rawId == null || rawId.isEmpty) && (nameFallback == null || nameFallback.isEmpty)) {
                                  return Text('General', style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1);
                                }

                                // If we have an id, prefer the category name for that id,
                                // but allow the transaction-provided `categoryName` to
                                // override when it differs (handles race/rename cases).
                                if (rawId != null && rawId.isNotEmpty) {
                                  final byIdList = cats.where((final c) => c.id == rawId).toList();
                                  if (byIdList.isNotEmpty) {
                                    final catName = byIdList.first.name;
                                    if (nameFallback != null && nameFallback.isNotEmpty && catName.trim().toLowerCase() != nameFallback.toLowerCase()) {
                                      return Text(nameFallback, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1);
                                    }
                                    return Text(catName, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1);
                                  }
                                }

                                // Try matching by name (either the explicit fallback or
                                // the id-as-name); otherwise show the fallback or raw value.
                                final lookup = (nameFallback ?? rawId) ?? '';
                                final byNameList = cats.where((final c) => c.name.toLowerCase() == lookup.toLowerCase()).toList();
                                if (byNameList.isNotEmpty) {
                                  return Text(byNameList.first.name, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1);
                                }
                                if (nameFallback != null && nameFallback.isNotEmpty) {
                                  return Text(nameFallback, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1);
                                }
                                return Text(lookup, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1);
                              }),
                            ),
                          ),
                      const SizedBox(width: 8),
                      Text(
                        formatDate(tx.date, datePattern),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  if (tx.tags != null && tx.tags!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: tx.tags!.map((final tag) => Chip(
                        label: Text(
                          tag,
                          style: theme.textTheme.labelSmall,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              formatAmount(tx.amount, currency),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
    );
  }
}
