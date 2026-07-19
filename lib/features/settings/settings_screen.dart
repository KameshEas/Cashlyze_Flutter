import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/drive_backup_service.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/dialogs.dart';
import '../../features/auth/data/auth_remote_data_source.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_router.dart';
import 'biometric_lock_tile.dart';
import 'widgets/enhanced_progress_dialog.dart';
import 'widgets/extracted_dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Enhanced section card with better visual hierarchy, spacing, and icons
  Widget sectionCard(final IconData icon, final String title, final List<Widget> children, {final String? description}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          // Enhanced header with larger icon and better typography
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Enhanced preference row with icon, status indicator, and better styling
  Widget _preferenceRow({
    required final IconData icon,
    required final String title,
    final String? description,
    required final Widget trailing,
    final bool showDivider = false,
    final Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final bgColor = iconColor ?? theme.colorScheme.primary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: bgColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  /// Status badge widget for showing active/inactive states
  Widget _statusBadge(final bool isActive) {
    final theme = Theme.of(context);
    final color = isActive ? AppColors.success : theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final text = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showExportDataDialog(
    final BuildContext context,
    final WidgetRef ref,
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
              (final e) => {
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
              (final b) => {
                'id': b.id,
                'name': b.name,
                'allocated': b.allocated,
                'period': b.period.toString(),
              },
            )
            .toList(),
        'categories': categories
            .map((final c) => {'id': c.id, 'name': c.name})
            .toList(),
        'emiPlans': emiPlans
            .map(
              (final p) => {
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
      messenger.showSnackBar(SnackBar(content: Text(repoErrorMessage(e))));
    }
  }

  /// Enhanced action tile with better visual hierarchy and hover effects
  Widget _actionTile({
    required final IconData icon,
    required final String title,
    final String? subtitle,
    required final VoidCallback onTap,
    final Color? color,
    final bool isDangerous = false,
  }) {
    final theme = Theme.of(context);
    final iconColor = isDangerous ? theme.colorScheme.error : (color ?? theme.colorScheme.primary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDangerous ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final bool alertsEnabled = prefs.alertsEnabled;
    final currency = ref.watch(currencyProvider);
    final String dateFormat = prefs.dateFormat;

    final t = AppLocalizations.of(context);
    final preferences = sectionCard(
      Icons.tune,
      t?.preferencesTitle ?? 'Preferences',
      [
        // Alerts setting with icon and status
        _preferenceRow(
          icon: Icons.notifications_outlined,
          title: t?.alertsTitle ?? 'Alerts',
          description: t?.alertsSubtitle ?? 'Budget threshold notifications',
              trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusBadge(alertsEnabled),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: alertsEnabled,
                onChanged: (final v) async {
                  await prefs.setAlertsEnabled(v);
                  setState(() {});
                },
              ),
            ],
          ),
          showDivider: true,
        ),
        
        // Alert threshold slider (shown when enabled)
        if (prefs.alertsEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alert Threshold',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(prefs.alertThreshold * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Budget alert threshold',
                  value: '${(prefs.alertThreshold * 100).toStringAsFixed(0)}%',
                  child: Slider(
                    value: (prefs.alertThreshold.clamp(0.5, 1.0)),
                    min: 0.5,
                    divisions: 10,
                    label: '${(prefs.alertThreshold * 100).toStringAsFixed(0)}% threshold',
                    onChanged: (final v) {
                      prefs.setAlertThreshold(v);
                      setState(() {});
                    },
                    onChangeEnd: (final v) async {
                      await ref.read(analyticsServiceProvider).logEvent(
                        'alert_threshold_change',
                        params: {'threshold_percent': (v * 100).round()},
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ],
        
        // Currency setting
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.currency_exchange, size: 18, color: theme.colorScheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currency',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: DropdownButtonFormField<String>(
                  initialValue: currency,
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'INR', child: Text('INR')),
                  ],
                  onChanged: (final v) async {
                    if (v == null) return;
                    await ref.read(currencyProvider.notifier).set(v);
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 0,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        
        // Date format setting
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.secondary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Format',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: dateFormat,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'yyyy-MM-dd',
                      child: Text('yyyy-MM-dd', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'dd/MM/yyyy',
                      child: Text('dd/MM/yyyy', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'MM/dd/yyyy',
                      child: Text('MM/dd/yyyy', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (final v) async {
                    if (v == null) return;
                    await prefs.setDateFormat(v);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final aiAssistantSection = sectionCard(
      Icons.auto_awesome_outlined,
      'AI Assistant',
      [
        _actionTile(
          icon: Icons.chat_bubble_outline,
          title: 'Ask Cashlyze AI',
          subtitle: 'Ask about spending, budgets, and shared expenses',
          onTap: () => context.push('/ai-assistant'),
        ),
      ],
      description: 'Chat with an assistant that can see your finances',
    );
    final dataSection = sectionCard(
      Icons.cloud_outlined,
      t?.dataPrivacyTitle ?? 'Data & Privacy',
      [
        const SizedBox(height: 8),
        _actionTile(
          icon: Icons.payments_outlined,
          title: t?.emiTrackerTitle ?? 'EMI Tracker',
          subtitle: 'Track installments',
          onTap: () => context.push('/emi'),
        ),
        const Divider(height: 1, indent: 52),
        _actionTile(
          icon: Icons.add_card,
          title: t?.addEmiPlanTitle ?? 'Add EMI Plan',
          subtitle: t?.addEmiPlanSubtitle ?? 'Create plan',
          onTap: () => context.push('/emi/new'),
        ),
        const Divider(height: 1, indent: 52),
        _actionTile(
          icon: Icons.savings_outlined,
          title: 'Savings Goals',
          subtitle: 'Track your savings targets',
          onTap: () => context.push('/goals'),
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
        _actionTile(
          icon: Icons.delete_sweep_outlined,
          title: 'Clear All Data',
          subtitle: 'Erase transactions, budgets, categories & EMI plans',
          isDangerous: true,
          onTap: () async {
            final confirm = await ClearDataDialog.show(
              context,
              onConfirm: (_) {},
            );
            if (confirm == true) {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              final failures = await _clearAllUserData(ref, user.uid);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    failures.isEmpty
                        ? 'All data cleared'
                        : 'Data cleared, but some items failed (${failures.join(', ')}). Try again if needed.',
                  ),
                ),
              );
            }
          },
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
      Icons.security,
      'Account & Security',
      [
        // Change Password
        _actionTile(
          icon: Icons.lock_reset,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () async {
            final currentController = TextEditingController();
            final newController = TextEditingController();
            var isSubmitting = false;
            String? errorText;
            await showDialog<void>(
              context: context,
              builder: (final ctx) => StatefulBuilder(
                builder: (final ctx, final setDialogState) {
                  Future<void> submit() async {
                    final current = currentController.text.trim();
                    final next = newController.text.trim();
                    if (current.isEmpty || next.isEmpty) {
                      setDialogState(() => errorText = 'Enter both passwords');
                      return;
                    }
                    if (next.length < 8 ||
                        !next.contains(RegExp('[A-Z]')) ||
                        !next.contains(RegExp('[a-z]')) ||
                        !next.contains(RegExp('[0-9]'))) {
                      setDialogState(
                        () => errorText =
                            'New password needs 8+ characters with upper, lower, and a digit',
                      );
                      return;
                    }
                    setDialogState(() {
                      errorText = null;
                      isSubmitting = true;
                    });
                    try {
                      await ref.read(authRemoteDataSourceProvider).changePassword(
                        currentPassword: current,
                        newPassword: next,
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Password updated')),
                      );
                    } catch (e) {
                      setDialogState(() {
                        isSubmitting = false;
                        errorText = repoErrorMessage(e);
                      });
                    }
                  }

                  return AlertDialog(
                    title: const Text('Change Password'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: currentController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Current password'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: newController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'New password'),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: isSubmitting ? null : submit,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Update'),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
        const Divider(height: 1, indent: 52),
        
        // Sign out
        _actionTile(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'End your session',
          onTap: () async {
            final confirm = await showConfirmDialog(
              context,
              title: 'Sign Out',
              content: 'Are you sure you want to sign out?',
              confirmLabel: 'Sign Out',
            );
            if (confirm == true) {
              // Clear cached repositories first so they don't hold user data.
              // Do NOT invalidate `authStateChangesProvider` or
              // `currentUserProvider` here — invalidating them causes the
              // router redirect to see the providers in a loading state and
              // navigate to the `/loading` route. That can hang because the
              // sign-out event was already emitted before a new subscription
              // is created. Rely on the auth service's stream emission instead.
              ref.invalidate(userTransactionsProvider);
              ref.invalidate(transactionRepositoryProvider);

              await ref.read(authServiceProvider).signOut();
              await ref.read(analyticsServiceProvider).logEvent('sign_out');

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
              try {
                ref.read(appRouterProvider).go('/login');
              } catch (_) {
                router.go('/login');
              }
            }
          },
        ),
        const Divider(height: 1, indent: 52),

        // Biometric Lock
        const BiometricLockTile(),
        const Divider(height: 1, indent: 52),

        // Delete Account (Danger Zone)
        _actionTile(
          icon: Icons.delete_forever,
          title: 'Delete Account',
          subtitle: 'Delete all data & account',
          isDangerous: true,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (final ctx) => DeleteAccountDialog(
                userEmail: ref.read(currentUserProvider)?.email,
                onExportPressed: () => _showExportDataDialog(context, ref),
                onConfirm: (_) {},
              ),
            );
            if (confirm == true) {
              try {
                final user = ref.read(currentUserProvider);
                List<String> failures = const [];
                if (user != null) {
                  failures = await _clearAllUserData(ref, user.uid);
                }
                await ref.read(authRemoteDataSourceProvider).deleteAccount();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      failures.isEmpty
                          ? 'Account and all data deleted'
                          : 'Account deleted, but some data failed to clear (${failures.join(', ')}). Contact support if this persists.',
                    ),
                  ),
                );
                router.go('/login');
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(repoErrorMessage(e))));
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
        builder: (final ctx, final constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: constraints.maxWidth - 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          preferences,
                          const SizedBox(height: 20),
                          aiAssistantSection,
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
                aiAssistantSection,
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
    final BuildContext context,
    final WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final progressController = StreamController<({String phase, double progress, String? errorMessage})>();

    // Show enhanced progress dialog (dismissed later; not awaited).
    unawaited(EnhancedProgressDialog.show(
      context: context,
      title: 'Backup to Drive',
      subtitle: 'Uploading transactions...',
      progressStream: progressController.stream,
      onCancel: progressController.close,
    ));

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
            .map((final e) => {
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Drive upload failed';
      if (e is StateError &&
          e.toString().contains('Google Sign-In failed')) {
        errorMsg = 'Google sign-in failed. Please sign in to continue.';
      } else {
        errorMsg = repoErrorMessage(e);
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
      await progressController.close();
    }
  }

  Future<void> _restoreTransactionsFromDrive(
    final BuildContext context,
    final WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final progressController = StreamController<({String phase, double progress, String? errorMessage})>();

    // Show enhanced progress dialog (dismissed later; not awaited).
    unawaited(EnhancedProgressDialog.show(
      context: context,
      title: 'Restore from Drive',
      subtitle: 'Downloading transactions...',
      type: ProgressDialogType.restore,
      progressStream: progressController.stream,
      onCancel: progressController.close,
    ));

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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Drive restore failed';
      if (e is StateError &&
          e.toString().contains('Google Sign-In failed')) {
        errorMsg = 'Google sign-in failed. Please sign in to continue.';
      } else {
        errorMsg = repoErrorMessage(e);
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
      await progressController.close();
    }
  }

  void _showPrivacyPolicyDialog(final BuildContext context) {
    showDialog(
      context: context,
      builder: (final ctx) => AlertDialog(
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



  /// Clears all of the user's transactions/budgets/categories/EMI plans.
  ///
  /// Each category is attempted independently so one failure doesn't block
  /// the rest. Returns the list of data categories that failed to clear
  /// (empty if everything succeeded) so callers can give an honest outcome
  /// message instead of an unconditional "success".
  Future<List<String>> _clearAllUserData(final WidgetRef ref, final String userId) async {
    final failures = <String>[];

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
      debugPrint('Failed to clear transactions: $e');
      failures.add('transactions');
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
      debugPrint('Failed to clear budgets: $e');
      failures.add('budgets');
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
      debugPrint('Failed to clear categories: $e');
      failures.add('categories');
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
      debugPrint('Failed to clear EMI plans: $e');
      failures.add('EMI plans');
    }

    return failures;
  }
}
