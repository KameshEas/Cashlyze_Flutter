import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/constants.dart';

/// Help Center screen with FAQ sections grouped by feature
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const List<HelpSection> _helpSections = [
    HelpSection(
      title: 'Transactions',
      icon: Icons.receipt_long_rounded,
      faqs: [
        FAQItem(
          question: 'How do I add a new transaction?',
          answer:
              'Navigate to the Transactions tab and tap "Add Transaction". Select a category, enter the amount, choose the type (Income/Expense), and confirm.',
        ),
        FAQItem(
          question: 'Can I edit or delete transactions?',
          answer:
              'Yes, you can swipe left on a transaction to edit or delete it. Deleted transactions cannot be recovered.',
        ),
        FAQItem(
          question: 'How are transactions categorized?',
          answer:
              'Each transaction is assigned to a category for better tracking and analytics. You can create custom categories in the Categories section.',
        ),
      ],
    ),
    HelpSection(
      title: 'Budgets',
      icon: Icons.account_balance_wallet_rounded,
      faqs: [
        FAQItem(
          question: 'What are budget periods?',
          answer:
              'Budget periods (Daily, Weekly, Monthly) determine how often your budget resets. Daily budgets reset every day, weekly every 7 days, and monthly every month.',
        ),
        FAQItem(
          question: 'How do I create a budget?',
          answer:
              'Tap the Create button on the Budgets screen. Name your budget, set an allocation amount, select a period (Daily/Weekly/Monthly), and choose categories.',
        ),
        FAQItem(
          question: 'Can I reorder my budgets?',
          answer:
              'Yes! Long-press and drag a budget card to reorder them. Your custom order is saved automatically.',
        ),
        FAQItem(
          question: 'What happens if I exceed my budget?',
          answer:
              'You\'ll see a warning when utilization exceeds 90%. You can still spend beyond your budget, but it helps you track overspending.',
        ),
        FAQItem(
          question: 'Can I undo budget changes?',
          answer:
              'Yes. Adjustments can be undone within 5 seconds, and deletions within 8 seconds. Look for the undo button in the snackbar.',
        ),
      ],
    ),
    HelpSection(
      title: 'Categories',
      icon: Icons.category_rounded,
      faqs: [
        FAQItem(
          question: 'How do I create a custom category?',
          answer:
              'Go to Categories and tap Create. Enter a name, select a color and icon, then save. Custom categories help you organize transactions.',
        ),
        FAQItem(
          question: 'Can I delete categories?',
          answer:
              'You can delete custom categories you created, but system categories (default ones) cannot be deleted to prevent data loss.',
        ),
        FAQItem(
          question: 'Why should I use categories?',
          answer:
              'Categories help you track spending patterns, set focused budgets, and understand where your money goes across different areas.',
        ),
      ],
    ),
    HelpSection(
      title: 'EMI Calculator',
      icon: Icons.calculate_rounded,
      faqs: [
        FAQItem(
          question: 'How do I calculate EMI?',
          answer:
              'Open the EMI Calculator, enter the principal amount (loan), annual interest rate, and tenure in months. The monthly EMI will be calculated instantly.',
        ),
        FAQItem(
          question: 'What do the EMI fields mean?',
          answer:
              'Principal: Total loan amount. Interest Rate: Annual percentage rate. Tenure: Number of months to repay the loan.',
        ),
        FAQItem(
          question: 'Can I save EMI calculations?',
          answer:
              'Yes, after calculating EMI, you can save it to track loan payments. Saved EMIs appear in your transaction history.',
        ),
      ],
    ),
    HelpSection(
      title: 'Analytics',
      icon: Icons.insights_rounded,
      faqs: [
        FAQItem(
          question: 'What insights does the Analytics section provide?',
          answer:
              'Analytics shows spending trends, category breakdowns, budget utilization, and financial health indicators over time.',
        ),
        FAQItem(
          question: 'Can I view analytics for different time periods?',
          answer:
              'Yes, use the date filter to view analytics for specific weeks, months, or custom date ranges.',
        ),
        FAQItem(
          question: 'How are trends calculated?',
          answer:
              'Trends compare spending in different periods. A positive trend means higher spending compared to the previous period.',
        ),
      ],
    ),
    HelpSection(
      title: 'Settings',
      icon: Icons.settings_rounded,
      faqs: [
        FAQItem(
          question: 'What are notification settings?',
          answer:
              'Notifications alert you about budget overruns and important financial events. You can enable/disable them in Settings > Notifications.',
        ),
        FAQItem(
          question: 'How do I change my currency?',
          answer:
              'Go to Settings and select your preferred currency. All amounts will be displayed in the selected currency.',
        ),
        FAQItem(
          question: 'Can I backup my data?',
          answer:
              'Your data is automatically backed up to Firebase. You can sign out and sign in on another device to access your data.',
        ),
        FAQItem(
          question: 'How do I replay the onboarding tutorial?',
          answer:
              'In Settings, tap "Replay Onboarding" to see the tutorial again. This is useful if you want to refresh your knowledge about features.',
        ),
      ],
    ),
  ];

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: context.pop,
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.s16),
          itemCount: _helpSections.length,
          separatorBuilder: (final _, final _) => const SizedBox(height: AppSpacing.s8),
          itemBuilder: (final BuildContext context, final int index) {
            final section = _helpSections[index];
            return _buildHelpSection(context, section);
          },
        ),
      ),
    );
  }

  Widget _buildHelpSection(final BuildContext context, final HelpSection section) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(
            section.icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      children: [
        for (final faq in section.faqs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.question,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  faq.answer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                if (section.faqs.indexOf(faq) < section.faqs.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s12),
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      height: 1,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class HelpSection {

  const HelpSection({
    required this.title,
    required this.icon,
    required this.faqs,
  });
  final String title;
  final IconData icon;
  final List<FAQItem> faqs;
}

class FAQItem {

  const FAQItem({
    required this.question,
    required this.answer,
  });
  final String question;
  final String answer;
}
