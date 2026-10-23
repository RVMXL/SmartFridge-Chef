import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// Подпись release-сборки («Умный Холодильник & Шеф-Планер»).
// Приоритет источников ключа:
//   1) переменные окружения — CI (GitHub Secrets):
//      KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEYSTORE_KEY_ALIAS,
//      KEYSTORE_KEY_PASSWORD;
//   2) файл android/key.properties — локальная сборка
//      (в git не попадает, см. .gitignore).
// Сам ключ подписи в репозитории не хранится никогда.
// ============================================================
val keystoreBase64: String? = System.getenv("KEYSTORE_BASE64")
val keystorePassword: String? = System.getenv("KEYSTORE_PASSWORD")
val keystoreKeyAlias: String? = System.getenv("KEYSTORE_KEY_ALIAS")
val keystoreKeyPassword: String? = System.getenv("KEYSTORE_KEY_PASSWORD")

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "ru.rvmxl.smart_fridge_chef"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ru.rvmxl.smart_fridge_chef"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Использует versionCode из pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!keystoreBase64.isNullOrEmpty()) {
                // CI: ключ приходит из GitHub Secrets в base64
                val ksFile = File.createTempFile("upload-keystore", ".jks")
                ksFile.writeBytes(Base64.getDecoder().decode(keystoreBase64))
                ksFile.deleteOnExit()
                storeFile = ksFile
                storePassword = keystorePassword
                keyAlias = keystoreKeyAlias
                keyPassword = keystoreKeyPassword
            } else if (keyPropertiesFile.exists()) {
                // Локальная сборка: android/key.properties
                storeFile = (keyProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keyProperties["storePassword"] as String?
                keyAlias = keyProperties["keyAlias"] as String?
                keyPassword = keyProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Release-ключ, если настроен (CI или key.properties); иначе —
            // debug-ключ, чтобы `flutter run --release` работал без настроек.
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
