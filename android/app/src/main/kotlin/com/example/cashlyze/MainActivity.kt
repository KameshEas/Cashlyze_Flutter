package com.aspiredesignovation.cashlyze

import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: the local_auth plugin shows the
// system BiometricPrompt as a fragment, and fails outright ("no_fragment_activity")
// when hosted by a plain FlutterActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_SETUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openEnrollment" -> result.success(openBiometricEnrollment())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens the system screen where the user adds a fingerprint / face, or
     * (when the device has no screen lock yet) sets one up first. Tries the most
     * specific screen the OS version offers and falls back to general security
     * settings, since OEM builds don't all ship every screen.
     */
    private fun openBiometricEnrollment(): Boolean {
        val attempts = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            attempts.add(
                Intent(Settings.ACTION_BIOMETRIC_ENROLL).putExtra(
                    Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                    BiometricManager.Authenticators.BIOMETRIC_STRONG,
                ),
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            attempts.add(Intent(Settings.ACTION_FINGERPRINT_ENROLL))
        }
        attempts.add(Intent(Settings.ACTION_SECURITY_SETTINGS))

        for (intent in attempts) {
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try the next, more general screen.
            }
        }
        return false
    }

    private companion object {
        const val BIOMETRIC_SETUP_CHANNEL = "com.aspiredesignovation.cashlyze/biometric_setup"
    }
}
