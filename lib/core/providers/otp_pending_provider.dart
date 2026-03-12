import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_prefs_provider.dart';

const _kOtpPendingKey = 'otp_pending';
const _kOtpPendingEmailKey = 'otp_pending_email';
const _kOtpSentKey = 'otp_sent';

/// Tracks whether the current user still needs to complete OTP verification
/// after a fresh signup. Set to [true] just before navigating to /otp, and
/// cleared to [false] once the OTP is successfully verified.
///
/// State is persisted via [SharedPreferences] so that going to the background
/// and relaunching the app does not accidentally bypass OTP verification.
///
/// [pendingEmail] stores the email address so the router redirect can always
/// forward to `/otp?email=...` even when the pending flag is set before
/// navigation happens.
///
/// [otpAlreadySent] tracks whether the OTP was already dispatched so that
/// the OTP screen can skip straight to the code-entry phase if it is
/// recreated mid-session (e.g. due to a router rebuild after Firebase auth
/// state changes).
class OtpPendingNotifier extends Notifier<bool> {
  String pendingEmail = '';
  bool otpAlreadySent = false;

  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    pendingEmail = prefs.getString(_kOtpPendingEmailKey) ?? '';
    otpAlreadySent = prefs.getBool(_kOtpSentKey) ?? false;
    return prefs.getBool(_kOtpPendingKey) ?? false;
  }

  void setPending({String email = ''}) {
    final prefs = ref.read(sharedPrefsProvider);
    pendingEmail = email;
    prefs.setBool(_kOtpPendingKey, true);
    prefs.setString(_kOtpPendingEmailKey, email);
    state = true;
  }

  void markOtpSent() {
    final prefs = ref.read(sharedPrefsProvider);
    otpAlreadySent = true;
    prefs.setBool(_kOtpSentKey, true);
  }

  void clearPending() {
    final prefs = ref.read(sharedPrefsProvider);
    pendingEmail = '';
    otpAlreadySent = false;
    prefs.remove(_kOtpPendingKey);
    prefs.remove(_kOtpPendingEmailKey);
    prefs.remove(_kOtpSentKey);
    state = false;
  }
}

final otpPendingProvider = NotifierProvider<OtpPendingNotifier, bool>(
  OtpPendingNotifier.new,
);
