import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/onboarding_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/analytics_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Track Your Spending',
      'description':
          'Keep track of every penny you spend and understand your habits.',
      'animation':
          'https://assets10.lottiefiles.com/packages/lf20_ka1v9j.json', // Placeholder URL
    },
    {
      'title': 'Set Smart Budgets',
      'description':
          'Create budgets that work for you and achieve your financial goals.',
      'animation':
          'https://assets10.lottiefiles.com/packages/lf20_w51pcehl.json', // Placeholder URL
    },
    {
      'title': 'Gain Insights',
      'description':
          'Visualize your financial health with beautiful charts and reports.',
      'animation':
          'https://assets10.lottiefiles.com/packages/lf20_qp1q7mct.json', // Placeholder URL
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(
                    _onboardingData[index]['title']!,
                    _onboardingData[index]['description']!,
                    _onboardingData[index]['animation']!,
                  );
                },
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
    String title,
    String description,
    String animationUrl,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Using a container placeholder if Lottie fails or for preview
          SizedBox(
            height: 300,
            child: MediaQuery.of(context).disableAnimations
                ? Semantics(
                    label: 'Onboarding illustration',
                    child: Icon(
                      Icons.image,
                      size: 100,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  )
                : Semantics(
                    label: 'Onboarding animation',
                    child: Lottie.network(
                      animationUrl,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Indicators
          Row(
            children: List.generate(
              _onboardingData.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Next/Get Started Button
          ElevatedButton(
            onPressed: () async {
              if (_currentPage < _onboardingData.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                // Complete onboarding
                await ref.read(sharedPrefsServiceProvider).completeOnboarding();
                // Update state to trigger redirect
                ref.read(onboardingCompletedProvider.notifier).complete();
                await ref.read(analyticsServiceProvider).logEvent('onboarding_complete');
                if (mounted) {
                  context.go('/login');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text(
              _currentPage == _onboardingData.length - 1
                  ? 'Get Started'
                  : 'Next',
            ),
          ),
        ],
      ),
    );
  }
}
