# 📝 DailyTask App

A Flutter-based productivity app to manage daily tasks with real-time cloud storage, Google Sign-In, and crash analytics using **Firebase**.

## 🚀 Features

- Firebase Firestore for cloud data storage  
- Google Sign-In authentication  
- Firebase Crashlytics for error tracking  
- Works on both Android & iOS  

---

## 🔧 Firebase Setup Guide

### 1. Create Firebase Project

- Go to [Firebase Console](https://console.firebase.google.com/)
- Click **"Create a project"**
- Project name: `daily-tasks-app`
- (Optional) Enable Google Analytics

---

### 2. Register Your Apps in Firebase

#### 🔹 Android
- Add Android app:
  - Package name: *your.package.name*
  - App nickname: `DailyTasks Android`
  - Add SHA-1:
    ```bash
    cd android
    ./gradlew signingReport
    ```
- Download `google-services.json`  
  → Place it in `android/app/`

#### 🔹 iOS
- Add iOS app:
  - Bundle ID: *your.bundle.id*
- Download `GoogleService-Info.plist`  
  → Place it in `ios/Runner/`

---

### 3. Enable Firebase Services

#### 🔐 Authentication

- Go to **Authentication > Sign-in method**
- Enable **Google Sign-In**
- Add your support email

#### 🗂 Firestore Database

- Go to **Cloud Firestore**
- Click **Create database**
- Choose **Start in test mode**
- Select the nearest region

---

### 4. Configure Firebase in Flutter

#### 🔹 Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

#### 🔹 Configure your project

Generate `firebase_options.dart` by running the following in your project root:

```bash
flutterfire configure --project=daily-tasks-app
```

- Select platforms (Android, iOS)
- This will auto-generate `lib/firebase_options.dart`
- Make sure to import it in your main file:

```dart
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```


> This generates `lib/firebase_options.dart`

---

## ⚙️ Android Configuration

### 🔸 Project-level `build.gradle.kts`
```kotlin
dependencies {
    classpath("com.google.gms:google-services:4.4.2")
    classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
}
```

### 🔸 App-level `build.gradle.kts`
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    compileSdk = 34
    defaultConfig {
        applicationId = "your.package.name"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    // Optional:
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
}
```

---

### 🔸 `AndroidManifest.xml` Permissions
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

### 🔸 Proguard Rules (`proguard-rules.pro`)
```proguard
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**
-keep class your.package.name.** extends java.lang.Exception { *; }

# Flutter-related
-keep class io.flutter.** { *; }
```

---

## 🛠 Tools Used

- Flutter
- Firebase (Firestore, Auth, Crashlytics)
- Kotlin DSL (Gradle)
- Google Sign-In

---

## 🧑‍💻 Developed By

**transBuzz**  
📧 Email: transbuzzofficial@gmail.com

---
