## Prerequisites

Before you can run the **AquaLeaf** mobile application, ensure you have the following software and environment configurations set up on your machine:

### **1. Flutter SDK**
* **Flutter:** Ensure you have the Flutter SDK installed. 
  * [Download Flutter SDK](https://docs.flutter.dev/get-started/install)
  * After installation, run `flutter doctor` in your terminal to verify that all dependencies are met.

### **2. Integrated Development Environment (IDE)**
* **Android Studio:** * Install the **Flutter** and **Dart** plugins via `Settings > Plugins`.
  * Set up the **Android SDK** and **Command-line Tools** within the SDK Manager.
* *Alternative:* Visual Studio Code (with Flutter/Dart extensions).

### **3. Mobile Development Environment**
* **Android:** * An **Android Emulator** (configured via AVD Manager in Android Studio) or a physical Android device with **USB Debugging** enabled.
  * Java Development Kit (JDK) 11 or higher (usually bundled with Android Studio).
* **iOS (macOS only):** * Xcode installed to run on iOS simulators or physical iPhones.

### **4. CocoaPods (macOS only)**
* If you are developing on a Mac for iOS, you must have CocoaPods installed to manage plugin dependencies:
  ```bash
  sudo gem install cocoapods
  ```

---

## Getting Started

Once the prerequisites are met, follow these steps to launch the app:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AddinSuhaimi/aqualeaf_app.git
   ```
2. **Navigate to the project directory:**
   ```bash
   cd aqualeaf_app
   ```
3. **Install dependencies:**
   ```bash
   flutter pub get
   ```
4. **Run the application:**
   ```bash
   flutter run
   ```
