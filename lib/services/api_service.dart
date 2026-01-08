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

      print("Response ${response.statusCode}: ${response.body}");

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login successful
        return {
          "success": true,
          "data": body,
        };
      } else {
        // Login failed, but return server message
        return {
          "success": false,
          "message": body['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print("Error connecting to API during login: $e");
      return {
        "success": false,
        "message": "Connection error. Please try again.",
      };
    }
  }

  // Method to refresh access token
  static Future<bool> refreshAccessToken() async {
    final refresh = await SecureStorage.getRefreshToken();
    if (refresh == null) return false;

    final url = Uri.parse("${AppConfig.apiBaseUrl}/refresh");

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refreshToken": refresh}),
      );

      print("Refresh response: ${res.statusCode} ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newAccess = data["accessToken"];

        // update stored token
        await SecureStorage.saveAccessToken(newAccess);

        print("Access token refreshed");
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // Helper method for automatically refreshing access tokens
  static Future<http.Response> _authorizedGet(String endpoint) async {
    String? token = await SecureStorage.getAccessToken();

    final url = Uri.parse("${AppConfig.apiBaseUrl}$endpoint");

    var res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    // If access token expired, try refresh token
    if (res.statusCode == 401) {
      final refreshed = await refreshAccessToken();

      if (refreshed) {
        // retry request with new token
        token = await SecureStorage.getAccessToken();
        res = await http.get(
          url,
          headers: {"Authorization": "Bearer $token"},
        );
      }
    }
    return res;
  }

  // ------------------------
  // FETCH FARM DETAILS (protected)
  // ------------------------
  static Future<Map<String, dynamic>?> fetchFarmDetails() async {
    final token = await SecureStorage.getAccessToken();

    if (token == null) return null;

    //skip API call attempt if offline
    final online = await _isOnline();
    if (!online) {
      final cached = await SecureStorage.getFarmDetails();

      if (cached['farmName'] == null) {
        return {"offline": true};
      }

      return {
        "farmName": cached['farmName'],
        "farmLocation": cached['farmLocation'],
        "offline": true
      };
    }

    // Try online mode
    try {
      final response = await _authorizedGet("/farm-details");

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
      "farmName": cached['farmName'],
      "farmLocation": cached['farmLocation'],
      "offline": true
    };
  }

  static Future<Map<String, dynamic>> checkLoginStatus() async {
    final access = await SecureStorage.getAccessToken();
    final refresh = await SecureStorage.getRefreshToken();

    // No tokens at all: user never logged in/haven't logged in the last 7 days
    if (refresh == null) {
      return {"status": "no_token"};
    }

    // Check internet connection
    final online = await _isOnline();

    // ===== ONLINE MODE =====
    if (online) {
      // Try verifying access token by hitting backend OR simply try auto-refresh.
      // Best approach with refresh token system:
      //   → just immediately attempt to refresh access token.
      final refreshed = await refreshAccessToken();

      if (refreshed) {
        return {"status": "valid"};   // user stays logged in
      } else {
        return {"status": "invalid"}; // refresh token expired → must login again
      }
    }

    // ===== OFFLINE MODE =====
    // Access token cannot be validated, but refresh token exists.
    // That means the user SHOULD be allowed to continue in offline mode.
    return {"status": "offline_allowed"};
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
