import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../models/srs_progress.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/srs_provider.dart';
import '../widgets/pinyin_text.dart';
import '../widgets/hanzi_canvas_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase 3 — SRS Flashcard Screen (Duolingo-inspired)
//
// Features:
//  • 3D flip card with spring physics (perspective matrix)
//  • Swipe left/right gesture to flip card
//  • Duolingo-style tactile "shelf" rating buttons with press animation
//  • Confetti particle system on session complete
//  • Haptic feedback on every interaction
//  • Slide transition between cards
//  • Session stats (accuracy %, XP earned)
//  • Keyboard shortcuts: Space/Enter flip, 1-4 rate, P/V play TTS
// ─────────────────────────────────────────────────────────────────────────────

class SrsReviewScreen extends ConsumerStatefulWidget {
  final List<VocabularyItem>? customItems;
  final String? title;

  const SrsReviewScreen({super.key, this.customItems, this.title});

  @override
  ConsumerState<SrsReviewScreen> createState() => _SrsReviewScreenState();
}

class _SrsReviewScreenState extends ConsumerState<SrsReviewScreen>
    with TickerProviderStateMixin {

  // ── Flip card animation ──────────────────────────────────────────────────
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // ── Card slide transition (next card) ────────────────────────────────────
  late AnimationController _slideController;
  late Animation<Offset> _slideOutAnim;
  late Animation<double> _slideOutFade;

  // ── Confetti ──────────────────────────────────────────────────────────────
  late AnimationController _confettiController;
  late List<_ConfettiParticle> _particles;

  // ── Rating button press (tactile shelf) ───────────────────────────────────
  final Map<SrsRating, bool> _buttonPressed = {
    SrsRating.again: false,
    SrsRating.hard: false,
    SrsRating.good: false,
    SrsRating.easy: false,
  };

  // ── Session stats ─────────────────────────────────────────────────────────
  int _goodCount = 0;  // again=0, hard=1, good=2, easy=2

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    if (widget.customItems != null && widget.customItems!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(srsProvider.notifier).startCustomSession(widget.customItems!);
      });
    }

    // Flip (3D card rotation on Y axis)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    // Slide-out (card exits screen to left on submit)
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideOutAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.5, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeIn));
    _slideOutFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeIn));

    // Confetti
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _particles = _generateParticles();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // ── Particle generator ────────────────────────────────────────────────────
  List<_ConfettiParticle> _generateParticles() {
    final rng = Random();
    final colors = [
      AppColors.primaryEnglish, AppColors.streakOrange, AppColors.accent,
      AppColors.streakAmber, const Color(0xFFEC4899), const Color(0xFF8B5CF6),
    ];
    return List.generate(80, (_) => _ConfettiParticle(
      x: rng.nextDouble(),
      y: -rng.nextDouble() * 0.3,
      vx: (rng.nextDouble() - 0.5) * 0.3,
      vy: 0.2 + rng.nextDouble() * 0.5,
      color: colors[rng.nextInt(colors.length)],
      size: 5 + rng.nextDouble() * 6,
      angle: rng.nextDouble() * 2 * pi,
      angularV: (rng.nextDouble() - 0.5) * 6,
      shape: rng.nextInt(3),
    ));
  }

  // ── Flip ──────────────────────────────────────────────────────────────────
  void _handleFlip() {
    if (_flipController.isAnimating) return;
    HapticFeedback.lightImpact();
    if (_flipController.isCompleted) {
      _flipController.reverse();
      ref.read(srsProvider.notifier).flipCard();
    } else {
      _flipController.forward();
      ref.read(srsProvider.notifier).flipCard();
    }
  }

  // ── Rating submit with slide-out animation ────────────────────────────────
  void _submitRating(SrsRating rating) async {
    if (_slideController.isAnimating) return;
    HapticFeedback.mediumImpact();

    // Tactile press feedback
    setState(() => _buttonPressed[rating] = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() => _buttonPressed[rating] = false);

    // Track accuracy
    if (rating == SrsRating.good || rating == SrsRating.easy) _goodCount++;

    // Slide out current card
    _slideController.reset();
    await _slideController.forward();
    if (!mounted) return;

    // Commit to provider and reset animations
    _flipController.reset();
    _slideController.reset();
    ref.read(srsProvider.notifier).submitReview(rating);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final srsState = ref.watch(srsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (srsState.isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryEnglish),
        ),
      );
    }

    if (srsState.isSessionCompleted || srsState.currentItem == null) {
      return _buildCelebrationScreen(srsState, isDark);
    }

    final currentItem = srsState.currentItem!;
    final isZh = currentItem.languageCode.toUpperCase() == 'ZH';
    final total = srsState.totalDue;
    final idx = srsState.currentIndex;
    final progressVal = total > 0 ? (idx / total).clamp(0.0, 1.0) : 1.0;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          _handleFlip();
          return KeyEventResult.handled;
        }
        if (srsState.isCardFlipped) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.digit1:
            case LogicalKeyboardKey.numpad1:
              _submitRating(SrsRating.again);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.digit2:
            case LogicalKeyboardKey.numpad2:
              _submitRating(SrsRating.hard);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.digit3:
            case LogicalKeyboardKey.numpad3:
              _submitRating(SrsRating.good);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.digit4:
            case LogicalKeyboardKey.numpad4:
              _submitRating(SrsRating.easy);
              return KeyEventResult.handled;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.keyP ||
            event.logicalKey == LogicalKeyboardKey.keyV) {
          TtsService.instance.speak(
              text: currentItem.word, languageCode: currentItem.languageCode);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        // ── AppBar ─────────────────────────────────────────────────────────
        appBar: _buildAppBar(srsState, isDark, isZh, progressVal, idx, total),

        // ── Body ──────────────────────────────────────────────────────────
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet
                    ? AppBreakpoints.flashcardMaxWidth
                    : double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    // ── Card Stack ────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: !srsState.isCardFlipped ? _handleFlip : null,
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null &&
                              details.primaryVelocity!.abs() > 200) {
                            if (!srsState.isCardFlipped) _handleFlip();
                          }
                        },
                        child: SlideTransition(
                          position: _slideOutAnim,
                          child: FadeTransition(
                            opacity: _slideOutFade,
                            child: _buildFlipCard(currentItem, isZh, isDark, srsState),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Bottom Controls ───────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: srsState.isCardFlipped
                          ? _buildRatingBar(key: const ValueKey('rating'))
                          : _buildFlipCta(isZh: isZh, key: const ValueKey('cta')),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar with animated progress bar ─────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
    SrsState srsState,
    bool isDark,
    bool isZh,
    double progressVal,
    int idx,
    int total,
  ) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ôn tập SRS (SM-2)',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            'Thẻ ${idx + 1} / $total  •  [Space] lật  •  [1-4] đánh giá',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ],
      ),
      actions: [
        // XP badge
        _InfoBadge(
          icon: Icons.bolt_rounded,
          label: '${(_goodCount * 10)} XP',
          color: AppColors.xpCyan,
        ),
        const SizedBox(width: 6),
        // Streak badge
        _InfoBadge(
          icon: Icons.local_fire_department_rounded,
          label: '${srsState.streak}',
          color: AppColors.streakOrange,
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(6),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progressVal),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            backgroundColor: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
            ),
            minHeight: 6,
          ),
        ),
      ),
    );
  }

  // ── 3D Flip Card ───────────────────────────────────────────────────────────
  Widget _buildFlipCard(VocabularyItem item, bool isZh, bool isDark, SrsState srsState) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, _) {
        final angle = _flipAnimation.value * pi;
        final isBack = angle > (pi / 2);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012) // perspective depth
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isBack
              ? Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _buildCardBack(item, isZh, isDark),
                )
              : _buildCardFront(item, isZh, isDark),
        );
      },
    );
  }

  // ── Card Front ─────────────────────────────────────────────────────────────
  Widget _buildCardFront(VocabularyItem item, bool isZh, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Column(
        children: [
          // Colored top accent strip
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                isZh ? AppColors.primaryChineseDark : AppColors.primaryEnglishDark,
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Language mode chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isZh ? Icons.translate_rounded : Icons.abc_rounded,
                          size: 14,
                          color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isZh ? '🇨🇳 Tiếng Trung (HSK)' : '🇺🇸 Tiếng Anh',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Main word — LARGE
                  Text(
                    item.word,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: isZh ? 64 : 44,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TTS button
                  _TtsButton(
                    text: item.word,
                    languageCode: item.languageCode,
                    color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                  ),

                  const Spacer(),

                  // Swipe hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 15,
                        color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Chạm hoặc vuốt để lật',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Back ──────────────────────────────────────────────────────────────
  Widget _buildCardBack(VocabularyItem item, bool isZh, bool isDark) {
    final accent = isZh ? AppColors.primaryChinese : AppColors.primaryEnglish;
    final accentLight = isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Column(
        children: [
          // Accent top strip (brighter = back of card)
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                accent,
                accent.withValues(alpha: 0.5),
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Word + audio row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.word,
                          style: GoogleFonts.outfit(
                            fontSize: isZh ? 38 : 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          ),
                        ),
                      ),
                      _TtsButton(
                        text: item.word,
                        languageCode: item.languageCode,
                        color: accent,
                        size: 22,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Phonetic
                  if (isZh && item.phonetic != null)
                    PinyinText(pinyin: item.phonetic!, fontSize: 18)
                  else if (!isZh && item.phonetic != null)
                    Text(
                      '[${item.phonetic}]',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Courier',
                        color: AppColors.textLightMuted,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Hán-Việt badge
                  if (isZh && item.hanViet != null && item.hanViet!.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.hanVietBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.hanVietBorder),
                          ),
                          child: Text(
                            'HV: ${item.hanViet}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.hanVietText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => HanziCanvasDialog.show(
                            context,
                            hanzi: item.word,
                            pinyin: item.phonetic,
                            hanViet: item.hanViet,
                            meaningVi: item.meaningVi,
                          ),
                          icon: const Icon(Icons.draw_rounded, size: 14),
                          label: const Text('Viết thử', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Meaning block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nghĩa tiếng Việt',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.meaningVi,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Character breakdown (Chinese)
                  if (isZh && item.breakdown != null && item.breakdown!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.dashboard_customize_outlined, size: 14, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.breakdown}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Collocations (English)
                  if (!isZh && item.collocations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.collocations.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(c, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],

                  // Examples
                  if (item.examples.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.format_quote_rounded, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Câu ví dụ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ...item.examples.take(2).map((ex) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                            ),
                          ),
                          if (isZh && ex.pinyin != null)
                            Text(ex.pinyin!,
                                style: const TextStyle(fontSize: 11, color: AppColors.textLightMuted)),
                          Text(ex.vi,
                              style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Flip CTA Button ────────────────────────────────────────────────────────
  Widget _buildFlipCta({required Key key, required bool isZh}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      child: _TactileButton(
        label: 'Lật thẻ để xem đáp án',
        icon: Icons.flip_camera_android_rounded,
        faceColor: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
        shelfColor: isZh ? AppColors.primaryChineseDark : AppColors.primaryEnglishDark,
        onTap: _handleFlip,
      ),
    );
  }

  // ── SM-2 Rating Bar ────────────────────────────────────────────────────────
  Widget _buildRatingBar({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bạn nhớ bao nhiêu?  •  [1] [2] [3] [4]',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textLightMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TactileButton(
                label: 'Quên',
                sublabel: '< 10p',
                keyHint: '1',
                faceColor: AppColors.srsAgain,
                shelfColor: AppColors.srsAgainShelf,
                isPressed: _buttonPressed[SrsRating.again]!,
                onTap: () => _submitRating(SrsRating.again),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TactileButton(
                label: 'Khó',
                sublabel: '× 1.2',
                keyHint: '2',
                faceColor: AppColors.srsHard,
                shelfColor: AppColors.srsHardShelf,
                isPressed: _buttonPressed[SrsRating.hard]!,
                onTap: () => _submitRating(SrsRating.hard),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TactileButton(
                label: 'Tốt',
                sublabel: '× 2.5',
                keyHint: '3',
                faceColor: AppColors.srsGood,
                shelfColor: AppColors.srsGoodShelf,
                isPressed: _buttonPressed[SrsRating.good]!,
                onTap: () => _submitRating(SrsRating.good),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TactileButton(
                label: 'Dễ',
                sublabel: '× 3.5',
                keyHint: '4',
                faceColor: AppColors.srsEasy,
                shelfColor: AppColors.srsEasyShelf,
                isPressed: _buttonPressed[SrsRating.easy]!,
                onTap: () => _submitRating(SrsRating.easy),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Celebration / Session Complete ─────────────────────────────────────────
  Widget _buildCelebrationScreen(SrsState srsState, bool isDark) {
    final total = srsState.totalDue > 0 ? srsState.totalDue : 1;
    final accuracy = (_goodCount / total * 100).clamp(0, 100).round();
    final xp = _goodCount * 10;

    // Trigger confetti on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_confettiController.isAnimating) {
        _confettiController.forward(from: 0);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Confetti layer
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _confettiController.value,
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Trophy icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.streakAmber, AppColors.streakOrange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.streakOrange.withValues(alpha: 0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      accuracy >= 80 ? '🌟 Xuất sắc!' :
                      accuracy >= 50 ? '👍 Làm tốt lắm!' : '💪 Cố lên nào!',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Chuỗi học: ${srsState.streak} ngày liên tiếp 🔥',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.streakOrange,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatCard(
                          icon: Icons.check_circle_rounded,
                          value: '$accuracy%',
                          label: 'Chính xác',
                          color: AppColors.successGreen,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.bolt_rounded,
                          value: '+$xp',
                          label: 'XP kiếm được',
                          color: AppColors.xpCyan,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.style_rounded,
                          value: '${srsState.totalDue}',
                          label: 'Thẻ ôn tập',
                          color: AppColors.primaryEnglish,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // SM-2 info chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.memory_rounded,
                              color: AppColors.primaryEnglish, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Thuật toán SM-2 đã cập nhật lịch ôn tập',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _goodCount = 0;
                              _particles = _generateParticles();
                            });
                            ref.read(srsProvider.notifier).initSrs();
                          },
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('Ôn lại'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(srsProvider.notifier).initSrs();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: const Text('Về trang chủ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryEnglish,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TACTILE BUTTON  (Duolingo 3D shelf effect)
// ─────────────────────────────────────────────────────────────────────────────
class _TactileButton extends StatefulWidget {
  const _TactileButton({
    required this.label,
    required this.faceColor,
    required this.shelfColor,
    required this.onTap,
    this.sublabel,
    this.keyHint,
    this.icon,
    this.isPressed = false,
  });

  final String label;
  final String? sublabel;
  final String? keyHint;
  final IconData? icon;
  final Color faceColor;
  final Color shelfColor;
  final VoidCallback onTap;
  final bool isPressed;

  @override
  State<_TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<_TactileButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _down || widget.isPressed;
    // Shelf is 4px, pressing slides face down by 4px
    const shelfHeight = 4.0;
    final topOffset = pressed ? shelfHeight : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            // Shelf (bottom layer)
            Positioned(
              left: 0,
              right: 0,
              top: shelfHeight,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.shelfColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Face (top layer)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: topOffset,
              height: 52 - shelfHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.faceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.keyHint != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.keyHint!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.sublabel != null) ...[
                        Text(
                          widget.sublabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TTS BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _TtsButton extends StatefulWidget {
  const _TtsButton({
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
  State<_TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends State<_TtsButton>
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
        text: widget.text, languageCode: widget.languageCode);
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

// ─────────────────────────────────────────────────────────────────────────────
// INFO BADGE  (streak / XP in appbar)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CARD  (accuracy / XP / cards on celebration screen)
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: AppColors.shadowLevel1,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI PARTICLE  (data class)
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

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI PAINTER  (draws animated particles)
// ─────────────────────────────────────────────────────────────────────────────
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
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size * 0.7),
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
