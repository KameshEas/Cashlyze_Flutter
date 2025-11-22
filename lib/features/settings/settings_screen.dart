import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/providers/onboarding_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedPrefsServiceProvider);
    bool alertsEnabled = prefs.alertsEnabled;
    String currency = prefs.currency;
    String dateFormat = prefs.dateFormat;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Alerts'),
            subtitle: const Text('Notify when budgets approach thresholds'),
            trailing: Switch(
              value: alertsEnabled,
              onChanged: (v) async {
                await prefs.setAlertsEnabled(v);
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Expanded(child: Text('Currency')),
                DropdownButton<String>(
                  value: currency,
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'INR', child: Text('INR')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await prefs.setCurrency(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('Date format')),
                DropdownButton<String>(
                  value: dateFormat,
                  items: const [
                    DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd')),
                    DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy')),
                    DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/dd/yyyy')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await prefs.setDateFormat(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            onTap: () => GoRouter.of(context).go('/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Revisit Onboarding'),
            onTap: () => GoRouter.of(context).go('/onboarding_preview'),
          ),
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
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Update')),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await ref.read(authServiceProvider).updatePassword(controller.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
                  content: const Text('This will permanently delete your account. Are you sure?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await ref.read(authServiceProvider).deleteAccount();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted')));
                  GoRouter.of(context).go('/login');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
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
      ),
    );
  }
}
