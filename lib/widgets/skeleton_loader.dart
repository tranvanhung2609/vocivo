import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Animated shimmer skeleton for loading states
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final shimmerColor =
        isDark ? const Color(0xFF2D3F55) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
              colors: [
                baseColor,
                shimmerColor,
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder for a word card
class SkeletonWordCard extends StatelessWidget {
  const SkeletonWordCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word + badge row
          Row(
            children: [
              SkeletonLoader(width: 100, height: 24, borderRadius: 6),
              const SizedBox(width: 10),
              SkeletonLoader(width: 48, height: 22, borderRadius: 6),
              const Spacer(),
              SkeletonLoader(width: 36, height: 36, borderRadius: 18),
            ],
          ),
          const SizedBox(height: 10),
          // Phonetic
          SkeletonLoader(width: 140, height: 14, borderRadius: 6),
          const SizedBox(height: 10),
          // Meaning
          const SkeletonLoader(height: 16, borderRadius: 6),
          const SizedBox(height: 6),
          SkeletonLoader(width: 200, height: 14, borderRadius: 6),
          const SizedBox(height: 14),
          // Divider
          Container(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          const SizedBox(height: 10),
          // Example
          const SkeletonLoader(height: 13, borderRadius: 5),
          const SizedBox(height: 5),
          SkeletonLoader(width: 220, height: 12, borderRadius: 5),
        ],
      ),
    );
  }
}

/// Full-page skeleton for word list loading state
class WordListSkeleton extends StatelessWidget {
  const WordListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => const SkeletonWordCard(),
    );
  }
}
