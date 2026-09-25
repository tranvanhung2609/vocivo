import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tactile 3D shelf-style button với press animation.
/// Tách ra từ srs_review_screen.dart.
class SrsTactileButton extends StatefulWidget {
  const SrsTactileButton({
    super.key,
    required this.label,
    required this.faceColor,
    required this.shelfColor,
    required this.onTap,
    this.sublabel,
    this.keyHint,
    this.icon,
    this.isPressed = false,
  });

  final String label;
  final String? sublabel;
  final String? keyHint;
  final IconData? icon;
  final Color faceColor;
  final Color shelfColor;
  final VoidCallback onTap;
  final bool isPressed;

  @override
  State<SrsTactileButton> createState() => _SrsTactileButtonState();
}

class _SrsTactileButtonState extends State<SrsTactileButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _down || widget.isPressed;
    const shelfHeight = 4.0;
    final topOffset = pressed ? shelfHeight : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            // Shelf (bottom layer)
            Positioned(
              left: 0,
              right: 0,
              top: shelfHeight,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.shelfColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Face (top layer)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: topOffset,
              height: 52 - shelfHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.faceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.keyHint != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.keyHint!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.sublabel != null) ...[
                        Text(
                          widget.sublabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
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
