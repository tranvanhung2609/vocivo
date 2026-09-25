import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Edge-to-edge rendering (transparent status/nav bars) ───────
  // This allows content to draw behind system bars; each screen uses
  // SafeArea to avoid overlap. Supports all notch types:
  //   tai thỏ, chấm ruồi, giọt nước, Dynamic Island clones.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // ── Supported orientations ────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ── Platform-specific database initialization ─────────────────
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── Pre-initialize database ───────────────────────────────────
  try {
    await AppDatabase.instance.database;
  } catch (e) {
    debugPrint('Database initialization warning: $e');
  }

  runApp(
    const ProviderScope(
      child: VocivoApp(),
    ),
  );
}

class VocivoApp extends ConsumerWidget {
  const VocivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Vocivo — Ghi nhớ từ vựng & Tự tin luyện nói',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      // Ensure text scales reasonably on accessibility settings
      builder: (context, child) {
        // Giới hạn text scale để tránh text quá to/nhỏ trên các thiết bị accessibility
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              mq.textScaler.scale(1.0).clamp(0.85, 1.3),
            ),
          ),
          child: child!,
        );
      },
      home: settings.isLoaded && !settings.hasCompletedOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }
}
