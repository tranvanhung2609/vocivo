import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_breakpoints.dart';
import '../../core/services/pronunciation_evaluator.dart';
import '../../core/services/stt_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';
import '../widgets/pinyin_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & CONFIG
// ─────────────────────────────────────────────────────────────────────────────

enum PracticeMode {
  wordDrill, // Luyện phát âm từng từ, âm tiết
  sentence,  // Luyện phát âm cả câu ví dụ
}

enum SpeakingPhase {
  ready,      // Sẵn sàng nghe mẫu và bấm nói
  listening,  // Đang thu âm qua microphone
  evaluating, // Đang tính điểm
  result,     // Đã có kết quả đánh giá chi tiết
}

class SpeakingScreen extends ConsumerStatefulWidget {
  final List<VocabularyItem>? initialItems;
  final String? title;

  const SpeakingScreen({super.key, this.initialItems, this.title});

  @override
  ConsumerState<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends ConsumerState<SpeakingScreen>
    with TickerProviderStateMixin {
  // Practice items & mode
  PracticeMode _practiceMode = PracticeMode.wordDrill;
  SpeakingPhase _phase = SpeakingPhase.ready;
  int _currentIndex = 0;
  List<VocabularyItem> _items = [];

  // Audio & TTS
  bool _isPlayingTts = false;
  bool _isSlowTts = false;

  // Speech Recognition (STT)
  final SttService _sttService = SttService.instance;
  final PronunciationEvaluator _evaluator = PronunciationEvaluator.instance;
  StreamSubscription<double>? _soundLevelSub;
  double _currentSoundLevel = 0.0;
  String _liveRecognizedText = '';
  PronunciationResult? _latestResult;

  // Score & Session stats
  int _totalScoreSum = 0;
  int _completedCount = 0;
  int _earnedXp = 0;

  // Animations
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnimation;

  // Confetti particles for completion
  final List<_ConfettiParticle> _confettiParticles = [];
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scoreAnimation = CurvedAnimation(
      parent: _scoreAnimController,
      curve: Curves.easeOutCubic,
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Initialize STT
    _sttService.initialize();

    // Listen to sound levels for dynamic waveform
    _soundLevelSub = _sttService.soundLevelStream.listen((level) {
      if (mounted) {
        setState(() => _currentSoundLevel = level);
      }
    });
  }

  @override
  void dispose() {
    _soundLevelSub?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    _scoreAnimController.dispose();
    _confettiController.dispose();
    _sttService.stopListening();
    super.dispose();
  }

  void _loadItems(VocabularyState vocabState) {
    if (_items.isEmpty) {
      if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
        _items = [...widget.initialItems!];
        _currentIndex = 0;
        return;
      }
      var list = [...vocabState.notebookItems];
      if (list.isEmpty) {
        list = [...vocabState.searchResults];
      }
      if (list.isEmpty) return;
      list.shuffle(Random());
      _items = list.take(15).toList();
      _currentIndex = 0;
    }
  }

  VocabularyItem? get _currentItem =>
      _items.isEmpty || _currentIndex >= _items.length ? null : _items[_currentIndex];

