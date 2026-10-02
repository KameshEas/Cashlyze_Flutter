import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../ui/category_style.dart';
import '../ui/constants.dart';
import '../ui/finance_style.dart';

/// Content of one transaction line: category glyph · title + caption ·
/// right-aligned signed amount. Pure content (no surface or padding) so it
/// can sit inside a [GroupedRow] on Home and on the Transactions list.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.tx,
    required this.currency,
    this.caption,
    this.leading,
  });

  final TransactionModel tx;
  final String currency;

  /// Second line; defaults to the category name.
  final String? caption;

  /// Replaces the category glyph (e.g. a selection checkbox).
  final Widget? leading;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final category = tx.categoryName ?? tx.categoryId ?? 'General';
    final style = categoryStyleFor(category, isIncome: tx.amount > 0);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.66);

    return Row(
      children: [
        leading ?? CategoryGlyph(style: style),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.title,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                caption ?? category,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Flexible(
          flex: 2,
          child: AmountText(amount: tx.amount, currency: currency),
        ),
      ],
    );
  }
}
