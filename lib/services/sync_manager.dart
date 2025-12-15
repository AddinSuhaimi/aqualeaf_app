import 'sync_service.dart';

class SyncManager {
  static bool _syncing = false;
  static DateTime? _lastAttempt;

  static Future<void> trySync({
    Duration cooldown = const Duration(seconds: 30),
  }) async {
    if (_syncing) return;

    final now = DateTime.now();
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < cooldown) {
      return;
    }

    _syncing = true;
    _lastAttempt = now;

    try {
      await SyncService.syncPendingReports();
    } catch (_) {
      // swallow autosync errors to avoid UI crash
    } finally {
      _syncing = false;
    }
  }
}