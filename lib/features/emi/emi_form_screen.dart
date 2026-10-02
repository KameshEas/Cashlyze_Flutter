import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/emi.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/emi_calculator.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import 'widgets/emi_form_widgets.dart';

class EMIFormScreen extends ConsumerStatefulWidget {
  const EMIFormScreen({super.key, this.initialPlan});
  final EMIPlan? initialPlan;

  @override
  ConsumerState<EMIFormScreen> createState() => _EMIFormScreenState();
}

class _EMIFormScreenState extends ConsumerState<EMIFormScreen> {
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _rateFocusNode = FocusNode();
  final _tenureFocusNode = FocusNode();
  DateTime _startDate = DateTime.now();
  PaymentFrequency _frequency = PaymentFrequency.monthly;
  bool _isZeroCostEMI = false;
  bool _isSaving = false;

  // Inline validation messages, cleared as the user edits (see InlineFieldError).
  String? _amountError;
  String? _rateError;
  String? _tenureError;

  /// Rate to restore when Zero Cost EMI is switched back off.
  String _savedRate = '';

  @override
  void initState() {
    super.initState();
    final p = widget.initialPlan;
    if (p != null) {
      _amountController.text = AmountGroupingFormatter.format(
        p.loanAmount,
        locale: _groupingLocale(),
      );
      _rateController.text = p.annualInterestRate.toString();
      _tenureController.text = p.tenureMonths.toString();
      _startDate = p.startDate;
      _frequency = p.frequency;
      _isZeroCostEMI = p.annualInterestRate == 0.0;
    }
    // The live preview recomputes as any term changes.
    for (final c in [_amountController, _rateController, _tenureController]) {
      c.addListener(_refresh);
    }
  }

  /// Digit grouping follows the currency: lakh/crore for INR, thousands otherwise.
  String _groupingLocale() =>
      ref.read(sharedPrefsServiceProvider).currency == 'INR'
      ? 'en_IN'
      : 'en_US';

