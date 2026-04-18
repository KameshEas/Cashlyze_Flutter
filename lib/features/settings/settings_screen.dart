import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/emi_repository.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import '../../core/services/drive_backup_service.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_router.dart';
import 'settings_providers.dart';
import 'widgets/extracted_dialogs.dart';
import 'widgets/enhanced_progress_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ── Extracted from build() closure — was recreated on every setState call.
  // Now defined once as a class method: stable across rebuilds.
  Widget sectionCard(IconData icon, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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

  /// Full-width action tile for the Data section.
  /// Extracted from build() closure so it is stable across redraws and
  /// no longer has a hard-coded width:180 that clips on narrow screens.
  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    bool alertsEnabled = prefs.alertsEnabled;
    final currency = ref.watch(currencyProvider);
    String dateFormat = prefs.dateFormat;

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
        // Show the alert threshold slider only when Alerts are enabled.
        if (prefs.alertsEnabled) ...[
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget alert threshold',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(prefs.alertThreshold * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
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
                    await ref.read(analyticsServiceProvider).logEvent(
                          'alert_threshold_change',
                          params: {'threshold_percent': (v * 100).round()},
                        );
                  },
                ),
              ),
            ],
          ),
        ],
        // Use cached biometric provider instead of FutureBuilder
        ref.watch(biometricAvailableProvider).when(
          data: (available) {
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
          loading: () => SwitchListTile.adaptive(
            title: Text(t?.biometricRequireTitle ?? 'Require biometric to unlock'),
            value: false,
            onChanged: null,
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // Developer Options removed from Settings.
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
    final dataSection = sectionCard(
      Icons.layers_outlined,
      t?.dataPrivacyTitle ?? 'Data & Privacy',
      [
        // Export / local Backup removed — use Backup to Drive / Restore from Drive instead.
        const SizedBox(height: 8),
        // Navigation + action tiles — changed from Wrap(width:180) to full-width
        // Column so tiles never clip on narrow phones.
        // Categories and Onboarding removed from Settings per request.
        _actionTile(
          icon: Icons.payments_outlined,
          title: t?.emiTrackerTitle ?? 'EMI Tracker',
          subtitle: 'Track installments',
          onTap: () => GoRouter.of(context).go('/emi'),
        ),
        const Divider(height: 1, indent: 52),
        _actionTile(
          icon: Icons.add_card,
          title: t?.addEmiPlanTitle ?? 'Add EMI Plan',
          subtitle: t?.addEmiPlanSubtitle ?? 'Create plan',
          onTap: () => GoRouter.of(context).go('/emi/new'),
        ),
        const Divider(height: 1, indent: 52),
        _actionTile(
          icon: Icons.cloud_upload_outlined,
          title: t?.backupToDriveTitle ?? 'Backup to Drive',
          subtitle: t?.backupToDriveSubtitle ?? 'Upload JSON to Drive',
          onTap: () async => _backupTransactionsToDrive(context, ref),
        ),
        const Divider(height: 1, indent: 52),
        _actionTile(
          icon: Icons.cloud_download_outlined,
          title: t?.restoreFromDriveTitle ?? 'Restore from Drive',
          subtitle: t?.restoreFromDriveSubtitle ?? 'Download & import JSON',
          onTap: () async => _restoreTransactionsFromDrive(context, ref),
        ),
        const Divider(height: 1, indent: 52),
        // Connect Mock Bank removed from Settings.
        const Divider(height: 1, indent: 52),
        _actionTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'View our privacy policy',
          onTap: () async {
            await ref
                .read(analyticsServiceProvider)
                .logEvent('privacy_policy_viewed');
            if (context.mounted) _showPrivacyPolicyDialog(context);
          },
        ),
      ],
    );
    // Account section — ListTile leading icons now use the same 36×36 rounded
    // pill container as _actionTile for visual consistency.
    final accountSection = sectionCard(
      Icons.lock_outline,
      'Account & Security',
      [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_reset,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_forever, size: 18, color: Colors.red),
          ),
          title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
          subtitle: const Text('Delete all data & account'),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => DeleteAccountDialog(
                userEmail: ref.read(currentUserProvider)?.email,
                onExportPressed: () async {
                  Navigator.pop(ctx);
                  await _showExportDataDialog(context, ref);
                },
                onConfirm: (_) {},
              ),
            );
            if (confirm == true) {
              try {
                // First delete all user data
                final user = ref.read(currentUserProvider);
                if (user != null) {
                  await _clearAllUserData(ref, user.uid);
                }
                // Then delete the account
                await ref.read(authServiceProvider).deleteAccount();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Account and all data deleted')),
                );
                router.go('/login');
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            }
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.logout,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
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
              // Invalidate auth-related providers so UI refreshes immediately
              ref.invalidate(authStateChangesProvider);
              ref.invalidate(currentUserProvider);
              ref.invalidate(userTransactionsProvider);
              ref.invalidate(transactionRepositoryProvider);

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              // Use the app router provider to ensure root navigation is used
              try {
                ref.read(appRouterProvider).go('/login');
              } catch (_) {
                // Fallback to local router if provider router is unavailable
                router.go('/login');
              }
            }
          },
        ),
      ],
    );

    // Developer tools removed from Settings UI.
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
                        const SizedBox(height: 20),
                        dataSection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        accountSection,
                        const SizedBox(height: 20),
                        // Developer tools removed.
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
                const SizedBox(height: 20),
                dataSection,
                const SizedBox(height: 20),
                accountSection,
                const SizedBox(height: 20),
                // Developer tools removed.
              ],
            ),
          );
        },
      ),
    );
  }

  

  Future<void> _backupTransactionsToDrive(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final progressController = StreamController<({String phase, double progress, String? errorMessage})>();

    // Show enhanced progress dialog
    EnhancedProgressDialog.show(
      context: context,
      title: 'Backup to Drive',
      subtitle: 'Uploading transactions...',
      type: ProgressDialogType.backup,
      progressStream: progressController.stream,
      onCancel: () {
        progressController.close();
      },
      canCancel: true,
    );

    try {
      // Phase 1: Fetch transactions
      progressController.add((
        phase: 'Fetching transactions...',
        progress: 0.2,
        errorMessage: null,
      ));

      final transactions =
          await ref.read(transactionRepositoryProvider).getAllForUser(user.uid);

      // Phase 2: Prepare data
      progressController.add((
        phase: 'Preparing backup file...',
        progress: 0.5,
        errorMessage: null,
      ));

      final data = {
        'version': 1,
        'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
        'transactions': transactions
            .map((e) => {
                  'title': e.title,
                  'amount': e.amount,
                  'categoryId': e.categoryId,
                  'date_ms': e.date.millisecondsSinceEpoch,
                  'notes': e.notes,
                })
            .toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      // Phase 3: Upload to Drive
      progressController.add((
        phase: 'Uploading to Google Drive...',
        progress: 0.7,
        errorMessage: null,
      ));

      final filename = 'cashlyze_transactions_${user.uid}.json';
      final fileId = await ref
          .read(driveBackupServiceProvider)
          .uploadJson(filename: filename, json: jsonStr);

      // Phase 4: Complete
      progressController.add((
        phase: 'Backup completed successfully',
        progress: 1.0,
        errorMessage: null,
      ));

      await ref.read(analyticsServiceProvider).logEvent('backup_drive',
          params: {'items': transactions.length, 'file_id': fileId});

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Uploaded to Google Drive'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Drive upload failed';
      if (e is StateError &&
          e.toString().contains('Google Sign-In failed')) {
        errorMsg = 'Google sign-in failed. Please sign in to continue.';
      } else {
        errorMsg = 'Upload failed: $e';
      }

      progressController.add((
        phase: 'Backup failed',
        progress: 1.0,
        errorMessage: errorMsg,
      ));

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      progressController.close();
    }
  }

  Future<void> _restoreTransactionsFromDrive(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final progressController = StreamController<({String phase, double progress, String? errorMessage})>();

    // Show enhanced progress dialog
    EnhancedProgressDialog.show(
      context: context,
      title: 'Restore from Drive',
      subtitle: 'Downloading transactions...',
      type: ProgressDialogType.restore,
      progressStream: progressController.stream,
      onCancel: () {
        progressController.close();
      },
      canCancel: true,
    );

    try {
      // Phase 1: Download from Drive
      progressController.add((
        phase: 'Downloading from Google Drive...',
        progress: 0.2,
        errorMessage: null,
      ));

      final filename = 'cashlyze_transactions_${user.uid}.json';
      final jsonStr =
          await ref.read(driveBackupServiceProvider).downloadJson(filename: filename);

      if (jsonStr == null) {
        progressController.add((
          phase: 'No backup found',
          progress: 1.0,
          errorMessage: 'No backup found in Drive',
        ));
        if (context.mounted) {
          messenger.showSnackBar(
              const SnackBar(content: Text('No backup found in Drive')));
        }
        return;
      }

      // Phase 2: Parse backup file
      progressController.add((
        phase: 'Parsing backup file...',
        progress: 0.4,
        errorMessage: null,
      ));

      final Map<String, dynamic> map = jsonDecode(jsonStr);
      final List txs = (map['transactions'] as List?) ?? const [];

      // Phase 3: Importing transactions
      progressController.add((
        phase: 'Importing transactions (0/${txs.length})...',
        progress: 0.5,
        errorMessage: null,
      ));

      int count = 0;
      final total = txs.length;

      for (final t in txs) {
        if (t is Map) {
          await ref.read(transactionRepositoryProvider).create(
                userId: user.uid,
                title: (t['title'] as String?) ?? 'Imported',
                amount: ((t['amount'] as num?) ?? 0).toDouble(),
                categoryId: t['categoryId'] as String?,
                date: DateTime.fromMillisecondsSinceEpoch(
                    (((t['date_ms'] as num?) ?? DateTime.now().millisecondsSinceEpoch)
                        .toInt())),
                notes: t['notes'] as String?,
              );
          count++;

          // Update progress
          final progress = 0.5 + (count / total) * 0.4;
          progressController.add((
            phase: 'Importing transactions ($count/$total)...',
            progress: progress,
            errorMessage: null,
          ));
        }
      }

      // Phase 4: Complete
      progressController.add((
        phase: 'Restore completed successfully',
        progress: 1.0,
        errorMessage: null,
      ));

      await ref.read(analyticsServiceProvider).logEvent('restore_drive',
          params: {'items': count});
      await ref.read(analyticsServiceProvider).logEvent('transaction_imported',
          params: {
            'import_method': 'drive',
            'provider': null,
            'count': count,
            'import_duration_ms': 0,
            'success': true,
          });

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Restored $count transactions from Drive'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Drive restore failed';
      if (e is StateError &&
          e.toString().contains('Google Sign-In failed')) {
        errorMsg = 'Google sign-in failed. Please sign in to continue.';
      } else {
        errorMsg = 'Restore failed: $e';
      }

      progressController.add((
        phase: 'Restore failed',
        progress: 1.0,
        errorMessage: errorMsg,
      ));

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      progressController.close();
    }
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy & Data Safety'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Data Collection Disclosure',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Cashlyze is a personal finance management app that stores all your financial data locally on your device and/or in your personal cloud storage (Google Drive). We do not have access to or control over your financial data.\n\n'
                'Data we may collect (with your consent):\n'
                '• Usage analytics to improve the app\n'
                '• Crash reports for bug fixes\n'
                '• No personal financial data is sent to our servers\n\n'
                'Your data is stored:\n'
                '• Locally on your device using encrypted storage\n'
                '• In your personal Google Drive (if you enable backup)\n\n'
                'You can control analytics sharing in Settings.',
              ),
              SizedBox(height: 16),
              Text(
                'Key Points',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Your financial data stays on your device\n'
                '• Cloud backups are only accessible by you\n'
                '• We do not sell or rent your personal information\n'
                '• You can export or delete your data at any time\n'
                '• Analytics can be disabled in Settings',
              ),
              SizedBox(height: 16),
              Text(
                'For complete details, visit:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('https://cashlyze.app/privacy_policy.html'),
            ],
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
