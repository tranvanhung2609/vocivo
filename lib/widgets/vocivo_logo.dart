import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Reusable vector logo for Vocivo (Vocabulary + Voice)
/// Features a stylized letter "V" morphing into an open book page & dynamic speech waves,
/// with a warm coral voice accent.
class VocivoLogo extends StatelessWidget {
  const VocivoLogo({
    super.key,
    this.size = 40,
    this.showText = true,
    this.showSlogan = false,
    this.textColor,
    this.sloganColor,
    this.fontSize,
  });

  final double size;
  final bool showText;
  final bool showSlogan;
  final Color? textColor;
  final Color? sloganColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF4F46E5), // Deep Indigo
            Color(0xFF7C3AED), // Violet
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.65, size * 0.65),
          painter: _VocivoMarkPainter(),
        ),
      ),
    );

    if (!showText) return iconWidget;

    final resolvedTextColor = textColor ??
        (isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary);
    final resolvedSloganColor = sloganColor ??
        (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        SizedBox(width: size * 0.25),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vocivo',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: fontSize ?? (size * 0.52),
                letterSpacing: -0.5,
                color: resolvedTextColor,
              ),
            ),
            if (showSlogan) ...[
              const SizedBox(height: 2),
              Text(
                'Từ vựng nhớ sâu • Tự tin cất lời',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (fontSize ?? (size * 0.52)) * 0.48,
                  fontWeight: FontWeight.w600,
                  color: resolvedSloganColor,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Custom vector painter rendering the Vocivo mark:
/// Left wing = open book page (Vocabulary)
/// Right wing = ascending voice wave / speech loop (Voice)
/// Orange dot = voice articulation accent
class _VocivoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Start at top-left of the book page wing
    path.moveTo(w * 0.15, h * 0.22);
    // Curve down into the root vertex
    path.quadraticBezierTo(w * 0.22, h * 0.70, w * 0.46, h * 0.88);
    // Ascend into the voice wave curve
    path.quadraticBezierTo(w * 0.62, h * 0.80, w * 0.78, h * 0.45);
    // Crest of speech bubble / voice loop
    path.arcToPoint(
      Offset(w * 0.88, h * 0.28),
      radius: Radius.circular(w * 0.25),
      clockwise: false,
    );

    canvas.drawPath(path, paintStroke);

    // Inner book leaf line
    final innerLeaf = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    final leafPath = Path();
    leafPath.moveTo(w * 0.32, h * 0.32);
    leafPath.quadraticBezierTo(w * 0.36, h * 0.62, w * 0.50, h * 0.76);
    canvas.drawPath(leafPath, innerLeaf);

    // Warm coral voice accent dot
    final dotPaint = Paint()
      ..color = const Color(0xFFFF8A3D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.68, h * 0.58), w * 0.09, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
