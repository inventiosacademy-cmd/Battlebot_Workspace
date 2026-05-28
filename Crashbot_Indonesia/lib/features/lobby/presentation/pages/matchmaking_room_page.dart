import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/constants/app_routes.dart';
import 'package:my_flutter_app/core/services/audio_manager.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/moving_background_painter.dart';
import 'package:my_flutter_app/features/profile/presentation/widgets/game_profile_avatar.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

/// Matchmaking or Waiting Room page before entering the actual remote control arena.
class MatchmakingRoomPage extends StatefulWidget {
  const MatchmakingRoomPage({super.key});

  @override
  State<MatchmakingRoomPage> createState() => _MatchmakingRoomPageState();
}

class _MatchmakingRoomPageState extends State<MatchmakingRoomPage>
    with TickerProviderStateMixin {
  late final AnimationController _backgroundController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final DatabaseReference _roomRef = FirebaseDatabase.instance.ref('matchmaking_room');
  
  String? _mySlot;
  Map<String, dynamic>? _player1Data;
  Map<String, dynamic>? _player2Data;
  String _gameState = 'waiting';
  bool _isFull = false;
  StreamSubscription<DatabaseEvent>? _roomSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _joinRoom();
  }

  Future<void> _joinRoom() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    String username = 'USER';
    
    // Fetch user profile from Firestore once for username
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      username = userDoc.data()?['username'] ?? 'USER';
    }
    String avatarAsset = profile.avatarAsset;

    final myData = {
      'uid': user.uid,
      'username': username,
      'avatarAsset': avatarAsset,
      'isReady': false,
      'joinedAt': ServerValue.timestamp,
    };

    final transactionResult = await _roomRef.runTransaction((Object? roomData) {
      Map<String, dynamic> room = {};
      if (roomData != null) {
        room = Map<String, dynamic>.from(roomData as Map);
      }
      
      final p1 = room['player1'];
      final p2 = room['player2'];
      
      if (p1 != null && (p1 as Map)['uid'] == user.uid) {
        room['player1'] = myData; 
      } else if (p2 != null && (p2 as Map)['uid'] == user.uid) {
        room['player2'] = myData;
      } else if (p1 == null) {
        room['player1'] = myData;
      } else if (p2 == null) {
        room['player2'] = myData;
      } else {
        return Transaction.abort();
      }
      return Transaction.success(room);
    });

    if (!transactionResult.committed) {
      if (mounted) {
        setState(() => _isFull = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room penuh! Tidak dapat masuk.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final room = transactionResult.snapshot.value as Map<dynamic, dynamic>?;
    final p1 = room?['player1'];
    final p2 = room?['player2'];
    if (p1 != null && p1['uid'] == user.uid) {
      _mySlot = 'player1';
    } else if (p2 != null && p2['uid'] == user.uid) {
      _mySlot = 'player2';
    }

    if (_mySlot != null) {
      _roomRef.child(_mySlot!).onDisconnect().remove();
    }

    _roomSubscription = _roomRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        if (mounted) {
          setState(() {
            _player1Data = data['player1'] != null ? Map<String, dynamic>.from(data['player1'] as Map) : null;
            _player2Data = data['player2'] != null ? Map<String, dynamic>.from(data['player2'] as Map) : null;
            _gameState = data['gameState']?.toString() ?? 'waiting';
          });
          
          if (_gameState == 'started') {
            _startGame();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _player1Data = null;
            _player2Data = null;
            _gameState = 'waiting';
          });
        }
      }
    });
  }

  void _startGame() async {
    if (_roomSubscription != null) {
      await _roomSubscription?.cancel();
      _roomSubscription = null;
    }
    if (_mySlot != null) {
      _roomRef.child(_mySlot!).onDisconnect().cancel();
    }
    
    final audioManager = Provider.of<AudioManager>(context, listen: false);
    await audioManager.pauseLobbyMusic();

    if (mounted) {
      await Navigator.pushReplacementNamed(context, AppRoutes.remote);
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    _roomSubscription?.cancel();
    if (_mySlot != null && _gameState != 'started') {
      _roomRef.child(_mySlot!).remove();
      _roomRef.child(_mySlot!).onDisconnect().cancel();
    }
    super.dispose();
  }

  void _onReadyPressed() async {
    if (_mySlot == null) return;
    
    bool isCurrentlyReady = false;
    if (_mySlot == 'player1' && _player1Data != null) {
      isCurrentlyReady = _player1Data!['isReady'] ?? false;
    } else if (_mySlot == 'player2' && _player2Data != null) {
      isCurrentlyReady = _player2Data!['isReady'] ?? false;
    }

    await _roomRef.child(_mySlot!).update({'isReady': !isCurrentlyReady});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: Center(
                    child: _buildVersusSection(),
                  ),
                ),
                _buildReadyButton(),
                const SizedBox(height: AppSizes.spacingXl),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spacingSm),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          const Text(
            'MATCHMAKING ROOM',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersusSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left Slot: Player 1
        _buildSlot(_player1Data, 'player1'),

        // VS Icon
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingXxl),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: AppColors.dangerRed,
                    shadows: [
                      Shadow(
                        color: AppColors.dangerRed.withValues(alpha: 0.6),
                        blurRadius: 15,
                      ),
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 5,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Right Slot: Player 2
        _buildSlot(_player2Data, 'player2'),
      ],
    );
  }

  Widget _buildSlot(Map<String, dynamic>? data, String slotKey) {
    if (data == null) {
      return const _PlayerSlot(
        username: 'MENUNGGU...',
        avatarAsset: 'assets/avatar2.png',
        isCurrentPlayer: false,
        isReady: false,
      );
    }

    final bool isMe = slotKey == _mySlot;
    return _PlayerSlot(
      username: data['username'] ?? 'USER',
      avatarAsset: data['avatarAsset'] ?? 'assets/avatar1.png',
      isCurrentPlayer: isMe,
      isReady: data['isReady'] ?? false,
    );
  }

  Widget _buildReadyButton() {
    bool isReady = false;
    if (_mySlot == 'player1' && _player1Data != null) {
      isReady = _player1Data!['isReady'] ?? false;
    } else if (_mySlot == 'player2' && _player2Data != null) {
      isReady = _player2Data!['isReady'] ?? false;
    }

    final buttonColor = isReady ? AppColors.successGreen : AppColors.primaryBlue;
    final buttonGradient = isReady 
      ? [AppColors.successGreen, Colors.green[700]!] 
      : [AppColors.primaryBlue, AppColors.royalBlue];
    final buttonText = isReady ? 'BATAL READY' : 'READY';

    return GestureDetector(
      onTap: _onReadyPressed,
      child: Container(
        width: 250,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: buttonGradient,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: (isReady ? Colors.greenAccent : AppColors.accentBlue).withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            buttonText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppSizes.fontXxl,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final String username;
  final String avatarAsset;
  final bool isCurrentPlayer;
  final bool isReady;

  const _PlayerSlot({
    required this.username,
    required this.avatarAsset,
    required this.isCurrentPlayer,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrentPlayer ? AppColors.accentBlue : AppColors.dangerRed;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            GameProfileAvatar(
              avatarAsset: username == 'MENUNGGU...' ? 'assets/avatar2.png' : avatarAsset,
              size: 140,
            ),
            if (isReady)
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Text(
                    'READY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.spacingLg),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingLg, vertical: AppSizes.spacingSm),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            username.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
