import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/constants.dart';
import '../../../core/ui/finance_style.dart';
import '../../../core/ui/motion.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/inline_field_error.dart';

/// Building blocks for the EMI plan form: a hero amount field, grouped
/// inline-field rows, a sliding segmented selector and a live preview card.
/// They share one language: hairlines instead of boxes, focus shown by a
/// tint + label colour, errors inline under the field.

Color _hairline(final BuildContext context) {
  final theme = Theme.of(context);
  return theme.colorScheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 1 : 0.8);
}

Color _muted(final BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64);

/// Brand accent for *text and thin lines*. In dark mode `colorScheme.primary`
/// (ocean500) is a fill colour and is too dim as text on dark surfaces, so use
/// the same lighter tone the theme uses for links and outlined buttons.
Color _accent(final BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.ocean400 : AppColors.ocean700;

/// Groups the integer part of an amount as it is typed ("250000" ->
/// "2,50,000" for en_IN) and limits decimals to two. The controller text
/// therefore contains separators: parse with [parse].
class AmountGroupingFormatter extends TextInputFormatter {
  const AmountGroupingFormatter({this.locale = 'en_IN', this.maxIntegerDigits = 12});

  final String locale;
  final int maxIntegerDigits;

  /// Parses grouped text back to a number (null when empty/invalid).
  static double? parse(final String text) => double.tryParse(text.replaceAll(',', ''));

  /// Formats a stored amount for the field: grouped, decimals only if needed.
  static String format(final double value, {final String locale = 'en_IN'}) {
    final fixed = value.toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final whole = int.parse(fixed.substring(0, dot));
    final frac = fixed.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '');
    final grouped = NumberFormat.decimalPattern(locale).format(whole);
    return frac.isEmpty ? grouped : '$grouped.$frac';
  }

  @override
  TextEditingValue formatEditUpdate(final TextEditingValue oldValue, final TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return const TextEditingValue();
    final match = RegExp(r'^(\d*)(\.\d{0,2})?$').firstMatch(raw);
    if (match == null) return oldValue;

    var whole = match.group(1) ?? '';
    final frac = match.group(2) ?? '';
    if (whole.length > maxIntegerDigits) return oldValue;
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final leadingZeroAdded = whole.isEmpty && frac.isNotEmpty;
    final grouped = whole.isEmpty ? (frac.isNotEmpty ? '0' : '') : NumberFormat.decimalPattern(locale).format(int.parse(whole));
    final text = grouped + frac;

    // Keep the caret after the same number of digits/dot it followed before.
    final caret = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    var target = newValue.text.substring(0, caret).replaceAll(',', '').length + (leadingZeroAdded ? 1 : 0);
    var offset = 0;
    while (offset < text.length && target > 0) {
      if (text[offset] != ',') target--;
      offset++;
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}

/// Small section title above a group.
class EmiSectionLabel extends StatelessWidget {
  const EmiSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.s4, bottom: AppSpacing.s8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: _muted(context), letterSpacing: 0.2),
          ),
        ),
      );
}

