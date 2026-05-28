import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/lobby_top_bar.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/lobby_sidebar.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/settings_dialog.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/lobby_center_arena.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/lobby_leaderboard.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/moving_background_painter.dart';

import 'package:my_flutter_app/core/services/audio_manager.dart';

/// Main lobby page — the home screen after authentication.
/// Orchestrates realtime battery/connectivity/ping monitoring
/// and delegates UI to extracted sub-widgets.
class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> with TickerProviderStateMixin {
  String _selectedTab = 'GUIDE';

  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _floatController;
  late final AnimationController _backgroundController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _floatAnimation;

  // Realtime: Battery
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  Timer? _batteryTimer;
  StreamSubscription<BatteryState>? _batterySubscription;

  // Realtime: Connectivity
  List<ConnectivityResult> _connectivityResult = [ConnectivityResult.wifi];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Realtime: Ping
  int _lobbyPingMs = 0;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initAnimations();
    _initBattery();
    _initConnectivity();
    _initPing();
    _checkUsernameAndPrompt();
    
    // Start background lobby music
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AudioManager>().startLobbyMusic();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _backgroundController.dispose();
    _batteryTimer?.cancel();
    _batterySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  // ─── Animation Setup ───

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  // ─── Battery Monitoring ───

  Future<void> _initBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      if (mounted) setState(() {});

      _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
        if (mounted) {
          setState(() => _batteryState = state);
          _battery.batteryLevel.then((level) {
            if (mounted) setState(() => _batteryLevel = level);
          });
        }
      });

      _batteryTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollBatteryLevel(),
      );
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      if (mounted) setState(() => _batteryLevel = -1);
    }
  }

  Future<void> _pollBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _batteryState = state;
        });
      }
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  // ─── Connectivity Monitoring ───

  Future<void> _initConnectivity() async {
    try {
      _connectivityResult = await Connectivity().checkConnectivity();
      if (mounted) setState(() {});

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        result,
      ) {
        if (mounted) setState(() => _connectivityResult = result);
      });
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      if (mounted) {
        setState(() => _connectivityResult = [ConnectivityResult.none]);
      }
    }
  }

  // ─── Ping Monitoring ───

  Future<void> _initPing() async {
    await _performPing();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _performPing(),
    );
  }

  Future<void> _performPing() async {
    if (_connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) setState(() => _lobbyPingMs = 0);
      return;
    }
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      stopwatch.stop();
      socket.destroy();
      if (mounted) {
        setState(() => _lobbyPingMs = stopwatch.elapsedMilliseconds);
      }
    } on Exception catch (_) {
      if (mounted) setState(() => _lobbyPingMs = 999);
    }
  }

  // ─── Battery & Signal Helpers ───

  IconData get _batteryIcon {
    if (_batteryState == BatteryState.charging) {
      return Icons.battery_charging_full;
    }
    if (_batteryLevel < 0) return Icons.battery_unknown;
    if (_batteryLevel > 80) return Icons.battery_full;
    if (_batteryLevel > 60) return Icons.battery_5_bar;
    if (_batteryLevel > 40) return Icons.battery_4_bar;
    if (_batteryLevel > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  String get _batteryText {
    if (_batteryLevel < 0) return '??%';
    return '$_batteryLevel%';
  }

  IconData get _signalIcon {
    if (_connectivityResult.contains(ConnectivityResult.wifi)) {
      return Icons.wifi;
    }
    if (_connectivityResult.contains(ConnectivityResult.mobile)) {
      return Icons.signal_cellular_alt;
    }
    if (_connectivityResult.contains(ConnectivityResult.ethernet)) {
      return Icons.lan;
    }
    if (_connectivityResult.contains(ConnectivityResult.none)) {
      return Icons.signal_wifi_off;
    }
    return Icons.signal_cellular_alt;
  }

  Color get _signalColor {
    if (_connectivityResult.contains(ConnectivityResult.none) ||
        _lobbyPingMs == 999) {
      return AppColors.dangerRed;
    }
    if (_lobbyPingMs > 0 && _lobbyPingMs <= 100) {
      return AppColors.successGreen;
    }
    if (_lobbyPingMs > 100 && _lobbyPingMs <= 200) {
      return AppColors.warningYellow;
    }
    if (_lobbyPingMs > 200) return AppColors.dangerRed;
    return AppColors.successGreen;
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [_buildBackground(), _buildMainLayout()]),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return CustomPaint(
            painter: MovingBackgroundPainter(_backgroundController.value),
          );
        },
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      children: [
        const SizedBox(height: AppSizes.spacingSm),
        LobbyTopBar(
          batteryLevel: _batteryLevel,
          batteryIcon: _batteryIcon,
          batteryColor: AppColors.batteryGreen,
          batteryText: _batteryText,
          signalIcon: _signalIcon,
          signalColor: _signalColor,
          pingMs: _lobbyPingMs,
        ),
        Expanded(
          child: Row(
            children: [
              LobbySidebar(
                selectedTab: _selectedTab,
                onTabChanged: (tab) {
                  if (tab == 'PENGATURAN') {
                    SettingsDialog.show(context);
                  } else {
                    setState(() => _selectedTab = tab);
                  }
                },
              ),
              Expanded(
                child: LobbyCenterArena(
                  pulseAnimation: _pulseAnimation,
                  floatAnimation: _floatAnimation,
                ),
              ),
              const LobbyLeaderboard(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Username Setup Pop-up Check ───

  Future<void> _checkUsernameAndPrompt() async {
    // Tunggu render page siap & map context aman
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        final hasSet = data?['hasSetUsername'] == true;
        final currentUsername = data?['username'] as String?;

        if (!hasSet || currentUsername == null || currentUsername.trim().isEmpty || currentUsername == 'Player') {
          if (mounted) {
            _showUsernameSetupDialog(user.uid, data?['playerId']);
          }
        }
      } else {
        if (mounted) {
          _showUsernameSetupDialog(user.uid, null);
        }
      }
    } catch (e) {
      debugPrint("Error checking username setup: $e");
    }
  }

  void _showUsernameSetupDialog(String uid, String? existingPlayerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: _UsernameSetupCard(
              uid: uid,
              existingPlayerId: existingPlayerId,
              onSuccess: () => Navigator.pop(dialogContext),
            ),
          ),
        );
      },
    );
  }
}