  double? get _amountValue =>
      AmountGroupingFormatter.parse(_amountController.text);

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _amountFocusNode.dispose();
    _rateFocusNode.dispose();
    _tenureFocusNode.dispose();
    super.dispose();
  }

  /// Validates every field, shows all problems inline and focuses the first
  /// invalid one (top to bottom). Returns true when the form is valid.
  bool _validate() {
    final amount = _amountValue;
    final rate = double.tryParse(_rateController.text);
    final tenure = int.tryParse(_tenureController.text);
    final amountBad = amount == null || amount <= 0;
    final rateBad = !_isZeroCostEMI && (rate == null || rate < 0);
    final tenureBad = tenure == null || tenure <= 0;
    setState(() {
      _amountError = amountBad ? 'Enter a valid amount' : null;
      _rateError = rateBad ? 'Enter a valid rate' : null;
      _tenureError = tenureBad ? 'Enter the tenure in months' : null;
    });
    if (amountBad) {
      _amountFocusNode.requestFocus();
    } else if (rateBad) {
      _rateFocusNode.requestFocus();
    } else if (tenureBad) {
      _tenureFocusNode.requestFocus();
    }
    return !(amountBad || rateBad || tenureBad);
  }

  void _setZeroCost(final bool value) {
    HapticFeedback.selectionClick();
    setState(() {
      _isZeroCostEMI = value;
      _rateError = null;
      if (value) {
        _savedRate = _rateController.text == '0' ? '' : _rateController.text;
        _rateController.text = '0';
      } else {
        _rateController.text = _savedRate;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// Null until amount, rate and tenure are all usable, so the preview only
  /// appears when it can be trusted. Tenure is capped so a stray extra digit
  /// can't make a weekly schedule enormous on every keystroke.
  EmiPreviewData? _preview() {
    final amount = _amountValue;
    final tenure = int.tryParse(_tenureController.text);
    final rate = _isZeroCostEMI ? 0.0 : double.tryParse(_rateController.text);
    if (amount == null ||
        amount <= 0 ||
        tenure == null ||
        tenure <= 0 ||
        tenure > 600) {
      return null;
    }
    if (rate == null || rate < 0 || rate > 100) {
      return null;
    }
    final result = EMICalculator.compute(
      planId: 'preview',
      loanAmount: amount,
      annualRate: rate,
      tenureMonths: tenure,
      startDate: _startDate,
      frequency: _frequency,
    );
    if (result.schedule.isEmpty) return null;
    return EmiPreviewData(
      installment: result.installment,
      totalInterest: result.totalInterest,
      totalPayable: amount + result.totalInterest,
      payments: result.schedule.length,
      lastDue: result.schedule.last.dueDate,
    );
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final interestRate = _isZeroCostEMI
        ? 0.0
        : double.parse(_rateController.text);

    final plan = EMIPlan(
      id: widget.initialPlan?.id ?? 'new',
      userId: user.uid,
      loanAmount: _amountValue!,
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
              _isZeroCostEMI
                  ? 'Zero cost EMI plan created'
                  : 'EMI plan created',
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
              _isZeroCostEMI
                  ? 'Zero cost EMI plan updated'
                  : 'EMI plan updated',
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
    final theme = Theme.of(context);
    final isEditing = widget.initialPlan != null;
    final prefs = ref.read(sharedPrefsServiceProvider);
    final preview = _preview();
    final periodLabel = switch (_frequency) {
      PaymentFrequency.weekly => 'week',
      PaymentFrequency.monthly => 'month',
      PaymentFrequency.quarterly => 'quarter',
    };

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit EMI Plan' : 'New EMI Plan')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.s8,
                AppSpacing.pagePadding,
                AppSpacing.s24,
              ),
              child: MotionFadeIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EmiAmountField(
                      label: 'Loan amount',
                      helper: 'The principal you are borrowing',
                      symbol: currencySymbol(prefs.currency),
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      groupingLocale: _groupingLocale(),
                      error: _amountError,
                      onChanged: (final _) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(
                        _isZeroCostEMI ? _tenureFocusNode : _rateFocusNode,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    const EmiSectionLabel('Loan terms'),
                    EmiGroup(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                          ),
                          title: Text(
                            'Zero-cost EMI',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Interest-free plan',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.64,
                              ),
                            ),
                          ),
                          value: _isZeroCostEMI,
                          onChanged: _setZeroCost,
                        ),
                        EmiReveal(
                          visible: !_isZeroCostEMI,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const EmiDivider(),
                              EmiFieldRow(
                                label: 'Interest rate',
                                suffix: '% p.a.',
                                controller: _rateController,
                                focusNode: _rateFocusNode,
                                error: _rateError,
                                onChanged: (final _) {
                                  if (_rateError != null) {
                                    setState(() => _rateError = null);
                                  }
                                },
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                onSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_tenureFocusNode),
                              ),
                            ],
                          ),
                        ),
                        const EmiDivider(),
                        EmiFieldRow(
                          label: 'Tenure',
                          suffix: 'months',
                          controller: _tenureController,
                          focusNode: _tenureFocusNode,
                          error: _tenureError,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (final _) {
                            if (_tenureError != null) {
                              setState(() => _tenureError = null);
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    const EmiSectionLabel('Schedule'),
                    EmiGroup(
                      children: [
                        EmiValueRow(
                          label: 'Start date',
                          value: formatDate(
                            _startDate.toLocal(),
                            prefs.dateFormat,
                          ),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickDate,
                        ),
                        const EmiDivider(),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment frequency',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.86,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              EmiSegmented<PaymentFrequency>(
                                value: _frequency,
                                onChanged: (final v) =>
                                    setState(() => _frequency = v),
                                options: const [
                                  (PaymentFrequency.weekly, 'Weekly'),
                                  (PaymentFrequency.monthly, 'Monthly'),
                                  (PaymentFrequency.quarterly, 'Quarterly'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    EmiReveal(
                      visible: preview != null,
                      child: preview == null
                          ? const SizedBox.shrink()
                          : EmiPreviewCard(
                              data: preview,
                              currency: prefs.currency,
                              dateFormat: prefs.dateFormat,
                              periodLabel: periodLabel,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _SubmitBar(
            summary: preview == null
                ? null
                : EmiSummaryLine(
                    data: preview,
                    currency: prefs.currency,
                    periodLabel: periodLabel,
                  ),
            label: isEditing ? 'Update plan' : 'Create plan',
            saving: _isSaving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Pinned primary action. Sits above the keyboard (the Scaffold resizes the
/// body), shows press feedback, and keeps its brand colour while saving
/// instead of greying out.
class _SubmitBar extends StatefulWidget {
  const _SubmitBar({
    required this.summary,
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  /// Live one-line result, revealed above the button once the terms are valid.
  final Widget? summary;
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  @override
  State<_SubmitBar> createState() => _SubmitBarState();
}

class _SubmitBarState extends State<_SubmitBar> {
  bool _pressed = false;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final reduce = reduceMotionOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.s12,
            AppSpacing.pagePadding,
            AppSpacing.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmiReveal(
                visible: widget.summary != null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: widget.summary ?? const SizedBox.shrink(),
                ),
              ),
              Listener(
                onPointerDown: (final _) => setState(() => _pressed = true),
                onPointerUp: (final _) => setState(() => _pressed = false),
                onPointerCancel: (final _) => setState(() => _pressed = false),
                child: AnimatedScale(
                  scale: _pressed && !reduce ? 0.98 : 1,
                  duration: reduce ? Duration.zero : AppDuration.micro,
                  curve: AppCurve.tap,
                  child: FilledButton(
                    // Not disabled while saving: it keeps its colour and the
                    // handler ignores re-entry, so the state reads as "working".
                    onPressed: widget.saving ? () {} : widget.onPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: AnimatedSwitcher(
                      duration: reduce ? Duration.zero : AppDuration.fast,
                      child: widget.saving
                          ? const SizedBox(
                              key: ValueKey('saving'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.label, key: const ValueKey('label')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
