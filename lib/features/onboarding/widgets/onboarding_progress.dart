import 'package:flutter/material.dart';

import '../../../core/ui/constants.dart';
import '../../../l10n/app_localizations.dart';

/// Segmented step indicator ("Step 2 of 3") for the onboarding flow.
///
/// Segments are decorative; the whole bar is a single semantics node with a
/// localised "Step x of y" label so screen readers announce progress instead
/// of reading anonymous dots.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, required this.current, required this.total});

  /// Zero-based index of the visible step.
  final int current;
  final int total;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final active = theme.brightness == Brightness.dark ? AppColors.ocean400 : theme.colorScheme.primary;
    final label =
        AppLocalizations.of(context)?.onboardingStepLabel(current + 1, total) ?? 'Step ${current + 1} of $total';

    return Semantics(
      label: label,
      value: '${current + 1}/$total',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.s4 + 2),
              Expanded(
                child: AnimatedContainer(
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? active : theme.colorScheme.onSurface.withValues(alpha: 0.14),
                    borderRadius: AppRadius.fullAll,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
