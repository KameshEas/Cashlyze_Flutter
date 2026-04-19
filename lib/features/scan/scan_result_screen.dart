import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/scanned_bill.dart';
import '../../core/providers/scan_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/ui/constants.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  late TextEditingController merchantController;
  late TextEditingController amountController;
  late TextEditingController categoryController;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    final bill = ref.read(scanProvider).result;
    
    merchantController = TextEditingController(text: bill?.merchantName ?? '');
    amountController = TextEditingController(text: bill?.amount.toStringAsFixed(2) ?? '');
    categoryController = TextEditingController(text: bill?.suggestedCategory ?? '');
    selectedDate = bill?.date;
  }

  @override
  void dispose() {
    merchantController.dispose();
    amountController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final bill = scanState.result;

    if (bill == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Result')),
        body: const Center(child: Text('No scan data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
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
                TextField(
                  controller: categoryController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Suggested Category',
                    filled: true,
                    suffixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onTap: () => _showCategoryPicker(),
                ),
              ]),
              const SizedBox(height: AppSpacing.s20),

              _buildSection('Date', [
                InkWell(
                  onTap: () => _selectDate(),
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
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                      itemBuilder: (_, index) {
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
                                  '₹${item.price?.toStringAsFixed(2) ?? '0.00'}',
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
                  onPressed: () => _confirmTransaction(),
                  child: const Text('Confirm & Add to Wallet'),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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

  Color _getConfidenceColor(double confidence) {
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

  void _showCategoryPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              'Food',
              'Transport',
              'Entertainment',
              'Health',
              'Utilities',
              'Shopping',
              'Other',
            ]
                .map(
                  (cat) => ListTile(
                    title: Text(cat),
                    onTap: () {
                      categoryController.text = cat;
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTransaction() async {
    try {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      final user = ref.read(currentUserProvider);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
        return;
      }

      // Create transaction with scanned data
      final ingestService = ref.read(transactionIngestServiceProvider);
      await ingestService.addManual(
        userId: user.uid,
        title: merchantController.text.trim(),
        amount: amount,
        isIncome: false, // Receipts are typically expenses
        categoryId: categoryController.text.trim(),
        date: selectedDate ?? DateTime.now(),
        notes: 'Scanned receipt',
      );

      if (mounted) {
        // Clear scan state
        ref.read(scanProvider.notifier).reset();

        // Show success and navigate back to transactions
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to transactions
        context.go('/transactions');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
