import 'package:flutter_test/flutter_test.dart';
import 'package:vocivo/models/srs_progress.dart';

void main() {
  group('SrsProgress SM-2 Algorithm Tests', () {
    test('Initial progress is due by default if nextReviewDate is now', () {
      final progress = SrsProgress(
        vocabId: 1,
        nextReviewDate: DateTime.now(),
      );
      expect(progress.isDue, isTrue);
    });

    test('Future review date is not due', () {
      final progress = SrsProgress(
        vocabId: 1,
        nextReviewDate: DateTime.now().add(const Duration(days: 2)),
      );
      expect(progress.isDue, isFalse);
    });

    test('Rating again resets repetitionCount and sets interval to 0', () {
      final initial = SrsProgress(
        vocabId: 1,
        repetitionCount: 4,
        intervalDays: 10,
        easeFactor: 2.5,
        nextReviewDate: DateTime.now(),
      );

      final next = initial.applyReview(SrsRating.again);
      expect(next.repetitionCount, equals(0));
      expect(next.intervalDays, equals(0));
      expect(next.easeFactor, equals(2.3));
    });

    test('Ease factor does not fall below 1.3', () {
      final initial = SrsProgress(
        vocabId: 1,
        repetitionCount: 0,
        intervalDays: 1,
        easeFactor: 1.35,
        nextReviewDate: DateTime.now(),
      );

      final next = initial.applyReview(SrsRating.again);
      expect(next.easeFactor, equals(1.3));
    });

    test('Rating good increments repetitions and calculates interval', () {
      final rep0 = SrsProgress(
        vocabId: 1,
        repetitionCount: 0,
        intervalDays: 1,
        easeFactor: 2.5,
        nextReviewDate: DateTime.now(),
      );

      final rep1 = rep0.applyReview(SrsRating.good);
      expect(rep1.repetitionCount, equals(1));
      expect(rep1.intervalDays, equals(1));

      final rep2 = rep1.applyReview(SrsRating.good);
      expect(rep2.repetitionCount, equals(2));
      expect(rep2.intervalDays, equals(6));

      final rep3 = rep2.applyReview(SrsRating.good);
      expect(rep3.repetitionCount, equals(3));
      expect(rep3.intervalDays, equals((6 * 2.5).round()));
    });

    test('Rating easy increases easeFactor without upper cap', () {
      final initial = SrsProgress(
        vocabId: 1,
        repetitionCount: 2,
        intervalDays: 6,
        easeFactor: 3.0,
        nextReviewDate: DateTime.now(),
      );

      final next = initial.applyReview(SrsRating.easy);
      expect(next.easeFactor, greaterThan(3.0));
      expect(next.repetitionCount, equals(3));
    });
  });
}
