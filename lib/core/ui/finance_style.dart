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

/// Money-out colour: a soft coral, deliberately warmer and quieter than the
/// error red (which stays reserved for overspend and failures). 5.0:1 on
/// light surfaces; a lightened tone on dark ones.
Color expenseColorOf(final BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF8F86) : const Color(0xFFC2453B);

/// Income tone for use on the deep-ocean hero surface.
const Color kIncomeOnHero = Color(0xFF7FE3B2);

/// Expense tone for use on the deep-ocean hero surface.
const Color kExpenseOnHero = Color(0xFFFFB0A8);

/// Adds tabular (fixed-width) figures so columns of amounts line up and
/// digits don't jitter while values animate.
TextStyle tabular(final TextStyle? base) => (base ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// A signed money value: `+₹5,000.00` / `−₹420.00`.
///
/// Meaning is carried by the sign (and the screen-reader label), never by
/// colour alone. Income is tinted green and money-out a soft coral, so the
/// two read differently at a glance; the error red stays reserved for
/// overspend and failures.
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
    this.expenseColor,
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

  /// Override for the expense tint (e.g. [kExpenseOnHero] on dark surfaces).
  final Color? expenseColor;

  /// Override for the neutral colour; also used for expense when
  /// [expenseColor] isn't given (so a caller forcing, say, white text on a
  /// hero keeps it).
  final Color? color;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Unsigned figures (averages, forecasts, totals) are plain numbers: no
    // income tint and no "Income"/"Expense" announcement.
    final isIncome = showSign && amount > 0;
    final isExpense = showSign && amount < 0;
    final formatted = formatAmount(amount.abs(), currency);
    final sign = isIncome ? '+' : (isExpense ? kMinus : '');
    final kind = isIncome
        ? (l10n?.filterIncome ?? 'Income')
        : (isExpense ? (l10n?.filterExpense ?? 'Expense') : '');

    final base = style ?? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    final Color? tint = isIncome
        ? (incomeColor ?? incomeColorOf(context))
        : isExpense
            ? (expenseColor ?? color ?? expenseColorOf(context))
            : (color ?? base?.color);
    final resolved = tabular(base).copyWith(color: tint);

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
