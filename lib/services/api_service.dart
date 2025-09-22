import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'token_storage.dart';

class ApiService {
  static Future<Map<String, dynamic>?> loginUser(
      String email, String password) async {
    final url = Uri.parse("${AppConfig.apiBaseUrl}/login");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Login failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("⚠️ Error connecting to API: $e");
      return null;
    }
  }

  // Example: Authenticated GET request
  static Future<Map<String, dynamic>?> getProtectedData() async {
    final token = await TokenStorage.getToken(); // read token from secure storage
    if (token == null) {
      print("⚠️ No token found, user not logged in");
      return null;
    }

    final url = Uri.parse("${AppConfig.apiBaseUrl}/protected");

    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // ✅ attach token
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Request failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("⚠️ Error connecting to API: $e");
      return null;
    }
  }

}
