import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/account_form_sheet.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';
import '../ui/constants.dart';

/// "Which card / UPI / cash was this paid with?" Mirrors [CategoryPickerField]:
/// a field that opens a bottom sheet. Lists the user's accounts with an
/// "Add account" row, and opens the add form directly when there are none, so
/// a first-time user is never stuck on a required field with nothing to pick.
class AccountPickerField extends ConsumerWidget {
  const AccountPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.label = 'Account',
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final String label;

  static const Object _addMarker = Object();

  Future<void> _addAccount(final BuildContext context) async {
    final created = await showAccountFormSheet(context);
    if (created != null) onChanged(created.id);
  }

  Future<void> _open(final BuildContext context, final List<AccountModel> accounts) async {
    if (accounts.isEmpty) return _addAccount(context);

    final theme = Theme.of(context);
    final picked = await showModalBottomSheet<Object>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (final sheetCtx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final a in accounts)
              ListTile(
                leading: Icon(a.kind.icon),
                title: Text(a.name, overflow: TextOverflow.ellipsis),
                subtitle: a.subtitle == null ? null : Text(a.subtitle!, overflow: TextOverflow.ellipsis),
                trailing: a.id == value ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
                onTap: () => Navigator.of(sheetCtx).pop(a.id),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Add account'),
              onTap: () => Navigator.of(sheetCtx).pop(_addMarker),
            ),
          ],
        ),
      ),
    );

    if (picked == _addMarker) {
      if (context.mounted) await _addAccount(context);
    } else if (picked is String) {
      onChanged(picked);
    }
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(userAccountsProvider);
    final accounts = accountsAsync.value ?? const <AccountModel>[];
    final selected = accounts.where((final a) => a.id == value).firstOrNull;

    final String text;
    if (selected != null) {
      text = selected.shortLabel;
    } else if (accountsAsync.isLoading) {
      text = 'Loading…';
    } else if (accountsAsync.hasError) {
      text = "Couldn't load accounts. Tap to retry";
    } else {
      text = accounts.isEmpty ? 'Add your first card or account' : 'Choose an account';
    }

    return Semantics(
      button: true,
      label: '$label: $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: accountsAsync.hasError
            ? () => ref.invalidate(userAccountsProvider)
            : accountsAsync.isLoading
                ? null
                : () => _open(context, accounts),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            filled: true,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: Row(
            children: [
              Icon(selected?.kind.icon ?? Icons.credit_card_outlined, size: 20, color: theme.iconTheme.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: selected == null
                      ? theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        )
                      : null,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
            ],
          ),
        ),
      ),
    );
  }
}
