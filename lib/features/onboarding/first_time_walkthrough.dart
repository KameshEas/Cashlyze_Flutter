import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/first_time_feature_provider.dart';

/// First-time user walkthrough screen shown on app launch
/// Guides new users through key features with step-by-step instructions
class FirstTimeWalkthrough extends ConsumerStatefulWidget {
  const FirstTimeWalkthrough({super.key});

  @override
  ConsumerState<FirstTimeWalkthrough> createState() =>
      _FirstTimeWalkthroughState();
}

class _FirstTimeWalkthroughState extends ConsumerState<FirstTimeWalkthrough>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;

  final _pages = [
    _WalkthroughPage(
      icon: Icons.trending_up,
      title: 'Track Your Money',
      description: 'Log every expense and income to get a complete picture of your finances',
      color: Colors.blue,
    ),
    _WalkthroughPage(
      icon: Icons.savings,
      title: 'Set Budgets',
      description: 'Create daily, weekly, or monthly budgets to control your spending',
      color: Colors.green,
    ),
    _WalkthroughPage(
      icon: Icons.credit_card,
      title: 'Manage EMIs',
      description: 'Track loan payments and EMI schedules all in one place',
      color: Colors.purple,
    ),
    _WalkthroughPage(
      icon: Icons.pie_chart,
      title: 'Get Insights',
      description: 'Visualize spending patterns and make smarter financial decisions',
      color: Colors.orange,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _completeWalkthrough() async {
    await ref.read(firstTimeAppLaunchProvider.notifier).markAsSeen();
    if (mounted) {
      GoRouter.of(context).go('/home');
    }
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _completeWalkthrough();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _pageController,
            onPageChanged: (final int index) {
              setState(() => _currentPage = index);
              _animationController.reset();
              _animationController.forward();
            },
            itemCount: _pages.length,
            itemBuilder: (final BuildContext context, final int index) {
              return _buildPage(context, _pages[index]);
            },
          ),
          // Progress indicators
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (final int index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: index == _currentPage ? 32 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Action buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('Back'),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _goToNextPage,
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _completeWalkthrough,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(
    final BuildContext context,
    final _WalkthroughPage page,
  ) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _animationController,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              page.color.withValues(alpha: 0.1),
              page.color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (final BuildContext context, final double value, final Widget? child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: page.color.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: page.color.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      page.icon,
                      size: 60,
                      color: page.color,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                page.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                page.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkthroughPage {

  _WalkthroughPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color color;
}
