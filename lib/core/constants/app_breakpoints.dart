// Breakpoints & layout constants for Vocivo adaptive layout.
// Follows the design system spec:
//   Mobile  < 600px  : 4-col, margin 16px, bottom nav
//   Tablet  600–1024 : 8-col, margin 24px, nav rail or dual-pane
//   Desktop > 1024px : 12-col, max 1200px, sidebar 260px

class AppBreakpoints {
  AppBreakpoints._();

  // --- Screen width thresholds ---
  static const double mobile = 0;
  static const double largeMobile = 480;   // Landscape phones / phablets
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double largeDesktop = 1280; // Wide desktop → expanded sidebar

  // --- Sidebar / nav rail widths ---
  static const double sidebarWidth = 260.0;
  static const double navRailWidth = 72.0;

  // --- Max content width for desktop ---
  static const double maxContentWidth = 1200.0;

  // --- Master list panel (desktop 3-column layout) ---
  static const double masterListWidth = 460.0;

  // --- Margins per breakpoint ---
  static const double marginMobile = 16.0;
  static const double marginTablet = 24.0;
  static const double marginDesktop = 40.0;

  // --- Gutters ---
  static const double gutterMobile = 16.0;
  static const double gutterDesktop = 24.0;

  // --- Bottom safe area minimum ---
  static const double bottomNavMinHeight = 64.0;

  // --- Card / modal constraints ---
  static const double flashcardMaxWidth = 640.0;
  static const double dialogMaxWidth = 500.0;
  static const double detailPanelMinWidth = 320.0;
}
