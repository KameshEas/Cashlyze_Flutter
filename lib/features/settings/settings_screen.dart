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
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: theme.textTheme.titleMedium)]),
          const SizedBox(height: 12),
          ...children
        ]),
      );
    }
    final preferences = sectionCard(Icons.tune, 'Preferences', [
      ListTile(title: const Text('Alerts'), subtitle: const Text('Notify when budgets approach thresholds'), contentPadding: EdgeInsets.zero, trailing: Switch(value: alertsEnabled, onChanged: (v) async {await prefs.setAlertsEnabled(v); setState(() {});})),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: currency, items: const [DropdownMenuItem(value: 'USD', child: Text('USD')), DropdownMenuItem(value: 'EUR', child: Text('EUR')), DropdownMenuItem(value: 'INR', child: Text('INR'))], onChanged: (v) async {if (v == null) return; await ref.read(currencyProvider.notifier).set(v);}, decoration: const InputDecoration(labelText: 'Currency', filled: true)))
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: dateFormat, items: const [DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd')), DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy')), DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/dd/yyyy'))], onChanged: (v) async {if (v == null) return; await prefs.setDateFormat(v); setState(() {});}, decoration: const InputDecoration(labelText: 'Date format', filled: true)))
      ])
    ]);
    final dataSection = sectionCard(Icons.layers_outlined, 'Data & Personalization', [
      ListTile(leading: const Icon(Icons.category_outlined), title: const Text('Manage Categories'), subtitle: const Text('Create and edit your spending categories'), onTap: () => GoRouter.of(context).go('/categories')),
      ListTile(leading: const Icon(Icons.school_outlined), title: const Text('Revisit Onboarding'), subtitle: const Text('Refresh tips and app walkthrough'), onTap: () => GoRouter.of(context).go('/onboarding_preview')),
      ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('EMI Tracker'), subtitle: const Text('Track loans and installments'), onTap: () => GoRouter.of(context).go('/emi')),
      ListTile(leading: const Icon(Icons.add_card), title: const Text('Add EMI Plan'), subtitle: const Text('Create a new EMI plan'), onTap: () => GoRouter.of(context).go('/emi/new')),
    ]);
    final accountSection = sectionCard(Icons.lock_outline, 'Account & Security', [
      ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Change Password'), onTap: () async {final controller = TextEditingController(); final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Change Password'), content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: 'New password')), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Update'))])); if (confirm == true) {try {await ref.read(authServiceProvider).updatePassword(controller.text.trim()); messenger.showSnackBar(const SnackBar(content: Text('Password updated')));} catch (e) {messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));} } controller.dispose();}),
      ListTile(leading: const Icon(Icons.delete_forever), title: const Text('Delete Account'), onTap: () async {final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Account'), content: const Text('This will permanently delete your account. Are you sure?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete'))])); if (confirm == true) {try {await ref.read(authServiceProvider).deleteAccount(); messenger.showSnackBar(const SnackBar(content: Text('Account deleted'))); router.go('/login');} catch (e) {messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));} }}),
      ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: () async {final confirm = await showDialog<bool>(context: context, builder: (ctx) {return AlertDialog(title: const Text('Sign out'), content: const Text('Are you sure you want to sign out?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out'))] );}); if (confirm == true) {await ref.read(authServiceProvider).signOut(); await ref.read(analyticsServiceProvider).logEvent('sign_out'); messenger.showSnackBar(const SnackBar(content: Text('Signed out successfully'), backgroundColor: Colors.green)); router.go('/login');}}),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [preferences, const SizedBox(height: 24), dataSection])),
              const SizedBox(width: 24),
              Expanded(child: Column(children: [accountSection]))
            ])
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            preferences,
            const SizedBox(height: 16),
            dataSection,
            const SizedBox(height: 16),
            accountSection,
          ])
        );
      })
    );
  }
}
