plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.subbridge.subbridge"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.subbridge.subbridge"
        // AudioPlaybackCapture API는 Android 10 (API 29) 이상 필요
        minSdk = 29
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Vosk 온디바이스 STT — alphacephei 저장소에서 제공
    implementation("com.alphacephei:vosk-android:0.3.75@aar")
    // Vosk가 내부적으로 JNA를 통해 네이티브 라이브러리를 로드함
    implementation("net.java.dev.jna:jna:5.13.0@aar")
    // Kotlin 코루틴
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
