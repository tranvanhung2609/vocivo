import 'package:flutter/material.dart';

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
}

enum AchievementCategory {
  streak,
  vocabulary,
  speaking,
  srs,
  xp,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final AchievementTier tier;
  final AchievementCategory category;
  final int currentProgress;
  final int targetProgress;
  final bool isUnlocked;
  final String? unlockedAt;
  final int rewardXp;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.tier,
    required this.category,
    required this.currentProgress,
    required this.targetProgress,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.rewardXp,
  });

  double get progressFraction =>
      targetProgress == 0 ? 1.0 : (currentProgress / targetProgress).clamp(0.0, 1.0);

  Achievement copyWith({
    int? currentProgress,
    bool? isUnlocked,
    String? unlockedAt,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      color: color,
      tier: tier,
      category: category,
      currentProgress: currentProgress ?? this.currentProgress,
      targetProgress: targetProgress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rewardXp: rewardXp,
    );
  }
}
