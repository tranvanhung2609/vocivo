import 'package:flutter/foundation.dart';

enum SrsRating {
  again, // 0 - Quên
  hard,  // 1 - Khó
  good,  // 2 - Tốt
  easy,  // 3 - Dễ
}

@immutable
class SrsProgress {
  final int vocabId;
  final int repetitionCount;
  final int intervalDays;
  final double easeFactor;
  final DateTime nextReviewDate;
  final DateTime? lastReviewedAt;

  const SrsProgress({
    required this.vocabId,
    this.repetitionCount = 0,
    this.intervalDays = 1,
    this.easeFactor = 2.5,
    required this.nextReviewDate,
    this.lastReviewedAt,
  });

  // Thẻ được coi là đến hạn khi thời điểm hiện tại >= nextReviewDate
  bool get isDue => !DateTime.now().isBefore(nextReviewDate);

  Map<String, dynamic> toMap() {
    return {
      'vocab_id': vocabId,
      'repetition_count': repetitionCount,
      'interval_days': intervalDays,
      'ease_factor': easeFactor,
      'next_review_date': nextReviewDate.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    };
  }

  factory SrsProgress.fromMap(Map<String, dynamic> map) {
    return SrsProgress(
      vocabId: map['vocab_id'] as int,
      repetitionCount: (map['repetition_count'] as int?) ?? 0,
      intervalDays: (map['interval_days'] as int?) ?? 1,
      easeFactor: ((map['ease_factor'] as num?) ?? 2.5).toDouble(),
      nextReviewDate: DateTime.tryParse(map['next_review_date']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 1)),
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.tryParse(map['last_reviewed_at'].toString())
          : null,
    );
  }

  /// Calculates next SRS state based on SM-2 algorithm
  SrsProgress applyReview(SrsRating rating) {
    final now = DateTime.now();
    int newReps = repetitionCount;
    int newInterval = intervalDays;
    double newEase = easeFactor;

    switch (rating) {
      case SrsRating.again:
        newReps = 0;
        newInterval = 0; // Same day (review in 10 minutes)
        newEase = (easeFactor - 0.2).clamp(1.3, double.infinity);
        break;

      case SrsRating.hard:
        newInterval = (intervalDays == 0 ? 1 : (intervalDays * 1.2).round()).clamp(1, 365);
        newEase = (easeFactor - 0.15).clamp(1.3, double.infinity);
        break;

      case SrsRating.good:
        newReps += 1;
        if (newReps == 1) {
          newInterval = 1;
        } else if (newReps == 2) {
          newInterval = 6;
        } else {
          newInterval = (intervalDays * easeFactor).round().clamp(1, 365);
        }
        break;

      case SrsRating.easy:
        newReps += 1;
        if (newReps == 1) {
          newInterval = 4;
        } else if (newReps == 2) {
          newInterval = 10;
        } else {
          newInterval = (intervalDays * easeFactor * 1.3).round().clamp(1, 365);
        }
        newEase = easeFactor + 0.15;
        break;
    }

    final nextReview = rating == SrsRating.again
        ? now.add(const Duration(minutes: 10))
        : now.add(Duration(days: newInterval));

    return SrsProgress(
      vocabId: vocabId,
      repetitionCount: newReps,
      intervalDays: newInterval,
      easeFactor: double.parse(newEase.toStringAsFixed(2)),
      nextReviewDate: nextReview,
      lastReviewedAt: now,
    );
  }
}
