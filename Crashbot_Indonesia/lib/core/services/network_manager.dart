import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:my_flutter_app/core/services/dual_network_channel.dart';

/// Represents the status of a single network interface.
enum NetworkStatus { connected, disconnected, unknown }

/// Sending mode for robot control commands.
enum NetworkSendMode {
  /// Send via the default system-chosen network (normal behavior).
  normal,

  /// Send only via WiFi (network-bound).
  wifiOnly,

  /// Send only via Cellular/SIM (network-bound).
  cellularOnly,

  /// Send via BOTH networks simultaneously for lowest latency.
  dual,
}

/// Information about the current network state including both WiFi and Mobile.
class NetworkInfo {
  final NetworkStatus wifiStatus;
  final NetworkStatus mobileStatus;
  final String? wifiName;
  final String activeNetwork; // 'wifi', 'mobile', 'none'
  final int wifiPingMs;
  final int cellularPingMs;

  const NetworkInfo({
    this.wifiStatus = NetworkStatus.unknown,
    this.mobileStatus = NetworkStatus.unknown,
    this.wifiName,
    this.activeNetwork = 'none',
    this.wifiPingMs = -1,
    this.cellularPingMs = -1,
  });

  bool get hasWifi => wifiStatus == NetworkStatus.connected;
  bool get hasMobile => mobileStatus == NetworkStatus.connected;
  bool get hasAnyConnection => hasWifi || hasMobile;
  bool get hasDualConnection => hasWifi && hasMobile;

  /// Returns a user-friendly label for the active connection.
  String get activeLabel {
    if (hasDualConnection) return 'Dual (WiFi + SIM)';
    if (hasWifi) return 'WiFi';
    if (hasMobile) return 'SIM/Seluler';
    return 'Tidak ada jaringan';
  }

  /// Returns the best (lowest) ping among available networks.
  int get bestPingMs {
    if (hasWifi && hasMobile) {
      if (wifiPingMs >= 0 && cellularPingMs >= 0) {
        return wifiPingMs < cellularPingMs ? wifiPingMs : cellularPingMs;
      }
      return wifiPingMs >= 0 ? wifiPingMs : cellularPingMs;
    }
    if (hasWifi) return wifiPingMs;
    if (hasMobile) return cellularPingMs;
    return -1;
  }

  NetworkInfo copyWith({
    NetworkStatus? wifiStatus,
    NetworkStatus? mobileStatus,
    String? wifiName,
    String? activeNetwork,
    int? wifiPingMs,
    int? cellularPingMs,
  }) {
    return NetworkInfo(
      wifiStatus: wifiStatus ?? this.wifiStatus,
      mobileStatus: mobileStatus ?? this.mobileStatus,
      wifiName: wifiName ?? this.wifiName,
      activeNetwork: activeNetwork ?? this.activeNetwork,
      wifiPingMs: wifiPingMs ?? this.wifiPingMs,
      cellularPingMs: cellularPingMs ?? this.cellularPingMs,
    );
  }
}

