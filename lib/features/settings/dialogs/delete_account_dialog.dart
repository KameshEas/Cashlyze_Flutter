import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog for deleting account with proper confirmation flow
class DeleteAccountDialog extends ConsumerStatefulWidget {
  final VoidCallback onExportTap;
  final VoidCallback onConfirmDelete;

  const DeleteAccountDialog({
    super.key,
    required this.onExportTap,
    required this.onConfirmDelete,
  });

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  String typed = '';
  bool exportAcknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDelete = exportAcknowledged && typed == 'DELETE';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            'Delete Account',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.red),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action is IRREVERSIBLE!',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // What will be deleted
            Text(
              'Deleting your account will permanently remove:',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Your account and login credentials'),
                  Text('• All transactions'),
                  Text('• All budgets'),
                  Text('• All categories'),
                  Text('• All EMI plans'),
                  Text('• All preferences'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Export prompt
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Export your data first to keep a backup',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onExportTap,
              icon: const Icon(Icons.download),
              label: const Text('Export All Data'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            // Confirmation checkbox
            CheckboxListTile(
              value: exportAcknowledged,
              onChanged: (v) => setState(() => exportAcknowledged = v ?? false),
              title: const Text('I have exported my data'),
              subtitle: const Text('Required to proceed'),
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
          onPressed: canDelete ? widget.onConfirmDelete : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
          ),
          child: const Text('Delete Everything'),
        ),
      ],
    );
  }
}
