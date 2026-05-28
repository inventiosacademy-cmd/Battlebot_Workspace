import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of a network-bound HTTP request.
class NetworkSendResult {
  final bool success;
  final String network; // 'wifi' or 'cellular'
  final int latencyMs;
  final int statusCode;
  final String? error;

  const NetworkSendResult({
    required this.success,
    required this.network,
    this.latencyMs = 0,
    this.statusCode = 0,
    this.error,
  });

  factory NetworkSendResult.fromMap(Map<dynamic, dynamic> map) {
    return NetworkSendResult(
      success: map['success'] as bool? ?? false,
      network: map['network'] as String? ?? 'unknown',
      latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
      statusCode: (map['statusCode'] as num?)?.toInt() ?? 0,
      error: map['error'] as String?,
    );
  }

  @override
  String toString() =>
      'NetworkSendResult(network: $network, success: $success, latencyMs: ${latencyMs}ms)';
}

/// Ping measurement result for a specific network.
class PingResult {
  final String network;
  final int pingMs;
  final bool available;

  const PingResult({
    required this.network,
    required this.pingMs,
    required this.available,
  });

  factory PingResult.fromMap(Map<dynamic, dynamic> map) {
    return PingResult(
      network: map['network'] as String? ?? 'unknown',
      pingMs: (map['pingMs'] as num?)?.toInt() ?? -1,
      available: map['available'] as bool? ?? false,
    );
  }
}

/// Native network status from Android ConnectivityManager.
class NativeNetworkStatus {
  final bool wifiAvailable;
  final bool cellularAvailable;
  final bool dualActive;

  const NativeNetworkStatus({
    this.wifiAvailable = false,
    this.cellularAvailable = false,
    this.dualActive = false,
  });

  bool get hasDual => wifiAvailable && cellularAvailable;

  factory NativeNetworkStatus.fromMap(Map<dynamic, dynamic> map) {
    return NativeNetworkStatus(
      wifiAvailable: map['wifiAvailable'] as bool? ?? false,
      cellularAvailable: map['cellularAvailable'] as bool? ?? false,
      dualActive: map['dualActive'] as bool? ?? false,
    );
  }
}

/// Flutter bridge to the native Android dual-network plugin.
///
/// Provides methods to:
/// - Keep both WiFi and Cellular active simultaneously
/// - Send HTTP requests bound to specific networks
/// - Measure per-network latency
/// - Listen for real-time network status changes
class DualNetworkChannel with ChangeNotifier {
  static const _methodChannel = MethodChannel('com.crashbot/dual_network');
  static const _eventChannel = EventChannel('com.crashbot/network_status');

  StreamSubscription? _eventSubscription;
  NativeNetworkStatus _nativeStatus = const NativeNetworkStatus();
  NativeNetworkStatus get nativeStatus => _nativeStatus;

  int _wifiPingMs = -1;
  int _cellularPingMs = -1;
  int get wifiPingMs => _wifiPingMs;
  int get cellularPingMs => _cellularPingMs;

  bool _isDualActive = false;
  bool get isDualActive => _isDualActive;

  /// The Firebase RTDB REST endpoint for rc_control.
  final String _firebaseDbUrl;

  DualNetworkChannel({required String firebaseDatabaseUrl})
      : _firebaseDbUrl = '$firebaseDatabaseUrl/rc_control.json';

  /// Start dual network mode — keeps both WiFi and Cellular active.
  Future<void> startDualNetwork() async {
    if (kIsWeb) return; // Not supported on web

    try {
      await _methodChannel.invokeMethod('startDualNetwork');
      _isDualActive = true;

      // Listen for native status updates
      _eventSubscription = _eventChannel
          .receiveBroadcastStream()
          .listen((event) {
        if (event is Map) {
          _nativeStatus = NativeNetworkStatus.fromMap(event);
          notifyListeners();
        }
      });

      // Initial status check
      await refreshStatus();
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: Failed to start — ${e.message}');
    }
  }

  /// Stop dual network mode.
  Future<void> stopDualNetwork() async {
    if (kIsWeb) return;

    try {
      await _methodChannel.invokeMethod('stopDualNetwork');
      _isDualActive = false;
      _eventSubscription?.cancel();
      _eventSubscription = null;
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: Failed to stop — ${e.message}');
    }
  }

  /// Refresh the native network status.
  Future<void> refreshStatus() async {
    try {
      final result = await _methodChannel.invokeMethod('getNetworkStatus');
      if (result is Map) {
        _nativeStatus = NativeNetworkStatus.fromMap(result);
        notifyListeners();
      }
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: Status check failed — ${e.message}');
    }
  }

  /// Send control data via WiFi only.
  Future<NetworkSendResult?> sendViaWifi(Map<String, dynamic> data) async {
    return _sendVia('sendViaWifi', data);
  }

  /// Send control data via Cellular only.
  Future<NetworkSendResult?> sendViaCellular(Map<String, dynamic> data) async {
    return _sendVia('sendViaCellular', data);
  }

  /// Send control data through BOTH networks simultaneously.
  /// This is the "network boost" — redundant sending for minimum latency.
  Future<List<NetworkSendResult>> sendViaBoth(Map<String, dynamic> data) async {
    if (kIsWeb) return [];

    try {
      final result = await _methodChannel.invokeMethod('sendViaBoth', {
        'url': _firebaseDbUrl,
        'body': jsonEncode(data),
      });

      if (result is Map && result['results'] is List) {
        return (result['results'] as List)
            .whereType<Map>()
            .map((m) => NetworkSendResult.fromMap(m))
            .toList();
      }
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: sendViaBoth failed — ${e.message}');
    }
    return [];
  }

  /// Measure latency on WiFi network.
  Future<PingResult> pingWifi() async {
    try {
      final result = await _methodChannel.invokeMethod('pingWifi');
      if (result is Map) {
        final ping = PingResult.fromMap(result);
        _wifiPingMs = ping.pingMs;
        notifyListeners();
        return ping;
      }
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: pingWifi failed — ${e.message}');
    }
    return const PingResult(network: 'wifi', pingMs: -1, available: false);
  }

  /// Measure latency on Cellular network.
  Future<PingResult> pingCellular() async {
    try {
      final result = await _methodChannel.invokeMethod('pingCellular');
      if (result is Map) {
        final ping = PingResult.fromMap(result);
        _cellularPingMs = ping.pingMs;
        notifyListeners();
        return ping;
      }
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: pingCellular failed — ${e.message}');
    }
    return const PingResult(network: 'cellular', pingMs: -1, available: false);
  }

  /// Measure ping on both networks simultaneously.
  Future<void> pingBoth() async {
    await Future.wait([pingWifi(), pingCellular()]);
  }

  Future<NetworkSendResult?> _sendVia(String method, Map<String, dynamic> data) async {
    if (kIsWeb) return null;

    try {
      final result = await _methodChannel.invokeMethod(method, {
        'url': _firebaseDbUrl,
        'body': jsonEncode(data),
      });

      if (result is Map) {
        return NetworkSendResult.fromMap(result);
      }
    } on PlatformException catch (e) {
      debugPrint('DualNetwork: $method failed — ${e.message}');
    }
    return null;
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
