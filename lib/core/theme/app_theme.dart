import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Application theme following the Vocivo design system.
///
/// Typography: Plus Jakarta Sans (UI) — already loaded via google_fonts.
/// Hanzi display: Noto Sans SC (system fallback on Android; explicit on web).
/// Font scale: headline-xl 36px/800 → body-md 15px/400 → label-sm 11px/700.
class AppTheme {
  AppTheme._();

  // ────────────────────────────────────────────────────────────────
  // LIGHT THEME
  // ────────────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryEnglish,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryEnglishLight,
      onPrimaryContainer: AppColors.primaryEnglishDeep,
      secondary: AppColors.streakAmber,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.streakOrangeLight,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.accentLight,
      surface: AppColors.bgLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF1F5F9),
      surfaceContainer: AppColors.bgLight,
      surfaceContainerHigh: AppColors.borderLight,
      error: AppColors.errorRed,
      onError: Colors.white,
      onSurface: AppColors.textLightPrimary,
      onSurfaceVariant: AppColors.textLightSecondary,
      outline: AppColors.borderLight,
      outlineVariant: const Color(0xFFCBD5E1),
    ),
    scaffoldBackgroundColor: AppColors.bgLight,

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textLightPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: AppColors.borderLight,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textLightPrimary,
      ),
      surfaceTintColor: Colors.transparent,
    ),

    // ── Cards ────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    // ── Elevated Buttons ─────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // ── Outlined Buttons ─────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.borderLight, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Text Buttons ─────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryEnglish,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Input Decoration ─────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.borderLight, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.borderLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.primaryEnglish, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textLightMuted,
        fontSize: 14,
      ),
    ),

    // ── Chips ────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgLight,
      selectedColor: AppColors.primaryEnglishLight,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight),
      ),
    ),

    // ── Bottom Navigation Bar ────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.borderLight,
      elevation: 0,
      indicatorColor: AppColors.primaryEnglishLight,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primaryEnglish, size: 24);
        }
        return const IconThemeData(color: AppColors.textLightMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryEnglish,
          );
        }
        return GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textLightMuted,
        );
      }),
    ),

    // ── Navigation Rail ──────────────────────────────────────────
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme:
          const IconThemeData(color: AppColors.primaryEnglish, size: 24),
      unselectedIconTheme:
          const IconThemeData(color: AppColors.textLightMuted, size: 24),
      indicatorColor: AppColors.primaryEnglishLight,
      selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryEnglish,
      ),
      unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: AppColors.textLightMuted,
      ),
    ),

    // ── Divider ──────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
      space: 1,
    ),

    // ── Bottom Sheet ─────────────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      dragHandleColor: Color(0xFFCBD5E1),
      dragHandleSize: Size(48, 4),
    ),

    // ── Dialog ───────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textLightPrimary,
      ),
    ),

    // ── Typography ───────────────────────────────────────────────
    textTheme: _buildTextTheme(isDark: false),
  );

  // ────────────────────────────────────────────────────────────────
  // DARK THEME
  // ────────────────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF4EDEA3),       // Inverse primary from spec
      onPrimary: AppColors.primaryEnglishDeep,
      primaryContainer: const Color(0xFF005236),
      onPrimaryContainer: const Color(0xFF6FFBBE),
      secondary: AppColors.streakAmber,
      onSecondary: const Color(0xFF2A1700),
      secondaryContainer: const Color(0xFF653E00),
      tertiary: const Color(0xFFADC6FF),
      onTertiary: const Color(0xFF001A42),
      surface: AppColors.bgDark,
      surfaceContainerLowest: AppColors.surfaceDark1,
      surfaceContainerLow: const Color(0xFF162032),
      surfaceContainer: AppColors.surfaceDark2,
      surfaceContainerHigh: AppColors.surfaceDark3,
      error: AppColors.errorRed,
      onError: Colors.white,
      onSurface: AppColors.textDarkPrimary,
      onSurfaceVariant: AppColors.textDarkSecondary,
      outline: AppColors.borderDark,
      outlineVariant: const Color(0xFF3D506A),
    ),
    scaffoldBackgroundColor: AppColors.bgDark,

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceDark1,
      foregroundColor: AppColors.textDarkPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textDarkPrimary,
      ),
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF4EDEA3), width: 2),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textDarkMuted,
        fontSize: 14,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cardDark,
      selectedColor: const Color(0xFF005236),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: AppColors.cardDark.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: const Color(0xFF005236),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF4EDEA3), size: 24);
        }
        return const IconThemeData(color: AppColors.textDarkMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4EDEA3),
          );
        }
        return GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: AppColors.textDarkMuted,
        );
      }),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.cardDark,
      selectedIconTheme:
          const IconThemeData(color: Color(0xFF4EDEA3), size: 24),
      unselectedIconTheme:
          const IconThemeData(color: AppColors.textDarkMuted, size: 24),
      indicatorColor: const Color(0xFF005236),
      selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF4EDEA3),
      ),
      unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: AppColors.textDarkMuted,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
      space: 1,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      dragHandleColor: Color(0xFF475569),
      dragHandleSize: Size(48, 4),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDarkPrimary,
      ),
    ),

    textTheme: _buildTextTheme(isDark: true),
  );

  // ────────────────────────────────────────────────────────────────
  // SHARED TEXT THEME
  // Typography follows the design spec type scale with Plus Jakarta Sans.
  // ────────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme({required bool isDark}) {
    final baseColor = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final mutedColor = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final base = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      // headline-xl: 36px/800 (desktop brand heading)
      displayLarge: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02 * 36,
        color: baseColor,
      ),
      // headline-lg: 28px/700
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01 * 28,
        color: baseColor,
      ),
      // headline-md: 20px/700
      displaySmall: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      // titleLarge (AppBar titles, card headers): 20px/700
      titleLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: baseColor,
      ),
      // titleMedium (section headers): 16px/600
      titleMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: baseColor,
      ),
      // titleSmall (label headers): 14px/600
      titleSmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: baseColor,
      ),
      // bodyLarge: 18px/400
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      // bodyMedium: 15px/400 (default body)
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
      ),
      // bodySmall: 13px/400
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: mutedColor,
      ),
      // labelLarge: 14px/600
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      // labelMedium: 12px/600
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02 * 12,
        color: mutedColor,
      ),
      // labelSmall: 11px/700 (badges, chips)
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.04 * 11,
        color: mutedColor,
      ),
    );
  }
}
