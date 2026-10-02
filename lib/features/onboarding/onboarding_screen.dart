import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/onboarding_progress.dart';
import 'widgets/onboarding_vignettes.dart';

/// One onboarding page: which illustration, and how to look up its copy.
@immutable
class _PageSpec {
  const _PageSpec({
    required this.kind,
    required this.title,
    required this.body,
    required this.semantics,
  });

  final OnboardingVignetteKind kind;
  final String Function(AppLocalizations? l10n) title;
  final String Function(AppLocalizations? l10n) body;
  final String Function(AppLocalizations? l10n) semantics;
}

final List<_PageSpec> _pages = [
  _PageSpec(
    kind: OnboardingVignetteKind.transactions,
    title: (final l) => l?.onboardingPage1Title ?? 'See where your money goes',
    body: (final l) =>
        l?.onboardingPage1Body ??
        'Log expenses in seconds or scan a receipt, and every transaction lands in the right category.',
    semantics: (final l) =>
        l?.onboardingPage1Semantics ?? 'Illustration: a list of categorised transactions',
  ),
  _PageSpec(
    kind: OnboardingVignetteKind.budgets,
    title: (final l) => l?.onboardingPage2Title ?? 'Budgets that keep you on track',
    body: (final l) =>
        l?.onboardingPage2Body ??
        'Set daily, weekly or monthly limits and get a heads-up before you overspend.',
    semantics: (final l) =>
        l?.onboardingPage2Semantics ?? 'Illustration: budget progress bars, one nearing its limit',
  ),
  _PageSpec(
    kind: OnboardingVignetteKind.insights,
    title: (final l) => l?.onboardingPage3Title ?? 'Insights you can act on',
    body: (final l) =>
        l?.onboardingPage3Body ??
        'Clear charts show trends early, so small leaks never turn into big problems.',
    semantics: (final l) =>
        l?.onboardingPage3Semantics ?? 'Illustration: a bar chart of spending over time',
  ),
];

/// Below this height, or at large text scales, the illustration is dropped
/// so the copy and the CTA always fit without overflow.
const double _kMinHeightForArt = 560;
const double _kMaxTextScaleForArt = 1.5;

/// Minimum tap target for the Skip / Back controls.
const double _kTapTarget = 48;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late DateTime _onboardingStart;
  bool _isCompleting = false;

  bool get _isLast => _currentPage == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    _onboardingStart = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete({final bool skipped = false}) async {
    // Guard against double-taps firing the analytics event twice.
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final durationMs = DateTime.now().difference(_onboardingStart).inMilliseconds;
    final steps = _currentPage + 1;
    final method = skipped ? 'skip' : 'slides';

    try {
      await ref.read(sharedPrefsServiceProvider).completeOnboarding();
      ref.read(onboardingCompletedProvider.notifier).complete();
      await ref.read(analyticsServiceProvider).logEvent(
        'onboarding_completed',
        params: {
          'method': method,
          'steps': steps,
          'duration_ms': durationMs,
          'success': true,
        },
      );
    } catch (_) {
      // Persisting failed: stay on the screen and let the user retry rather
      // than leave a dead button.
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.retry ?? 'Retry')),
        );
      }
      return;
    }

    if (mounted) context.go('/login');
  }

  Future<void> _goTo(final int page) async {
    if (reduceMotionOf(context)) {
      _pageController.jumpToPage(page);
    } else {
      await _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (final context, final box) {
            final textScale = MediaQuery.textScalerOf(context).scale(AppType.b1) / AppType.b1;
            final showArt = box.maxHeight >= _kMinHeightForArt && textScale < _kMaxTextScaleForArt;
            return Column(
              children: [
                _TopBar(
                  current: _currentPage,
                  total: _pages.length,
                  showBack: _currentPage > 0,
                  showSkip: !_isLast,
                  onBack: () => _goTo(_currentPage - 1),
                  onSkip: () => _complete(skipped: true),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (final i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (final context, final i) => _OnboardingPage(
                      spec: _pages[i],
                      l10n: l10n,
                      active: i == _currentPage,
                      showArt: showArt,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.heroPadding,
                    AppSpacing.s16,
                    AppSpacing.heroPadding,
                    AppSpacing.s24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isCompleting
                          ? null
                          : () => _isLast ? _complete() : _goTo(_currentPage + 1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _isLast
                                  ? (l10n?.onboardingGetStarted ?? 'Get Started')
                                  : (l10n?.onboardingNext ?? 'Next'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_isLast) ...[
                            const SizedBox(width: AppSpacing.s8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Back (left) · segmented progress (centre) · Skip (right). Back and Skip
/// reserve their slots even when hidden so the progress bar never shifts.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.current,
    required this.total,
    required this.showBack,
    required this.showSkip,
    required this.onBack,
    required this.onSkip,
  });

  final int current;
  final int total;
  final bool showBack;
  final bool showSkip;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(final BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s8),
      child: Row(
        children: [
          SizedBox(
            width: _kTapTarget,
            height: _kTapTarget,
            child: showBack
                ? IconButton(
                    onPressed: onBack,
                    tooltip: l10n?.onboardingBack ?? 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              child: OnboardingProgress(current: current, total: total),
            ),
          ),
          // Fixed-width slot so hiding Skip on the last page doesn't reflow.
          SizedBox(
            width: 88,
            height: _kTapTarget,
            child: showSkip
                ? TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(minimumSize: const Size(_kTapTarget, _kTapTarget)),
                    // scaleDown keeps longer translations inside the fixed slot.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n?.onboardingSkip ?? 'Skip'),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.spec,
    required this.l10n,
    required this.active,
    required this.showArt,
  });

  final _PageSpec spec;
  final AppLocalizations? l10n;
  final bool active;
  final bool showArt;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showArt) ...[
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              flex: 5,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440, maxHeight: 300),
                  child: OnboardingVignette(
                    kind: spec.kind,
                    active: active,
                    semanticsLabel: spec.semantics(l10n),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
          // Copy scrolls if it ever outgrows the space (very large text).
          Flexible(
            flex: showArt ? 4 : 1,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title scaling is capped so a 200% setting can't push the
                  // body and CTA off small screens; body text still scales fully.
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Semantics(
                      header: true,
                      child: Text(
                        spec.title(l10n),
                        style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    spec.body(l10n),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      height: AppType.lhLoose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
