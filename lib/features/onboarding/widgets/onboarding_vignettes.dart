import 'package:flutter/material.dart';

import '../../../core/ui/category_style.dart';
import '../../../core/ui/constants.dart';
import '../../../l10n/app_localizations.dart';

/// Which illustration an onboarding page shows.
enum OnboardingVignetteKind { transactions, budgets, insights }

/// Abstract, purpose-built illustration for an onboarding page.
///
/// Deliberately *not* live app components and carries no sample merchants,
/// amounts or currency: rows and figures are drawn as neutral bars, so
/// nothing can be mistaken for the user's own data and nothing needs
/// per-locale formatting. Category tiles reuse [categoryStyleFor] so the
/// colours match the real app.
///
/// Plays a single ≤300 ms entrance whenever [active] becomes true and holds
/// the final state under reduced motion. Screen readers get one description
/// ([semanticsLabel]); the drawing itself is excluded.
class OnboardingVignette extends StatelessWidget {
  const OnboardingVignette({
    super.key,
    required this.kind,
    required this.active,
    required this.semanticsLabel,
  });

  final OnboardingVignetteKind kind;
  final bool active;
  final String semanticsLabel;

  static const Duration _entrance = Duration(milliseconds: 300);

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: isDark ? null : AppShadow.soft,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: active ? 1 : 0),
            duration: reduce ? Duration.zero : _entrance,
            curve: Curves.easeOutCubic,
            builder: (final context, final t, final _) => switch (kind) {
              OnboardingVignetteKind.transactions => _TransactionsArt(t: t),
              OnboardingVignetteKind.budgets => _BudgetsArt(t: t),
              OnboardingVignetteKind.insights => _InsightsArt(t: t),
            },
          ),
        ),
      ),
    );
  }
}

/// Sub-interval of [t] mapped to 0..1 (for staggering inside one tween).
double _stage(final double t, final double start, final double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

Color _skeleton(final BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

class _Bar extends StatelessWidget {
  const _Bar({required this.widthFactor, this.height = 10, this.color});

  final double widthFactor;
  final double height;
  final Color? color;

  @override
  Widget build(final BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color ?? _skeleton(context),
            borderRadius: AppRadius.fullAll,
          ),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.style);

  final CategoryStyle style;

  @override
  Widget build(final BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: style.tint(Theme.of(context).brightness),
          borderRadius: AppRadius.mdAll,
        ),
        child: Icon(style.icon, color: style.color, size: 22),
      );
}

// ── Page 1: categorised transactions ─────────────────────────────────────

class _TransactionsArt extends StatelessWidget {
  const _TransactionsArt({required this.t});

  final double t;

  static const _rows = [
    (name: 'food', income: false, title: 0.55, sub: 0.32, amount: 0.22),
    (name: 'transport', income: false, title: 0.42, sub: 0.28, amount: 0.18),
    (name: 'salary', income: true, title: 0.5, sub: 0.3, amount: 0.26),
  ];

  @override
  Widget build(final BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s16),
          Builder(builder: (final context) {
            final r = _rows[i];
            final p = Curves.easeOut.transform(_stage(t, i * 0.2, i * 0.2 + 0.6));
            return Opacity(
              opacity: p,
              child: Transform.translate(
                offset: Offset(0, (1 - p) * 14),
                child: Row(
                  children: [
                    _CategoryTile(categoryStyleFor(r.name, isIncome: r.income)),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bar(widthFactor: r.title, height: 11),
                          const SizedBox(height: AppSpacing.s8),
                          _Bar(widthFactor: r.sub, height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _Bar(
                        widthFactor: 1,
                        height: 11,
                        color: (r.income ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Page 2: budgets with a near-limit state ──────────────────────────────

class _BudgetsArt extends StatelessWidget {
  const _BudgetsArt({required this.t});

  final double t;

  @override
  Widget build(final BuildContext context) {
    final t1 = Curves.easeOut.transform(_stage(t, 0, 0.75));
    final t2 = Curves.easeOut.transform(_stage(t, 0.15, 0.9));
    final warn = _stage(t, 0.8, 1);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BudgetRow(
          style: categoryStyleFor('shopping'),
          fill: 0.52 * t1,
          fillColor: AppColors.brandTeal,
        ),
        const SizedBox(height: AppSpacing.s24),
        _BudgetRow(
          style: categoryStyleFor('food'),
          fill: 0.94 * t2,
          fillColor: AppColors.warning,
          // The warning is carried by an icon + text, not colour alone.
          caption: Opacity(
            opacity: warn,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: AppSpacing.s4),
                Flexible(
                  child: Text(
                    l10n?.onboardingNearLimit ?? 'Near limit',
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.style,
    required this.fill,
    required this.fillColor,
    this.caption,
  });

  final CategoryStyle style;
  final double fill;
  final Color fillColor;
  final Widget? caption;

  @override
  Widget build(final BuildContext context) {
    return Row(
      children: [
        _CategoryTile(style),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bar(widthFactor: 0.4),
              const SizedBox(height: AppSpacing.s8),
              ClipRRect(
                borderRadius: AppRadius.fullAll,
                child: Stack(
                  children: [
                    Container(height: 10, color: _skeleton(context)),
                    FractionallySizedBox(
                      widthFactor: fill.clamp(0.0, 1.0),
                      child: Container(height: 10, color: fillColor),
                    ),
                  ],
                ),
              ),
              // Reserve the caption's height so the bar doesn't jump.
              SizedBox(
                height: 26,
                child: Align(alignment: Alignment.bottomLeft, child: caption),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Page 3: spending-over-time bars ──────────────────────────────────────

class _InsightsArt extends StatelessWidget {
  const _InsightsArt({required this.t});

  final double t;

  static const _heights = [0.38, 0.62, 0.48, 0.8, 0.58, 0.92];

  @override
  Widget build(final BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = (isDark ? AppColors.ocean400 : AppColors.ocean700).withValues(alpha: 0.28);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _heights.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor:
                        _heights[i] * Curves.easeOutCubic.transform(_stage(t, i * 0.1, i * 0.1 + 0.5)),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        // The latest period is emphasised by brand colour *and*
                        // by being tallest, so it isn't colour-only.
                        color: i == _heights.length - 1 ? AppColors.brandTeal : base,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(height: 2, color: _skeleton(context)),
      ],
    );
  }
}
