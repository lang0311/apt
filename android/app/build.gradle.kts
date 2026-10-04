import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `--dart-define`/`--dart-define-from-file` 값 (base64, 쉼표 구분). 네이티브 설정(카카오 URL scheme 등)에 쓴다.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.map { String(Base64.getDecoder().decode(it)) }
    ?.mapNotNull { entry -> entry.split("=", limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] } }
    ?.toMap()
    ?: emptyMap()

android {
    namespace = "com.teamjkk.apt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.teamjkk.apt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 카카오 로그인 리다이렉트 scheme (kakao{네이티브 앱 키}). 키가 없으면 더미 값.
        manifestPlaceholders["kakaoNativeAppKey"] = dartDefines["KAKAO_NATIVE_APP_KEY"] ?: "NONE"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
