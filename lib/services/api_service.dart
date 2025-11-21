import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'token_storage.dart';

class ApiService {

  // ------------------------
  // LOGIN USER
  // ------------------------
  static Future<Map<String, dynamic>?> loginUser(
      String email, String password) async {

    final url = Uri.parse("${AppConfig.apiBaseUrl}/login");
    print("➡ POST $url");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      print("⬅ Response ${response.statusCode}: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Login failed: ${response.body}");
        return null;
      }

    } catch (e) {
      print("Error connecting to API during login: $e");
      return null;
    }
  }

  // ------------------------
  // FETCH FARM DETAILS (protected)
  // ------------------------
  static Future<Map<String, dynamic>?> fetchFarmDetails() async {
    final token = await TokenStorage.getToken();

    if (token == null) {
      print("No token found — user not logged in.");
      return null;
    }

    final url = Uri.parse("${AppConfig.apiBaseUrl}/farm-details");
    print("GET $url");
    print("Using Token: Bearer $token");

    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("Response ${response.statusCode}: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print("Parsed farm details: $json");
        return json;
      }

      if (response.statusCode == 401) {
        print("Unauthorized — token invalid or expired.");
        return {"__unauthorized": true};
      }

      print("Unexpected status code: ${response.statusCode}");
      return null;

    } catch (e) {
      print("Error during fetchFarmDetails: $e");
      return null;
    }
  }
}
