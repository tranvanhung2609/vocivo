import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/update_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'widgets/update/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Edge-to-edge rendering (transparent status/nav bars) ───────
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

class VocivoApp extends ConsumerStatefulWidget {
  const VocivoApp({super.key});

  @override
  ConsumerState<VocivoApp> createState() => _VocivoAppState();
}

class _VocivoAppState extends ConsumerState<VocivoApp> {
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    // Auto-check update sau khi app khởi động xong (delay 3s tránh block UI)
    _autoCheckTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _autoCheckUpdate();
      }
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoCheckUpdate() async {
    if (!mounted) return;
    await ref.read(updateProvider.notifier).autoCheck();
    // Nếu có update và app đã load xong settings
    if (mounted && ref.read(updateProvider).status == UpdateStatus.available) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await UpdateDialog.show(ctx);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vocivo — Ghi nhớ từ vựng & Tự tin luyện nói',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      // ── Smooth scroll behavior for desktop (show scrollbar, better physics)
      scrollBehavior: _VocivoScrollBehavior(),
      // ── Text scale clamp + theme-aware system bar sync ──────────
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Sync system UI overlay style with current theme
        SystemChrome.setSystemUIOverlayStyle(
          isDark
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                ),
        );

        return MediaQuery(
          data: mq.copyWith(
            // Clamp text scale: 0.85–1.25 (tighter max to avoid layout overflow)
            textScaler: TextScaler.linear(
              mq.textScaler.scale(1.0).clamp(0.85, 1.25),
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

/// Custom scroll behavior: enables mouse drag scrolling on Desktop,
/// shows scrollbars, uses smooth physics on all platforms.
class _VocivoScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Show scrollbar on desktop platforms
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return Scrollbar(
        controller: details.controller,
        child: child,
      );
    }
    return child;
  }
}

/// Global navigator key để show dialog từ ngoài widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
