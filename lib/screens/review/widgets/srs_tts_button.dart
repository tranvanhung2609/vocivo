import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../../core/services/tts_service.dart';

/// TTS play button với pulse animation khi đang phát.
/// Tách ra từ srs_review_screen.dart.
class SrsTtsButton extends StatefulWidget {
  const SrsTtsButton({
    super.key,
    required this.text,
    required this.languageCode,
    required this.color,
    this.size = 26,
  });

  final String text;
  final String languageCode;
  final Color color;
  final double size;

  @override
  State<SrsTtsButton> createState() => _SrsTtsButtonState();
}

class _SrsTtsButtonState extends State<SrsTtsButton>
    with SingleTickerProviderStateMixin {
  bool _playing = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _play() async {
    setState(() => _playing = true);
    _pulseCtrl.repeat(reverse: true);
    HapticFeedback.selectionClick();
    await TtsService.instance.speak(
      text: widget.text,
      languageCode: widget.languageCode,
    );
    if (mounted) {
      setState(() => _playing = false);
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: _playing ? (1.0 + _pulseCtrl.value * 0.12) : 1.0,
        child: child,
      ),
      child: IconButton.filledTonal(
        onPressed: _playing ? null : _play,
        icon: Icon(
          _playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
          size: widget.size,
          color: widget.color,
        ),
        style: IconButton.styleFrom(
          backgroundColor: widget.color.withValues(alpha: 0.1),
        ),
        tooltip: 'Phát âm [P]',
      ),
    );
  }
}
