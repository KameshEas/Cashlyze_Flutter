# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# ── Flutter Core ──────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# ── Firebase / Google Play Services ──────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ── Riverpod / State Management (reflection & generated code) ─────────────────
-keep class com.riverpod.** { *; }
-dontwarn com.riverpod.**
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**

# ── Dio HTTP Client & OkHttp (interceptors, converters, platform) ─────────────
-keep class com.squareup.dio.** { *; }
-dontwarn com.squareup.dio.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ── GoRouter (uses reflection for route registration) ─────────────────────────
-keep class com.google.router.** { *; }
-dontwarn com.google.router.**

# ── JSON serialization (json_serializable / built_value / freezed, etc.) ───────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepclassmembers class * {
    @com.google.gson.annotations.Expose <fields>;
}
-keepattributes *Annotation*
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ── WebSocket channel ─────────────────────────────────────────────────────────
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# ── Image Picker (Camera/Gallery) ─────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ── Flutter Secure Storage ────────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.ryansteysker.encrypt.** { *; }

# ── Local Authentication (Biometric / Device Credentials) ──────────────────────
-keep class com.shounakmulay.authenticator.** { *; }
-dontwarn com.shounakmulay.authenticator.**
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ── Google Sign-In / Google APIs (Drive backup, ML Kit, etc.) ──────────────────
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.api.services.drive.** { *; }
-dontwarn com.google.api.services.drive.**
-keep class com.google.android.gms.common.util.** { *; }

# ── Google ML Kit Text Recognition ────────────────────────────────────────────
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# ── OneSignal Push Notifications ───────────────────────────────────────────────
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**
-keep class com.onesignal.OneSignal$* { *; }
-keep class com.onesignal.OneSignalRestore.* { *; }

# ── Flutter Local Notifications ────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# ── Shared Preferences / Platform Channels ────────────────────────────────────
-keep class io.flutter.plugin.common.MethodChannel$* { *; }
-keep class io.flutter.plugin.common.EventChannel$* { *; }

# ── Lottie Animations ─────────────────────────────────────────────────────────
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# ── Fl Chart ──────────────────────────────────────────────────────────────────
-keep class com.patrykandpatrick.vico.** { *; }
-dontwarn com.patrykandpatrick.vico.**

# ── Sentry Crash Reporting ────────────────────────────────────────────────────
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# ── Shorebird (if used) ───────────────────────────────────────────────────────
-keep class dev.shorebird.** { *; }
-dontwarn dev.shorebird.**

# ── Kotlin Coroutines (used extensively by Riverpod & async code) ──────────────
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ── Generic / Reflection safety ───────────────────────────────────────────────
# Keep generic signatures of Call/Reply (needed by many libs using reflection).
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes that extend Annotation (prevents R8 from stripping annotations)
-keep class * extends java.lang.annotation.Annotation { *; }

# Keep data classes / constructors used by serialization frameworks
-keepclassmembers class * {
    <init>(...);
    <fields>;
}

# Don't warn about missing optional classes (Flutter embedding variants, etc.)
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
