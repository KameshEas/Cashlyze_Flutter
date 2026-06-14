import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/onboarding_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/constants.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late DateTime _onboardingStart;

  // ── Onboarding data ────────────────────────────────────────────────────────
  // Removed dead CDN Lottie URLs — replaced with intentional icon + gradient.
  // Icons are full-opacity inside a branded gradient circle: no more "broken
  // fallback" aesthetic that faded icons at 0.5 opacity created.
  static const List<Map<String, dynamic>> _pages = [
    {
      'title': 'Track Your Spending',
      'description':
          'Every transaction recorded in seconds. See exactly where your money goes, category by category.',
      'icon': Icons.receipt_long_rounded,
      'gradientStart': Color(0xFF059669),
      'gradientEnd': Color(0xFF14B8A6),
    },
    {
      'title': 'Set Smart Budgets',
      'description':
          'Create Daily, Weekly, or Monthly budgets. Filter by period, reorder for quick access, and undo changes.',
      'icon': Icons.account_balance_wallet_rounded,
      'gradientStart': Color(0xFF14B8A6),
      'gradientEnd': Color(0xFF3B82F6),
      'features': [
        '• Multiple budget periods: Daily, Weekly, Monthly',
        '• Filter budgets to focus on what matters',
        '• Drag to reorder for quick access',
        '• Undo adjustments within 5 seconds',
      ],
    },
    {
      'title': 'Gain Clear Insights',
      'description':
          'Beautiful charts reveal your financial health. Spot trends and act before they become problems.',
      'icon': Icons.insights_rounded,
      'gradientStart': Color(0xFF3B82F6),
      'gradientEnd': Color(0xFF8B5CF6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _onboardingStart = DateTime.now();
  }

  Future<void> _complete({bool skipped = false}) async {
    final start = _onboardingStart;
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    final steps = _currentPage + 1;
    final method = skipped ? 'skip' : 'slides';

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

    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — top right, visible on pages 1 & 2 only
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _currentPage < _pages.length - 1 ? 1 : 0,
                  child: TextButton(
                    onPressed:
                      _currentPage < _pages.length - 1 ? () => _complete(skipped: true) : null,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _buildPage(context, _pages[index]),
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, Map<String, dynamic> data) {
    final features = data['features'] as List<String>?;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.heroPadding,
        vertical: AppSpacing.s16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: features != null ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            if (features != null) const SizedBox(height: AppSpacing.s24),
            // ── Illustration ───────────────────────────────────────────────
            // Previously: Icon at 50–70% opacity → looked like a broken fallback.
            // Now: full-opacity icon on a branded gradient circle — intentional.
            Semantics(
              label: 'Onboarding illustration for ${data['title']}',
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (data['gradientStart'] as Color),
                      (data['gradientEnd'] as Color),
                    ],
                  ),
                  boxShadow: AppShadow.brand(data['gradientStart'] as Color),
                ),
                child: Icon(
                  data['icon'] as IconData,
                  size: 70,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s32),
            // ── Title ──────────────────────────────────────────────────────
            Text(
              data['title'] as String,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: AppType.lhTight,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            // ── Description ────────────────────────────────────────────────
            Text(
              data['description'] as String,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                height: AppType.lhNormal,
              ),
            ),
            // ── Features (if available) ────────────────────────────────────
            if (features != null) ...[
              const SizedBox(height: AppSpacing.s24),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final feature in features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          feature,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.heroPadding,
        AppSpacing.s8,
        AppSpacing.heroPadding,
        AppSpacing.heroPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Page indicators ────────────────────────────────────────────
          Row(
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: AppSpacing.s8),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: 0.25,
                        ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
          // ── Next / Get Started ─────────────────────────────────────────
          FilledButton(
            onPressed: () async {
                if (_currentPage < _pages.length - 1) {
                if (MediaQuery.of(context).disableAnimations) {
                  _pageController.jumpToPage(_currentPage + 1);
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  );
                }
              } else {
                await _complete();
              }
            },
            child: Text(
              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
            ),
          ),
        ],
      ),
    );
  }
}
