import 'package:flutter/material.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';

/// Right-side leaderboard panel showing global rankings.
class LobbyLeaderboard extends StatelessWidget {
  const LobbyLeaderboard({super.key});

  static const List<(int, String, int)> _players = [
    (1, 'NeonStrider', 4520),
    (2, 'Cipher', 3910),
    (3, 'VoidWalker', 3150),
    (4, 'ApexSumo', 2800),
    (5, 'TitanSmasher', 2100),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.leaderboardWidth,
      margin: const EdgeInsets.only(
        top: AppSizes.spacingMd,
        bottom: AppSizes.spacingMd,
        right: AppSizes.spacingMd,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.7), // Dark blue transparent
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          const _LeaderboardTitle(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.spacingSm,
                horizontal: AppSizes.spacingSm,
              ),
              itemCount: _players.length,
              itemBuilder: (_, index) {
                final (rank, name, score) = _players[index];
                return _LeaderboardEntry(rank: rank, name: name, score: score);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTitle extends StatelessWidget {
  const _LeaderboardTitle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg - 2)),
        border: Border(
          bottom: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3), width: 2),
        ),
      ),
      child: const Text(
        'LEADERBOARD',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: AppSizes.fontMd,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _LeaderboardEntry extends StatelessWidget {
  final int rank;
  final String name;
  final int score;

  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
  });

  Color get _rankColor => switch (rank) {
    1 => AppColors.rankGold,
    2 => AppColors.rankSilver,
    3 => AppColors.rankBronze,
    _ => Colors.white60,
  };

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Rank Indicator
          SizedBox(
            width: 45,
            height: 45,
            child: isTop3
                ? Image.asset(
                    'assets/LB$rank.png',
                    fit: BoxFit.contain,
                  )
                : Center(
                    child: Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: AppSizes.fontBase,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          
          // Avatar
          Container(
            width: AppSizes.avatarSmall,
            height: AppSizes.avatarSmall,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1B263B), // Darker inner blue
              border: Border.all(
                color: isTop3 ? _rankColor : Colors.white24,
                width: isTop3 ? 2 : 1,
              ),
              image: DecorationImage(
                image: AssetImage('assets/avatar$rank.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Name and Score Pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$score',
                    style: const TextStyle(
                      color: Colors.amber, // Highlight score
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