/// One rounded surface that holds related rows; rows add their own dividers.
class EmiGroup extends StatelessWidget {
  const EmiGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(final BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: _hairline(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class EmiDivider extends StatelessWidget {
  const EmiDivider({super.key});

  @override
  Widget build(final BuildContext context) =>
      Container(height: 1, margin: const EdgeInsets.only(left: AppSpacing.s16), color: _hairline(context));
}

/// Shows/hides [child] with a height + fade transition. Reduced motion swaps
/// instantly (AnimatedSize asserts with a zero duration, so it is skipped
/// entirely rather than shortened).
class EmiReveal extends StatelessWidget {
  const EmiReveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    if (reduceMotionOf(context)) return visible ? child : const SizedBox(width: double.infinity);
    return AnimatedSize(
      duration: AppDuration.component,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDuration.fast,
        switchInCurve: AppCurve.standard,
        switchOutCurve: AppCurve.exit,
        transitionBuilder: (final c, final a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
            child: c,
          ),
        ),
        layoutBuilder: (final current, final previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: visible
            ? KeyedSubtree(key: const ValueKey('shown'), child: child)
            : const SizedBox(key: ValueKey('hidden'), width: double.infinity),
      ),
    );
  }
}

/// The primary figure: large, borderless, with an underline that thickens and
/// recolours on focus / error.
class EmiAmountField extends StatelessWidget {
  const EmiAmountField({
    super.key,
    required this.label,
    required this.helper,
    required this.symbol,
    required this.groupingLocale,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String helper;
  final String symbol;
  final String groupingLocale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (final context, final _) {
        final focused = focusNode.hasFocus;
        final hasError = error != null;
        final accent = hasError ? scheme.error : (focused ? _accent(context) : _hairline(context));
        final big = tabular(theme.textTheme.displayMedium);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: focusNode.requestFocus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: AppMotion.durationFor(context, AppDuration.micro),
                style: theme.textTheme.labelLarge!.copyWith(
                  color: hasError ? scheme.error : (focused ? _accent(context) : _muted(context)),
                ),
                child: Text(label),
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Text(symbol, style: big.copyWith(color: scheme.onSurface.withValues(alpha: 0.4))),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AmountGroupingFormatter(locale: groupingLocale)],
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: big,
                      cursorColor: _accent(context),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: big.copyWith(color: scheme.onSurface.withValues(alpha: 0.25)),
                        filled: false,
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedContainer(
                duration: AppMotion.durationFor(context, AppDuration.micro),
                height: focused || hasError ? 2 : 1,
                color: accent,
              ),
              const SizedBox(height: AppSpacing.s8),
              if (!hasError) Text(helper, style: theme.textTheme.bodySmall?.copyWith(color: _muted(context))),
              InlineFieldError(message: error),
            ],
          ),
        );
      },
    );
  }
}

/// Label on the left, value typed on the right. The whole row is the tap
/// target; focus tints the row and recolours the label.
class EmiFieldRow extends StatelessWidget {
  const EmiFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    this.suffix,
    this.hint = '0',
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;
  final String? suffix;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (final context, final _) {
        final focused = focusNode.hasFocus;
        final hasError = error != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: AppMotion.durationFor(context, AppDuration.micro),
              color: focused ? _accent(context).withValues(alpha: 0.08) : Colors.transparent,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: focusNode.requestFocus,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: AppMotion.durationFor(context, AppDuration.micro),
                              style: theme.textTheme.bodyMedium!.copyWith(
                                fontWeight: FontWeight.w500,
                                color: hasError
                                    ? scheme.error
                                    : (focused ? _accent(context) : scheme.onSurface.withValues(alpha: 0.86)),
                              ),
                              child: Text(label),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 72, maxWidth: 168),
                            child: IntrinsicWidth(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: keyboardType,
                                textInputAction: textInputAction,
                                inputFormatters: inputFormatters,
                                onChanged: onChanged,
                                onSubmitted: onSubmitted,
                                textAlign: TextAlign.end,
                                cursorColor: _accent(context),
                                style: tabular(theme.textTheme.titleMedium),
                                decoration: InputDecoration(
                                  hintText: hint,
                                  hintStyle: tabular(theme.textTheme.titleMedium)
                                      .copyWith(color: scheme.onSurface.withValues(alpha: 0.3)),
                                  suffixText: suffix,
                                  suffixStyle: theme.textTheme.bodyMedium?.copyWith(color: _muted(context)),
                                  filled: false,
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, hasError ? AppSpacing.s8 : 0),
              child: InlineFieldError(message: error, textAlign: TextAlign.end),
            ),
          ],
        );
      },
    );
  }
}

