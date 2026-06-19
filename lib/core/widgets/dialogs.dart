import 'package:flutter/material.dart';

Future<bool?> showConfirmDialog(final BuildContext context, {
  required final String title,
  required final String content,
  final String confirmLabel = 'Confirm',
  final String cancelLabel = 'Cancel',
}) {
  return showDialog<bool>(
    context: context,
    builder: (final ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
}

Future<String?> showInputDialog(final BuildContext context, {
  required final String title,
  required final String label,
  final bool obscure = false,
  final String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  try {
    final res = await showDialog<String?>(
      context: context,
      builder: (final ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    return res;
  } finally {
    controller.dispose();
  }
}
