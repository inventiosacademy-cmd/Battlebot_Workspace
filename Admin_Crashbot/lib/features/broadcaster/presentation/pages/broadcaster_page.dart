import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:rc_camera_server/core/constants/app_colors.dart';
import 'package:rc_camera_server/core/constants/app_sizes.dart';
import 'package:rc_camera_server/data/config/agora_config.dart';

/// Admin broadcaster page — streams local camera via Agora to remote viewers.
/// Features Arena Operations UI with Matchmaking Room synchronization.
class BroadcasterPage extends StatefulWidget {
  const BroadcasterPage({super.key});

  @override
  State<BroadcasterPage> createState() => _BroadcasterPageState();
}

class _BroadcasterPageState extends State<BroadcasterPage> {
  // Agora state
  late RtcEngine _engine;
  bool _isJoined = false;
  String _statusText = 'Menyiapkan Kamera...';
  bool _isError = false;

  List<VideoDeviceInfo> _cameras = [];
  String? _selectedCamera1Id;
  String? _selectedCamera2Id;

  // Firebase state
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  Map<dynamic, dynamic>? _p1Data;
  Map<dynamic, dynamic>? _p2Data;
  String _gameState = 'waiting';

  // Timer state
  Timer? _countdownTimer;
  int _secondsLeft = 180; // 03:00 default

  @override
  void initState() {
    super.initState();
    _initAgora();
    _initFirebaseListener();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _roomSubscription?.cancel();
    _leaveChannel();
    super.dispose();
  }

