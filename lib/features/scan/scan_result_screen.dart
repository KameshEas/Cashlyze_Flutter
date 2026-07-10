import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/category.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/scan_providers.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/category_picker_field.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  late TextEditingController merchantController;
  late TextEditingController amountController;
  late String category;
  DateTime? selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final bill = ref.read(scanProvider).result;

    merchantController = TextEditingController(text: bill?.merchantName ?? '');
    amountController = TextEditingController(text: bill?.amount.toStringAsFixed(2) ?? '');
    category = bill?.suggestedCategory ?? 'General';
    selectedDate = bill?.date;
  }

  @override
  void dispose() {
    merchantController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final bill = scanState.result;

    if (bill == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Result')),
        body: const Center(child: Text('No scan data available')),
      );
    }

    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: MotionFadeIn(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Confidence indicator
              if (bill.categoryConfidence > 0)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(bill.categoryConfidence).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: _getConfidenceColor(bill.categoryConfidence).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: _getConfidenceColor(bill.categoryConfidence),
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          'Confidence: ${(bill.categoryConfidence * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getConfidenceColor(bill.categoryConfidence),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.s24),

              // Editable fields
              _buildSection('Merchant Name', [
                TextField(
                  controller: merchantController,
                  decoration: InputDecoration(
                    labelText: 'Store/Restaurant',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.s20),

              _buildSection('Amount', [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Total Amount',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.s20),

              _buildSection('Category', [
                CategoryPickerField(
                  value: category,
                  onChanged: (final v) => setState(() => category = v),
                  label: 'Category',
                ),
              ]),
              const SizedBox(height: AppSpacing.s20),

              _buildSection('Date', [
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate?.toString().split(' ')[0] ?? 'Select date',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.s20),

              // Items list (collapsible)
              if (bill.items.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    'Items (${bill.items.length})',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bill.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
                      itemBuilder: (final _, final index) {
                        final item = bill.items[index];
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (item.price != null)
                                Text(
                                  formatAmount(item.price!, currency),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.s32),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _confirmTransaction,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm & Add to Wallet'),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(scanProvider.notifier).reset();
                    context.pop();
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          )),
        ),
      ),
    );
  }

  Widget _buildSection(final String title, final List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        ...children,
      ],
    );
  }

  Color _getConfidenceColor(final double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  /// Resolves the picked category display name to a stable category id,
  /// creating a new category if the user picked a label that doesn't exist
  /// yet — mirrors `transaction_form_sheet.dart`'s `_resolveCategoryId` so
  /// scanned transactions land in the same real category system as manually
  /// entered ones.
  Future<String?> _resolveCategoryId({
    required final String userId,
    required final String? selectedCategory,
  }) async {
    if (selectedCategory == null || selectedCategory.trim().isEmpty) return null;
    final raw = selectedCategory.trim();
    if (raw.toLowerCase() == 'general') return null;

    var categories = ref
        .read(userCategoriesProvider)
        .maybeWhen(data: (final d) => d, orElse: () => const <CategoryModel>[]);

    if (categories.isEmpty) {
      categories = await ref.read(categoryRepositoryProvider).getAllForUser(userId);
    }

    for (final c in categories) {
      if (c.id == raw) return c.id;
    }
    for (final c in categories) {
      if (c.name.toLowerCase() == raw.toLowerCase()) return c.id;
    }

    final created = await ref.read(categoryRepositoryProvider).create(
      userId: userId,
      name: raw,
    );
    return created.id;
  }

  Future<void> _confirmTransaction() async {
    if (_isSubmitting) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      final user = ref.read(currentUserProvider);
      if (user == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      final categoryId = await _resolveCategoryId(userId: user.uid, selectedCategory: category);

      // Create transaction with scanned data
      final ingestService = ref.read(transactionIngestServiceProvider);
      await ingestService.addManual(
        userId: user.uid,
        title: merchantController.text.trim(),
        amount: amount,
        isIncome: false, // Receipts are typically expenses
        categoryId: categoryId,
        categoryName: category,
        date: selectedDate ?? DateTime.now(),
        notes: 'Scanned receipt',
      );

      if (mounted) {
        // Clear scan state
        ref.read(scanProvider.notifier).reset();
        final successColor = Theme.of(context).colorScheme.primary;
        await HapticFeedback.lightImpact();

        messenger.showSnackBar(
          SnackBar(
            content: const Text('Transaction added successfully'),
            backgroundColor: successColor,
          ),
        );

        // Navigate back to transactions
        if (mounted) context.go('/transactions');
      }
    } on BudgetMissingException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No budget found for "${e.categoryName}"'),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Create Budget',
            onPressed: () => GoRouter.of(context).go('/budgets'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(repoErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
