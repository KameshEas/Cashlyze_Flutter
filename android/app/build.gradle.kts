plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aspiredesignovation.cashlyze"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = (project.findProperty("APP_ID") as String?) ?: "com.aspiredesignovation.cashlyze"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // For production release, use one of the following options:
            
            // Option 1: Use a custom keystore (uncomment and configure)
            // signingConfig = signingConfigs.getByName("release")
            
            // Option 2: Use debug keys for testing (not for production)
            // Remove this line for production builds
            signingConfig = signingConfigs.getByName("debug")
            
            // Enable R8/ProGuard minification and obfuscation for release
            isMinifyEnabled = true
            isShrinkResources = true
            
            // Configure R8/ProGuard rules
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // R8 configuration for code shrinking and obfuscation
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}
