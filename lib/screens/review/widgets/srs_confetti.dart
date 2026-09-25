import 'dart:math';
import 'package:flutter/material.dart';

/// Data class cho mỗi particle confetti
class SrsConfettiParticle {
  SrsConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.angle,
    required this.angularV,
    required this.shape,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double angle;
  final double angularV;
  final int shape; // 0=circle, 1=square, 2=rect
}

/// CustomPainter vẽ các confetti particles theo [progress] (0.0 – 1.0)
class SrsConfettiPainter extends CustomPainter {
  const SrsConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<SrsConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = (p.x + p.vx * progress * 4) * size.width;
      final y = (p.y + p.vy * progress * 3) * size.height;
      if (y > size.height + 20) continue;

      final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + p.angularV * progress * 4);

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        case 1:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
        case 2:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.6,
              height: p.size * 0.7,
            ),
            paint,
          );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SrsConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Helper factory tạo danh sách particles ngẫu nhiên
List<SrsConfettiParticle> generateConfettiParticles({
  int count = 80,
  List<Color>? colors,
}) {
  final rng = Random();
  final palette = colors ??
      const [
        Color(0xFF3B82F6), // blue
        Color(0xFFF97316), // orange
        Color(0xFF8B5CF6), // purple
        Color(0xFFF59E0B), // amber
        Color(0xFFEC4899), // pink
        Color(0xFF10B981), // green
      ];

  return List.generate(count, (_) => SrsConfettiParticle(
    x: rng.nextDouble(),
    y: -rng.nextDouble() * 0.3,
    vx: (rng.nextDouble() - 0.5) * 0.3,
    vy: 0.2 + rng.nextDouble() * 0.5,
    color: palette[rng.nextInt(palette.length)],
    size: 5 + rng.nextDouble() * 6,
    angle: rng.nextDouble() * 2 * pi,
    angularV: (rng.nextDouble() - 0.5) * 6,
    shape: rng.nextInt(3),
  ));
}
