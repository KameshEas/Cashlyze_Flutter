import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/goals_model.dart';
import '../../core/providers/goals_providers.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import 'widgets/goal_completion_celebration.dart';

class CreateEditGoalSheet extends ConsumerStatefulWidget {
  const CreateEditGoalSheet({
    this.goal,
    super.key,
  });

  final GoalsModel? goal;

  @override
  ConsumerState<CreateEditGoalSheet> createState() =>
      _CreateEditGoalSheetState();
}

class _CreateEditGoalSheetState extends ConsumerState<CreateEditGoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _currentAmountController;

  late DateTime? _selectedTargetDate;
  late String _selectedIcon;
  late String _selectedColor;
  late bool _isActive;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _nameController = TextEditingController(text: widget.goal!.name);
      _descriptionController =
          TextEditingController(text: widget.goal!.description ?? '');
      _targetAmountController =
          TextEditingController(text: widget.goal!.targetAmount.toString());
      _currentAmountController =
          TextEditingController(text: widget.goal!.currentAmount.toString());
      _selectedTargetDate = widget.goal!.targetDate;
      _selectedIcon = widget.goal!.icon ?? '🎯';
      _selectedColor = widget.goal!.color ?? '#2196F3';
      _isActive = widget.goal!.isActive;
    } else {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _targetAmountController = TextEditingController();
      _currentAmountController = TextEditingController(text: '0');
      _selectedTargetDate = null;
      _selectedIcon = '🎯';
      _selectedColor = '#2196F3';
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTargetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTargetDate = picked);
    }
  }

  void _selectIcon() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (final context) => _IconPickerDialog(
        selectedIcon: _selectedIcon,
        onSelected: (final icon) {
          setState(() => _selectedIcon = icon);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _selectColor() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (final context) => _ColorPickerDialog(
        selectedColor: _selectedColor,
        onSelected: (final color) {
          setState(() => _selectedColor = color);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_nameController.text.isEmpty ||
        _targetAmountController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields')),
      );
      return;
    }

    final targetAmount = double.tryParse(_targetAmountController.text);
    final currentAmount = _currentAmountController.text.isEmpty
        ? 0.0
        : double.tryParse(_currentAmountController.text);
    if (targetAmount == null || currentAmount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final goal = GoalsModel(
      id: widget.goal?.id ?? '',
      userId: widget.goal?.userId ?? '',
      name: _nameController.text,
      description: _descriptionController.text,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: _selectedTargetDate,
      icon: _selectedIcon,
      color: _selectedColor,
      isActive: _isActive,
      createdAt: widget.goal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final wasCompleted = widget.goal?.isCompleted ?? false;

    setState(() => _isSubmitting = true);
    try {
      if (widget.goal == null) {
        await ref.read(goalsServiceProvider).createGoal(goal);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        await HapticFeedback.lightImpact();
        messenger.showSnackBar(
          const SnackBar(content: Text('Goal created successfully')),
        );
      } else {
        await ref.read(goalsServiceProvider).updateGoal(goal.id, goal);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        await HapticFeedback.lightImpact();
        messenger.showSnackBar(
          const SnackBar(content: Text('Goal updated successfully')),
        );

        final justCompleted = !wasCompleted && goal.isCompleted;
        if (justCompleted) {
          final prefs = ref.read(sharedPrefsServiceProvider);
          if (!prefs.hasCelebratedGoal(goal.id)) {
            await prefs.markGoalCelebrated(goal.id);
            if (mounted) await GoalCompletionCelebration.show(context);
          }
        }
      }
      ref.invalidate(goalsListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(repoErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal == null ? 'Create Goal' : 'Edit Goal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                GestureDetector(
                  onTap: _selectIcon,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedIcon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Goal name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetAmountController,
                    decoration: InputDecoration(
                      labelText: 'Target Amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefix: Text('${currencySymbol(currency)} '),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _currentAmountController,
                    decoration: InputDecoration(
                      labelText: 'Current Amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefix: Text('${currencySymbol(currency)} '),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedTargetDate == null
                            ? 'Select target date'
                            : '${_selectedTargetDate!.year}-${_selectedTargetDate!.month.toString().padLeft(2, '0')}-${_selectedTargetDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Color:'),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _selectColor,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(_selectedColor),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Active'),
                const Spacer(),
                Switch(
                  value: _isActive,
                  onChanged: (final value) => setState(() => _isActive = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.goal == null ? 'Create Goal' : 'Update Goal',
                        style: theme.textTheme.titleMedium,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(final String colorHex) {
    try {
      return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

class _IconPickerDialog extends StatelessWidget {
  const _IconPickerDialog({
    required this.selectedIcon,
    required this.onSelected,
  });

  final String selectedIcon;
  final Function(String) onSelected;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final icons = ['🎯', '💰', '🏠', '🎓', '✈️', '🚗', '💍', '🏥'];

    return AlertDialog(
      title: const Text('Select Icon'),
      content: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        children: icons
            .map(
              (final icon) => GestureDetector(
                onTap: () => onSelected(icon),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedIcon == icon
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: selectedIcon == icon ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({
    required this.selectedColor,
    required this.onSelected,
  });

  final String selectedColor;
  final Function(String) onSelected;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      '#2196F3',
      '#4CAF50',
      '#FF9800',
      '#F44336',
      '#9C27B0',
      '#00BCD4',
      '#FFC107',
      '#E91E63',
    ];

    return AlertDialog(
      title: const Text('Select Color'),
      content: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        children: colors
            .map(
              (final color) => GestureDetector(
                onTap: () => onSelected(color),
                child: Container(
                  decoration: BoxDecoration(
                    color: _parseColor(color),
                    border: Border.all(
                      color: selectedColor == color
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                      width: selectedColor == color ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Color _parseColor(final String colorHex) {
    try {
      return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}
