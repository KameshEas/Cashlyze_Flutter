# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Add Google Play Core (for R8)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Ignore missing classes from Flutter SDK
-ignorewarnings
-keep class * extends java.lang.annotation.Annotation { *; }

# Keep encryption packages
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.ryansteysker.encrypt.** { *; }

# Prevent obfuscation of types which use FlutterViewModel
-keep class androidx.lifecycle.** { *; }

# Keep generic signature of Call, Reply (so that they work with reflection)
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep data classes
-keepclassmembers class * {
    <init>(...);
    <fields>;
}