/// Manages dual network monitoring (WiFi + SIM/Mobile).
/// Integrates with native Android platform channel for true dual-network support.
class NetworkManager with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Native dual-network channel for network-bound sending.
  late final DualNetworkChannel _dualChannel;
  DualNetworkChannel get dualChannel => _dualChannel;

  NetworkInfo _networkInfo = const NetworkInfo();
  NetworkInfo get networkInfo => _networkInfo;

  /// Current send mode.
  NetworkSendMode _sendMode = NetworkSendMode.normal;
  NetworkSendMode get sendMode => _sendMode;

  /// Tracks if we've ever been initialized.
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Whether native dual-network is active.
  bool get isDualActive => _dualChannel.isDualActive;

  /// Timer for periodic ping measurement.
  Timer? _pingTimer;

  /// History of network events for debugging / UI display.
  final List<NetworkEvent> _eventLog = [];
  List<NetworkEvent> get eventLog => List.unmodifiable(_eventLog);

  NetworkManager({required String firebaseDatabaseUrl}) {
    _dualChannel = DualNetworkChannel(firebaseDatabaseUrl: firebaseDatabaseUrl);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _processConnectivityResults(results);
      _initialized = true;

      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _processConnectivityResults(results);
      });

      // Start native dual network
      if (!kIsWeb) {
        await _dualChannel.startDualNetwork();
        _addEvent('Dual Network diaktifkan', NetworkEventType.connected);

        // Listen for native status changes
        _dualChannel.addListener(_onNativeStatusChanged);

        // Start periodic ping measurement (every 3 seconds)
        _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _measurePings();
        });

        // Initial ping measurement
        _measurePings();
      }
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  void _onNativeStatusChanged() {
    final nativeStatus = _dualChannel.nativeStatus;

    final oldInfo = _networkInfo;

    // Use native status as truth when dual network is active
    final hasWifi = nativeStatus.wifiAvailable;
    final hasMobile = nativeStatus.cellularAvailable;

    String activeNetwork;
    if (hasWifi) {
      activeNetwork = 'wifi';
    } else if (hasMobile) {
      activeNetwork = 'mobile';
    } else {
      activeNetwork = 'none';
    }

    _networkInfo = _networkInfo.copyWith(
      wifiStatus: hasWifi ? NetworkStatus.connected : NetworkStatus.disconnected,
      mobileStatus: hasMobile ? NetworkStatus.connected : NetworkStatus.disconnected,
      activeNetwork: activeNetwork,
      wifiPingMs: _dualChannel.wifiPingMs,
      cellularPingMs: _dualChannel.cellularPingMs,
    );

    // Log native connection changes
    if (oldInfo.hasWifi != _networkInfo.hasWifi) {
      _addEvent(
        _networkInfo.hasWifi ? 'WiFi terhubung (Native)' : 'WiFi terputus (Native)',
        _networkInfo.hasWifi ? NetworkEventType.connected : NetworkEventType.disconnected,
      );
    }
    if (oldInfo.hasMobile != _networkInfo.hasMobile) {
      _addEvent(
        _networkInfo.hasMobile ? 'SIM/Seluler terhubung (Native)' : 'SIM/Seluler terputus (Native)',
        _networkInfo.hasMobile ? NetworkEventType.connected : NetworkEventType.disconnected,
      );
    }

    notifyListeners();
  }

  Future<void> _measurePings() async {
    if (kIsWeb) return;

    try {
      await _dualChannel.pingBoth();

      _networkInfo = _networkInfo.copyWith(
        wifiPingMs: _dualChannel.wifiPingMs,
        cellularPingMs: _dualChannel.cellularPingMs,
      );

      notifyListeners();
    } on Exception catch (_) {
      // Silently handle ping failures
    }
  }

  /// Change the sending mode.
  void setSendMode(NetworkSendMode mode) {
    _sendMode = mode;
    _addEvent(
      'Mode pengiriman: ${_sendModeLabel(mode)}',
      NetworkEventType.connected,
    );
    notifyListeners();
  }

  String _sendModeLabel(NetworkSendMode mode) {
    switch (mode) {
      case NetworkSendMode.normal:
        return 'Normal';
      case NetworkSendMode.wifiOnly:
        return 'WiFi Only';
      case NetworkSendMode.cellularOnly:
        return 'SIM Only';
      case NetworkSendMode.dual:
        return 'Dual (Boost)';
    }
  }

  /// Send control data using the current send mode.
  /// Returns true if at least one send succeeded.
  Future<bool> sendControlData(Map<String, dynamic> data) async {
    if (kIsWeb) return false;

    switch (_sendMode) {
      case NetworkSendMode.normal:
        // Use default Flutter/Firebase SDK (no network binding)
        return true; // Handled by ControlProvider directly
      case NetworkSendMode.wifiOnly:
        final result = await _dualChannel.sendViaWifi(data);
        return result?.success ?? false;
      case NetworkSendMode.cellularOnly:
        final result = await _dualChannel.sendViaCellular(data);
        return result?.success ?? false;
      case NetworkSendMode.dual:
        final results = await _dualChannel.sendViaBoth(data);
        return results.any((r) => r.success);
    }
  }

  void _processConnectivityResults(List<ConnectivityResult> results) {
    final hasWifi = results.contains(ConnectivityResult.wifi);
    final hasMobile = results.contains(ConnectivityResult.mobile);

    // Determine active network priority: wifi > mobile > none
    String activeNetwork;
    if (hasWifi) {
      activeNetwork = 'wifi';
    } else if (hasMobile) {
      activeNetwork = 'mobile';
    } else {
      activeNetwork = 'none';
    }

    final oldInfo = _networkInfo;
    _networkInfo = _networkInfo.copyWith(
      wifiStatus: hasWifi ? NetworkStatus.connected : NetworkStatus.disconnected,
      mobileStatus: hasMobile ? NetworkStatus.connected : NetworkStatus.disconnected,
      activeNetwork: activeNetwork,
    );

    // Log significant events
    if (oldInfo.hasWifi != _networkInfo.hasWifi) {
      _addEvent(
        _networkInfo.hasWifi ? 'WiFi terhubung' : 'WiFi terputus',
        _networkInfo.hasWifi ? NetworkEventType.connected : NetworkEventType.disconnected,
      );
    }
    if (oldInfo.hasMobile != _networkInfo.hasMobile) {
      _addEvent(
        _networkInfo.hasMobile ? 'SIM/Seluler terhubung' : 'SIM/Seluler terputus',
        _networkInfo.hasMobile ? NetworkEventType.connected : NetworkEventType.disconnected,
      );
    }

    // Failover detection
    if (oldInfo.hasWifi && !_networkInfo.hasWifi && _networkInfo.hasMobile) {
      _addEvent('Failover: beralih ke SIM/Seluler', NetworkEventType.failover);
    } else if (oldInfo.hasMobile && !_networkInfo.hasMobile && _networkInfo.hasWifi) {
      _addEvent('Failover: beralih ke WiFi', NetworkEventType.failover);
    }

    notifyListeners();
  }

  void _addEvent(String message, NetworkEventType type) {
    _eventLog.insert(0, NetworkEvent(
      message: message,
      type: type,
      timestamp: DateTime.now(),
    ));
    // Keep only the last 20 events
    if (_eventLog.length > 20) {
      _eventLog.removeRange(20, _eventLog.length);
    }
  }

  /// Force refresh the connectivity check and pings.
  Future<void> refresh() async {
    final results = await _connectivity.checkConnectivity();
    _processConnectivityResults(results);
    await _measurePings();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pingTimer?.cancel();
    _dualChannel.removeListener(_onNativeStatusChanged);
    _dualChannel.stopDualNetwork();
    _dualChannel.dispose();
    super.dispose();
  }
}

/// Types of network events for logging.
enum NetworkEventType { connected, disconnected, failover }

/// A single network event log entry.
class NetworkEvent {
  final String message;
  final NetworkEventType type;
  final DateTime timestamp;

  const NetworkEvent({
    required this.message,
    required this.type,
    required this.timestamp,
  });
}
