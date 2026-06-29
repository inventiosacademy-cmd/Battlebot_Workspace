import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/widgets/dual_network_indicator.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:my_flutter_app/features/profile/presentation/widgets/game_profile_avatar.dart';
import 'package:my_flutter_app/features/profile/presentation/widgets/profile_customization_dialog.dart';

/// Top bar widget for lobby screen.
/// Displays user profile, app title, and realtime status indicators.
class LobbyTopBar extends StatelessWidget {
  final int batteryLevel;
  final IconData batteryIcon;
  final Color batteryColor;
  final String batteryText;
  final IconData signalIcon;
  final Color signalColor;
  final int pingMs;

  const LobbyTopBar({
    super.key,
    required this.batteryLevel,
    required this.batteryIcon,
    required this.batteryColor,
    required this.batteryText,
    required this.signalIcon,
    required this.signalColor,
    required this.pingMs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingLg,
        vertical: 6,
      ),
      child: SizedBox(
        height: AppSizes.topBarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Aligned exactly with Center Arena
            const Row(
              children: [
                SizedBox(width: AppSizes.sidebarWidth),
                Expanded(
                  child: Center(
                    child: _AppTitle(),
                  ),
                ),
                SizedBox(width: AppSizes.leaderboardWidth),
              ],
            ),
            // Layer 2: Left Profile chip & Right status indicators
            const Align(
              alignment: Alignment.centerLeft,
              child: _ProfileChip(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _StatusIndicators(
                signalIcon: signalIcon,
                signalColor: signalColor,
                pingMs: pingMs,
                batteryIcon: batteryIcon,
                batteryColor: batteryColor,
                batteryText: batteryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        String username = 'LOADING...';
        String playerId = 'CB-00000';
        String avatarAsset = profile.avatarAsset;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            username = data['username'] ?? 'USER';
            playerId = data['playerId'] ?? 'CB-00000';
            avatarAsset = data['avatarAsset'] ?? profile.avatarAsset;
          }
        }

        return GestureDetector(
          onTap: () => ProfileCustomizationDialog.show(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameProfileAvatar(
                avatarAsset: avatarAsset,
                size: 56,
              ),
              const SizedBox(width: AppSizes.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontLg,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playerId,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class _StatusIndicators extends StatelessWidget {
  final IconData signalIcon;
  final Color signalColor;
  final int pingMs;
  final IconData batteryIcon;
  final Color batteryColor;
  final String batteryText;

  const _StatusIndicators({
    required this.signalIcon,
    required this.signalColor,
    required this.pingMs,
    required this.batteryIcon,
    required this.batteryColor,
    required this.batteryText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _GemsDisplay(),
        const SizedBox(width: 12),
        const DualNetworkIndicator(isLobby: true),
        const SizedBox(width: 12),
        _BatteryDisplay(
          icon: batteryIcon,
          color: batteryColor,
          text: batteryText,
        ),
      ],
    );
  }
}

class _GemsDisplay extends StatelessWidget {
  const _GemsDisplay();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) return const _GemsContainer(gems: 0);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        int gems = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            gems = data['gems'] ?? 0;
          }
        }
        return _GemsContainer(gems: gems);
      },
    );
  }
}

class _GemsContainer extends StatelessWidget {
  final int gems;
  const _GemsContainer({required this.gems});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: AppSizes.spacingMd),
          // Aset ikon berlian 3D cyberpunk kustom
          Image.asset(
            'assets/diamond_icon.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSizes.spacingSm),
          Text(
            '$gems',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: AppSizes.fontLg,
            ),
          ),
          const SizedBox(width: 8),
          // Pembatas vertikal tipis
          Container(
            height: 14,
            width: 1,
            color: AppColors.accentBlue.withValues(alpha: 0.3),
          ),
          // Tombol + terintegrasi (berwarna biru neon kustom)
          GestureDetector(
            onTap: () {
              // Aksi saat tombol + ditekan
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: const Icon(
                Icons.add,
                color: AppColors.accentBlue,
                size: AppSizes.iconSm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _BatteryDisplay extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _BatteryDisplay({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppSizes.iconSm),
          const SizedBox(width: AppSizes.spacingXs),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
