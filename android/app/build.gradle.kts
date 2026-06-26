import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.mind"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
    defaultConfig {
        applicationId = "io.mind"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // === SIGNING CONFIGS ===
    signingConfigs {
        getByName("debug") {
            // Debug signing - используется по умолчанию для debug builds
        }

        // Для staging flavor
        create("staging") {
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            val keystoreProperties = Properties()
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))

            storeFile = file(keystoreProperties["stagingStoreFile"] as String)
            storePassword = keystoreProperties["stagingStorePassword"] as String
            keyAlias = keystoreProperties["stagingKeyAlias"] as String
            keyPassword = keystoreProperties["stagingKeyPassword"] as String
        }

        // Для prod release builds
        create("release") {
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))

                storeFile = file(keystoreProperties["releaseStoreFile"] as String)
                storePassword = keystoreProperties["releaseStorePassword"] as String
                keyAlias = keystoreProperties["releaseKeyAlias"] as String
                keyPassword = keystoreProperties["releaseKeyPassword"] as String
            } else {
                println("⚠️  keystore.properties not found, using debug signing for release")
            }
        }
    }

    // === FLAVORS ===
    flavorDimensions += "environment"

    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-staging"
            // Staging flavor ВСЕГДА использует staging signing config (критично для Google Sign-In SHA-1)
            // Если keystore.properties нет, staging config будет пустой и сработает fallback на debug
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("staging")
            } else {
                // Используем debug signing если нет keystore.properties
                signingConfigs.getByName("debug")
            }
        }

        create("prod") {
            dimension = "environment"
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // === SOURCE SETS для разных иконок ===
    // sourceSets {
    //     getByName("staging") {
    //         res.srcDirs("src/staging/res")
    //     }
    //     getByName("main") {
    //         res.srcDirs("src/main/res")
    //     }
    // }

    buildTypes {
        debug {
            signingConfig = null
        }

        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

}

androidComponents {
    onVariants { variant ->
        val flavor = variant.flavorName ?: return@onVariants
        val configName = if (flavor == "staging") "staging" else "release"
        variant.signingConfig?.setConfig(android.signingConfigs.getByName(configName))
    }
}

flutter {
    source = "../.."
}
