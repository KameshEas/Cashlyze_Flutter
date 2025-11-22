import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/emi.dart';
import '../../core/services/emi_calculator.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/services/auth_service.dart';

class EMIFormScreen extends ConsumerStatefulWidget {
  const EMIFormScreen({super.key});

  @override
  ConsumerState<EMIFormScreen> createState() => _EMIFormScreenState();
}

class _EMIFormScreenState extends ConsumerState<EMIFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  DateTime _startDate = DateTime.now();
  PaymentFrequency _frequency = PaymentFrequency.monthly;

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New EMI Plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Loan amount', filled: true, helperText: 'Enter principal amount'),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Interest rate (%)', filled: true),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter valid rate';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tenureController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tenure (months)', filled: true),
                validator: (v) {
                  final d = int.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter valid months';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () async {final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setState(() => _startDate = picked);}, child: Text('Start: ${_startDate.toLocal()}'.split(' ').first))),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<PaymentFrequency>(value: _frequency, items: const [DropdownMenuItem(value: PaymentFrequency.weekly, child: Text('Weekly')), DropdownMenuItem(value: PaymentFrequency.monthly, child: Text('Monthly')), DropdownMenuItem(value: PaymentFrequency.quarterly, child: Text('Quarterly'))], onChanged: (v) => setState(() => _frequency = v ?? PaymentFrequency.monthly), decoration: const InputDecoration(labelText: 'Frequency', filled: true))),
              ]),
              const SizedBox(height: 24),
              FilledButton(onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final plan = EMIPlan(
                  id: 'new',
                  userId: user.uid,
                  loanAmount: double.parse(_amountController.text),
                  annualInterestRate: double.parse(_rateController.text),
                  tenureMonths: int.parse(_tenureController.text),
                  startDate: _startDate,
                  frequency: _frequency,
                  active: true,
                );
                final repo = ref.read(emiRepositoryProvider);
                final created = await repo.createPlan(plan);
                final calc = EMICalculator.compute(
                  planId: created.id,
                  loanAmount: plan.loanAmount,
                  annualRate: plan.annualInterestRate,
                  tenureMonths: plan.tenureMonths,
                  startDate: plan.startDate,
                  frequency: plan.frequency,
                );
                await repo.addSchedule(created.id, calc.schedule);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMI plan created')));
                Navigator.of(context).pop();
              }, child: const Text('Create Plan')),
            ],
          ),
        ),
      ),
    );
  }
}