import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_prefs_provider.dart';

const _kOtpPendingKey = 'otp_pending';
const _kOtpPendingEmailKey = 'otp_pending_email';
const _kOtpPendingNameKey = 'otp_pending_name';
const _kOtpPendingMobileKey = 'otp_pending_mobile';
const _kOtpSentKey = 'otp_sent';
const _kOtpPendingPasswordKey = 'otp_pending_password';

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
  String pendingName = '';
  String pendingMobile = '';
  String pendingPassword = '';
  bool otpAlreadySent = false;

  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    pendingEmail = prefs.getString(_kOtpPendingEmailKey) ?? '';
    pendingName = prefs.getString(_kOtpPendingNameKey) ?? '';
    pendingMobile = prefs.getString(_kOtpPendingMobileKey) ?? '';
    pendingPassword = prefs.getString(_kOtpPendingPasswordKey) ?? '';
    otpAlreadySent = prefs.getBool(_kOtpSentKey) ?? false;
    return prefs.getBool(_kOtpPendingKey) ?? false;
  }

  void setPending({
    final String email = '',
    final String password = '',
    final String name = '',
    final String mobile = '',
  }) {
    final prefs = ref.read(sharedPrefsProvider);
    pendingEmail = email;
    pendingName = name;
    pendingMobile = mobile;
    pendingPassword = password;
    prefs.setBool(_kOtpPendingKey, true);
    prefs.setString(_kOtpPendingEmailKey, email);
    prefs.setString(_kOtpPendingNameKey, name);
    prefs.setString(_kOtpPendingMobileKey, mobile);
    prefs.setString(_kOtpPendingPasswordKey, password);
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
    pendingName = '';
    pendingMobile = '';
    pendingPassword = '';
    otpAlreadySent = false;
    prefs.remove(_kOtpPendingKey);
    prefs.remove(_kOtpPendingEmailKey);
    prefs.remove(_kOtpPendingNameKey);
    prefs.remove(_kOtpPendingMobileKey);
    prefs.remove(_kOtpPendingPasswordKey);
    prefs.remove(_kOtpSentKey);
    state = false;
  }
}

final otpPendingProvider = NotifierProvider<OtpPendingNotifier, bool>(
  OtpPendingNotifier.new,
);
