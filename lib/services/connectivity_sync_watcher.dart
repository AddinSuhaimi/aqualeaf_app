import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_manager.dart';

class ConnectivitySyncWatcher {
  ConnectivitySyncWatcher._();
  static final ConnectivitySyncWatcher instance =
  ConnectivitySyncWatcher._();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  Future<void> start() async {
    if (_sub != null) return;

    final initial = await Connectivity().checkConnectivity();
    _wasOffline = _isOffline(initial);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offlineNow = _isOffline(results);

      // offline -> online transition
      if (_wasOffline && !offlineNow) {
        SyncManager.trySync();
      }

      _wasOffline = offlineNow;
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool _isOffline(List<ConnectivityResult> results) {
    final online = results.any((r) =>
    r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

    return !online;
  }
}
