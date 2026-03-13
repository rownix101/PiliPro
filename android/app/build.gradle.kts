import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter 官方插件
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties().also {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use { stream -> it.load(stream) }
    }
}

android {
    // 1. 品牌命名空间
    namespace = "com.video.pilipro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 2. 独立品牌包名
        applicationId = "com.video.pilipro"
        // 针对 Android 10 (API 29) 及以上优化
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 3. 性能优化：使用 --split-per-abi 构建时，不要设置 abiFilters
    }

    // 4. 签名配置
    signingConfigs {
        create("release") {
            val storeFileProperty = keyProperties.getProperty("storeFile")
            if (storeFileProperty != null) {
                storeFile = file(storeFileProperty)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                // 启用全版本签名，提升 Android 11+ 的安装性能
                enableV1Signing = false
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // 给 debug 版本加后缀，方便与 release 版本共存
            applicationIdSuffix = ".debug"
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            // 5. 极致瘦身与性能优化
            isMinifyEnabled = true    // 开启代码混淆 (R8)
            isShrinkResources = true // 开启资源压缩
            
            signingConfig = signingConfigs.getByName("release")
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        // 确保所有构建变体都有签名配置
        all {
            if (signingConfig == null) {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    // 6. 解决部分 native 库冲突，并优化 SO 库加载
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    // 7. 自动同步 Flutter 版本号到 APK
    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            if (output is ApkVariantOutputImpl) {
                output.versionCodeOverride = flutter.versionCode
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 8. Media3 视频全家桶 (1.5.1 为 2026 年稳定推荐版本)
    val media3Version = "1.5.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-datasource:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")
    implementation("androidx.media3:media3-database:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version") // 视频控制 UI 常用
}
