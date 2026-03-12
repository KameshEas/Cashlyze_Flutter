import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the current user still needs to complete OTP verification
/// after a fresh signup. Set to [true] just before navigating to /otp, and
/// cleared to [false] once the OTP is successfully verified.
///
/// This is in-memory state — it resets on app restart, which is intentional:
/// OTP verification is only required once per signup session.
class OtpPendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setPending() => state = true;
  void clearPending() => state = false;
}

final otpPendingProvider = NotifierProvider<OtpPendingNotifier, bool>(
  OtpPendingNotifier.new,
);
