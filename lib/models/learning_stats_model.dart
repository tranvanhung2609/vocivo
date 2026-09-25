class DailyActivity {
  final DateTime date;
  final int cardsReviewed;
  final int speakingPracticed;
  final int wordsAdded;
  final int xpGained;

  const DailyActivity({
    required this.date,
    this.cardsReviewed = 0,
    this.speakingPracticed = 0,
    this.wordsAdded = 0,
    this.xpGained = 0,
  });

  int get totalActivity => cardsReviewed + speakingPracticed + wordsAdded;

  /// Heatmap intensity level (0 = none, 1 = light, 2 = medium, 3 = high)
  int get intensity {
    if (totalActivity == 0) return 0;
    if (totalActivity <= 5) return 1;
    if (totalActivity <= 15) return 2;
    return 3;
  }
}

class UserLevel {
  final int level;
  final String title;
  final int currentXp;
  final int nextLevelXp;
  final int baseLevelXp;

  const UserLevel({
    required this.level,
    required this.title,
    required this.currentXp,
    required this.nextLevelXp,
    required this.baseLevelXp,
  });

  double get progress {
    final range = nextLevelXp - baseLevelXp;
    if (range <= 0) return 1.0;
    final currentInRange = currentXp - baseLevelXp;
    return (currentInRange / range).clamp(0.0, 1.0);
  }

  static UserLevel fromXp(int xp) {
    const thresholds = [
      0,     // Level 1
      100,   // Level 2
      250,   // Level 3
      500,   // Level 4
      900,   // Level 5
      1500,  // Level 6
      2400,  // Level 7
      3600,  // Level 8
      5200,  // Level 9
      7500,  // Level 10
    ];

    const titles = [
      'Mầm Non Ngôn Ngữ',
      'Tập Sự Khởi Đầu',
      'Thám Hiểm Cần Mẫn',
      'Chiến Binh Từ Vựng',
      'Học Giả Siêng Năng',
      'Người Nói Lưu Loát',
      'Bậc Thầy Trí Nhớ',
      'Chuyên Gia Song Ngữ',
      'Đại Sư Ngôn Từ',
      'Huyền Thoại Song Ngữ',
    ];

    int level = 1;
    for (int i = 0; i < thresholds.length; i++) {
      if (xp >= thresholds[i]) {
        level = i + 1;
      } else {
        break;
      }
    }

    final currentLevelIdx = (level - 1).clamp(0, thresholds.length - 1);
    final nextLevelIdx = level < thresholds.length ? level : thresholds.length - 1;

    final base = thresholds[currentLevelIdx];
    final next = level < thresholds.length ? thresholds[nextLevelIdx] : base + 2000;
    final title = currentLevelIdx < titles.length ? titles[currentLevelIdx] : 'Huyền Thoại';

    return UserLevel(
      level: level,
      title: title,
      currentXp: xp,
      nextLevelXp: next,
      baseLevelXp: base,
    );
  }
}
