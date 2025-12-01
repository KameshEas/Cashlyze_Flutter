import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/emi_repository.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/drive_backup_service.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    bool alertsEnabled = prefs.alertsEnabled;
    final currency = ref.watch(currencyProvider);
    String dateFormat = prefs.dateFormat;
    Widget sectionCard(IconData icon, String title, List<Widget> children) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    final preferences = sectionCard(Icons.tune, 'Preferences', [
      ListTile(
        title: const Text('Alerts'),
        subtitle: const Text('Notify when budgets approach thresholds'),
        contentPadding: EdgeInsets.zero,
        trailing: Switch(
          value: alertsEnabled,
          onChanged: (v) async {
            await prefs.setAlertsEnabled(v);
            setState(() {});
          },
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: currency,
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'INR', child: Text('INR')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await ref.read(currencyProvider.notifier).set(v);
              },
              decoration: const InputDecoration(
                labelText: 'Currency',
                filled: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: dateFormat,
              items: const [
                DropdownMenuItem(
                  value: 'yyyy-MM-dd',
                  child: Text('yyyy-MM-dd'),
                ),
                DropdownMenuItem(
                  value: 'dd/MM/yyyy',
                  child: Text('dd/MM/yyyy'),
                ),
                DropdownMenuItem(
                  value: 'MM/dd/yyyy',
                  child: Text('MM/dd/yyyy'),
                ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await prefs.setDateFormat(v);
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Date format',
                filled: true,
              ),
            ),
          ),
        ],
      ),
    ]);
    final dataSection =
        sectionCard(Icons.layers_outlined, 'Data & Personalization', [
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            subtitle: const Text('Create and edit your spending categories'),
            onTap: () => GoRouter.of(context).go('/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Revisit Onboarding'),
            subtitle: const Text('Refresh tips and app walkthrough'),
            onTap: () => GoRouter.of(context).go('/onboarding_preview'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('EMI Tracker'),
            subtitle: const Text('Track loans and installments'),
            onTap: () => GoRouter.of(context).go('/emi'),
          ),
          ListTile(
            leading: const Icon(Icons.add_card),
            title: const Text('Add EMI Plan'),
            subtitle: const Text('Create a new EMI plan'),
            onTap: () => GoRouter.of(context).go('/emi/new'),
          ),
        ]);
    final accountSection = sectionCard(
      Icons.lock_outline,
      'Account & Security',
      [
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Change Password'),
          onTap: () async {
            final controller = TextEditingController();
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Change Password'),
                content: TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Update'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await ref
                    .read(authServiceProvider)
                    .updatePassword(controller.text.trim());
                messenger.showSnackBar(
                  const SnackBar(content: Text('Password updated')),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            }
            controller.dispose();
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: const Text('Delete Account'),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Account'),
                content: const Text(
                  'This will permanently delete your account. Are you sure?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await ref.read(authServiceProvider).deleteAccount();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Account deleted')),
                );
                router.go('/login');
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text('Sign out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                );
              },
            );
            if (confirm == true) {
              await ref.read(authServiceProvider).signOut();
              await ref.read(analyticsServiceProvider).logEvent('sign_out');
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              router.go('/login');
            }
          },
        ),
      ],
    );

    final developmentSection = sectionCard(Icons.code, 'Development', [
      ListTile(
        leading: const Icon(Icons.backup_outlined, color: Colors.blue),
        title: const Text('Backup Transactions'),
        subtitle: const Text('Save a JSON file and share to Drive'),
        onTap: () async => _backupTransactionsToFile(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
        title: const Text('Back up to Google Drive'),
        subtitle: const Text('Upload transactions JSON to Drive'),
        onTap: () async => _backupTransactionsToDrive(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.restore_outlined, color: Colors.green),
        title: const Text('Restore Transactions'),
        subtitle: const Text('Import from a JSON file'),
        onTap: () async => _restoreTransactionsFromFile(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.cloud_download_outlined, color: Colors.green),
        title: const Text('Restore from Google Drive'),
        subtitle: const Text('Download and import transactions JSON'),
        onTap: () async => _restoreTransactionsFromDrive(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.upload_file, color: Colors.blue),
        title: const Text('Import from CSV'),
        subtitle: const Text('date,title,amount,category'),
        onTap: () async => _importTransactionsFromCSV(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.download_outlined, color: Colors.blue),
        title: const Text('Export Data'),
        subtitle: const Text('Copy JSON of your data to clipboard'),
        onTap: () async => _showExportDataDialog(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.clear_all, color: Colors.orange),
        title: const Text('Clear All Data'),
        subtitle: const Text(
          'Requires typing DELETE and export acknowledgment',
        ),
        onTap: () async => _showClearDataDialog(context, ref),
      ),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        preferences,
                        const SizedBox(height: 24),
                        dataSection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        accountSection,
                        const SizedBox(height: 24),
                        developmentSection,
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preferences,
                const SizedBox(height: 16),
                dataSection,
                const SizedBox(height: 16),
                accountSection,
                const SizedBox(height: 16),
                developmentSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _backupTransactionsToFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .getAllForUser(user.uid);
      final data = {
        'version': 1,
        'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
        'transactions': transactions
            .map(
              (e) => {
                'title': e.title,
                'amount': e.amount,
                'categoryId': e.categoryId,
                'date_ms': e.date.millisecondsSinceEpoch,
                'notes': e.notes,
              },
            )
            .toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final filename =
          'cashlyze_transactions_${DateTime.now().toIso8601String().split('T').first}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Cashlyze transactions backup');
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup file ready to share')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _backupTransactionsToDrive(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .getAllForUser(user.uid);
      final data = {
        'version': 1,
        'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
        'transactions': transactions
            .map(
              (e) => {
                'title': e.title,
                'amount': e.amount,
                'categoryId': e.categoryId,
                'date_ms': e.date.millisecondsSinceEpoch,
                'notes': e.notes,
              },
            )
            .toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final filename = 'cashlyze_transactions_${user.uid}.json';
      await ref
          .read(driveBackupServiceProvider)
          .uploadJson(filename: filename, json: jsonStr);
      await ref
          .read(analyticsServiceProvider)
          .logEvent('backup_drive', params: {'items': transactions.length});
      messenger.showSnackBar(
        const SnackBar(content: Text('Uploaded to Google Drive')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Drive upload failed: $e')),
      );
    }
  }

  Future<void> _restoreTransactionsFromDrive(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final filename = 'cashlyze_transactions_${user.uid}.json';
      final jsonStr = await ref
          .read(driveBackupServiceProvider)
          .downloadJson(filename: filename);
      if (jsonStr == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No backup found in Drive')),
        );
        return;
      }
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      final List txs = (map['transactions'] as List?) ?? const [];
      int count = 0;
      for (final t in txs) {
        if (t is Map) {
          await ref
              .read(transactionRepositoryProvider)
              .create(
                userId: user.uid,
                title: (t['title'] as String?) ?? 'Imported',
                amount: ((t['amount'] as num?) ?? 0).toDouble(),
                categoryId: t['categoryId'] as String?,
                date: DateTime.fromMillisecondsSinceEpoch(
                  ((t['date_ms'] as num?) ??
                          DateTime.now().millisecondsSinceEpoch)
                      .toInt(),
                ),
                notes: t['notes'] as String?,
              );
          count++;
        }
      }
      await ref
          .read(analyticsServiceProvider)
          .logEvent('restore_drive', params: {'items': count});
      messenger.showSnackBar(
        SnackBar(content: Text('Restored $count transactions from Drive')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Drive restore failed: $e')),
      );
    }
  }

  Future<void> _restoreTransactionsFromFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      final contents = await File(path).readAsString();
      final Map<String, dynamic> map = jsonDecode(contents);
      final List txs = (map['transactions'] as List?) ?? const [];
      int count = 0;
      for (final t in txs) {
        if (t is Map) {
          await ref
              .read(transactionRepositoryProvider)
              .create(
                userId: user.uid,
                title: (t['title'] as String?) ?? 'Imported',
                amount: ((t['amount'] as num?) ?? 0).toDouble(),
                categoryId: t['categoryId'] as String?,
                date: DateTime.fromMillisecondsSinceEpoch(
                  ((t['date_ms'] as num?) ??
                          DateTime.now().millisecondsSinceEpoch)
                      .toInt(),
                ),
                notes: t['notes'] as String?,
              );
          count++;
        }
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Restored $count transactions')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  Future<void> _showExportDataDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .getAllForUser(user.uid);
      final budgets = await ref
          .read(budgetRepositoryProvider)
          .streamForUser(user.uid)
          .first;
      final categories = await ref
          .read(categoryRepositoryProvider)
          .streamForUser(user.uid)
          .first;
      final emiPlans = await ref
          .read(emiRepositoryProvider)
          .getAllPlansForUser(user.uid);
      final data = {
        'transactions': transactions
            .map(
              (e) => {
                'id': e.id,
                'title': e.title,
                'amount': e.amount,
                'categoryId': e.categoryId,
                'date_ms': e.date.millisecondsSinceEpoch,
                'notes': e.notes,
              },
            )
            .toList(),
        'budgets': budgets
            .map(
              (b) => {
                'id': b.id,
                'name': b.name,
                'allocated': b.allocated,
                'period': b.period.toString(),
              },
            )
            .toList(),
        'categories': categories
            .map((c) => {'id': c.id, 'name': c.name})
            .toList(),
        'emiPlans': emiPlans
            .map(
              (p) => {
                'id': p.id,
                'loanAmount': p.loanAmount,
                'annualInterestRate': p.annualInterestRate,
                'tenureMonths': p.tenureMonths,
                'startDate_ms': p.startDate.millisecondsSinceEpoch,
                'frequency': p.frequency.toString(),
                'active': p.active,
              },
            )
            .toList(),
      };
      final jsonStr = jsonEncode(data);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      messenger.showSnackBar(
        const SnackBar(content: Text('Export copied to clipboard')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _showClearDataDialog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String typed = '';
        bool acknowledged = false;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Clear All Data'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete all your data including:\n\n'
                    '• All transactions\n'
                    '• All budgets\n'
                    '• All categories\n'
                    '• All EMI plans\n\n'
                    'This action cannot be undone.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async => _showExportDataDialog(context, ref),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Copy Export (JSON)'),
                  ),
                  CheckboxListTile(
                    value: acknowledged,
                    onChanged: (v) => setState(() => acknowledged = v ?? false),
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
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: (acknowledged && typed == 'DELETE')
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        messenger.showSnackBar(
          const SnackBar(content: Text('Clearing data...')),
        );
        await _clearAllUserData(ref, user.uid);
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to clear data: $e')),
        );
      }
    }
  }

  Future<void> _clearAllUserData(WidgetRef ref, String userId) async {
    // Clear transactions
    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .getAllForUser(userId);
      for (final transaction in transactions) {
        await ref
            .read(transactionRepositoryProvider)
            .deleteForUser(userId, transaction.id);
      }
    } catch (e) {
      // Continue with other data even if transactions fail
    }

    // Clear budgets
    try {
      final budgets = await ref
          .read(budgetRepositoryProvider)
          .streamForUser(userId)
          .first;
      for (final budget in budgets) {
        await ref.read(budgetRepositoryProvider).delete(userId, budget.id);
      }
    } catch (e) {
      // Continue with other data even if budgets fail
    }

    // Clear categories
    try {
      final categories = await ref
          .read(categoryRepositoryProvider)
          .streamForUser(userId)
          .first;
      for (final category in categories) {
        await ref.read(categoryRepositoryProvider).delete(userId, category.id);
      }
    } catch (e) {
      // Continue with other data even if categories fail
    }

    // Clear EMI plans and payments
    try {
      final emiPlans = await ref
          .read(emiRepositoryProvider)
          .getAllPlansForUser(userId);
      for (final plan in emiPlans) {
        await ref.read(emiRepositoryProvider).deletePlan(userId, plan.id);
      }
    } catch (e) {
      // Continue even if EMI data fails
    }
  }
}
