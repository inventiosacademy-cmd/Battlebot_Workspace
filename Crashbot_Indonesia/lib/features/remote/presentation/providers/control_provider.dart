import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'package:my_flutter_app/core/services/network_manager.dart';

/// Manages robot directional control state and syncs with Firebase RTDB.
/// Each direction (forward, backward, left, right) is represented as 0 or 1.
///
/// When dual-network mode is active, commands are sent through both WiFi
/// and Cellular simultaneously via the native platform channel for
/// minimum latency (network boost).
class ControlProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Reference to the NetworkManager for dual-network sending.
  NetworkManager? _networkManager;

  ControlProvider() {
    _dbRef.child('rc_control').keepSynced(true);
  }

  /// Attach the NetworkManager for dual-network support.
  void attachNetworkManager(NetworkManager manager) {
    _networkManager = manager;
  }

  int _f = 0;
  int _b = 0;
  int _l = 0;
  int _r = 0;
  int _s = 0;

  int get f => _f;
  int get b => _b;
  int get l => _l;
  int get r => _r;
  int get s => _s;

  /// Updates a directional control value and syncs to Firebase.
  ///
  /// [direction] must be one of: "F", "B", "L", "R", "S".
  /// [isPressed] toggles the value between 1 (pressed) and 0 (released).
  void updateDirection(String direction, {required bool isPressed}) {
    final int value = isPressed ? 1 : 0;

    switch (direction) {
      case 'F':
        _f = value;
      case 'B':
        _b = value;
      case 'L':
        _l = value;
      case 'R':
        _r = value;
      case 'S':
        _s = value;
    }

    notifyListeners();
    _syncWithFirebase();
  }

  void _syncWithFirebase() {
    final data = {'F': _f, 'B': _b, 'L': _l, 'R': _r, 'S': _s};
    final manager = _networkManager;

    if (manager != null && manager.sendMode != NetworkSendMode.normal) {
      // Use native network-bound sending (dual network boost)
      manager.sendControlData(data);
    }

    // Always also send via the normal Firebase SDK as a fallback.
    // Firebase SDK uses the OS-default network, so this ensures
    // at least one path always works.
    _dbRef.child('rc_control').update(data);
  }
}
