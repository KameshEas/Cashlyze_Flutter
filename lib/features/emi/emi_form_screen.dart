import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/emi.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';

class EMIFormScreen extends ConsumerStatefulWidget {
  const EMIFormScreen({super.key, this.initialPlan});
  final EMIPlan? initialPlan;

  @override
  ConsumerState<EMIFormScreen> createState() => _EMIFormScreenState();
}

class _EMIFormScreenState extends ConsumerState<EMIFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _rateFocusNode = FocusNode();
  final _tenureFocusNode = FocusNode();
  DateTime _startDate = DateTime.now();
  PaymentFrequency _frequency = PaymentFrequency.monthly;
  bool _isZeroCostEMI = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPlan;
    if (p != null) {
      _amountController.text = p.loanAmount.toStringAsFixed(2);
      _rateController.text = p.annualInterestRate.toString();
      _tenureController.text = p.tenureMonths.toString();
      _startDate = p.startDate;
      _frequency = p.frequency;
      _isZeroCostEMI = p.annualInterestRate == 0.0;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _rateFocusNode.dispose();
    _tenureFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final interestRate = _isZeroCostEMI ? 0.0 : double.parse(_rateController.text);

    final plan = EMIPlan(
      id: widget.initialPlan?.id ?? 'new',
      userId: user.uid,
      loanAmount: double.parse(_amountController.text),
      annualInterestRate: interestRate,
      tenureMonths: int.parse(_tenureController.text),
      startDate: _startDate,
      frequency: _frequency,
      active: true,
    );
    final repo = ref.read(emiRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      if (widget.initialPlan == null) {
        await repo.createPlan(plan);
        try {
          ref.invalidate(userEMIPlansProvider);
        } catch (_) {}
        if (!mounted) return;
        await HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _isZeroCostEMI ? 'Zero cost EMI plan created' : 'EMI plan created',
            ),
          ),
        );
      } else {
        // Update existing plan (backend regenerates schedule automatically)
        await repo.updatePlan(plan);
        try {
          ref.invalidate(userEMIPlansProvider);
        } catch (_) {}
        if (!mounted) return;
        await HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _isZeroCostEMI ? 'Zero cost EMI plan updated' : 'EMI plan updated',
            ),
          ),
        );
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        GoRouter.of(context).go('/emi');
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(repoErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final isEditing = widget.initialPlan != null;
    final prefs = ref.read(sharedPrefsServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit EMI Plan' : 'New EMI Plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MotionFadeIn(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(
                    _isZeroCostEMI ? _tenureFocusNode : _rateFocusNode,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Loan amount',
                    filled: true,
                    helperText: 'Enter principal amount',
                  ),
                  validator: (final v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Zero Cost EMI'),
                  subtitle: const Text('No interest will be charged on this EMI'),
                  value: _isZeroCostEMI,
                  onChanged: (final value) {
                    setState(() {
                      _isZeroCostEMI = value ?? false;
                      if (_isZeroCostEMI) {
                        _rateController.text = '0';
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rateController,
                  focusNode: _rateFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_tenureFocusNode),
                  decoration: const InputDecoration(
                    labelText: 'Interest rate (%)',
                    filled: true,
                  ),
                  enabled: !_isZeroCostEMI,
                  validator: (final v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d < 0) return 'Enter valid rate';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tenureController,
                  focusNode: _tenureFocusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Tenure (months)',
                    filled: true,
                  ),
                  validator: (final v) {
                    final d = int.tryParse(v ?? '');
                    if (d == null || d <= 0) return 'Enter valid months';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _startDate = picked);
                        },
                        child: Text(
                          'Start: ${formatDate(_startDate.toLocal(), prefs.dateFormat)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<PaymentFrequency>(
                        initialValue: _frequency,
                        items: const [
                          DropdownMenuItem(
                            value: PaymentFrequency.weekly,
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: PaymentFrequency.monthly,
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: PaymentFrequency.quarterly,
                            child: Text('Quarterly'),
                          ),
                        ],
                        onChanged: (final v) => setState(
                          () => _frequency = v ?? PaymentFrequency.monthly,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Update Plan' : 'Create Plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
