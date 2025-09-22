class AppConfig {
  // Default to localhost for Android emulator (10.0.2.2)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: "http://10.0.2.2:3000/api",
  );
}
