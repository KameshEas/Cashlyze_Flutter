import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/providers/shared_prefs_provider.dart';

/// Dialog for clearing all user data with export option
class ClearDataDialog extends ConsumerStatefulWidget {
  final VoidCallback onExportTap;
  final VoidCallback onConfirmClear;

  const ClearDataDialog({
    super.key,
    required this.onExportTap,
    required this.onConfirmClear,
  });

  @override
  ConsumerState<ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends ConsumerState<ClearDataDialog> {
  String typed = '';
  bool acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.read(sharedPrefsServiceProvider);
    final canClear = acknowledged && typed == 'DELETE';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clear All Data',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently delete all your data',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // What will be deleted
            Text(
              'Will be deleted:',
              style:
                  theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• All transactions'),
                  Text('• All budgets'),
                  Text('• All categories'),
                  Text('• All EMI plans'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Export button
            FilledButton.icon(
              onPressed: widget.onExportTap,
              icon: const Icon(Icons.download),
              label: const Text('Export Data First'),
            ),
            const SizedBox(height: 12),
            // Acknowledgment checkbox
            CheckboxListTile(
              value: acknowledged,
              onChanged: (v) => setState(() => acknowledged = v ?? false),
              title: const Text('I understand this cannot be undone'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            // Confirmation text field
            TextField(
              onChanged: (v) => setState(() => typed = v),
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                hintText: 'DELETE',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canClear ? widget.onConfirmClear : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            disabledBackgroundColor: Colors.orange.withValues(alpha: 0.3),
          ),
          child: const Text('Clear All Data'),
        ),
      ],
    );
  }
}
