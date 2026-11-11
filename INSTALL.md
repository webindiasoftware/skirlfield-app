# Build the SkirlField app — step by step

You need this once per computer. Android builds work on Windows; **iOS builds need a Mac** (Apple's rule).

---

## A. Windows: Android app

### 1. Android Studio (gives you the Android SDK)
You already have an `AndroidStudioProjects` folder, so it may be installed. If not:
1. Download from https://developer.android.com/studio and install with the default options.
2. Open it once → **More Actions → SDK Manager**:
   - *SDK Platforms*: tick the newest Android version.
   - *SDK Tools*: tick **Android SDK Command-line Tools** and **Android SDK Build-Tools**. Apply.

### 2. Flutter SDK
First check if it's already there: open **PowerShell** and type `flutter --version`.
If you get "not recognized":
1. Install Git for Windows: https://git-scm.com/download/win (defaults are fine).
2. Download the Flutter SDK zip for Windows from https://docs.flutter.dev/get-started/install/windows/mobile
3. Extract it to `C:\src\flutter` (not inside Program Files).
4. Start menu → "Edit environment variables for your account" → **Path** → **New** → `C:\src\flutter\bin` → OK.
5. Close and reopen PowerShell, then run:
   ```
   flutter doctor
   flutter doctor --android-licenses      (press y for each)
   ```
   `flutter doctor` should show ✓ for Flutter and Android toolchain. (Chrome / Visual Studio warnings don't matter for phones.)

### 3. Your phone
1. Settings → About phone → tap **Build number** 7 times (Developer options on).
2. Settings → Developer options → turn on **USB debugging**.
3. Connect by USB, accept the "Allow USB debugging" prompt.
4. `flutter devices` should list the phone.

### 4. Set up and run the app
1. Unzip `skirlfield-app-flutter.zip`, e.g. to `C:\src\skirlfield_app`.
2. In PowerShell:
   ```
   cd C:\src\skirlfield_app
   powershell -ExecutionPolicy Bypass -File .\setup.ps1
   flutter run --release
   ```
   The first build takes 5–10 minutes (Gradle downloads). The app opens on your phone.
3. Sign in as a field employee, e.g. `priya@demo.skirlfield.in` / `Demo@123`.

### 5. Make an APK to share
```
flutter build apk --release
```
The file is `build\app\outputs\flutter-apk\app-release.apk`. Send it on WhatsApp/Drive; staff tap it and allow "Install unknown apps".
(For the Play Store you'll later create a signing key and an `.aab` — ask when you get there.)

---

## B. Mac: iOS app
1. Install **Xcode** from the App Store, open it once, accept the licence.
2. Install Flutter for macOS (https://docs.flutter.dev/get-started/install/macos/mobile-ios) and CocoaPods: `sudo gem install cocoapods` (or `brew install cocoapods`).
3. Copy the project folder to the Mac and run `bash setup.sh` — it also adds the iOS location settings.
4. `open ios/Runner.xcworkspace` → Runner → **Signing & Capabilities** → choose your Team (an Apple ID works for testing; the App Store needs the $99/year Apple Developer Program).
5. Connect the iPhone, then `flutter run --release`.

---

## Pointing the app at another server
The app talks to `https://softskirl.co.in/skirlfield/api/v1`. To test against another server:
```
flutter run --release --dart-define=API_BASE=http://192.168.1.20/skirlfield/api/v1
```
(Plain `http://` works only for testing; use HTTPS for real use.)

## If something fails
Copy the **whole red error text** from PowerShell and send it to me. Common ones:
| Message | Fix |
|---|---|
| `flutter is not recognized` | Step A2.4, then reopen PowerShell |
| `Android license status unknown` | `flutter doctor --android-licenses` |
| `version solving failed` | `flutter pub upgrade --major-versions`, then run again |
| `No connected devices` | USB debugging on, accept the prompt on the phone, try another cable |
| Sign-in says *waiting for HR approval* | Approve the phone in the web app → Approval Centre → Phone changes |
