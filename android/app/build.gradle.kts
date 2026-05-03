import java.util.Properties

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

// Load signing config at top level (accessible to all scopes in Kotlin DSL)
val signingProps = Properties()
val envKeystorePassword: String? = System.getenv("ANDROID_KEYSTORE_PASSWORD")
if (envKeystorePassword != null) {
    signingProps["storeFile"] = "cashlyze-release.jks"
    signingProps["storePassword"] = envKeystorePassword
    signingProps["keyAlias"] = System.getenv("ANDROID_KEY_ALIAS") ?: "cashlyze"
    signingProps["keyPassword"] = System.getenv("ANDROID_KEY_PASSWORD") ?: envKeystorePassword
} else {
    val keystorePropsFile = rootProject.file("key.properties")
    if (keystorePropsFile.exists()) {
        keystorePropsFile.reader().use { signingProps.load(it) }
    }
}

android {
    namespace = "com.aspiredesignovation.cashlyze"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for newer Java APIs used by plugins
        isCoreLibraryDesugaringEnabled = true
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
            val sf = signingProps.getProperty("storeFile")
            if (sf != null) {
                storeFile = file(sf)
                storePassword = signingProps.getProperty("storePassword")
                keyAlias = signingProps.getProperty("keyAlias") ?: "cashlyze"
                keyPassword = signingProps.getProperty("keyPassword")
            }
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
    
    // Split APKs by ABI for smaller file sizes (DISABLED - causing bundle issues)
    splits {
        abi {
            isEnable = false
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            isUniversalApk = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for core library desugaring (Java 8+ APIs used by some plugins)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Material 3 design system for edge-to-edge display support
    implementation("com.google.android.material:material:1.12.0")
}
