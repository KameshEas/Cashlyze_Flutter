import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/ui/category_style.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/finance_style.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/grouped_list.dart';

/// How long the saved-row tint takes to fade.
const Duration kSavedHighlightDuration = Duration(milliseconds: 900);

/// One transaction line in the (grouped) Transactions list.
///
/// Rendered as a [GroupedRow] so a day's transactions read as one surface
/// with hairline dividers. Selection mode swaps the category glyph for a
/// checkbox and tints the row; there are no per-row borders.
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
    this.highlight = false,
    this.position = GroupPosition.only,
  });

  final TransactionModel tx;
  final String currency;
  final String datePattern;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  /// Plays a one-shot "just saved" tint that fades out. Reduced motion skips it
  /// (the save snackbar still confirms).
  final bool highlight;

  /// Position within the day group (decides rounding + divider).
  final GroupPosition position;

  /// Resolves the display name for a transaction's category.
  ///
  /// If an id is present, prefer the live category name for it, but let the
  /// transaction-provided `categoryName` override when it differs (handles
  /// rename/race cases). Otherwise match by name, then fall back to the raw
  /// value, then 'General'.
  static String resolveCategoryName(final TransactionModel tx, final List<CategoryModel> cats) {
    final rawId = tx.categoryId?.trim();
    final nameFallback = tx.categoryName?.trim();
    final hasId = rawId != null && rawId.isNotEmpty;
    final hasName = nameFallback != null && nameFallback.isNotEmpty;

    if (!hasId && !hasName) return 'General';

    if (hasId) {
      final byId = cats.where((final c) => c.id == rawId).toList();
      if (byId.isNotEmpty) {
        final catName = byId.first.name;
        if (hasName && catName.trim().toLowerCase() != nameFallback.toLowerCase()) return nameFallback;
        return catName;
      }
    }

    final lookup = (nameFallback ?? rawId) ?? '';
    final byName = cats.where((final c) => c.name.toLowerCase() == lookup.toLowerCase()).toList();
    if (byName.isNotEmpty) return byName.first.name;
    if (hasName) return nameFallback;
    return lookup;
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.66);
    final cats = ref.watch(userCategoriesProvider).maybeWhen(
          data: (final d) => d,
          orElse: () => const <CategoryModel>[],
        );
    final category = resolveCategoryName(tx, cats);
    final style = categoryStyleFor(category, isIncome: tx.amount > 0);
    final caption = '$category · ${formatDate(tx.date, datePattern)}';

    return _SavedFlash(
      active: highlight,
      builder: (final context, final t) => GroupedRow(
      position: position,
      selected: selected,
      highlight: t,
      onTap: selectionMode ? () => onSelectedChanged?.call(!selected) : onTap,
      onLongPress: onLongPress,
      child: LayoutBuilder(
        builder: (final context, final box) => Row(
        children: [
          if (selectionMode)
            SizedBox(
              width: 40,
              height: 40,
              child: Checkbox(
                value: selected,
                onChanged: (final v) => onSelectedChanged?.call(v ?? false),
              ),
            )
          else
            CategoryGlyph(style: style),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
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
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tx.tags != null && tx.tags!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      for (final tag in tx.tags!)
                        Chip(
                          label: Text(tag, style: theme.textTheme.labelSmall),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          // Natural width, capped at 42% of the row, so the caption keeps the rest.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.42),
            child: AmountText(amount: tx.amount, currency: currency),
          ),
        ],
        ),
      ),
      ),
    );
  }
}

/// Plays a one-shot 1 -> 0 fade each time [active] turns on, including on a
/// row that is already mounted (an edited row), which a TweenAnimationBuilder
/// would not restart. Under reduced motion it never animates.
class _SavedFlash extends StatefulWidget {
  const _SavedFlash({required this.active, required this.builder});

  final bool active;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_SavedFlash> createState() => _SavedFlashState();
}

class _SavedFlashState extends State<_SavedFlash> with SingleTickerProviderStateMixin {
  // value 1 = idle (no tint); forward(from: 0) plays the fade.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: kSavedHighlightDuration,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _c.value == 1 && !_c.isAnimating) _play();
  }

  @override
  void didUpdateWidget(final _SavedFlash old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _play();
  }

  void _play() {
    if (reduceMotionOf(context)) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (final context, final _) => widget.builder(context, 1 - Curves.easeOut.transform(_c.value)),
      );
}
