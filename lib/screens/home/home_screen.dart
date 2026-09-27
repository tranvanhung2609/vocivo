import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../v2/app_shell.dart';
import 'legacy_home_screen.dart';

/// Entry point của trải nghiệm Vocivo V2.
///
/// Điều hướng chính sống trong một app shell cố định để trạng thái của Hôm nay,
/// Lộ trình, Luyện tập, Sổ từ và Tiến bộ không bị reset khi chuyển mục.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useV2 = ref.watch(
      settingsProvider.select((state) => state.useV2Experience),
    );
    return useV2 ? const VocivoAppShell() : const LegacyHomeScreen();
  }
}
