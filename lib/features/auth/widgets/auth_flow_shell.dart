import 'package:flutter/material.dart';

import '../../../core/branding/animated_brand_logo.dart';
import '../../../core/branding/flow_backdrop.dart';
import '../../../core/ui/constants.dart';

/// Backdrop + logo + bottom sheet used by the forgot-password screens, so all
/// three share one layout (same look as the OTP screen).
class AuthFlowShell extends StatelessWidget {
  const AuthFlowShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: isDark ? const FlowBackdrop.ocean() : const FlowBackdrop.paper(),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: keyboardOpen ? 120 : 170,
                          child: FittedBox(
                            child: PlayOnceBrandLogo(
                              color: isDark ? Colors.white : AppColors.brandTeal,
                              showTagline: false,
                              width: 170,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                              border: Border.all(color: scheme.outline),
                              boxShadow: isDark
                                  ? null
                                  : const [
                                      BoxShadow(
                                        color: Color(0x1416201B),
                                        blurRadius: 28,
                                        offset: Offset(0, -8),
                                      ),
                                    ],
                            ),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              28,
                              24,
                              24 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline status banner (announced to screen readers; replaces snackbars).
class AuthFlowBanner extends StatelessWidget {
  const AuthFlowBanner({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = isError ? scheme.error : scheme.primary;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: AppSpacing.s16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.mark_email_read_outlined,
              size: 20,
              color: isError
                  ? (isDark ? const Color(0xFFFF9A9A) : AppColors.error)
                  : (isDark ? AppColors.ocean400 : scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
