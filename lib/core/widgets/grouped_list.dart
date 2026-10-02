import 'package:flutter/material.dart';

import '../ui/constants.dart';

/// Where a row sits inside a visual group; decides which corners round and
/// whether a divider is drawn beneath it.
enum GroupPosition { only, first, middle, last }

GroupPosition groupPositionOf(final int index, final int count) {
  if (count <= 1) return GroupPosition.only;
  if (index == 0) return GroupPosition.first;
  if (index == count - 1) return GroupPosition.last;
  return GroupPosition.middle;
}

/// One row of a grouped ("inset list") surface.
///
/// The group look is produced per row, so long lists can stay lazy
/// (`ListView.builder`) instead of building one giant column: each row paints
/// its own slice of the rounded surface plus a hairline divider inset to the
/// text edge. Pass [selected] for a tinted selected state (no borders needed).
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.position,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.dividerIndent = 68,
    this.minHeight = 56,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
  });

  final GroupPosition position;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// Left inset of the divider (icon width + gap) so it aligns with the text.
  final double dividerIndent;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const r = AppRadius.lg;
    final radius = BorderRadius.vertical(
      top: (position == GroupPosition.first || position == GroupPosition.only) ? const Radius.circular(r) : Radius.zero,
      bottom: (position == GroupPosition.last || position == GroupPosition.only) ? const Radius.circular(r) : Radius.zero,
    );
    final showDivider = position == GroupPosition.first || position == GroupPosition.middle;
    final fill = selected ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), scheme.surface) : scheme.surface;

    return Semantics(
      selected: selected,
      child: Material(
        color: fill,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(padding: padding, child: child),
              ),
              if (showDivider)
                Positioned(
                  left: dividerIndent,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 1, color: scheme.outline.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, eager group of rows (Home's recent list, Settings sections, …).
/// For long, scrolling lists use [GroupedRow] inside a lazy list instead.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    required this.children,
    this.dividerIndent = 68,
  });

  /// Each child is placed in a [GroupedRow]-like slice; supply the row
  /// content only (padding is applied here).
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: isDark ? 1 : 0.8)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++)
              GroupedRow(
                // The outer container supplies the rounding and border.
                position: i == children.length - 1 ? GroupPosition.last : GroupPosition.middle,
                dividerIndent: dividerIndent,
                child: children[i],
              ),
          ],
        ),
      ),
    );
  }
}