  String _getTargetText(VocabularyItem item) {
    if (_practiceMode == PracticeMode.sentence) {
      if (item.examples.isNotEmpty) {
        return item.examples.first.text;
      }
    }
    return item.word;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AUDIO & SPEECH HANDLERS
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _playTts({bool slow = false}) async {
    final item = _currentItem;
    if (item == null || _isPlayingTts) return;

    final targetText = _getTargetText(item);
    setState(() {
      _isPlayingTts = true;
      _isSlowTts = slow;
    });

    HapticFeedback.selectionClick();
    await TtsService.instance.speak(
      text: targetText,
      languageCode: item.languageCode,
      rate: slow ? 0.32 : 0.48,
    );

    if (mounted) {
      setState(() => _isPlayingTts = false);
    }
  }

  void _startSpeaking() async {
    final item = _currentItem;
    if (item == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _phase = SpeakingPhase.listening;
      _liveRecognizedText = '';
      _latestResult = null;
    });

    final success = await _sttService.startListening(
      languageCode: item.languageCode,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _liveRecognizedText = text);
        if (isFinal && text.trim().isNotEmpty) {
          _evaluateSpeech(text);
        }
      },
    );

    if (!success) {
      // Platform doesn't support STT or permission denied (e.g. Windows native)
      // Provide an automated fallback simulation dialog or prompt
      _showDesktopFallbackNotice();
    }
  }

  void _stopSpeaking() async {
    await _sttService.stopListening();
    if (_phase == SpeakingPhase.listening) {
      if (_liveRecognizedText.trim().isNotEmpty) {
        _evaluateSpeech(_liveRecognizedText);
      } else {
        // Evaluate empty
        _evaluateSpeech('');
      }
    }
  }

  void _evaluateSpeech(String spokenText) {
    final item = _currentItem;
    if (item == null) return;

    final targetText = _getTargetText(item);
    final result = _evaluator.evaluate(
      target: targetText,
      spoken: spokenText,
      languageCode: item.languageCode,
      phonetic: item.phonetic,
    );

    setState(() {
      _phase = SpeakingPhase.result;
      _latestResult = result;
      _completedCount++;
      _totalScoreSum += result.overallScore;
      if (result.isPassed) {
        _earnedXp += 15 + (result.overallScore >= 90 ? 10 : 0);
      }
    });

    _scoreAnimController.forward(from: 0.0);

    if (result.overallScore >= 80) {
      HapticFeedback.lightImpact();
    }
  }

  void _simulateSpeech(String testText) {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = SpeakingPhase.listening;
      _liveRecognizedText = testText;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _evaluateSpeech(testText);
      }
    });
  }

  void _nextItem() {
    HapticFeedback.selectionClick();
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _phase = SpeakingPhase.ready;
        _liveRecognizedText = '';
        _latestResult = null;
      });
    } else {
      _showSessionCompletion();
    }
  }

  void _retryItem() {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = SpeakingPhase.ready;
      _liveRecognizedText = '';
      _latestResult = null;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // COMPLETION & CELEBRATION
  // ───────────────────────────────────────────────────────────────────────────

  void _showSessionCompletion() {
    _initConfetti();
    _confettiController.forward(from: 0.0);

    final avgScore = _completedCount > 0 ? (_totalScoreSum / _completedCount).round() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Stack(
        children: [
          // Confetti overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (_, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _confettiParticles,
                    progress: _confettiController.value,
                  ),
                ),
              ),
            ),
          ),
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryEnglish.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.streakAmber,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Hoàn thành Luyện Nói!',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn đã hoàn thành phiên luyện phát âm xuất sắc.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textLightMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      icon: Icons.star_rounded,
                      title: '$avgScore%',
                      subtitle: 'Điểm TB',
                      color: avgScore >= 75 ? AppColors.successGreen : AppColors.streakAmber,
                    ),
                    _buildStatCard(
                      icon: Icons.bolt_rounded,
                      title: '+$_earnedXp XP',
                      subtitle: 'Kinh nghiệm',
                      color: AppColors.primaryEnglish,
                    ),
                    _buildStatCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: '$_completedCount',
                      subtitle: 'Đã luyện',
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Về Trang Chủ'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _items.shuffle(Random());
                    _currentIndex = 0;
                    _phase = SpeakingPhase.ready;
                    _liveRecognizedText = '';
                    _latestResult = null;
                    _totalScoreSum = 0;
                    _completedCount = 0;
                    _earnedXp = 0;
                  });
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Luyện Tập Lại'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryEnglish,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textLightMuted),
          ),
        ],
      ),
    );
  }

  void _initConfetti() {
    _confettiParticles.clear();
    final random = Random();
    final colors = [
      AppColors.primaryEnglish,
      AppColors.streakOrange,
      AppColors.accent,
      AppColors.streakAmber,
      Colors.pinkAccent,
      Colors.purpleAccent,
    ];

    for (int i = 0; i < 50; i++) {
      _confettiParticles.add(
        _ConfettiParticle(
          x: 0.5 + (random.nextDouble() - 0.5) * 0.4,
          y: 0.35 + (random.nextDouble() - 0.5) * 0.2,
          vx: (random.nextDouble() - 0.5) * 0.7,
          vy: -random.nextDouble() * 0.6 - 0.2,
          color: colors[random.nextInt(colors.length)],
          size: random.nextDouble() * 8 + 6,
          angle: random.nextDouble() * pi * 2,
          angularV: (random.nextDouble() - 0.5) * 8,
          shape: random.nextInt(3),
        ),
      );
    }
  }

  void _showDesktopFallbackNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Thiết bị chưa hỗ trợ nhận diện trực tiếp hoặc chưa cấp quyền Mic. Hãy dùng thanh "Thử nghiệm mẫu" ở dưới để kiểm tra.',
        ),
        backgroundColor: AppColors.accentDeep,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vocabState = ref.watch(vocabularyProvider);
    _loadItems(vocabState);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isTablet = width >= AppBreakpoints.tablet && width < AppBreakpoints.desktop;
    final item = _currentItem;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.surfaceLight,
      appBar: _buildAppBar(isDark),
      body: SafeArea(
        child: item == null
            ? _buildEmptyState(isDark)
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 960 : (isTablet ? 720 : double.infinity),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: isDesktop
                        ? _buildDesktopLayout(item, isDark)
                        : _buildMobileLayout(item, isDark),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: item != null && !isDesktop ? _buildBottomBar(item, isDark) : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final progress = _items.isEmpty ? 0.0 : (_currentIndex + 1) / _items.length;

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Luyện Phát Âm',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                ),
              ),
              const SizedBox(width: 8),
              // XP badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.streakAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: AppColors.streakAmber),
                    const SizedBox(width: 2),
                    Text(
                      '$_earnedXp XP',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.streakAmberDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            _items.isEmpty
                ? 'Đang tải...'
                : 'Mục ${_currentIndex + 1} / ${_items.length}  •  ${_practiceMode == PracticeMode.wordDrill ? "Từ vựng" : "Câu hoàn chỉnh"}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ],
      ),
      actions: [
        // Mode Switcher segmented button
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDark : AppColors.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeTab(
                label: 'Từ',
                mode: PracticeMode.wordDrill,
                icon: Icons.spellcheck_rounded,
                isDark: isDark,
              ),
              _buildModeTab(
                label: 'Câu',
                mode: PracticeMode.sentence,
                icon: Icons.notes_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          color: AppColors.primaryEnglish,
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required PracticeMode mode,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _practiceMode == mode;
    return InkWell(
      onTap: () {
        if (_phase == SpeakingPhase.listening) _sttService.stopListening();
        setState(() {
          _practiceMode = mode;
          _phase = SpeakingPhase.ready;
          _liveRecognizedText = '';
          _latestResult = null;
        });
      },
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryEnglish : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LAYOUTS (Mobile & Desktop)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(VocabularyItem item, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Main content card (Word or Sentence)
          _buildPromptCard(item, isDark),
          const SizedBox(height: 16),

          // Evaluation or Audio visualization
          if (_phase == SpeakingPhase.listening) ...[
            _buildListeningWaveform(isDark),
            const SizedBox(height: 16),
          ] else if (_phase == SpeakingPhase.result && _latestResult != null) ...[
            _buildResultGaugeAndMetrics(_latestResult!, isDark),
            const SizedBox(height: 16),
          ],

          // Simulation / Testing buttons for desktop or easy test
          _buildSimulatorBar(item, isDark),
          const SizedBox(height: 80), // padding for bottom bar
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(VocabularyItem item, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Prompt Card & Audio Controls
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildPromptCard(item, isDark),
                const SizedBox(height: 16),
                _buildDesktopAudioControls(item, isDark),
                const SizedBox(height: 16),
                _buildSimulatorBar(item, isDark),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Live Waveform or Scoring Metrics
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_phase == SpeakingPhase.listening)
                  _buildListeningWaveform(isDark)
                else if (_phase == SpeakingPhase.result && _latestResult != null)
                  _buildResultGaugeAndMetrics(_latestResult!, isDark)
                else
                  _buildReadyGuideCard(item, isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PROMPT CARD (Word vs Sentence Mode)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPromptCard(VocabularyItem item, bool isDark) {
    final isZh = item.languageCode.toUpperCase() == 'ZH';
    final hasSentence = item.examples.isNotEmpty;
    final sentence = hasSentence ? item.examples.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header tags: Language & CEFR/HSK badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isZh ? AppColors.hskBg : AppColors.cefrBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isZh ? AppColors.hskBorder : AppColors.cefrBorder),
                ),
                child: Text(
                  isZh ? 'Tiếng Trung (HSK)' : 'Tiếng Anh (CEFR)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isZh ? AppColors.hskText : AppColors.cefrText,
                  ),
                ),
              ),
              if (item.hanViet != null && isZh)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.hanVietBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hanVietBorder),
                  ),
                  child: Text(
                    'Hán-Việt: ${item.hanViet}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hanVietText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Prompt Text
          if (_practiceMode == PracticeMode.wordDrill) ...[
            // Word display
            Text(
              item.word,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isZh ? 48 : 36,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                letterSpacing: isZh ? 2.0 : 0.0,
              ),
            ),
            const SizedBox(height: 8),

            // Phonetic / Pinyin
            if (item.phonetic != null) ...[
              if (isZh)
                PinyinText(pinyin: item.phonetic!, fontSize: 20)
              else
                Text(
                  '/${item.phonetic}/',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Vietnamese meaning
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.meaningVi,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                ),
              ),
            ),
          ] else ...[
            // Sentence Mode
            if (sentence != null) ...[
              Text(
                sentence.text,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: isZh ? 24 : 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                ),
              ),
              if (sentence.pinyin != null && isZh) ...[
                const SizedBox(height: 6),
                PinyinText(pinyin: sentence.pinyin!, fontSize: 16),
              ],
              const SizedBox(height: 10),
              Text(
                sentence.vi,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              Text(
                item.word,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Chưa có câu mẫu cho từ này. Đang luyện từ vựng đơn lẻ.',
                style: TextStyle(fontSize: 12, color: AppColors.streakAmberDeep),
              ),
            ],
          ],

          const SizedBox(height: 20),

          // Pronunciation Audio Controls (Normal & Slow)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isPlayingTts ? null : () => _playTts(slow: false),
                icon: Icon(
                  _isPlayingTts && !_isSlowTts ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                  size: 18,
                ),
                label: const Text('Nghe chuẩn (1.0x)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryEnglish,
                  side: const BorderSide(color: AppColors.primaryEnglish),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isPlayingTts ? null : () => _playTts(slow: true),
                icon: Icon(
                  _isPlayingTts && _isSlowTts ? Icons.slow_motion_video_rounded : Icons.slow_motion_video_outlined,
                  size: 18,
                ),
                label: const Text('Nghe chậm (0.4x)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LIVE WAVEFORM & LISTENING DISPLAY
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildListeningWaveform(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryEnglish.withValues(alpha: 0.4), width: 2),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.6 + _pulseController.value * 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang lắng nghe giọng của bạn...',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryEnglish,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic multi-bar sound visualizer
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(24, (i) {
                    final delay = (i * 0.08) % 1.0;
                    final waveSine = sin((_waveController.value + delay) * pi * 2).abs();
                    // React to real sound level if available, otherwise oscillating wave
                    final levelBoost = _currentSoundLevel > 0.1 ? _currentSoundLevel * 45 : 12;
                    final barHeight = 8.0 + (waveSine * levelBoost);

                    return Container(
                      width: 4,
                      height: barHeight.clamp(6.0, 58.0),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primaryEnglish,
                            i % 2 == 0 ? AppColors.accent : AppColors.primaryEnglishDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Real-time recognized text preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDark : AppColors.bgLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Text(
              _liveRecognizedText.isEmpty ? 'Hãy phát âm rõ ràng vào microphone...' : '"$_liveRecognizedText"',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _liveRecognizedText.isEmpty
                    ? (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted)
                    : (isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stop button
          ElevatedButton.icon(
            onPressed: _stopSpeaking,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Dừng & Chấm Điểm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SCORING GAUGE & ACCURACY BREAKDOWN
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildResultGaugeAndMetrics(PronunciationResult result, bool isDark) {
    Color gradeColor;
    switch (result.grade) {
      case PronunciationGrade.excellent:
        gradeColor = AppColors.successGreen;
        break;
      case PronunciationGrade.good:
        gradeColor = AppColors.accent;
        break;
      case PronunciationGrade.fair:
        gradeColor = AppColors.streakAmber;
        break;
      case PronunciationGrade.needsWork:
        gradeColor = AppColors.errorRed;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gradeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Column(
        children: [
          // Circular gauge + feedback header
          Row(
            children: [
              // Circular Score Gauge
              AnimatedBuilder(
                animation: _scoreAnimation,
                builder: (context, child) {
                  final animatedScore = (_scoreAnimation.value * result.overallScore).round();
                  return SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (_scoreAnimation.value * result.overallScore) / 100.0,
                          strokeWidth: 8,
                          backgroundColor: gradeColor.withValues(alpha: 0.15),
                          color: gradeColor,
                          strokeCap: StrokeCap.round,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$animatedScore',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: gradeColor,
                              ),
                            ),
                            Text(
                              'ĐIỂM',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),

              // Feedback text & Motivational banner
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        result.overallScore >= 90
                            ? 'XUẤT SẮC'
                            : result.overallScore >= 75
                                ? 'RẤT TỐT'
                                : result.overallScore >= 50
                                    ? 'ĐẠT TIÊU CHUẨN'
                                    : 'CẦN LUYỆN THÊM',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: gradeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.feedbackVi,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3 Metric Bars: Accuracy, Completeness, Fluency
          Row(
            children: [
              Expanded(
                child: _buildMetricBar(
                  label: 'Độ chuẩn',
                  score: result.accuracyScore,
                  color: AppColors.primaryEnglish,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricBar(
                  label: 'Hoàn thiện',
                  score: result.completenessScore,
                  color: AppColors.accent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricBar(
                  label: 'Lưu loát',
                  score: result.fluencyScore,
                  color: AppColors.streakOrange,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Word-by-word token analysis
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chi tiết từng từ bạn đã phát âm:',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tokens Wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.words.map((wordEval) {
              Color tokenBg;
              Color tokenBorder;
              Color tokenText;
              IconData tokenIcon;

              switch (wordEval.accuracy) {
                case WordAccuracy.perfect:
                  tokenBg = AppColors.successGreenLight;
                  tokenBorder = AppColors.successGreen.withValues(alpha: 0.4);
                  tokenText = AppColors.primaryEnglishDeep;
                  tokenIcon = Icons.check_circle_rounded;
                  break;
                case WordAccuracy.close:
                  tokenBg = AppColors.hskBg;
                  tokenBorder = AppColors.hskBorder;
                  tokenText = AppColors.hskText;
                  tokenIcon = Icons.info_outline_rounded;
                  break;
                case WordAccuracy.missed:
                  tokenBg = AppColors.errorRedLight;
                  tokenBorder = AppColors.errorRed.withValues(alpha: 0.4);
                  tokenText = AppColors.errorRed;
                  tokenIcon = Icons.cancel_rounded;
                  break;
                case WordAccuracy.extra:
                  tokenBg = const Color(0xFFF1F5F9);
                  tokenBorder = const Color(0xFFCBD5E1);
                  tokenText = const Color(0xFF475569);
                  tokenIcon = Icons.add_circle_outline_rounded;
                  break;
              }

              return Tooltip(
                message: wordEval.tip ?? '',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokenBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokenBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tokenIcon, size: 14, color: tokenText),
                      const SizedBox(width: 5),
                      Text(
                        wordEval.targetWord.isNotEmpty ? wordEval.targetWord : (wordEval.spokenWord ?? ''),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokenText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // What user actually spoke
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDark : AppColors.bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Âm thanh thu được: "${result.recognizedText}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Buttons: Luyện lại & Tiếp theo
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retryItem,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Nói lại'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _nextItem,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Tiếp theo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryEnglish,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar({
    required String label,
    required int score,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : AppColors.bgLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                ),
              ),
              Text(
                '$score%',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 5,
              backgroundColor: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyGuideCard(VocabularyItem item, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: AppColors.shadowLevel1,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryEnglishLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: AppColors.primaryEnglish,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bí Quyết Phát Âm Chuẩn',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildTipRow(
            icon: Icons.headphones_rounded,
            text: 'Nghe mẫu 1.0x và 0.4x nhiều lần để cảm nhận nhịp điệu và ngữ điệu.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTipRow(
            icon: Icons.record_voice_over_rounded,
            text: 'Nhấn nút Mic to và bắt đầu phát âm to, rõ ràng gần microphone.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTipRow(
            icon: Icons.check_circle_outline_rounded,
            text: 'Hệ thống AI sẽ phân tích từng âm tiết và chấm điểm tức thì.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow({required IconData icon, required String text, required bool isDark}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryEnglish),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SIMULATOR / TEST BAR (Allows testing pronunciation outcomes on any platform)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSimulatorBar(VocabularyItem item, bool isDark) {
    final target = _getTargetText(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark.withValues(alpha: 0.5) : AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Thử nghiệm nhanh chất lượng phát âm:',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('Phát âm chuẩn (100%)'),
                avatar: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.successGreen),
                onPressed: () => _simulateSpeech(target),
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              ),
              ActionChip(
                label: const Text('Gần đúng (70%)'),
                avatar: const Icon(Icons.timelapse_rounded, size: 14, color: AppColors.warningYellow),
                onPressed: () {
                  final modified = target.length > 3 ? target.substring(0, target.length - 2) : target;
                  _simulateSpeech(modified);
                },
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              ),
              ActionChip(
                label: const Text('Phát âm sai'),
                avatar: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.errorRed),
                onPressed: () => _simulateSpeech('unrelated different sound'),
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DESKTOP AUDIO CONTROLS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopAudioControls(VocabularyItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_phase == SpeakingPhase.listening) ...[
            ElevatedButton.icon(
              onPressed: _stopSpeaking,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Dừng Ghi Âm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _startSpeaking,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Bắt Đầu Nói'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEnglish,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: _nextItem,
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Bỏ qua từ này',
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE BOTTOM BAR (Thumb-friendly huge mic button)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar(VocabularyItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Row(
        children: [
          // Skip / Previous
          IconButton.filledTonal(
            onPressed: _currentIndex > 0
                ? () {
                    setState(() {
                      _currentIndex--;
                      _phase = SpeakingPhase.ready;
                      _liveRecognizedText = '';
                      _latestResult = null;
                    });
                  }
                : null,
            icon: const Icon(Icons.skip_previous_rounded),
            tooltip: 'Từ trước',
          ),
          const SizedBox(width: 12),

          // Huge Record Microphone Button
          Expanded(
            child: _phase == SpeakingPhase.listening
                ? ElevatedButton.icon(
                    onPressed: _stopSpeaking,
                    icon: const Icon(Icons.stop_rounded, size: 22),
                    label: const Text(
                      'Dừng & Chấm Điểm',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _startSpeaking,
                    icon: const Icon(Icons.mic_rounded, size: 24),
                    label: Text(
                      _phase == SpeakingPhase.result ? 'Nói Lại' : 'Bắt Đầu Nói',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEnglish,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Next button
          IconButton.filled(
            onPressed: _nextItem,
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppColors.borderDark : AppColors.bgLight,
              foregroundColor: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'Từ tiếp theo',
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primaryEnglishLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_off_rounded,
                size: 56,
                color: AppColors.primaryEnglish,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có từ vựng để luyện nói',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thêm từ mới vào Sổ từ vựng cá nhân, hoặc nhấn làm mới danh sách seed data.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay Về Trang Chủ'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEnglish,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI PARTICLE (Custom lightweight visualizer)
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.angle,
    required this.angularV,
    required this.shape,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double angle;
  final double angularV;
  final int shape; // 0=circle, 1=square, 2=rect
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = (p.x + p.vx * progress * 4) * size.width;
      final y = (p.y + p.vy * progress * 3) * size.height;
      if (y > size.height + 20) continue;

      final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0, 1));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + p.angularV * progress * 4);

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        case 1:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
        case 2:
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size * 1.6, height: p.size * 0.7),
            paint,
          );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
