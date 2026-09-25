import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PinyinText extends StatelessWidget {
  final String pinyin;
  final double fontSize;
  final FontWeight fontWeight;

  const PinyinText({
    super.key,
    required this.pinyin,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    if (pinyin.isEmpty) return const SizedBox.shrink();

    // Split words or syllables
    final parts = pinyin.split(' ');
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((part) {
        final color = AppColors.getPinyinToneColor(part);
        return Text(
          part,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            letterSpacing: 0.3,
          ),
        );
      }).toList(),
    );
  }
}
