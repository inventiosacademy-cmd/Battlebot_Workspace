import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';

/// Animated abstract moving background with blurred color blobs.
/// Used as the lobby screen backdrop.
class MovingBackgroundPainter extends CustomPainter {
  final double animationValue;
  const MovingBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = AppColors.darkBase;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    final double w = size.width;
    final double h = size.height;
    final double phase = animationValue * 2 * math.pi;
    final double baseSize = math.min(w, h);

    final double blob1Radius = baseSize * 0.35 + math.sin(phase) * 20;
    _drawBlob(
      canvas,
      offset: Offset(
        w * 0.25 + math.sin(phase) * w * 0.15,
        h * 0.4 + math.cos(phase) * h * 0.2,
      ),
      radius: blob1Radius,
      color: AppColors.dangerRed.withValues(alpha: 0.38),
      blurSigma: blob1Radius * 0.55,
    );

    final double blob2Radius = baseSize * 0.35 + math.cos(phase) * 20;
    _drawBlob(
      canvas,
      offset: Offset(
        w * 0.75 + math.cos(phase) * w * 0.15,
        h * 0.5 + math.sin(phase) * h * 0.2,
      ),
      radius: blob2Radius,
      color: AppColors.lightBlue.withValues(alpha: 0.32),
      blurSigma: blob2Radius * 0.55,
    );

    final double blob3Radius = baseSize * 0.4 + math.sin(phase + 1.0) * 15;
    _drawBlob(
      canvas,
      offset: Offset(
        w * 0.6 + math.sin(phase + 1.0) * w * 0.2,
        h * 0.3 + math.cos(phase + 1.0) * h * 0.15,
      ),
      radius: blob3Radius,
      color: AppColors.primaryBlue.withValues(alpha: 0.33),
      blurSigma: blob3Radius * 0.55,
    );

    final double blob4Radius = baseSize * 0.35 + math.cos(phase + 2.0) * 15;
    _drawBlob(
      canvas,
      offset: Offset(
        w * 0.4 + math.cos(phase + 2.0) * w * 0.2,
        h * 0.7 + math.sin(phase + 2.0) * h * 0.15,
      ),
      radius: blob4Radius,
      color: AppColors.deepRed.withValues(alpha: 0.28),
      blurSigma: blob4Radius * 0.55,
    );
  }

  void _drawBlob(
    Canvas canvas, {
    required Offset offset,
    required double radius,
    required Color color,
    required double blurSigma,
  }) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    canvas.drawCircle(offset, radius, paint);
  }

  @override
  bool shouldRepaint(covariant MovingBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
