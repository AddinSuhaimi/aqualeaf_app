/*
class AppConfig {
  // Default to localhost for Android emulator (10.0.2.2)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: "http://10.0.2.2:3000/api",
  );
}
*/
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String? _apiBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = prefs.getString('apiBaseUrl') ?? 'https://helga-sulfureous-atomically.ngrok-free.dev/api';
  }

  static String get apiBaseUrl => _apiBaseUrl!;
  static Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiBaseUrl', url);
    _apiBaseUrl = url;
  }
}