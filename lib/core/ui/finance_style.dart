import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../utils/format.dart';
import 'constants.dart';

/// A true minus sign (U+2212). A hyphen-minus sits at x-height and reads as a
/// dash next to tabular digits; money-out deserves the real glyph.
const String kMinus = '−';

/// Income green with measured contrast: 5.2:1 on paper surfaces in light
/// mode, a lighter tone on dark surfaces.
Color incomeColorOf(final BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5BD39B) : const Color(0xFF1B7A4B);

/// Income tone for use on the deep-ocean hero surface.
const Color kIncomeOnHero = Color(0xFF7FE3B2);

/// Adds tabular (fixed-width) figures so columns of amounts line up and
/// digits don't jitter while values animate.
TextStyle tabular(final TextStyle? base) => (base ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// A signed money value: `+₹5,000.00` / `−₹420.00`.
///
/// Meaning is carried by the sign (and the screen-reader label), never by
/// colour alone. Income is tinted green; money-out stays in the neutral text
/// colour so red remains reserved for overspend and errors.
///
/// Wrap in a [Flexible]/[Expanded] inside rows: it scales down rather than
/// overflowing for very large numbers or large text sizes.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.showSign = true,
    this.alignment = Alignment.centerRight,
    this.incomeColor,
    this.color,
  });

  /// Positive = income, negative = expense.
  final num amount;
  final String currency;
  final TextStyle? style;
  final bool showSign;
  final AlignmentGeometry alignment;

  /// Override for the income tint (e.g. [kIncomeOnHero] on dark surfaces).
  final Color? incomeColor;

  /// Override for the non-income colour.
  final Color? color;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isIncome = amount > 0;
    final isExpense = amount < 0;
    final formatted = formatAmount(amount.abs(), currency);
    final sign = !showSign ? '' : (isIncome ? '+' : (isExpense ? kMinus : ''));
    final kind = isIncome
        ? (l10n?.filterIncome ?? 'Income')
        : (isExpense ? (l10n?.filterExpense ?? 'Expense') : '');

    final base = style ?? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    final resolved = tabular(base).copyWith(
      color: isIncome ? (incomeColor ?? incomeColorOf(context)) : (color ?? base?.color),
    );

    return Semantics(
      label: kind.isEmpty ? formatted : '$kind $formatted',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text('$sign$formatted', style: resolved, maxLines: 1, softWrap: false),
      ),
    );
  }
}

/// Small muted section label. Uppercase + tracking only for English: both
/// hurt Devanagari/Tamil, which have no case and rely on conjunct spacing.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final latin = Localizations.localeOf(context).languageCode == 'en';
    final text = Semantics(
      header: true,
      child: Text(
        latin ? title.toUpperCase() : title,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: latin ? 0.8 : 0,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
        ),
      ),
    );
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: AppSpacing.s8),
      child: trailing == null
          ? text
          : Row(
              children: [
                Expanded(child: text),
                trailing!,
              ],
            ),
    );
  }
}
