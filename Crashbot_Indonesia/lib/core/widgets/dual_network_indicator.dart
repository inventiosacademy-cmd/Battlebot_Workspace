import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/core/services/network_manager.dart';

/// Compact network indicator. Works seamlessly on both Lobby and Remote pages.
///
/// - **Boost OFF**: Shows separate WiFi and SIM icons with individual status.
/// - **Boost ON**: Shows a single combined WiFi+ icon (merged), no SIM icon.
///
/// Tapping opens a detail dialog with per-network info and event log.
class DualNetworkIndicator extends StatelessWidget {
  final int? customPingMs; // If provided, overrides default manager ping
  final bool isAgoraConnected;
  final bool isAgoraError;
  final bool hasRemoteUser;
  final bool isLobby;

  const DualNetworkIndicator({
    super.key,
    this.customPingMs,
    this.isAgoraConnected = false,
    this.isAgoraError = false,
    this.hasRemoteUser = false,
    this.isLobby = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkManager>(
      builder: (context, networkManager, _) {
        final info = networkManager.networkInfo;
        final isBoost = networkManager.sendMode == NetworkSendMode.dual;

        // Resolve display ping
        int displayPing = 0;
        if (customPingMs != null && customPingMs! > 0) {
          displayPing = customPingMs!;
        } else {
          // If in lobby or fallback, use actual measured pings from manager
          if (isBoost) {
            displayPing = info.bestPingMs;
          } else {
            displayPing = info.activeNetwork == 'wifi'
                ? info.wifiPingMs
                : info.cellularPingMs;
          }
        }

        return GestureDetector(
          onTap: () => _showNetworkDetail(context, networkManager, displayPing),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacingLg,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSizes.radiusRound),
              border: Border.all(
                color: _borderColor(info, isBoost).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBoost)
                  // ── BOOST MODE: single combined WiFi+ icon ──
                  _BoostIcon(
                    hasWifi: info.hasWifi,
                    hasMobile: info.hasMobile,
                  )
                else ...[
                  // ── NORMAL MODE: separate WiFi and SIM icons ──
                  _NetworkIcon(
                    icon: Icons.wifi,
                    isConnected: info.hasWifi,
                    isActive: info.activeNetwork == 'wifi',
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _NetworkIcon(
                    icon: Icons.signal_cellular_alt,
                    isConnected: info.hasMobile,
                    isActive: info.activeNetwork == 'mobile',
                  ),
                ],
                const SizedBox(width: 10),
                // Status text
                _StatusText(
                  info: info,
                  pingMs: displayPing,
                  isAgoraConnected: isAgoraConnected,
                  isAgoraError: isAgoraError,
                  hasRemoteUser: hasRemoteUser,
                  isBoost: isBoost,
                  isLobby: isLobby,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _borderColor(NetworkInfo info, bool isBoost) {
    if (isAgoraError) return AppColors.dangerRed;
    if (isBoost && info.hasAnyConnection) return AppColors.lightBlue;
    if (info.hasDualConnection) return AppColors.lightBlue;
    if (info.hasAnyConnection) return AppColors.successGreen;
    return AppColors.dangerRed;
  }

  void _showNetworkDetail(
      BuildContext context, NetworkManager manager, int activePing) {
    showDialog(
      context: context,
      builder: (ctx) => _NetworkDetailDialog(
        info: manager.networkInfo,
        events: manager.eventLog,
        pingMs: activePing,
        isBoost: manager.sendMode == NetworkSendMode.dual,
      ),
    );
  }
}

// ─── BOOST MODE: Combined WiFi+ Icon ─────────────────────────────

class _BoostIcon extends StatefulWidget {
  final bool hasWifi;
  final bool hasMobile;

  const _BoostIcon({
    required this.hasWifi,
    required this.hasMobile,
  });

  @override
  State<_BoostIcon> createState() => _BoostIconState();
}

class _BoostIconState extends State<_BoostIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.hasWifi || widget.hasMobile) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BoostIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasWifi || widget.hasMobile) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = widget.hasWifi || widget.hasMobile;
    final bool isBoosted = widget.hasWifi && widget.hasMobile;

    final Color iconColor = isConnected
        ? (isBoosted ? AppColors.lightBlue : AppColors.successGreen)
        : Colors.white.withValues(alpha: 0.2);

    return ScaleTransition(
      scale: _pulseAnimation,
      child: SizedBox(
        width: 24,
        height: 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main WiFi icon
            Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: iconColor,
              size: AppSizes.iconMd,
            ),
            // "+" badge
            if (isConnected)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: isBoosted
                        ? AppColors.lightBlue
                        : AppColors.warningYellow,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── NORMAL MODE: Individual Network Icon ─────────────────────────

class _NetworkIcon extends StatefulWidget {
  final IconData icon;
  final bool isConnected;
  final bool isActive;

  const _NetworkIcon({
    required this.icon,
    required this.isConnected,
    required this.isActive,
  });

  @override
  State<_NetworkIcon> createState() => _NetworkIconState();
}

class _NetworkIconState extends State<_NetworkIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive && widget.isConnected) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _NetworkIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && widget.isConnected) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (!widget.isConnected) {
      color = Colors.white.withValues(alpha: 0.2);
    } else if (widget.isActive) {
      color = AppColors.successGreen;
    } else {
      color = AppColors.warningYellow;
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Icon(
        widget.isConnected ? widget.icon : _getOfflineIcon(widget.icon),
        color: color,
        size: AppSizes.iconMd,
      ),
    );
  }

  IconData _getOfflineIcon(IconData onlineIcon) {
    if (onlineIcon == Icons.wifi) return Icons.wifi_off;
    return Icons.signal_cellular_off;
  }
}

// ─── Status Text ──────────────────────────────────────────────────

class _StatusText extends StatelessWidget {
  final NetworkInfo info;
  final int pingMs;
  final bool isAgoraConnected;
  final bool isAgoraError;
  final bool hasRemoteUser;
  final bool isBoost;
  final bool isLobby;

