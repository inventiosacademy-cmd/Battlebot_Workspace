import 'package:flutter/material.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/constants/app_routes.dart';
import 'package:my_flutter_app/features/lobby/presentation/widgets/floating_arena.dart';

/// Center arena section with floating platform and MASUK LOBBY button.
class LobbyCenterArena extends StatefulWidget {
  final Animation<double> pulseAnimation;
  final Animation<double> floatAnimation;

  const LobbyCenterArena({
    super.key,
    required this.pulseAnimation,
    required this.floatAnimation,
  });

  @override
  State<LobbyCenterArena> createState() => _LobbyCenterArenaState();
}

class _LobbyCenterArenaState extends State<LobbyCenterArena> {
  String _selectedMode = 'FIGHT MODE';

  void _showModeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _ModeSelectionDialog(
        currentMode: _selectedMode,
        onModeSelected: (mode) {
          setState(() {
            _selectedMode = mode;
          });
        },
      ),
    );
  }

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
              animation: widget.floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, widget.floatAnimation.value),
                child: child,
              ),
              child: FloatingArena(pulseAnimation: widget.pulseAnimation),
            ),
          ),
        ),
        Positioned(
          bottom: AppSizes.spacingLg,
          left: 0,
          right: 0,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingLg),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LobbyButton(pulseAnimation: widget.pulseAnimation),
                    const SizedBox(width: AppSizes.spacingLg),
                    _ModeButton(
                      selectedMode: _selectedMode,
                      onTap: _showModeSelectionDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
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

class _ModeButton extends StatelessWidget {
  final String selectedMode;
  final VoidCallback onTap;

  const _ModeButton({
    required this.selectedMode,
    required this.onTap,
  });

  IconData _getModeIcon() {
    switch (selectedMode) {
      case 'SOCCER MODE':
        return Icons.sports_soccer;
      case 'RACE MODE':
        return Icons.sports_score;
      default:
        return Icons.sports_mma;
    }
  }

  Color _getModeColor() {
    switch (selectedMode) {
      case 'SOCCER MODE':
        return Colors.greenAccent;
      case 'RACE MODE':
        return Colors.orangeAccent;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSizes.lobbyButtonHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingXl),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: _getModeColor().withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _getModeColor().withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getModeIcon(), color: _getModeColor(), size: 28),
              const SizedBox(height: 4),
              Text(
                selectedMode,
                style: TextStyle(
                  color: _getModeColor(),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSelectionDialog extends StatefulWidget {
  final String currentMode;
  final ValueChanged<String> onModeSelected;

  const _ModeSelectionDialog({
    required this.currentMode,
    required this.onModeSelected,
  });

  @override
  State<_ModeSelectionDialog> createState() => _ModeSelectionDialogState();
}

class _ModeSelectionDialogState extends State<_ModeSelectionDialog> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  final List<Map<String, dynamic>> _modes = [
    {'name': 'SOCCER MODE', 'icon': Icons.sports_soccer, 'color': Colors.greenAccent},
    {'name': 'RACE MODE', 'icon': Icons.sports_score, 'color': Colors.orangeAccent},
    {'name': 'FIGHT MODE', 'icon': Icons.sports_mma, 'color': Colors.redAccent},
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _modes.indexWhere((m) => m['name'] == widget.currentMode);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex, viewportFraction: 0.6);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 350),
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSizes.spacingLg),
              child: Text(
                'PILIH MODE PERMAINAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontXl,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: _modes.length,
                    itemBuilder: (context, index) {
                      final mode = _modes[index];
                      final isSelected = index == _currentIndex;
                      return AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        scale: isSelected ? 1.0 : 0.8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isSelected ? 1.0 : 0.4,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: AppSizes.spacingMd, vertical: AppSizes.spacingLg),
                            decoration: BoxDecoration(
                              color: mode['color'].withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                              border: Border.all(color: mode['color'], width: isSelected ? 3 : 1),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: mode['color'].withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(mode['icon'], size: 80, color: mode['color']),
                                const SizedBox(height: AppSizes.spacingLg),
                                Text(
                                  mode['name'],
                                  style: TextStyle(
                                    color: mode['color'],
                                    fontSize: AppSizes.fontLg,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Left Arrow
                  Positioned(
                    left: AppSizes.spacingLg,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                      onPressed: () {
                        if (_currentIndex > 0) {
                          _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                      },
                    ),
                  ),
                  // Right Arrow
                  Positioned(
                    right: AppSizes.spacingLg,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                      onPressed: () {
                        if (_currentIndex < _modes.length - 1) {
                          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.spacingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('BATAL', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: AppSizes.spacingXl),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modes[_currentIndex]['color'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingXxl, vertical: AppSizes.spacingMd),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                    ),
                    onPressed: () {
                      widget.onModeSelected(_modes[_currentIndex]['name']);
                      Navigator.pop(context);
                    },
                    child: const Text('PILIH MODE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
