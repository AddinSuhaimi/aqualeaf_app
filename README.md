## Prerequisites

To successfully set up and run **AquaLeaf**, please ensure your development environment meets the following requirements:

### **1. Core Development Tools**
* **Flutter SDK:** Version **3.9.2** or higher.
    * *Note:* Run `flutter --version` to check your current version.
* **Dart SDK:** Version **^3.9.2**.
* **Android Studio:** Latest version with the **Flutter** and **Dart** plugins installed.

### **2. Hardware & Permissions**
This app utilizes specialized hardware features. Ensure your testing environment supports:
* **Camera:** A physical device is recommended. If using an emulator, ensure "Camera" is enabled in the AVD settings.
* **Storage:** The app uses `sqflite` and `path_provider` for local data persistence.
* **Internet:** Required for `http` requests and `connectivity_plus` checks.

### **3. Machine Learning Requirements (`tflite_flutter`)**
Since the app uses **TensorFlow Lite** for image classification:
* **Android:** Ensure your `minSdkVersion` in `android/app/build.gradle` is at least **21**.
* **TensorFlow Binaries:** You may need to run the following if the ML models fail to load:
    ```bash
    flutter pub run tflite_flutter:download
    ```

### **4. Asset Configuration**
The app relies on specific local assets located in the `assets/` folder. Ensure these files exist before building:
* **Models:** `assets/models/` (TFLite models)
* **Manuals:** `assets/manual/`
* **Images:** `assets/seaweed/` and `assets/aqualeaf-logo.png`

---

## Installation & Setup

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/AddinSuhaimi/aqualeaf_app.git
    cd aqualeaf_app
    ```

2.  **Install Dependencies**
    Fetch all the packages listed in `pubspec.yaml` (including `flutter_secure_storage`, `camera`, and `tflite_flutter`):
    ```bash
    flutter pub get
    ```

3.  **Run the App**
    Connect your device/emulator and execute:
    ```bash
    flutter run
    ```

---

### **Troubleshooting Common Issues**
* **TFLite Errors:** If you get a "Library not found" error for TFLite, ensure you have followed the [tflite_flutter setup guide](https://pub.dev/packages/tflite_flutter) regarding dynamic libraries.
* **Secure Storage (Android):** If the app crashes on launch, ensure your `minSdkVersion` is high enough to support `flutter_secure_storage`.
* **CocoaPods (iOS):** If running on a Mac, navigate to the `ios` folder and run `pod install`.
