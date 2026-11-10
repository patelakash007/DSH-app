import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

// Debug builds use the release key only when it is all there; they are never the build
// that should stop over a half-filled key.properties.
// A password may be nothing but spaces; a path or an alias may not.
val hasWholeReleaseKey = listOf("storeFile", "keyAlias").all { !keyProps.getProperty(it).isNullOrBlank() } &&
    listOf("storePassword", "keyPassword").all { !keyProps.getProperty(it).isNullOrEmpty() } &&
    file(keyProps.getProperty("storeFile")).exists()

// The native Go engine ships per ABI as libdsh.so in src/main/jniLibs.

// versionCode is the build minute, same encoding as tooling/build_number.py:
// (year - 2026) * 10^8 + MMDDhhmm at UTC+8. tooling/build-apk.sh passes it as
// --build-number; this covers builds that skip the script (flutter run, the
// IDE), where pubspec's `+1` placeholder would be a downgrade and make
// `flutter run` uninstall the installed app, data included.
fun buildMinuteVersionCode(): Int {
    val t = OffsetDateTime.now(ZoneOffset.ofHours(8))
    return (t.year - 2026) * 100_000_000 + t.monthValue * 1_000_000 + t.dayOfMonth * 10_000 + t.hour * 100 + t.minute
}

android {
    namespace = "io.github.ccch1mneyyy.dsh_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.ccch1mneyyy.dsh_app"
        // java.nio.file and the native engine's process/path APIs need API 26.
        minSdk = 26
        // Target 28 is deliberate and documented in docs/architecture.md: this is
        // an APK distributed from GitHub Releases, not a Play build.
        targetSdk = 28
        versionCode = flutter.versionCode.takeIf { it > 1 } ?: buildMinuteVersionCode()
        versionName = flutter.versionName
    }

    flavorDimensions += "abi"
    productFlavors {
        create("arm64") {
            dimension = "abi"
            ndk { abiFilters += "arm64-v8a" }
        }
        create("x64") {
            dimension = "abi"
            ndk { abiFilters += "x86_64" }
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir("src/main/jniLibs")
        }
        getByName("arm64") {
            jniLibs.srcDir("src/main/jniLibs")
        }
        getByName("x64") {
            jniLibs.srcDir("src/main/jniLibs")
        }
    }

    packaging {
        // The Go engine ships as libdsh.so; it must be extracted to
        // nativeLibraryDir so it can be executed.
        jniLibs {
            useLegacyPackaging = true
            // Must remain byte-identical to the hash recorded in the runtime manifest.
            keepDebugSymbols += listOf("**/libdsh.so")
        }
    }

    lint {
        // targetSdk 28 is deliberate (see docs/architecture.md); not a Play build.
        disable += "ExpiredTargetSdkVersion"
    }

    androidResources {
        noCompress += listOf("gz", "xz", "zst", "tar")
    }

    signingConfigs {
        if (!keyProps.isEmpty) {
            create("release") {
                storeFile = keyProps.getProperty("storeFile")?.let { file(it) }
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
                // All three schemes: AGP drops v1 for minSdk 24+, but some installers and
                // security scanners on Chinese ROMs still read the JAR signature.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        debug {
            // tooling/dev-run.sh installs debug over the release build on a phone, data
            // kept: Android only allows that with the same key.
            if (hasWholeReleaseKey) signingConfig = signingConfigs.getByName("release")
        }
        release {
            // Never sign a release with the debug key implicitly: an unsigned artifact cannot be
            // installed or published by accident. Local release testing may opt in explicitly.
            signingConfig = when {
                hasWholeReleaseKey -> signingConfigs.getByName("release")
                providers.gradleProperty("dsh.allowDebugSigning").orNull == "true" -> signingConfigs.getByName("debug")
                else -> null
            }
            // Ours on top of Flutter's: phone control's privileged process and
            // its TLS libraries are reached by class name (see the file).
            proguardFiles("proguard-rules.pro")
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

dependencies {
    // Bundled Chinese OCR. SDK statistics disclosed separately; initialization is opt-in per use.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    testImplementation("junit:junit:4.13.2")
    // Android stubs do not implement JSONObject in local JVM tests.
    testImplementation("org.json:json:20240303")

    // 不打扰模式 (phone/background): a shell-uid privileged display via Shizuku or self-ADB.
    implementation("dev.rikka.shizuku:api:13.1.5")       // MIT
    implementation("dev.rikka.shizuku:provider:13.1.5")  // MIT
    implementation("com.github.MuntashirAkon:libadb-android:3.1.1") // used under its Apache-2.0 option; pulls in spake2-android (LGPL-3.0)
    implementation("org.conscrypt:conscrypt-android:2.8.0")         // Apache-2.0: libadb TLS/pairing
    // MIT: self-signed adb client cert. The same jdk15to18 family libadb-android
    // pulls in (bcprov-jdk15to18:1.81); adding jdk18on next to it duplicates every class.
    implementation("org.bouncycastle:bcpkix-jdk15to18:1.81")
    implementation("androidx.webkit:webkit:1.15.0") // Apache-2.0: web islands' force dark (webview_flutter's own version)
}
