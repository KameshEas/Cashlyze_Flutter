import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _serverOtp; // Only used in development when server returns OTP

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Try to prefill email from query param if present (GoRouter navigation passes it)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final loc = GoRouter.of(context).location;
        final uri = Uri.parse(loc);
        final email = uri.queryParameters['email'];
        if (email != null && email.isNotEmpty) {
          _emailController.text = Uri.decodeComponent(email);
        }
      } catch (_) {}
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      // Default to Netlify function path; change as needed for your deployment.
      final url = Uri.parse('/.netlify/functions/send-otp');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent. Check your inbox.')),
        );
        if (body != null && body['otp'] != null && body['otp'] != 'generated') {
          // Server returned OTP (dev mode) — store for verification convenience
          setState(() => _serverOtp = body['otp'].toString());
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: ${body['error'] ?? res.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final entered = _otpController.text.trim();
    if (entered.isEmpty) return;
    setState(() => _verifying = true);
    try {
      // If server returned OTP (dev), compare locally.
      if (_serverOtp != null) {
        if (entered == _serverOtp) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP verified (dev).')),
          );
          GoRouter.of(context).go('/');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP does not match.')),
          );
        }
        return;
      }
      // Call verify-otp server endpoint
      final email = _emailController.text.trim();
      final url = Uri.parse('/.netlify/functions/verify-otp');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': entered}),
      );
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verified.')),
        );
        GoRouter.of(context).go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed: ${body['error'] ?? res.statusCode}')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Enter your email to receive a one-time code', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _sending ? null : _sendOtp,
                  child: _sending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send OTP'),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Enter OTP'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _verifying ? null : _verifyOtp,
                  child: _verifying ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
