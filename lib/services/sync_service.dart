import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../db/database_helper.dart';
import '../models/scan_report_fresh.dart';
import '../models/scan_report_dried.dart';
import 'secure_storage.dart';
import 'api_service.dart';

class SyncService {
  static Future<void> syncPendingReports() async {
    final dbHelper = DatabaseHelper.instance;

    // Only try to sync when online
    final online = await ApiService.isOnline();
    if (!online) {
      return;
    }

    // Ensure a valid access token (refresh if needed)
    String? token = await SecureStorage.getAccessToken();

    if (token == null) {
      final refreshed = await ApiService.refreshAccessToken();
      if (!refreshed) {
        // Skip sync if cannot refresh
        return;
      }
      token = await SecureStorage.getAccessToken();
      if (token == null) return;
    }

    // Load unsynced data from SQLite
    final List<ScanReportFresh> unsyncedFresh =
    await dbHelper.getUnsyncedFreshReports();
    final List<ScanReportDried> unsyncedDried =
    await dbHelper.getUnsyncedDriedReports();

    if (unsyncedFresh.isEmpty && unsyncedDried.isEmpty) {
      return;
    }

    // Prepare payload
    final body = {
      "fresh_reports": unsyncedFresh
          .map((r) => {
        "local_id": r.scanId, // for marking as synced later
        ...r.toUploadMap(),   // farm_id, species_id, etc.
      })
          .toList(),
      "dried_reports": unsyncedDried
          .map((r) => {
        "local_id": r.scanId,
        ...r.toUploadMap(),
      })
          .toList(),
    };

    const endpoint = "/upload-scan-reports";
    final url = Uri.parse("${AppConfig.apiBaseUrl}$endpoint");

    // POST with auth, auto-refresh once if 401
    var response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      // access token probably expired -> try refresh, then retry once
      final refreshed = await ApiService.refreshAccessToken();
      if (refreshed) {
        token = await SecureStorage.getAccessToken();
        if (token != null) {
          response = await http.post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(body),
          );
        }
      }
    }

    // Handle final response
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Expecting backend to respond with the local IDs that were successfully saved
      final List<dynamic> syncedFreshLocalIds =
      (data["synced_fresh_local_ids"] ?? []) as List<dynamic>;
      final List<dynamic> syncedDriedLocalIds =
      (data["synced_dried_local_ids"] ?? []) as List<dynamic>;

      await dbHelper.markFreshListAsSynced(
        syncedFreshLocalIds.map((e) => e as int).toList(),
      );
      await dbHelper.markDriedListAsSynced(
        syncedDriedLocalIds.map((e) => e as int).toList(),
      );
    } else {
      throw Exception(
        "Sync failed (${response.statusCode}): ${response.body}",
      );
    }
  }
}

