import 'package:flutter/material.dart';

/// Color tokens aligned with the Vocivo design system.
class AppColors {
  AppColors._();

  // ────────────────────────────────────────────────────────────────
  // PRIMARY — Emerald Jade (English mode & brand identity)
  // ────────────────────────────────────────────────────────────────
  static const Color primaryEnglish = Color(0xFF10B981);       // Emerald 500
  static const Color primaryEnglishDark = Color(0xFF059669);   // Emerald 600 (tactile shadow)
  static const Color primaryEnglishDeep = Color(0xFF006C49);   // Deep jade
  static const Color primaryEnglishLight = Color(0xFFECFDF5);  // Emerald 50

  // ────────────────────────────────────────────────────────────────
  // SECONDARY — Vivid Amber / Tangerine (streaks & gamification)
  // ────────────────────────────────────────────────────────────────
  static const Color primaryChinese = Color(0xFF10B981);       // Same emerald for brand unity
  static const Color primaryChineseDark = Color(0xFF059669);
  static const Color primaryChineseDeep = Color(0xFF006C49);
  static const Color primaryChineseLight = Color(0xFFECFDF5);

  // ────────────────────────────────────────────────────────────────
  // ACCENT — Scholastic Slate Blue (grammar, CEFR, audio)
  // ────────────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF3B82F6);               // Blue 500
  static const Color accentDeep = Color(0xFF005AC2);
  static const Color accentLight = Color(0xFFEFF6FF);

  // ────────────────────────────────────────────────────────────────
  // GAMIFICATION — Streak & XP
  // ────────────────────────────────────────────────────────────────
  static const Color streakOrange = Color(0xFFF97316);         // Orange 500
  static const Color streakOrangeDeep = Color(0xFFEA580C);     // Orange 600
  static const Color streakOrangeLight = Color(0xFFFFF7ED);    // Orange 50
  static const Color streakAmber = Color(0xFFF59E0B);          // Amber 400
  static const Color streakAmberDeep = Color(0xFFD97706);      // Amber 600
  static const Color xpCyan = Color(0xFF06B6D4);

  // ────────────────────────────────────────────────────────────────
  // FEEDBACK
  // ────────────────────────────────────────────────────────────────
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenLight = Color(0xFFECFDF5);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedLight = Color(0xFFFEF2F2);
  static const Color crimsonAccent = Color(0xFFE11D48);

  // ────────────────────────────────────────────────────────────────
  // SRS SM-2 BUTTON COLORS
  // ────────────────────────────────────────────────────────────────
  static const Color srsAgain = Color(0xFFEF4444);   // Red   — Quên
  static const Color srsHard  = Color(0xFFF97316);   // Orange — Khó
  static const Color srsGood  = Color(0xFF10B981);   // Emerald — Tốt
  static const Color srsEasy  = Color(0xFF3B82F6);   // Blue  — Dễ

  // Tactile "shelf" shadows for SRS buttons (Vocivo 3D effect)
  static const Color srsAgainShelf = Color(0xFFB91C1C);
  static const Color srsHardShelf  = Color(0xFFEA580C);
  static const Color srsGoodShelf  = Color(0xFF059669);
  static const Color srsEasyShelf  = Color(0xFF1D4ED8);

  // ────────────────────────────────────────────────────────────────
  // PINYIN TONE COLORS (Standard 4-tone educational colors)
  // ────────────────────────────────────────────────────────────────
  static const Color pinyinTone1 = Color(0xFFEF4444); // Tone 1 (ā) — Crimson
  static const Color pinyinTone2 = Color(0xFF10B981); // Tone 2 (á) — Emerald
  static const Color pinyinTone3 = Color(0xFF3B82F6); // Tone 3 (ǎ) — Cobalt
  static const Color pinyinTone4 = Color(0xFF8B5CF6); // Tone 4 (à) — Violet
  static const Color pinyinTone0 = Color(0xFF64748B); // Neutral     — Slate