  const _StatusText({
    required this.info,
    required this.pingMs,
    required this.isAgoraConnected,
    required this.isAgoraError,
    required this.hasRemoteUser,
    required this.isBoost,
    required this.isLobby,
  });

  @override
  Widget build(BuildContext context) {
    final (Color textColor, String text) = _resolveState();

    return Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: AppSizes.fontLg,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  (Color, String) _resolveState() {
    if (isAgoraError) {
      return (AppColors.dangerRed, 'Error koneksi');
    }

    if (!info.hasAnyConnection) {
      return (AppColors.dangerRed, 'Offline');
    }

    // Direct ping display if in Lobby or Remote active user
    if (isLobby || hasRemoteUser) {
      final Color color = _pingColor;
      final String suffix = isBoost && info.hasDualConnection ? ' · Boost' : '';
      final String pingVal = pingMs >= 0 ? '$pingMs ms' : '-- ms';
      return (isBoost && info.hasDualConnection ? AppColors.lightBlue : color, '$pingVal$suffix');
    }

    if (isAgoraConnected) {
      return (AppColors.warningYellow, 'Menunggu Kamera...');
    }

    return (Colors.white38, 'Menghubungkan...');
  }

  Color get _pingColor {
    if (pingMs > 0 && pingMs < 100) return AppColors.successGreen;
    if (pingMs >= 100 && pingMs <= 200) return AppColors.warningYellow;
    if (pingMs > 200) return AppColors.dangerRed;
    return AppColors.successGreen;
  }
}

// ─── Detail Dialog ────────────────────────────────────────────────

class _NetworkDetailDialog extends StatelessWidget {
  final NetworkInfo info;
  final List<NetworkEvent> events;
  final int pingMs;
  final bool isBoost;

  const _NetworkDetailDialog({
    required this.info,
    required this.events,
    required this.pingMs,
    required this.isBoost,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D0D20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.lightBlue.withValues(alpha: 0.3)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.router, color: AppColors.lightBlue, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Status Jaringan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Network cards
              _NetworkCard(
                icon: Icons.wifi,
                label: 'WiFi',
                isConnected: info.hasWifi,
                isActive: isBoost ? info.hasWifi : info.activeNetwork == 'wifi',
                pingMs: info.wifiPingMs,
              ),
              const SizedBox(height: 8),
              _NetworkCard(
                icon: Icons.signal_cellular_alt,
                label: 'SIM / Seluler',
                isConnected: info.hasMobile,
                isActive: isBoost ? info.hasMobile : info.activeNetwork == 'mobile',
                pingMs: info.cellularPingMs,
              ),
              const SizedBox(height: 10),
              // Boost status badge
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isBoost
                      ? AppColors.lightBlue.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBoost
                        ? AppColors.lightBlue.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      color: isBoost ? AppColors.lightBlue : Colors.white30,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isBoost ? 'Network Boost AKTIF' : 'Network Boost OFF',
                      style: TextStyle(
                        color: isBoost ? AppColors.lightBlue : AppColors.dangerRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Atur di Pengaturan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Event log
              const Text(
                'Riwayat Jaringan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: events.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada aktivitas',
                          style:
                              TextStyle(color: Colors.white30, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return _EventRow(event: event);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────

class _NetworkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isConnected;
  final bool isActive;
  final int pingMs;

  const _NetworkCard({
    required this.icon,
    required this.label,
    required this.isConnected,
    required this.isActive,
    this.pingMs = -1,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusText;

    if (!isConnected) {
      statusColor = Colors.white.withValues(alpha: 0.3);
      statusText = 'Terputus';
    } else if (isActive) {
      statusColor = AppColors.successGreen;
      statusText = 'Aktif';
    } else {
      statusColor = AppColors.warningYellow;
      statusText = 'Terhubung (Standby)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isConnected
            ? statusColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isConnected
                ? icon
                : (icon == Icons.wifi
                    ? Icons.wifi_off
                    : Icons.signal_cellular_off),
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          // Per-network ping display
          if (isConnected && pingMs >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getPingColor(pingMs).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$pingMs ms',
                style: TextStyle(
                  color: _getPingColor(pingMs),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (isConnected && pingMs >= 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping > 0 && ping < 100) return AppColors.successGreen;
    if (ping >= 100 && ping <= 200) return AppColors.warningYellow;
    if (ping > 200) return AppColors.dangerRed;
    return AppColors.successGreen;
  }
}

class _EventRow extends StatelessWidget {
  final NetworkEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (event.type) {
      case NetworkEventType.connected:
        icon = Icons.check_circle_outline;
        color = AppColors.successGreen;
      case NetworkEventType.disconnected:
        icon = Icons.cancel_outlined;
        color = AppColors.dangerRed;
      case NetworkEventType.failover:
        icon = Icons.swap_horiz;
        color = AppColors.warningYellow;
    }

    final timeStr =
        '${event.timestamp.hour.toString().padLeft(2, '0')}:'
        '${event.timestamp.minute.toString().padLeft(2, '0')}:'
        '${event.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.message,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
