import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';

/// Utility class for responsive layout decisions.
class ResponsiveHelper {
  ResponsiveHelper._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= AppBreakpoints.tablet && w < AppBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

  /// Horizontal content padding adapted to screen size.
  static double horizontalMargin(BuildContext context) {
    if (isDesktop(context)) return AppBreakpoints.marginDesktop;
    if (isTablet(context)) return AppBreakpoints.marginTablet;
    return AppBreakpoints.marginMobile;
  }

  /// Safe content padding that accounts for system insets (notch, status bar,
  /// home indicator, keyboard, etc.) on ALL Android notch types:
  ///   - Tai thỏ (wide notch)
  ///   - Chấm ruồi (punch-hole)
  ///   - Giọt nước (dewdrop)
  ///   - Dynamic Island clones
  static EdgeInsets safeContentPadding(BuildContext context) {
    final mq = MediaQuery.of(context);
    final hMargin = horizontalMargin(context);
    return EdgeInsets.only(
      top: mq.viewPadding.top,
      bottom: max(AppBreakpoints.marginMobile, mq.viewPadding.bottom),
      left: hMargin,
      right: hMargin,
    );
  }

  /// Bottom nav / bottom bar safe padding.
  static double bottomSafeArea(BuildContext context) {
    final mq = MediaQuery.of(context);
    return max(0.0, mq.viewPadding.bottom);
  }

  /// Return different values based on current breakpoint.
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }
}

/// Builds different layouts based on screen width breakpoints.
///
/// Usage:
/// ```dart
/// AdaptiveLayout(
///   mobile: MobileView(),
///   tablet: TabletView(),      // optional
///   desktop: DesktopView(),    // optional
/// )
/// ```
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.desktop && desktop != null) return desktop!;
    if (width >= AppBreakpoints.tablet && tablet != null) return tablet!;
    return mobile;
  }
}

/// Adaptive navigation that switches between:
///   Mobile  → [NavigationBar] at the bottom
///   Tablet  → [NavigationRail] (compact, icons only)
///   Desktop → [NavigationRail] with labels (extended) — or use custom sidebar
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.body,
    required this.selectedIndex,
    required this.destinations,
    this.onDestinationSelected,
    this.floatingActionButton,
    this.appBar,
    super.key,
  });

  final Widget body;
  final int selectedIndex;
  final List<AdaptiveDestination> destinations;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final isTabletPlus = !ResponsiveHelper.isMobile(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isTabletPlus) {
      // Tablet & Desktop: NavigationRail on the left
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                extended: isDesktop,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                minWidth: AppBreakpoints.navRailWidth,
                minExtendedWidth: AppBreakpoints.sidebarWidth,
                destinations: destinations
                    .map((d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon ?? d.icon,
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: body),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // Mobile: NavigationBar at the bottom
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations
              .map((d) => NavigationDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon ?? d.icon,
                    label: d.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// Data class for navigation destinations used in [AdaptiveScaffold].
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  final String? badge;
}
