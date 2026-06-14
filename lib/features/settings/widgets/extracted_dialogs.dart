import 'package:flutter/material.dart';

/// A reusable delete account confirmation dialog.
class DeleteAccountDialog extends StatefulWidget {
  final String? userEmail;
  final Future<void> Function()? onExportPressed;
  final Function(bool) onConfirm;

  const DeleteAccountDialog({
    super.key,
    this.userEmail,
    this.onExportPressed,
    required this.onConfirm,
  });

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();

  static Future<bool?> show(
    BuildContext context, {
    String? userEmail,
    Future<void> Function()? onExportPressed,
    required Function(bool) onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DeleteAccountDialog(
        userEmail: userEmail,
        onExportPressed: onExportPressed,
        onConfirm: onConfirm,
      ),
    ).then((result) {
      if (result == true) {
        onConfirm(true);
        return true;
      }
      return false;
    });
  }
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  String typed = '';
  bool exportAcknowledged = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final confirmed = exportAcknowledged && typed == 'DELETE';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Delete Account', style: TextStyle(color: Colors.red)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ This action is IRREVERSIBLE!\n\n'
              'Deleting your account will permanently remove:\n\n'
              '• Your account and login credentials\n'
              '• All transactions\n'
              '• All budgets\n'
              '• All categories\n'
              '• All EMI plans\n'
              '• All preferences\n\n'
              'Your cloud backups will become orphaned.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Export your data before deleting to keep a backup.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () async {
                      setState(() => _isExporting = true);
                      try {
                        await widget.onExportPressed?.call();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isExporting = false;
                            exportAcknowledged = true;
                          });
                        }
                      }
                    },
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isExporting ? 'Exporting...' : 'Export All Data First'),
            ),
            CheckboxListTile(
              value: exportAcknowledged,
              onChanged: (v) => setState(() => exportAcknowledged = v ?? false),
              title: const Text('I have exported my data'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => typed = v),
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
                filled: true,
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
          onPressed: confirmed ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete Everything'),
        ),
      ],
    );
  }
}

/// A reusable clear all data confirmation dialog.
class ClearDataDialog extends StatefulWidget {
  final Function(bool) onConfirm;

  const ClearDataDialog({
    super.key,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Function(bool) onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ClearDataDialog(onConfirm: onConfirm),
    ).then((result) {
      if (result == true) {
        onConfirm(true);
        return true;
      }
      return false;
    });
  }

  @override
  State<ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<ClearDataDialog> {
  String typed = '';
  bool acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final confirmed = acknowledged && typed == 'DELETE';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Clear All Data', style: TextStyle(color: Colors.red)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ This action is IRREVERSIBLE!\n\n'
              'Clearing all local data will permanently remove:\n\n'
              '• All transactions\n'
              '• All budgets\n'
              '• All categories\n'
              '• All EMI plans\n'
              '• All preferences\n\n'
              'Cloud backups (if any) will remain untouched.',
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: acknowledged,
              onChanged: (v) => setState(() => acknowledged = v ?? false),
              title: const Text('I understand the consequences'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => typed = v),
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
                filled: true,
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
          onPressed: confirmed ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Clear All Data'),
        ),
      ],
    );
  }
}
