import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/transaction_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/dialogs.dart';
import 'app_bottom_nav_bar.dart';

/// Wraps the bottom-nav shell with back-button handling:
/// - On a non-Home tab, back switches to the Home tab first.
/// - On the Home tab, back asks the user to confirm logging out instead of
///   silently exiting the app.
class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  bool _loggingOut = false;

  Future<void> _handleBackPressed() async {
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }
    if (_loggingOut) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'Log Out',
      content: 'Are you sure you want to log out?',
      confirmLabel: 'Log Out',
    );
    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      // Clear cached repositories first so they don't hold user data. Do not
      // invalidate authStateChangesProvider/currentUserProvider directly —
      // the auth service's own signOut() emits the stream update.
      ref.invalidate(userTransactionsProvider);
      ref.invalidate(transactionRepositoryProvider);

      await ref.read(authServiceProvider).signOut();
      await ref.read(analyticsServiceProvider).logEvent('sign_out');

      if (mounted) GoRouter.of(context).go('/login');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (final didPop, final result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: AppBottomNavBar(navigationShell: widget.navigationShell),
      ),
    );
  }
}
