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
        
        // Enable ABI splits for smaller APK sizes
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("cashlyze-release.jks")
            storePassword = "Cashlyze2026!"
            keyAlias = "cashlyze"
            keyPassword = "Cashlyze2026!"
        }
    }

    buildTypes {
        release {
            // Use custom keystore for production release builds
            signingConfig = signingConfigs.getByName("release")
            
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
    
    // Split APKs by ABI for smaller file sizes
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            isUniversalApk = true
        }
    }
}

flutter {
    source = "../.."
}
