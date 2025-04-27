plugins {
    id("com.android.application")
    id("kotlin-android")
    // Add this line to apply the Google services plugin
    id("com.google.gms.google-services")
}

android {
    compileSdkVersion(33)

    defaultConfig {
        applicationId = "com.example.need1more"
        minSdkVersion(21)
        targetSdkVersion(33)
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("com.google.firebase:firebase-analytics-ktx:21.2.0") // Firebase Analytics (example)
    implementation("com.google.firebase:firebase-database-ktx:20.0.3") // Firebase Realtime Database (example)
    // Add other Firebase dependencies here

    // Google services dependency
    implementation("com.google.android.gms:play-services-base:18.1.0") // Required by Firebase
}