/// A tappable row showing a label and its current value (opens a picker).
class EmiValueRow extends StatelessWidget {
  const EmiValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: tabular(theme.textTheme.titleMedium).copyWith(color: _accent(context)),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Icon(icon, size: 20, color: _muted(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small segmented selector with a sliding thumb: every option stays
/// visible (three choices don't need a dropdown) and the change reads as one
/// continuous movement.
class EmiSegmented<T> extends StatelessWidget {
  const EmiSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  static const double _height = 48;
  static const double _pad = 4;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedIndex = options.indexWhere((final o) => o.$1 == value).clamp(0, options.length - 1);

    return LayoutBuilder(
      builder: (final context, final box) {
        final segment = (box.maxWidth - _pad * 2) / options.length;
        return Container(
          height: _height,
          padding: const EdgeInsets.all(_pad),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: AppRadius.mdAll,
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.durationFor(context, AppDuration.fast),
                curve: AppCurve.standard,
                left: selectedIndex * segment,
                width: segment,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md - _pad),
                    border: Border.all(color: _hairline(context)),
                    boxShadow: theme.brightness == Brightness.dark ? null : AppShadow.card,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (v, label) in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: v == value,
                        label: label,
                        excludeSemantics: true,
                        onTap: () => onChanged(v),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md - _pad),
                          onTap: () {
                            if (v != value) HapticFeedback.selectionClick();
                            onChanged(v);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: AppMotion.durationFor(context, AppDuration.fast),
                              style: theme.textTheme.labelLarge!.copyWith(
                                color: v == value ? scheme.onSurface : _muted(context),
                                fontWeight: v == value ? FontWeight.w700 : FontWeight.w500,
                              ),
                              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Numbers computed by the live preview.
@immutable
class EmiPreviewData {
  const EmiPreviewData({
    required this.installment,
    required this.totalInterest,
    required this.totalPayable,
    required this.payments,
    required this.lastDue,
  });

  final double installment;
  final double totalInterest;
  final double totalPayable;
  final int payments;
  final DateTime lastDue;
}

/// Compact summary of what the entered terms add up to. Numbers glide between
/// values; the card itself is revealed by [EmiReveal].
class EmiPreviewCard extends StatelessWidget {
  const EmiPreviewCard({
    super.key,
    required this.data,
    required this.currency,
    required this.dateFormat,
    required this.periodLabel,
  });

  final EmiPreviewData data;
  final String currency;
  final String dateFormat;

  /// "month", "week" or "quarter".
  final String periodLabel;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduce = reduceMotionOf(context);
    final noInterest = data.totalInterest <= 0;
    final summary = 'Estimated installment ${formatAmount(data.installment, currency)} per $periodLabel. '
        '${noInterest ? 'No interest' : 'Total interest ${formatAmount(data.totalInterest, currency)}'}. '
        'Total payable ${formatAmount(data.totalPayable, currency)} over ${data.payments} payments.';

    Widget figure(final double value, final TextStyle? style) => TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value),
          duration: reduce ? Duration.zero : AppDuration.normal,
          curve: AppCurve.standard,
          builder: (final context, final v, final _) => Text(formatAmount(v, currency), style: style),
        );

    Widget stat(final String label, final Widget value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: _muted(context))),
              const SizedBox(height: AppSpacing.s4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
            ],
          ),
        );

    final statStyle = tabular(theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700));

    return Semantics(
      container: true,
      label: summary,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s20),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: theme.brightness == Brightness.dark ? 0.55 : 0.7),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: _hairline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estimated EMI', style: theme.textTheme.labelLarge?.copyWith(color: _muted(context))),
            const SizedBox(height: AppSpacing.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: figure(data.installment, tabular(theme.textTheme.displayMedium)),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text('/ $periodLabel', style: theme.textTheme.bodyMedium?.copyWith(color: _muted(context))),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(height: 1, color: _hairline(context)),
            const SizedBox(height: AppSpacing.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(
                  'Total interest',
                  noInterest ? Text('None', style: statStyle) : figure(data.totalInterest, statStyle),
                ),
                const SizedBox(width: AppSpacing.s12),
                stat('Total payable', figure(data.totalPayable, statStyle)),
                const SizedBox(width: AppSpacing.s12),
                stat('Last payment', Text(formatDate(data.lastDue, dateFormat), style: statStyle)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One-line version of the preview, pinned above the primary action so the
/// result is visible without scrolling and while the keyboard is open.
class EmiSummaryLine extends StatelessWidget {
  const EmiSummaryLine({super.key, required this.data, required this.currency, required this.periodLabel});

  final EmiPreviewData data;
  final String currency;
  final String periodLabel;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final reduce = reduceMotionOf(context);
    return Row(
      children: [
        Expanded(
          child: Text('Estimated EMI', style: theme.textTheme.bodyMedium?.copyWith(color: _muted(context))),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: data.installment),
          duration: reduce ? Duration.zero : AppDuration.normal,
          curve: AppCurve.standard,
          builder: (final context, final v, final _) => Text(
            formatAmount(v, currency),
            style: tabular(theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
        Text('/ $periodLabel', style: theme.textTheme.bodyMedium?.copyWith(color: _muted(context))),
      ],
    );
  }
}
