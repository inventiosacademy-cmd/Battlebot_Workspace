import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/services/network_manager.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_flutter_app/core/services/audio_manager.dart';

/// Full-screen styled dialog for game Settings (Pengaturan).
/// Contains volume sliders, graphic settings, and the Logout (Keluar) button.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _boostEnabled;

  @override
  void initState() {
    super.initState();
    final networkManager = Provider.of<NetworkManager>(context, listen: false);
    _boostEnabled = networkManager.sendMode == NetworkSendMode.dual;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 60,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1F),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.spacingXxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('AUDIO'),
                    const SizedBox(height: AppSizes.spacingMd),
                    _buildMusicVolumeControl(context),
                    const SizedBox(height: AppSizes.spacingXl),
                    _buildSectionTitle('JARINGAN'),
                    const SizedBox(height: AppSizes.spacingMd),
                    _buildNetworkBoostToggle(),
                    const SizedBox(height: AppSizes.spacingXxxl),
                    _buildLogoutSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingXl),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.settings,
            color: AppColors.accentBlue,
            size: AppSizes.iconXxl,
          ),
          const SizedBox(width: AppSizes.spacingXl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PENGATURAN GAME',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.fontXxl,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  'Atur preferensi permainan dan akun Anda',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: AppSizes.fontBase,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white54,
                size: AppSizes.iconMd,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.accentBlue.withValues(alpha: 0.9),
        fontSize: AppSizes.fontLg,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }


  Widget _buildNetworkBoostToggle() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: _boostEnabled
            ? AppColors.lightBlue.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: _boostEnabled
              ? AppColors.lightBlue.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Boost icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _boostEnabled
                  ? AppColors.lightBlue.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(
              Icons.rocket_launch,
              color: _boostEnabled ? AppColors.lightBlue : Colors.white30,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Network Boost',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.fontBase,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_boostEnabled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ON',
                          style: TextStyle(
                            color: AppColors.lightBlue,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _boostEnabled
                      ? 'Gabungkan WiFi + SIM untuk latency terendah'
                      : 'Gunakan satu jaringan saja (default)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: AppSizes.fontXs,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _boostEnabled,
            activeThumbColor: AppColors.lightBlue,
            activeTrackColor: AppColors.lightBlue.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            onChanged: (val) {
              setState(() => _boostEnabled = val);
              final networkManager =
                  Provider.of<NetworkManager>(context, listen: false);
              networkManager.setSendMode(
                val ? NetworkSendMode.dual : NetworkSendMode.normal,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Akun & Autentikasi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontBase,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Keluar dari sesi permainan saat ini',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: AppSizes.fontSm,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.dangerRed.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingXl,
                vertical: AppSizes.spacingLg,
              ),
            ),
            onPressed: () {
              _showLogoutConfirmation(context);
            },
            icon: const Icon(Icons.logout, size: AppSizes.iconMd),
            label: const Text(
              'KELUAR',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.spacingXl),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun?',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Tutup dialog konfirmasi
            child: const Text('Batal', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            onPressed: () async {
              // Simpan referensi auth provider sebelum context di-pop
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              
              // Pop the confirmation dialog, settings dialog, and any other routes on top of the root
              Navigator.of(context).popUntil((route) => route.isFirst);
              
              await authProvider.signOut();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicVolumeControl(BuildContext context) {
    final audioManager = Provider.of<AudioManager>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingSm),
      child: Row(
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'Volume Musik',
              style: TextStyle(
                color: Colors.white70,
                fontSize: AppSizes.fontBase,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Switch(
            value: audioManager.isMusicEnabled,
            activeThumbColor: AppColors.accentBlue,
            activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white10,
            onChanged: (val) {
              audioManager.setMusicEnabled(val);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: audioManager.isMusicEnabled ? AppColors.primaryBlue : Colors.white10,
                inactiveTrackColor: Colors.white10,
                thumbColor: audioManager.isMusicEnabled ? AppColors.accentBlue : Colors.white30,
                overlayColor: AppColors.accentBlue.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: audioManager.volume,
                onChanged: audioManager.isMusicEnabled
                    ? (val) {
                        audioManager.setVolume(val);
                      }
                    : null,
              ),
            ),
          ),
          Text(
            '${(audioManager.volume * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: AppSizes.fontBase,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