  // ────────────────────────────────────────────────────────────────
  // ACADEMIC CLASSIFICATION BADGES
  // ────────────────────────────────────────────────────────────────
  // Hán-Việt Cognate Tag
  static const Color hanVietBg     = Color(0xFFECFDF5);
  static const Color hanVietBorder = Color(0xFFA7F3D0);
  static const Color hanVietText   = Color(0xFF065F46);

  // CEFR Level (A1–C2)
  static const Color cefrBg     = Color(0xFFEFF6FF);
  static const Color cefrBorder = Color(0xFFBFDBFE);
  static const Color cefrText   = Color(0xFF1E40AF);

  // HSK Level (HSK 1–9)
  static const Color hskBg     = Color(0xFFFEF3C7);
  static const Color hskBorder = Color(0xFFFDE68A);
  static const Color hskText   = Color(0xFF92400E);

  // ────────────────────────────────────────────────────────────────
  // NEUTRAL — LIGHT MODE
  // ────────────────────────────────────────────────────────────────
  static const Color bgLight          = Color(0xFFF8FAFC); // Canvas Tint
  static const Color surfaceLight     = Color(0xFFFAF8FF); // Surface (design spec)
  static const Color cardLight        = Color(0xFFFFFFFF); // Elevated Surface / Pure Milk
  static const Color textLightPrimary = Color(0xFF0F172A); // Deep Slate
  static const Color textLightSecondary = Color(0xFF475569);
  static const Color textLightMuted   = Color(0xFF64748B); // Muted Slate
  static const Color borderLight      = Color(0xFFE2E8F0); // Subtle Slate Line

  // ────────────────────────────────────────────────────────────────
  // NEUTRAL — DARK MODE
  // ────────────────────────────────────────────────────────────────
  static const Color bgDark           = Color(0xFF0B1120); // Slightly deeper base
  static const Color cardDark         = Color(0xFF1E293B); // z=2 elevated
  static const Color surfaceDark1     = Color(0xFF162032); // z=1 (subtle lift)
  static const Color surfaceDark2     = Color(0xFF1E293B); // z=2 (= cardDark)
  static const Color surfaceDark3     = Color(0xFF243349); // z=3 (dropdowns, popovers)
  static const Color textDarkPrimary  = Color(0xFFF1F5F9); // Slightly warmer
  static const Color textDarkSecondary = Color(0xFFCBD5E1);
  static const Color textDarkMuted    = Color(0xFF64748B);
  static const Color borderDark       = Color(0xFF2E4060); // Slightly brighter border

  // ────────────────────────────────────────────────────────────────
  // ELEVATION SHADOWS (design spec level system)
  // ────────────────────────────────────────────────────────────────
  static List<BoxShadow> shadowLevel1 = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
      spreadRadius: -1,
    ),
  ];

  static List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: const Color(0xFF10B981).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  // Dark mode shadows — deeper for better card separation
  static List<BoxShadow> shadowLevel1Dark = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.22),
      blurRadius: 6,
      offset: const Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  static List<BoxShadow> shadowLevel2Dark = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: const Color(0xFF10B981).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLevel3 = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, 20),
      spreadRadius: -8,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  // ────────────────────────────────────────────────────────────────
  // HELPER — Pinyin tone detection & coloring
  // ────────────────────────────────────────────────────────────────
  static Color getPinyinToneColor(String syllable) {
    if (syllable.contains(RegExp(r'[āēīōūǖĀĒĪŌŪǕ]'))) return pinyinTone1;
    if (syllable.contains(RegExp(r'[áéíóúǘÁÉÍÓÚǗ]'))) return pinyinTone2;
    if (syllable.contains(RegExp(r'[ǎěǐǒǔǚǍĚǏǑǓǙ]'))) return pinyinTone3;
    if (syllable.contains(RegExp(r'[àèìòùǜÀÈÌÒÙǛ]'))) return pinyinTone4;
    return pinyinTone0;
  }
}
