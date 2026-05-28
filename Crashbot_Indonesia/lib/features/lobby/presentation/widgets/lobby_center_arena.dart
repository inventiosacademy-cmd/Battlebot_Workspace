import 'package:flutter/material.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/constants/app_routes.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/floating_arena.dart';

/// Center arena section with floating platform and MASUK LOBBY button.
class LobbyCenterArena extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final Animation<double> floatAnimation;

  const LobbyCenterArena({
    super.key,
    required this.pulseAnimation,
    required this.floatAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 60,
          child: Align(
            alignment: const Alignment(0, -0.05),
            child: AnimatedBuilder(
              animation: floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, floatAnimation.value),
                child: child,
              ),
              child: FloatingArena(pulseAnimation: pulseAnimation),
            ),
          ),
        ),
        Positioned(
          bottom: AppSizes.spacingLg,
          left: 0,
          right: 0,
          child: Center(child: _LobbyButton(pulseAnimation: pulseAnimation)),
        ),
      ],
    );
  }
}

class _LobbyButton extends StatelessWidget {
  final Animation<double> pulseAnimation;
  const _LobbyButton({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Do NOT pause music yet, because we are just going to the matchmaking room
        // The music should continue in the matchmaking room
        
        if (context.mounted) {
          await Navigator.pushNamed(context, AppRoutes.matchmaking);
        }
      },
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (_, __) => Container(
          width: AppSizes.lobbyButtonWidth,
          height: AppSizes.lobbyButtonHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.deepNavy.withValues(alpha: 0.8),
                AppColors.royalBlue.withValues(alpha: 0.8),
                AppColors.deepNavy.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: Color.lerp(
                AppColors.accentBlue,
                Colors.white,
                pulseAnimation.value * 0.3,
              )!.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(
                  alpha: pulseAnimation.value * 0.3,
                ),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'MASUK LOBBY',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppSizes.fontXxl,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
                shadows: [
                  Shadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
