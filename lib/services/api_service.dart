import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'secure_storage.dart';

class ApiService {

  // ------------------------
  // LOGIN USER
  // ------------------------
  static Future<Map<String, dynamic>?> loginUser(
      String email, String password) async {

    final url = Uri.parse("${AppConfig.apiBaseUrl}/login");
    print("POST $url");

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
    final token = await SecureStorage.getToken();

    if (token == null) return null;

    //skip API call attempt if offline
    final online = await _isOnline();
    if (!online) {
      final cached = await SecureStorage.getFarmDetails();

      if (cached['farmName'] == null) {
        return {"offline": true};
      }

      return {
        "managerName": cached['managerName'],
        "managerEmail": cached['managerEmail'],
        "farmName": cached['farmName'],
        "farmLocation": cached['farmLocation'],
        "offline": true
      };
    }

    // Try online mode
    try {
      final url = Uri.parse("${AppConfig.apiBaseUrl}/farm-details");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      // ONLINE VALID
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save to offline cache
        await SecureStorage.saveFarmDetails(data);

        return data;
      }

      // ONLINE UNAUTHORIZED
      if (response.statusCode == 401) {
        return {"__unauthorized": true};
      }
    } catch (_) {
      // network or server unreachable → offline fallback
    }

    // OFFLINE MODE -> load cached farm details
    final cached = await SecureStorage.getFarmDetails();

    // If no saved data -> show minimal offline UI
    if (cached['farmName'] == null) return {"offline": true};

    return {
      "managerName": cached['managerName'],
      "managerEmail": cached['managerEmail'],
      "farmName": cached['farmName'],
      "farmLocation": cached['farmLocation'],
      "offline": true
    };
  }

  static Future<Map<String, dynamic>> checkLoginStatus() async {

    final token = await SecureStorage.getToken();

    // 1. No saved token -> user never logged in
    if (token == null) {
      return {"status": "no_token"};
    }

    // 2. Check internet connectivity
    final online = await _isOnline();

    // ---- ONLINE MODE ----
    if (online) {
      final url = Uri.parse("${AppConfig.apiBaseUrl}/auth/verify");

      try {
        final response = await http.get(
          url,
          headers: {"Authorization": "Bearer $token"},
        );

        print(response.statusCode);

        if (response.statusCode == 200) {
          return {"status": "online_valid"};
        }

        // Token invalid → force login
        return {"status": "online_invalid"};

      } catch (e) {
        // Server unreachable but internet exists
        return {"status": "server_error"};
      }
    }

    // ---- OFFLINE MODE ----
    // Token exists, so allow offline usage
    return {
      "status": "offline_allowed",
    };
  }

  // online status check helper
  static Future<bool> _isOnline() async {
    try {
      final result = await http.get(Uri.parse("https://google.com"))
          .timeout(const Duration(seconds: 3));
      return result.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isOnline() async {
    try {
      final resp = await http.get(Uri.parse("https://google.com"))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

}
