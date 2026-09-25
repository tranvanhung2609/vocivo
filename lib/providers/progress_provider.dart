import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../core/theme/app_colors.dart';
import '../models/achievement_model.dart';
import '../models/learning_stats_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATE DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ProgressState {
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final int totalReviews;
  final int totalSpeakingPractices;
  final int totalWordsMastered;
  final List<Achievement> achievements;
  final List<DailyActivity> recentActivities; // last 28 days
  final bool isLoaded;

  const ProgressState({
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalReviews,
    required this.totalSpeakingPractices,
    required this.totalWordsMastered,
    required this.achievements,
    required this.recentActivities,
    this.isLoaded = false,
  });

  UserLevel get userLevel => UserLevel.fromXp(totalXp);

  int get unlockedAchievementsCount =>
      achievements.where((a) => a.isUnlocked).length;

  ProgressState copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    int? totalReviews,
    int? totalSpeakingPractices,
    int? totalWordsMastered,
    List<Achievement>? achievements,
    List<DailyActivity>? recentActivities,
    bool? isLoaded,
  }) {
    return ProgressState(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalReviews: totalReviews ?? this.totalReviews,
      totalSpeakingPractices: totalSpeakingPractices ?? this.totalSpeakingPractices,
      totalWordsMastered: totalWordsMastered ?? this.totalWordsMastered,
      achievements: achievements ?? this.achievements,
      recentActivities: recentActivities ?? this.recentActivities,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT ACHIEVEMENTS (10+ Curated Badges)
// ─────────────────────────────────────────────────────────────────────────────

List<Achievement> _buildInitialAchievements() {
  return const [
    Achievement(
      id: 'first_word',
      title: 'Khởi Đầu Hứng Khởi',
      description: 'Lưu từ vựng đầu tiên vào sổ tay cá nhân',
      icon: Icons.bookmark_add_rounded,
      color: AppColors.primaryEnglish,
      tier: AchievementTier.bronze,
      category: AchievementCategory.vocabulary,
      currentProgress: 0,
      targetProgress: 1,
      rewardXp: 20,
    ),
    Achievement(
      id: 'vocab_20',
      title: 'Kho Từ Cơ Bản',
      description: 'Thu nạp 20 từ vựng vào sổ tay',
      icon: Icons.menu_book_rounded,
      color: AppColors.accent,
      tier: AchievementTier.bronze,
      category: AchievementCategory.vocabulary,
      currentProgress: 0,
      targetProgress: 20,
      rewardXp: 50,
    ),
    Achievement(
      id: 'vocab_100',
      title: 'Bậc Thầy Ngôn Từ',
      description: 'Sở hữu 100 từ vựng trong sổ tay',
      icon: Icons.auto_stories_rounded,
      color: AppColors.streakAmber,
      tier: AchievementTier.gold,
      category: AchievementCategory.vocabulary,
      currentProgress: 0,
      targetProgress: 100,
      rewardXp: 150,
    ),
    Achievement(
      id: 'streak_3',
      title: 'Giữ Lửa Đam Mê',
      description: 'Duy trì chuỗi học 3 ngày liên tiếp',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.streakOrange,
      tier: AchievementTier.bronze,
      category: AchievementCategory.streak,
      currentProgress: 0,
      targetProgress: 3,
      rewardXp: 40,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Chiến Binh Kiên Trì',
      description: 'Duy trì chuỗi học 7 ngày không gián đoạn',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFEA580C),
      tier: AchievementTier.silver,
      category: AchievementCategory.streak,
      currentProgress: 0,
      targetProgress: 7,
      rewardXp: 100,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Kỷ Luật Vàng',
      description: 'Chinh phục cột mốc 30 ngày học liên tục',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFC026D3),
      tier: AchievementTier.platinum,
      category: AchievementCategory.streak,
      currentProgress: 0,
      targetProgress: 30,
      rewardXp: 300,
    ),
    Achievement(
      id: 'speak_5',
      title: 'Tự Tin Mở Lời',
      description: 'Hoàn thành 5 bài luyện phát âm giọng nói',
      icon: Icons.mic_rounded,
      color: AppColors.primaryEnglish,
      tier: AchievementTier.bronze,
      category: AchievementCategory.speaking,
      currentProgress: 0,
      targetProgress: 5,
      rewardXp: 40,
    ),
    Achievement(
      id: 'speak_master',
      title: 'Giọng Vàng Bản Xứ',
      description: 'Đạt điểm phát âm trên 90% trong 10 bài luyện',
      icon: Icons.record_voice_over_rounded,
      color: Color(0xFF0284C7),
      tier: AchievementTier.silver,
      category: AchievementCategory.speaking,
      currentProgress: 0,
      targetProgress: 10,
      rewardXp: 120,
    ),
    Achievement(
      id: 'srs_review_50',
      title: 'Khai Phóng Trí Nhớ',
      description: 'Ôn tập 50 thẻ ghi nhớ thông minh SRS',
      icon: Icons.style_rounded,
      color: Color(0xFF8B5CF6),
      tier: AchievementTier.silver,
      category: AchievementCategory.srs,
      currentProgress: 0,
      targetProgress: 50,
      rewardXp: 80,
    ),
    Achievement(
      id: 'srs_master_20',
      title: 'Trí Nhớ Vĩnh Cửu',
      description: 'Làm chủ (Level 5) hoàn toàn 20 từ vựng',
      icon: Icons.verified_rounded,
      color: AppColors.successGreen,
      tier: AchievementTier.gold,
      category: AchievementCategory.srs,
      currentProgress: 0,
      targetProgress: 20,
      rewardXp: 160,
    ),
    Achievement(
      id: 'xp_500',
      title: 'Thợ Săn Kinh Nghiệm',
      description: 'Tích lũy tổng cộng 500 điểm XP học tập',
      icon: Icons.bolt_rounded,
      color: AppColors.streakAmber,
      tier: AchievementTier.silver,
      category: AchievementCategory.xp,
      currentProgress: 0,
      targetProgress: 500,
      rewardXp: 100,
    ),
    Achievement(
      id: 'bilingual_polyglot',
      title: 'Học Giả Song Ngữ',
      description: 'Thêm từ và luyện tập cả Tiếng Anh và Tiếng Trung',
      icon: Icons.translate_rounded,
      color: Color(0xFF06B6D4),
      tier: AchievementTier.gold,
      category: AchievementCategory.vocabulary,
      currentProgress: 0,
      targetProgress: 2,
      rewardXp: 100,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    // Khởi tạo với zero state — sẽ load real data ngay sau
    Future.microtask(() => _loadFromStorage());
    return const ProgressState(
      totalXp: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalReviews: 0,
      totalSpeakingPractices: 0,
      totalWordsMastered: 0,
      achievements: [],
      recentActivities: [],
      isLoaded: false,
    );
  }

  static const _keyTotalXp = 'progress_total_xp';
  static const _keyLongestStreak = 'progress_longest_streak';
  static const _keyReviews = 'progress_total_reviews';
  static const _keySpeaking = 'progress_total_speaking';
  static const _keyWordsMastered = 'progress_words_mastered';

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load XP & counters từ SharedPreferences
      final xp = prefs.getInt(_keyTotalXp) ?? 0;
      final speaking = prefs.getInt(_keySpeaking) ?? 0;

      // Load streak từ SQLite (nguồn chính xác nhất)
      final streak = await AppDatabase.instance.checkAndUpdateStreak();
      final longest = prefs.getInt(_keyLongestStreak) ?? streak;
      final reviews = prefs.getInt(_keyReviews) ?? 0;

      // Load real mastered count từ SQLite với fallback SharedPreferences
      final savedMastered = prefs.getInt(_keyWordsMastered) ?? 0;
      final dbMastered = await AppDatabase.instance.getMasteredWordsCount();
      final mastered = dbMastered > 0 ? dbMastered : savedMastered;

      // Load total words count cho achievements
      final totalWords = await AppDatabase.instance.getTotalWordsCount();

      // Load lịch sử hoạt động thực tế từ SQLite
      final activityRows = await AppDatabase.instance.getRecentActivities(days: 28);
      final activities = _buildActivitiesFromDb(activityRows);

      // Xây dựng achievements với progress thực tế
      final achievements = _buildAchievementsWithProgress(
        totalXp: xp,
        streak: streak,
        totalReviews: reviews,
        totalSpeaking: speaking,
        totalWords: totalWords,
        mastered: mastered,
      );

      state = ProgressState(
        totalXp: xp,
        currentStreak: streak,
        longestStreak: longest > streak ? longest : streak,
        totalReviews: reviews,
        totalSpeakingPractices: speaking,
        totalWordsMastered: mastered,
        achievements: achievements,
        recentActivities: activities,
        isLoaded: true,
      );
    } catch (e, st) {
      debugPrint('ProgressNotifier._loadFromStorage error: $e\n$st');
      // Fallback: vẫn hiển thị với zero values
      state = state.copyWith(
        achievements: _buildInitialAchievements(),
        isLoaded: true,
      );
    }
  }

  /// Chuyển đổi DB rows thành DailyActivity objects
  List<DailyActivity> _buildActivitiesFromDb(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final dateStr = row['date']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();
      return DailyActivity(
        date: date,
        cardsReviewed: (row['cards_reviewed'] as int?) ?? 0,
        speakingPracticed: (row['speaking_practiced'] as int?) ?? 0,
        wordsAdded: (row['words_added'] as int?) ?? 0,
        xpGained: (row['xp_gained'] as int?) ?? 0,
      );
    }).toList();
  }

  /// Xây achievements với progress thực tế từ DB
  List<Achievement> _buildAchievementsWithProgress({
    required int totalXp,
    required int streak,
    required int totalReviews,
    required int totalSpeaking,
    required int totalWords,
    required int mastered,
  }) {
    return _buildInitialAchievements().map((ach) {
      int cur = 0;
      switch (ach.id) {
        case 'first_word':
        case 'vocab_20':
        case 'vocab_100':
          cur = totalWords;
          break;
        case 'streak_3':
        case 'streak_7':
        case 'streak_30':
          cur = streak;
          break;
        case 'speak_5':
        case 'speak_master':
          cur = totalSpeaking;
          break;
        case 'srs_review_50':
          cur = totalReviews;
          break;
        case 'srs_master_20':
          cur = mastered;
          break;
        case 'xp_500':
          cur = totalXp;
          break;
        case 'bilingual_polyglot':
          // TODO: detect both EN & ZH từ DB
          cur = 0;
          break;
      }
      final unlocked = cur >= ach.targetProgress;
      return ach.copyWith(
        currentProgress: cur,
        isUnlocked: unlocked,
        unlockedAt: unlocked && ach.unlockedAt == null
            ? DateTime.now().toIso8601String()
            : ach.unlockedAt,
      );
    }).toList();
  }

  Future<void> addXp(int amount) async {
    final newXp = state.totalXp + amount;
    state = state.copyWith(totalXp: newXp);
    _checkAchievements();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyTotalXp, newXp);
    } catch (_) {}
  }

  Future<void> recordReview(int count) async {
    final newReviews = state.totalReviews + count;
    final earnedXp = count * 5;
    final newXp = state.totalXp + earnedXp;
    state = state.copyWith(totalReviews: newReviews, totalXp: newXp);
    _checkAchievements();

    // Ghi vào SQLite để có lịch sử thực tế
    await AppDatabase.instance.recordDailyActivity(
      cardsReviewed: count,
      xpGained: earnedXp,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyReviews, newReviews);
      await prefs.setInt(_keyTotalXp, newXp);
    } catch (_) {}
  }

  Future<void> recordSpeakingSession({required int score}) async {
    final newSpeaking = state.totalSpeakingPractices + 1;
    final earnedXp = score >= 90 ? 25 : 15;
    final newXp = state.totalXp + earnedXp;
    state = state.copyWith(totalSpeakingPractices: newSpeaking, totalXp: newXp);
    _checkAchievements();

    // Ghi vào SQLite
    await AppDatabase.instance.recordDailyActivity(
      speakingPracticed: 1,
      xpGained: earnedXp,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySpeaking, newSpeaking);
      await prefs.setInt(_keyTotalXp, newXp);
    } catch (_) {}
  }

  /// Gọi sau khi user lưu từ vựng mới
  Future<void> recordWordAdded() async {
    final mastered = await AppDatabase.instance.getMasteredWordsCount();
    state = state.copyWith(totalWordsMastered: mastered);
    _checkAchievements();

    await AppDatabase.instance.recordDailyActivity(wordsAdded: 1, xpGained: 5);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWordsMastered, mastered);
    } catch (_) {}
  }

  /// Làm mới và đồng bộ số từ đã thành thạo (repetition >= 5) từ SQLite
  Future<void> refreshMasteredWords() async {
    final mastered = await AppDatabase.instance.getMasteredWordsCount();
    state = state.copyWith(totalWordsMastered: mastered);
    _checkAchievements();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWordsMastered, mastered);
    } catch (_) {}
  }

  void _checkAchievements() {
    final totalWords = state.totalWordsMastered; // dùng mastered làm proxy
    final updated = state.achievements.map((ach) {
      if (ach.isUnlocked) return ach;

      int cur = ach.currentProgress;
      switch (ach.id) {
        case 'xp_500':
          cur = state.totalXp;
          break;
        case 'srs_review_50':
          cur = state.totalReviews;
          break;
        case 'speak_5':
        case 'speak_master':
          cur = state.totalSpeakingPractices;
          break;
        case 'streak_3':
        case 'streak_7':
        case 'streak_30':
          cur = state.currentStreak;
          break;
        case 'srs_master_20':
          cur = totalWords;
          break;
        default:
          break;
      }

      final unlocked = cur >= ach.targetProgress;
      return ach.copyWith(
        currentProgress: cur,
        isUnlocked: unlocked,
        unlockedAt: unlocked && ach.unlockedAt == null
            ? DateTime.now().toIso8601String()
            : ach.unlockedAt,
      );
    }).toList();

    state = state.copyWith(achievements: updated);
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(() {
  return ProgressNotifier();
});
