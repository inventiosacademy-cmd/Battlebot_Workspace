import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/widgets/control_button.dart';
import 'package:my_flutter_app/core/widgets/dual_network_indicator.dart';
import 'package:my_flutter_app/core/services/audio_manager.dart';
import 'package:my_flutter_app/data/config/agora_config.dart';
import 'package:my_flutter_app/features/remote/presentation/providers/control_provider.dart';

/// Remote control page with live camera feed from Agora and directional buttons.
class RemotePage extends StatefulWidget {
  const RemotePage({super.key});

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  late RtcEngine _engine;
  bool _isJoined = false;
  int? _remoteUid;
  bool _isError = false;
  int _pingMs = 0;
  
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  bool _isExiting = false;
  late AudioManager _audioManager;
  String? _mySlot;

  @override
  void initState() {
    super.initState();
    _audioManager = Provider.of<AudioManager>(context, listen: false);
    _initAgora();
    _setupPresence();
    _initFirebaseListener();
  }

  Future<void> _setupPresence() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    
    final ref = FirebaseDatabase.instance.ref('matchmaking_room');
    final snapshot = await ref.get();
    if (snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final p1 = data['player1'] as Map<dynamic, dynamic>?;
      final p2 = data['player2'] as Map<dynamic, dynamic>?;
      
      if (p1 != null && p1['uid'] == user.uid) _mySlot = 'player1';
      else if (p2 != null && p2['uid'] == user.uid) _mySlot = 'player2';
      
      if (_mySlot != null) {
        ref.child(_mySlot!).onDisconnect().remove();
        ref.child('gameState').onDisconnect().set('waiting');
      }
    }
  }

  void _initFirebaseListener() {
    _roomSubscription = FirebaseDatabase.instance.ref('matchmaking_room').onValue.listen((event) {
      if (_isExiting || !mounted) return;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
         _showOpponentLeftDialog("Room ditutup oleh server.");
         return;
      }
      
      final p1 = data['player1'];
      final p2 = data['player2'];
      final gameState = data['gameState'];
      
      if (gameState != 'started') {
         _showOpponentLeftDialog("Permainan dihentikan.");
      } else if (p1 == null || p2 == null) {
         _showOpponentLeftDialog("Lawan keluar dari permainan.");
      }
    });
  }

  void _showOpponentLeftDialog(String reason) {
    if (!mounted || _isExiting) return;
    setState(() => _isExiting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Permainan Selesai', style: TextStyle(color: Colors.white)),
        content: Text(reason, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); 
              Navigator.of(context).pop(); 
            },
            child: const Text('KEMBALI KE LOBBY', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cleanupPresence();
    _roomSubscription?.cancel();
    _leaveChannel();
    _audioManager.startLobbyMusic();
    super.dispose();
  }

  void _cleanupPresence() {
    if (_mySlot != null) {
      final ref = FirebaseDatabase.instance.ref('matchmaking_room');
      ref.child(_mySlot!).remove();
      ref.child(_mySlot!).onDisconnect().cancel();
      ref.update({'gameState': 'waiting'});
      ref.child('gameState').onDisconnect().cancel();
    }
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(
        const RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: _onJoinChannelSuccess,
          onUserJoined: _onUserJoined,
          onUserOffline: _onUserOffline,
          onError: _onAgoraError,
          onRtcStats: _onRtcStats,
        ),
      );

      await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);

      int randomUid = DateTime.now().millisecondsSinceEpoch % 1000000;
      await _engine.joinChannel(
        token: AgoraConfig.token,
        channelId: AgoraConfig.channelName,
        uid: randomUid,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: false,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      if (mounted) setState(() => _isError = true);
    }
  }

  void _onJoinChannelSuccess(RtcConnection connection, int elapsed) {
    if (mounted) setState(() => _isJoined = true);
  }

  void _onUserJoined(RtcConnection connection, int remoteUid, int elapsed) {
    if (mounted) setState(() => _remoteUid = remoteUid);
  }

  void _onUserOffline(
    RtcConnection connection,
    int remoteUid,
    UserOfflineReasonType reason,
  ) {
    if (_remoteUid == remoteUid && mounted) {
      setState(() => _remoteUid = null);
    }
  }

  void _onAgoraError(ErrorCodeType err, String msg) {
    if (mounted) setState(() => _isError = true);
  }

  void _onRtcStats(RtcConnection connection, RtcStats stats) {
    if (mounted) setState(() => _pingMs = stats.lastmileDelay ?? 0);
  }

  Future<void> _leaveChannel() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = Provider.of<ControlProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = constraints.biggest.shortestSide;
            final isCompact = shortestSide < 360;
            final buttonSize = isCompact
                ? AppSizes.controlButtonSmall
                : AppSizes.controlButtonDefault;
            final sideOffset = isCompact ? 24.0 : 60.0;
            final bottomOffset = isCompact ? 20.0 : 40.0;
            final buttonGap = isCompact ? 18.0 : 30.0;

            return Stack(
              children: [
                Positioned.fill(
                  child: _CameraBackground(
                    isError: _isError,
                    isJoined: _isJoined,
                    remoteUid: _remoteUid,
                    engine: _isError ? null : _engine,
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
                ),
                Positioned(
                  top: AppSizes.spacingLg,
                  left: AppSizes.spacingLg,
                  child: _BackButton(onTap: () => Navigator.pop(context)),
                ),
                Positioned(
                  top: AppSizes.spacingLg,
                  right: AppSizes.spacingLg,
                  child: DualNetworkIndicator(
                    isAgoraError: _isError,
                    isAgoraConnected: _isJoined,
                    hasRemoteUser: _remoteUid != null,
                    customPingMs: _pingMs,
                  ),
                ),
                _LeftControls(
                  sideOffset: sideOffset,
                  bottomOffset: bottomOffset,
                  buttonSize: buttonSize,
                  buttonGap: buttonGap,
                  control: control,
                ),
                _RightControls(
                  sideOffset: sideOffset,
                  bottomOffset: bottomOffset,
                  buttonSize: buttonSize,
                  buttonGap: buttonGap,
                  control: control,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Sub-widgets ───

class _CameraBackground extends StatelessWidget {
  final bool isError;
  final bool isJoined;
  final int? remoteUid;
  final RtcEngine? engine;

  const _CameraBackground({
    required this.isError,
    required this.isJoined,
    required this.remoteUid,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return const Center(
        child: Text(
          'Gagal memuat kamera',
          style: TextStyle(color: AppColors.dangerRed),
        ),
      );
    }

    if (remoteUid == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: AppSizes.spacingXl),
            Text(
              isJoined
                  ? 'Menunggu Server Kamera...'
                  : 'Menghubungkan ke Agora...',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine!,
        canvas: VideoCanvas(
          uid: remoteUid,
          mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
        ),
        connection: const RtcConnection(channelId: AgoraConfig.channelName),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppSizes.backButtonSize,
        height: AppSizes.backButtonSize,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white70,
          size: AppSizes.iconXl,
        ),
      ),
    );
  }
}

// _ConnectionIndicator removed — replaced by DualNetworkIndicator widget.

class _LeftControls extends StatelessWidget {
  final double sideOffset;
  final double bottomOffset;
  final double buttonSize;
  final double buttonGap;
  final ControlProvider control;

  const _LeftControls({
    required this.sideOffset,
    required this.bottomOffset,
    required this.buttonSize,
    required this.buttonGap,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: sideOffset,
      bottom: bottomOffset,
      child: Column(
        children: [
          ControlButton(
            size: buttonSize,
            icon: Icons.expand_less,
            color: AppColors.lightBlue,
            onTapDown: () => control.updateDirection('F', isPressed: true),
            onTapUp: () => control.updateDirection('F', isPressed: false),
          ),
          SizedBox(height: buttonGap),
          ControlButton(
            size: buttonSize,
            icon: Icons.expand_more,
            color: AppColors.lightBlue,
            onTapDown: () => control.updateDirection('B', isPressed: true),
            onTapUp: () => control.updateDirection('B', isPressed: false),
          ),
        ],
      ),
    );
  }
}

class _RightControls extends StatelessWidget {
  final double sideOffset;
  final double bottomOffset;
  final double buttonSize;
  final double buttonGap;
  final ControlProvider control;

  const _RightControls({
    required this.sideOffset,
    required this.bottomOffset,
    required this.buttonSize,
    required this.buttonGap,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: sideOffset,
      bottom: bottomOffset,
      child: Column(
        children: [
          ControlButton(
            size: buttonSize,
            icon: Icons.chevron_left,
            color: AppColors.dangerRed,
            onTapDown: () => control.updateDirection('L', isPressed: true),
            onTapUp: () => control.updateDirection('L', isPressed: false),
          ),
          SizedBox(height: buttonGap),
          ControlButton(
            size: buttonSize,
            icon: Icons.chevron_right,
            color: AppColors.dangerRed,
            onTapDown: () => control.updateDirection('R', isPressed: true),
            onTapUp: () => control.updateDirection('R', isPressed: false),
          ),
        ],
      ),
    );
  }
}
