import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/account_repository.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/inline_field_error.dart';

final RegExp _upiPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}@[A-Za-z][A-Za-z0-9.-]{1,48}$');

/// Opens the add / edit account sheet. Resolves to the saved account, or null
/// when dismissed.
Future<AccountModel?> showAccountFormSheet(
  final BuildContext context, {
  final AccountModel? existing,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<AccountModel>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (final _) => AccountFormSheet(existing: existing),
  );
}

/// Create or edit a card / UPI / cash / bank account. Which detail fields show
/// follows the chosen type: cards ask for bank + last 4, UPI for the app and
/// UPI ID, cash for nothing extra.
class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.existing});

  final AccountModel? existing;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _institution =
      TextEditingController(text: widget.existing?.institution ?? '');
  late final TextEditingController _last4 = TextEditingController(text: widget.existing?.last4 ?? '');
  late final TextEditingController _upiId = TextEditingController(text: widget.existing?.upiId ?? '');

  String? _typeId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _last4.dispose();
    _upiId.dispose();
    super.dispose();
  }

  /// Credit Card, Debit Card, UPI and Cash first (what a spend is paid with),
  /// then the remaining bank-style types.
  List<AccountType> _sorted(final List<AccountType> types) {
    int rank(final AccountType t) => switch (t.kind) {
          AccountKind.creditCard => 0,
          AccountKind.debitCard => 1,
          AccountKind.upi => 2,
          AccountKind.cash => 3,
          AccountKind.bank => 4,
        };
    return [...types]..sort((final a, final b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.name.compareTo(b.name);
      });
  }

  Future<void> _save(final AccountKind kind) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    String? clean(final TextEditingController c, {required final bool shown}) {
      final v = c.text.trim();
      return (!shown || v.isEmpty) ? null : v;
    }

    final institution = clean(_institution, shown: kind != AccountKind.cash);
    final last4 = clean(_last4, shown: kind.isCard);
    final upiId = clean(_upiId, shown: kind == AccountKind.upi);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notifier = ref.read(userAccountsProvider.notifier);
      final saved = _isEdit
          ? await notifier.edit(
              widget.existing!.id,
              name: _name.text,
              institution: institution,
              last4: last4,
              upiId: upiId,
            )
          : await notifier.add(
              name: _name.text,
              typeId: _typeId!,
              institution: institution,
              last4: last4,
              upiId: upiId,
              currencyCode: ref.read(sharedPrefsServiceProvider).currency,
            );
      ref.invalidate(accountMonthSpendProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = repoErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final typesAsync = ref.watch(accountTypesProvider);
    final types = typesAsync.maybeWhen(data: _sorted, orElse: () => const <AccountType>[]);

    // Default the type once the list arrives (new accounts only).
    if (!_isEdit && _typeId == null && types.isNotEmpty) _typeId = types.first.id;

    final kind = _isEdit
        ? widget.existing!.kind
        : types.where((final t) => t.id == _typeId).firstOrNull?.kind ?? AccountKind.bank;

    final nameHint = switch (kind) {
      AccountKind.creditCard => 'e.g. HDFC Regalia',
      AccountKind.debitCard => 'e.g. SBI Debit',
      AccountKind.upi => 'e.g. PhonePe',
      AccountKind.cash => 'e.g. Wallet cash',
      AccountKind.bank => 'e.g. Salary account',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(_isEdit ? 'Edit account' : 'Add account', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              if (_isEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(kind.icon, size: 18),
                    label: Text(widget.existing!.typeName),
                  ),
                )
              else if (typesAsync.hasError)
                Text("Couldn't load account types.", style: TextStyle(color: theme.colorScheme.error))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in types)
                      ChoiceChip(
                        avatar: Icon(t.kind.icon, size: 18),
                        label: Text(t.name),
                        selected: _typeId == t.id,
                        onSelected: (_) => setState(() => _typeId = t.id),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Name', hintText: nameHint, filled: true),
                validator: (final v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              if (kind != AccountKind.cash) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _institution,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: kind == AccountKind.upi ? 'UPI app / bank (optional)' : 'Bank / issuer (optional)',
                    hintText: kind == AccountKind.upi ? 'e.g. PhonePe, GPay' : 'e.g. HDFC',
                    filled: true,
                  ),
                ),
              ],
              if (kind.isCard) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _last4,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  decoration: const InputDecoration(
                    labelText: 'Last 4 digits (optional)',
                    hintText: '4821',
                    filled: true,
                  ),
                  validator: (final v) {
                    final t = v?.trim() ?? '';
                    return (t.isEmpty || t.length == 4) ? null : 'Enter exactly 4 digits';
                  },
                ),
              ],
              if (kind == AccountKind.upi) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _upiId,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID (optional)',
                    hintText: 'name@bank',
                    filled: true,
                  ),
                  validator: (final v) {
                    final t = v?.trim() ?? '';
                    return (t.isEmpty || _upiPattern.hasMatch(t)) ? null : 'Enter a UPI ID like name@bank';
                  },
                ),
              ],
              InlineFieldError(message: _error),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_saving || (!_isEdit && _typeId == null)) ? null : () => _save(kind),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Add account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
