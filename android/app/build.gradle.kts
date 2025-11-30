import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // === SIGNING CONFIGS ===
    signingConfigs {
        getByName("debug") {
            // Debug signing - используется по умолчанию для debug builds
        }

        // Для dev flavor (development builds)
        create("dev") {
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))

                storeFile = file(keystoreProperties["devStoreFile"] as String)
                storePassword = keystoreProperties["devStorePassword"] as String
                keyAlias = keystoreProperties["devKeyAlias"] as String
                keyPassword = keystoreProperties["devKeyPassword"] as String
            } else {
                // Fallback to debug signing если нет keystore.properties
                println("⚠️  keystore.properties not found, using debug signing for dev")
            }
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
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            // Dev flavor ВСЕГДА использует dev signing config (критично для Google Sign-In SHA-1)
            // Если keystore.properties нет, dev config будет пустой и сработает fallback на debug
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("dev")
            } else {
                // Используем debug signing если нет keystore.properties
                signingConfigs.getByName("debug")
            }
        }

        create("prod") {
            dimension = "environment"
            // Prod использует signing из buildTypes (debug или release)
        }
    }

    // === SOURCE SETS для разных иконок ===
    // sourceSets {
    //     getByName("dev") {
    //         res.srcDirs("src/dev/res")
    //     }
    //     getByName("main") {
    //         res.srcDirs("src/main/res")
    //     }
    // }

    buildTypes {
        debug {
            // Debug по умолчанию использует Android debug key
            // Но для dev flavor будет переопределено ниже на dev key
            signingConfig = signingConfigs.getByName("dev")
        }

        release {
            // Prod использует release keystore
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Копируем нужный google-services.json перед сборкой
    applicationVariants.all {
        val variant = this
        val flavorName = variant.flavorName

        variant.preBuildProvider.configure {
            doLast {
                val sourceFile = file("google-services-${flavorName}.json")

                if (sourceFile.exists()) {
                    copy {
                        from(sourceFile)
                        into(project.projectDir) // Corrected line
                        rename { "google-services.json" }
                    }
                    println("✅ Copied google-services-${flavorName}.json")
                } else {
                    println("⚠️  Warning: google-services-${flavorName}.json not found!")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
