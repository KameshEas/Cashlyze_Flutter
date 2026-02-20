import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/services/biometric_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/drive_backup_service.dart';
import '../../l10n/app_localizations.dart';

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

    final t = AppLocalizations.of(context);
    final preferences = sectionCard(
      Icons.tune,
      t?.preferencesTitle ?? 'Preferences',
      [
        SwitchListTile.adaptive(
          title: Text(t?.alertsTitle ?? 'Alerts'),
          subtitle: Text(
            t?.alertsSubtitle ?? 'Notify when budgets approach thresholds',
          ),
          contentPadding: EdgeInsets.zero,
          value: alertsEnabled,
          onChanged: (v) async {
            await prefs.setAlertsEnabled(v);
            setState(() {});
          },
        ),
        FutureBuilder<bool>(
          future: ref.read(biometricServiceProvider).isAvailable(),
          builder: (ctx, snap) {
            final available = snap.data ?? false;
            if (!available) return const SizedBox.shrink();
            return SwitchListTile.adaptive(
              title: Text(
                t?.biometricRequireTitle ?? 'Require biometric to unlock',
              ),
              subtitle: Text(
                t?.biometricRequireSubtitle ?? 'Prompt biometric on app launch',
              ),
              contentPadding: EdgeInsets.zero,
              value: prefs.biometricEnabled,
              onChanged: (v) async {
                await prefs.setBiometricEnabled(v);
                setState(() {});
              },
            );
          },
        ),
        SwitchListTile.adaptive(
          title: Text(t?.developerOptionsTitle ?? 'Developer Options'),
          subtitle: Text(
            t?.developerOptionsSubtitle ??
                'Show advanced tools like backup/restore',
          ),
          contentPadding: EdgeInsets.zero,
          value: prefs.showDevelopmentSection,
          onChanged: (v) async {
            await prefs.setShowDevelopmentSection(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Budget alert threshold',
                value: '${(prefs.alertThreshold * 100).toStringAsFixed(0)}%',
                child: Slider(
                  value: (prefs.alertThreshold.clamp(0.5, 1.0)),
                  min: 0.5,
                  max: 1.0,
                  divisions: 10,
                  label:
                      '${(prefs.alertThreshold * 100).toStringAsFixed(0)}% threshold',
                  onChanged: (v) {
                    prefs.setAlertThreshold(v);
                    setState(() {});
                  },
                  onChangeEnd: (v) async {
                    await ref
                        .read(analyticsServiceProvider)
                        .logEvent(
                          'alert_threshold_change',
                          params: {'threshold_percent': (v * 100).round()},
                        );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${(prefs.alertThreshold * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: prefs.alertFrequency,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await prefs.setAlertFrequency(v);
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'Alert frequency',
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
      ],
    );
    Widget actionTile({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
      Color? color,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (color ?? theme.colorScheme.primary).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color ?? theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dataSection = sectionCard(
      Icons.layers_outlined,
      t?.dataPrivacyTitle ?? 'Data & Privacy',
      [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            actionTile(
              icon: Icons.category_outlined,
              title: t?.categoriesManageTitle ?? 'Categories',
              subtitle: t?.categoriesManageSubtitle ?? 'Manage categories',
              onTap: () => GoRouter.of(context).go('/categories'),
            ),
            actionTile(
              icon: Icons.school_outlined,
              title: t?.onboardingTitle ?? 'Onboarding',
              subtitle: t?.onboardingSubtitle ?? 'Revisit walkthrough',
              onTap: () => GoRouter.of(context).go('/onboarding_preview'),
            ),
            actionTile(
              icon: Icons.payments_outlined,
              title: t?.emiTrackerTitle ?? 'EMI Tracker',
              subtitle: 'Track installments',
              onTap: () => GoRouter.of(context).go('/emi'),
            ),
            actionTile(
              icon: Icons.add_card,
              title: t?.addEmiPlanTitle ?? 'Add EMI Plan',
              subtitle: t?.addEmiPlanSubtitle ?? 'Create plan',
              onTap: () => GoRouter.of(context).go('/emi/new'),
            ),
            actionTile(
              icon: Icons.backup_outlined,
              title: t?.backupToFileTitle ?? 'Backup to File',
              subtitle: t?.backupToFileSubtitle ?? 'Save JSON and share',
              onTap: () async => _backupTransactionsToFile(context, ref),
            ),
            actionTile(
              icon: Icons.cloud_upload_outlined,
              title: t?.backupToDriveTitle ?? 'Backup to Drive',
              subtitle: t?.backupToDriveSubtitle ?? 'Upload JSON to Drive',
              onTap: () async => _backupTransactionsToDrive(context, ref),
            ),
            actionTile(
              icon: Icons.restore_outlined,
              title: t?.restoreFromFileTitle ?? 'Restore from File',
              subtitle: t?.restoreFromFileSubtitle ?? 'Import JSON backup',
              onTap: () async => _restoreTransactionsFromFile(context, ref),
            ),
            actionTile(
              icon: Icons.cloud_download_outlined,
              title: t?.restoreFromDriveTitle ?? 'Restore from Drive',
              subtitle: t?.restoreFromDriveSubtitle ?? 'Download & import JSON',
              onTap: () async => _restoreTransactionsFromDrive(context, ref),
            ),
            actionTile(
              icon: Icons.download_outlined,
              title: t?.exportDataTitle ?? 'Export Data',
              subtitle: t?.exportDataSubtitle ?? 'Copy JSON to clipboard',
              onTap: () async => _showExportDataDialog(context, ref),
            ),
            actionTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              onTap: () async {
                await ref.read(analyticsServiceProvider).logEvent('privacy_policy_viewed');
                if (context.mounted) {
                  _showPrivacyPolicyDialog(context);
                }
              },
            ),
          ],
        ),
      ],
    );
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

    final developmentSection =
        sectionCard(Icons.code, t?.developerOptionsTitle ?? 'Development', [
          ListTile(
            leading: const Icon(Icons.clear_all, color: Colors.orange),
            title: Text(t?.clearAllDataTitle ?? 'Clear All Data'),
            subtitle: Text(
              t?.clearAllDataSubtitle ??
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
                        if (prefs.showDevelopmentSection) developmentSection,
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
                if (prefs.showDevelopmentSection) developmentSection,
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

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Cashlyze is a personal finance management app that stores all your financial data locally on your device and/or in your personal cloud storage (Google Drive). We do not have access to or control over your financial data.\n\n'
            'For complete privacy policy details, please visit:\n\n'
            'https://cashlyze.app/privacy_policy.html\n\n'
            'Key points:\n'
            '• Your data is stored locally on your device using encrypted storage\n'
            '• Cloud backups (Google Drive) are only accessible by you\n'
            '• We do not sell or rent your personal information\n'
            '• You can export or delete your data at any time',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