  void _initFirebaseListener() {
    _roomSubscription = FirebaseDatabase.instance.ref('matchmaking_room').onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        _p1Data = data?['player1'];
        _p2Data = data?['player2'];
        _gameState = data?['gameState'] ?? 'waiting';
      });
    });
  }

  void _startMatch() {
    FirebaseDatabase.instance.ref('matchmaking_room').update({'gameState': 'started'});
    // start local timer
    _secondsLeft = 180;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _resetSequence() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 180);
    FirebaseDatabase.instance.ref('matchmaking_room').update({'gameState': 'waiting'});
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await [Permission.camera].request();

      await _engine.initialize(
        const RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: _onJoinSuccess,
          onError: _onAgoraError,
        ),
      );

      await _engine.enableVideo();
      await _engine.disableAudio();
      
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      await _fetchCameras();
      await _configureVideoEncoder();
      await _engine.startPreview();
      await _joinChannel();
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      if (mounted) {
        setState(() {
          _isError = true;
          _statusText = 'Gagal memulai kamera: $e';
        });
      }
    }
  }

  void _onJoinSuccess(RtcConnection connection, int elapsed) {
    if (mounted) {
      setState(() {
        _isJoined = true;
        _statusText = 'Live Streaming Aktif!';
      });
    }
  }

  void _onAgoraError(ErrorCodeType err, String msg) {
    if (mounted) {
      setState(() {
        _isError = true;
        _statusText = 'Error Code: $err | Msg: $msg';
      });
    }
  }

  Future<void> _fetchCameras() async {
    try {
      final deviceManager = _engine.getVideoDeviceManager();
      final cameras = await deviceManager.enumerateVideoDevices();

      if (mounted) {
        setState(() {
          _cameras = cameras;
          if (_cameras.isNotEmpty) {
            _selectedCamera1Id = _cameras.first.deviceId;
            if (_cameras.length > 1) {
              _selectedCamera2Id = _cameras[1].deviceId;
            } else {
              _selectedCamera2Id = _cameras.first.deviceId;
            }
          }
        });
      }
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  Future<void> _switchCamera1(String? deviceId) async {
    if (deviceId == null) return;
    try {
      await _engine.getVideoDeviceManager().setDevice(deviceId);
      if (mounted) setState(() => _selectedCamera1Id = deviceId);
    } on Exception catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  Future<void> _switchCamera2(String? deviceId) async {
    if (deviceId == null) return;
    if (mounted) setState(() => _selectedCamera2Id = deviceId);
    // Note: Rendering a second local camera feed simultaneously requires 
    // advanced Agora multi-channel or custom track setup.
  }

  Future<void> _configureVideoEncoder() async {
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 1280, height: 720),
        frameRate: 30,
        bitrate: 0,
        degradationPreference: DegradationPreference.maintainFramerate,
        mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
      ),
    );
  }

  Future<void> _joinChannel() async {
    await _engine.joinChannel(
      token: AgoraConfig.token,
      channelId: AgoraConfig.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: false,
        autoSubscribeAudio: false,
        publishCameraTrack: true,
        publishMicrophoneTrack: false,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _leaveChannel() async {
    try {
      await _engine.stopPreview();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: Column(
        children: [
          // Top section (Cameras)
          Expanded(
            flex: 8, // ~45% height
            child: Row(
              children: [
                // Cam 1 (Live Agora Preview)
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        color: const Color(0xFF2E2E2E),
                        child: _isError
                            ? const Center(child: Text('Kamera Error', style: TextStyle(color: Colors.red)))
                            : _CameraPreview(isJoined: _isJoined, engine: _engine),
                      ),
                      const Positioned(
                        top: 15,
                        left: 15,
                        child: Text('CAM 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (_cameras.isNotEmpty)
                        Positioned(
                          top: 10,
                          right: 15,
                          child: _CameraDropdown(
                            cameras: _cameras,
                            selectedCameraId: _selectedCamera1Id,
                            onChanged: _switchCamera1,
                          ),
                        ),
                      if (_isJoined) const Positioned(bottom: 15, left: 15, child: _LiveIndicator()),
                    ],
                  ),
                ),
                // Divider
                Container(width: 2, color: const Color(0xFF1E1E1E)),
                // Cam 2 (Placeholder)
                Expanded(
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFF2E2E2E)),
                      const Positioned(
                        top: 15,
                        left: 15,
                        child: Text('CAM 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (_cameras.isNotEmpty)
                        Positioned(
                          top: 10,
                          right: 15,
                          child: _CameraDropdown(
                            cameras: _cameras,
                            selectedCameraId: _selectedCamera2Id,
                            onChanged: _switchCamera2,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Middle Section (ARENA OPERATIONS)
          Container(
            color: const Color(0xFFE5E5E5), // Light grey
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ARENA OPERATIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _PlayerStatusCard(playerLabel: 'P1', playerData: _p1Data)),
                    const SizedBox(width: 30),
                    Expanded(child: _PlayerStatusCard(playerLabel: 'P2', playerData: _p2Data)),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Section (Time & Start Match)
          Expanded(
            flex: 7, // ~40% height
            child: Container(
              color: const Color(0xFFF9F9F9),
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('TIME TO INITIALIZATION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5, fontSize: 12)),
                  Text(
                    '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 400,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Safety Interlocks', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 16),
                            const SizedBox(width: 4),
                            Text('Engaged', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: 400,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0), // Blue 800
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: const Text('START MATCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  GestureDetector(
                    onTap: _resetSequence,
                    child: const Text('RESET SEQUENCE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ─── Sub-widgets ───

class _CameraPreview extends StatelessWidget {
  final bool isJoined;
  final RtcEngine engine;

  const _CameraPreview({required this.isJoined, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isJoined
          ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: engine,
                canvas: const VideoCanvas(
                  uid: 0,
                  mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
                ),
              ),
            )
          : const CircularProgressIndicator(color: Colors.white54),
    );
  }
}

class _CameraDropdown extends StatelessWidget {
  final List<VideoDeviceInfo> cameras;
  final String? selectedCameraId;
  final ValueChanged<String?> onChanged;

  const _CameraDropdown({
    required this.cameras,
    required this.selectedCameraId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: Colors.grey[900],
          value: selectedCameraId,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          onChanged: onChanged,
          items: cameras.map((VideoDeviceInfo cam) {
            String name = cam.deviceName ?? 'Camera';
            if (name.length > 20) name = '${name.substring(0, 20)}...';
            return DropdownMenuItem<String>(
              value: cam.deviceId,
              child: Text(name),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.transparent, // Background was transparent in image
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerStatusCard extends StatelessWidget {
  final String playerLabel;
  final Map<dynamic, dynamic>? playerData;

  const _PlayerStatusCard({required this.playerLabel, this.playerData});

  @override
  Widget build(BuildContext context) {
    bool hasPlayer = playerData != null;
    String name = hasPlayer ? (playerData!['username'] ?? 'Team Unknown') : 'Awaiting Entry';
    bool isReady = hasPlayer ? (playerData!['isReady'] == true) : false;

    Color labelBgColor = hasPlayer ? const Color(0xFF1565C0) : const Color(0xFFD6D6D6); // Blue or Grey
    Color labelTextColor = hasPlayer ? Colors.white : Colors.black54;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            color: labelBgColor,
            width: 45,
            height: 45,
            alignment: Alignment.center,
            child: Text(playerLabel, style: TextStyle(color: labelTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hasPlayer ? Colors.black87 : Colors.grey[600]))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isReady ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isReady ? 'READY' : 'MENUNGGU',
              style: TextStyle(
                color: isReady ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          )
        ],
      ),
    );
  }
}
