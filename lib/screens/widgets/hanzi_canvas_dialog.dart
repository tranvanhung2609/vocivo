import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/tts_service.dart';
import 'pinyin_text.dart';

class HanziCanvasDialog extends StatefulWidget {
  final String hanzi;
  final String? pinyin;
  final String? hanViet;
  final String? meaningVi;

  const HanziCanvasDialog({
    super.key,
    required this.hanzi,
    this.pinyin,
    this.hanViet,
    this.meaningVi,
  });

  static Future<void> show(
    BuildContext context, {
    required String hanzi,
    String? pinyin,
    String? hanViet,
    String? meaningVi,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => HanziCanvasDialog(
        hanzi: hanzi,
        pinyin: pinyin,
        hanViet: hanViet,
        meaningVi: meaningVi,
      ),
    );
  }

  @override
  State<HanziCanvasDialog> createState() => _HanziCanvasDialogState();
}

class _HanziCanvasDialogState extends State<HanziCanvasDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _showGhostCharacter = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryChineseLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.draw_rounded, color: AppColors.primaryChinese, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Luyện viết chữ Hán (田字格)',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.pinyin != null)
                        PinyinText(pinyin: widget.pinyin!, fontSize: 14),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryChinese),
                  tooltip: 'Phát âm',
                  onPressed: () {
                    TtsService.instance.speak(text: widget.hanzi, languageCode: 'ZH');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            if (widget.hanViet != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'Âm Hán-Việt: ${widget.hanViet}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Canvas with Tian Zi Ge (田字格) grid
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDC2626), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Grid background painter (Tian Zi Ge / Mi Zi Ge)
                      CustomPaint(
                        size: const Size(280, 280),
                        painter: _TianZiGePainter(isDark: isDark),
                      ),

                      // Ghost character for reference
                      if (_showGhostCharacter)
                        Center(
                          child: Text(
                            widget.hanzi.characters.firstOrNull ?? widget.hanzi,
                            style: GoogleFonts.maShanZheng(
                              fontSize: 190,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : const Color(0xFFDC2626).withValues(alpha: 0.18),
                            ),
                          ),
                        ),

                      // Interactive Drawing Canvas
                      GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _currentStroke = [details.localPosition];
                            _strokes.add(_currentStroke);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _currentStroke.add(details.localPosition);
                          });
                        },
                        onPanEnd: (_) {
                          _currentStroke = [];
                        },
                        child: CustomPaint(
                          size: const Size(280, 280),
                          painter: _StrokePainter(strokes: _strokes, isDark: isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Toggle ghost character
                TextButton.icon(
                  onPressed: () => setState(() => _showGhostCharacter = !_showGhostCharacter),
                  icon: Icon(
                    _showGhostCharacter ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  label: Text(_showGhostCharacter ? 'Ẩn nét mẫu' : 'Hiện nét mẫu'),
                ),

                // Clear strokes
                OutlinedButton.icon(
                  onPressed: () => setState(() => _strokes.clear()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Viết lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TianZiGePainter extends CustomPainter {
  final bool isDark;
  _TianZiGePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? Colors.red.shade900 : const Color(0xFFEF4444)).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = (isDark ? Colors.red.shade900 : const Color(0xFFEF4444)).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    final midX = size.width / 2;
    final midY = size.height / 2;

    // Cross lines (Tian Zi Ge)
    _drawDashedLine(canvas, Offset(midX, 0), Offset(midX, size.height), gridPaint);
    _drawDashedLine(canvas, Offset(0, midY), Offset(size.width, midY), gridPaint);

    // Diagonal lines (Mi Zi Ge)
    _drawDashedLine(canvas, Offset.zero, Offset(size.width, size.height), dashPaint);
    _drawDashedLine(canvas, Offset(size.width, 0), Offset(0, size.height), dashPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final count = (Offset(dx, dy).distance / (dashWidth + dashSpace)).floor();
    for (int i = 0; i < count; i++) {
      final startFrac = (i * (dashWidth + dashSpace)) / Offset(dx, dy).distance;
      final endFrac = ((i * (dashWidth + dashSpace)) + dashWidth) / Offset(dx, dy).distance;
      canvas.drawLine(
        Offset(p1.dx + dx * startFrac, p1.dy + dy * startFrac),
        Offset(p1.dx + dx * endFrac, p1.dy + dy * endFrac),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final bool isDark;

  _StrokePainter({required this.strokes, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white : const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 4.5, paint);
      } else {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