/// Panel dialog kustomisasi username pertama kali yang non-dismissible & premium.
class _UsernameSetupCard extends StatefulWidget {
  final String uid;
  final String? existingPlayerId;
  final VoidCallback onSuccess;

  const _UsernameSetupCard({
    required this.uid,
    required this.existingPlayerId,
    required this.onSuccess,
  });

  @override
  State<_UsernameSetupCard> createState() => _UsernameSetupCardState();
}

class _UsernameSetupCardState extends State<_UsernameSetupCard> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Username tidak boleh kosong');
      return;
    }
    if (name.length < 3) {
      setState(() => _errorMessage = 'Username minimal 3 karakter');
      return;
    }
    if (name.toLowerCase() == 'player') {
      setState(() => _errorMessage = 'Gunakan nama unik selain "Player"');
      return;
    }

    final validCharacters = RegExp(r'^[a-zA-Z0-9 ]+$');
    if (!validCharacters.hasMatch(name)) {
      setState(() => _errorMessage = 'Hanya huruf, angka, dan spasi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String playerId = widget.existingPlayerId ?? 'CB-${10000 + Random().nextInt(90000)}';

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'username': name,
        'hasSetUsername': true,
        'playerId': playerId,
      }, SetOptions(merge: true));

      widget.onSuccess();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal menyimpan: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1F),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(
          color: AppColors.accentBlue.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSizes.spacingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(
              Icons.stars,
              color: AppColors.accentBlue,
              size: 44,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          const Center(
            child: Text(
              'SET NICKNAME',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            'Username ini bersifat permanen dan tidak dapat diubah lagi. Silakan masukkan nama pemain kamu!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: AppSizes.fontBase,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXl),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.dangerRed,
                  AppColors.primaryBlue,
                ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            padding: const EdgeInsets.all(1.5),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF070B19),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl - 1.5),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                maxLength: 16,
                decoration: InputDecoration(
                  labelText: 'Nama Pemain',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.videogame_asset, color: AppColors.accentBlue),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSizes.spacingMd),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.dangerRed,
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSizes.spacingXl),
          Container(
            height: AppSizes.lobbyButtonHeight - 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.dangerRed,
                  AppColors.primaryBlue,
                ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'SIMPAN USERNAME',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
